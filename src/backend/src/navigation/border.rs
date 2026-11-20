//! Routes stay in the countries whose routing packages are installed
//! (Michael 2026-11-20).
//!
//! A country routing package (`carnine-install-maps --package routing-<land>`)
//! holds every tile that touches the country. Valhalla puts motorways and main
//! roads into large tiles (level 0: 4°, level 1: 1°), so those tiles also carry
//! the main roads of the neighbours, without their side roads and without a
//! map. With Germany and Austria installed, Berlin–Vienna then ran through the
//! Czech Republic (flutter-local-map, 2026-11-20).
//!
//! Each package brings its country's border as a Geofabrik `.poly`. A route
//! is computed as before; only when it leaves the area of the installed
//! countries is it computed again, with thin rings ("slits") along the border
//! where it left passed to Valhalla as `exclude_polygons`. Every road leaving
//! there crosses a slit and is closed; the inside stays untouched. Sending
//! all slits with every route cost 1.3 s per route on a Pi 4, these few cost
//! next to nothing.
//!
//! Without packages (a whole-area `valhalla_tiles.tar`) nothing of this runs.

use std::collections::BTreeSet;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::SystemTime;

use serde_json::{json, Value};
use tracing::{info, warn};

/// Width of a slit; any road crossing the border line crosses it.
const SLIT_WIDTH_M: f64 = 15.0;
/// Border points per slit; Valhalla checks each ring against the edges of the
/// bins it touches, small rings keep that cheap.
const SLIT_POINTS: usize = 12;
/// Route points closer together than this are not all checked.
const CHECK_SPACING_M: f64 = 300.0;
const EARTH_RADIUS_M: f64 = 6_371_008.8;

/// A ring of a `.poly`, as (longitude, latitude).
#[derive(Debug, Clone)]
struct Ring {
    hole: bool,
    points: Vec<(f64, f64)>,
    bbox: BBox,
}

#[derive(Debug, Clone, Copy, PartialEq)]
struct BBox {
    min_lon: f64,
    min_lat: f64,
    max_lon: f64,
    max_lat: f64,
}

impl BBox {
    fn of(points: &[(f64, f64)]) -> Self {
        let mut bbox = BBox {
            min_lon: f64::INFINITY,
            min_lat: f64::INFINITY,
            max_lon: f64::NEG_INFINITY,
            max_lat: f64::NEG_INFINITY,
        };
        for &(lon, lat) in points {
            bbox.min_lon = bbox.min_lon.min(lon);
            bbox.min_lat = bbox.min_lat.min(lat);
            bbox.max_lon = bbox.max_lon.max(lon);
            bbox.max_lat = bbox.max_lat.max(lat);
        }
        bbox
    }

    fn contains(&self, lon: f64, lat: f64) -> bool {
        (self.min_lon..=self.max_lon).contains(&lon) && (self.min_lat..=self.max_lat).contains(&lat)
    }

    /// Distance from a point to the box in metres, 0 inside.
    fn distance_m(&self, lon: f64, lat: f64) -> f64 {
        let near_lon = lon.clamp(self.min_lon, self.max_lon);
        let near_lat = lat.clamp(self.min_lat, self.max_lat);
        distance_m((lat, lon), (near_lat, near_lon))
    }
}

/// One country's border from its Geofabrik `.poly`.
#[derive(Debug, Clone)]
pub struct Country {
    name: String,
    rings: Vec<Ring>,
}

impl Country {
    /// Reads the `.poly` format: a name line, then sections of
    /// "lon lat" lines each closed by END (a section named `!…` is a hole),
    /// and a final END.
    pub fn parse(name: &str, text: &str) -> Result<Self, String> {
        let mut lines = text.lines().map(str::trim).filter(|line| !line.is_empty());
        lines.next().ok_or("empty .poly")?;
        let mut rings = Vec::new();
        let mut current: Option<(bool, Vec<(f64, f64)>)> = None;
        for line in lines {
            if line == "END" {
                match current.take() {
                    Some((hole, points)) => {
                        if points.len() < 3 {
                            return Err(format!("ring with {} points", points.len()));
                        }
                        let bbox = BBox::of(&points);
                        rings.push(Ring { hole, points, bbox });
                    }
                    None => break,
                }
                continue;
            }
            match current.as_mut() {
                None => current = Some((line.starts_with('!'), Vec::new())),
                Some((_, points)) => {
                    let mut values = line.split_whitespace().map(str::parse::<f64>);
                    match (values.next(), values.next()) {
                        (Some(Ok(lon)), Some(Ok(lat)))
                            if (-180.0..=180.0).contains(&lon) && (-90.0..=90.0).contains(&lat) =>
                        {
                            points.push((lon, lat))
                        }
                        _ => return Err(format!("not a coordinate: {line}")),
                    }
                }
            }
        }
        if current.is_some() {
            return Err("ring without END".to_string());
        }
        if !rings.iter().any(|ring| !ring.hole) {
            return Err("no outer ring".to_string());
        }
        Ok(Self {
            name: name.to_string(),
            rings,
        })
    }

    fn contains(&self, lon: f64, lat: f64) -> bool {
        let inside =
            |ring: &Ring| ring.bbox.contains(lon, lat) && inside_ring(lon, lat, &ring.points);
        self.rings.iter().any(|ring| !ring.hole && inside(ring))
            && !self.rings.iter().any(|ring| ring.hole && inside(ring))
    }
}

fn inside_ring(x: f64, y: f64, ring: &[(f64, f64)]) -> bool {
    let mut inside = false;
    let mut j = ring.len() - 1;
    for i in 0..ring.len() {
        let (xi, yi) = ring[i];
        let (xj, yj) = ring[j];
        if (yi > y) != (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi {
            inside = !inside;
        }
        j = i;
    }
    inside
}

/// Great-circle distance between two (lat, lon) points.
pub fn distance_m(a: (f64, f64), b: (f64, f64)) -> f64 {
    let (lat1, lat2) = (a.0.to_radians(), b.0.to_radians());
    let d_lat = lat2 - lat1;
    let d_lon = (b.1 - a.1).to_radians();
    let h = (d_lat / 2.0).sin().powi(2) + lat1.cos() * lat2.cos() * (d_lon / 2.0).sin().powi(2);
    2.0 * EARTH_RADIUS_M * h.sqrt().asin()
}

/// A thin ring along a piece of the outer border.
#[derive(Debug, Clone, PartialEq)]
pub struct Slit {
    /// Closed ring as (longitude, latitude).
    ring: Vec<(f64, f64)>,
    /// The piece of border it follows, as (longitude, latitude).
    line: Vec<(f64, f64)>,
    bbox: BBox,
}

impl Slit {
    /// Distance from a point to the piece of border, in metres. A slit may
    /// turn round a corner of a coarse border, so its box says little.
    fn distance_m(&self, lon: f64, lat: f64, within_m: f64) -> f64 {
        if self.bbox.distance_m(lon, lat) > within_m {
            return f64::INFINITY;
        }
        self.line
            .windows(2)
            .map(|pair| segment_distance_m((lon, lat), pair[0], pair[1]))
            .fold(f64::INFINITY, f64::min)
    }
}

/// Distance from p to the segment a–b, all (lon, lat), on a plane through p
/// (fine for the few kilometres that matter here).
fn segment_distance_m(p: (f64, f64), a: (f64, f64), b: (f64, f64)) -> f64 {
    let k = p.1.to_radians().cos();
    // R·π/180: metres per degree of latitude.
    let metres_per_degree = EARTH_RADIUS_M.to_radians();
    let to_xy = |q: (f64, f64)| {
        (
            (q.0 - p.0) * k * metres_per_degree,
            (q.1 - p.1) * metres_per_degree,
        )
    };
    let (ax, ay) = to_xy(a);
    let (bx, by) = to_xy(b);
    let (dx, dy) = (bx - ax, by - ay);
    let len2 = dx * dx + dy * dy;
    let t = if len2 > 0.0 {
        (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0)
    } else {
        0.0
    };
    (ax + t * dx).hypot(ay + t * dy)
}

/// The installed countries and the slits along their outer border: the
/// parts of each border that lie in no other installed country.
#[derive(Debug, Clone)]
pub struct LoadedArea {
    countries: Vec<Country>,
    slits: Vec<Slit>,
}

impl LoadedArea {
    pub fn new(countries: Vec<Country>) -> Self {
        let mut slits = Vec::new();
        for (index, country) in countries.iter().enumerate() {
            let others: Vec<&Country> = countries
                .iter()
                .enumerate()
                .filter(|(other, _)| *other != index)
                .map(|(_, country)| country)
                .collect();
            for ring in &country.rings {
                for run in runs_outside(&ring.points, &others) {
                    slits.extend(slits_along(&run));
                }
            }
        }
        Self { countries, slits }
    }

    pub fn country_names(&self) -> Vec<&str> {
        self.countries
            .iter()
            .map(|country| country.name.as_str())
            .collect()
    }

    pub fn slit_count(&self) -> usize {
        self.slits.len()
    }

    /// Whether a (lat, lon) point lies in one of the installed countries.
    pub fn contains(&self, point: (f64, f64)) -> bool {
        let (lat, lon) = point;
        self.countries
            .iter()
            .any(|country| country.contains(lon, lat))
    }

    /// Where a route of (lat, lon) points crosses the border of the area,
    /// found on the line between the last point on one side and the first on
    /// the other. Points closer than [`CHECK_SPACING_M`] to the last checked one
    /// are skipped; the last point is always checked.
    pub fn crossings(&self, geometry: &[(f64, f64)]) -> Vec<(f64, f64)> {
        let mut crossings = Vec::new();
        let Some(&first) = geometry.first() else {
            return crossings;
        };
        let mut previous = (first, self.contains(first));
        for (index, &point) in geometry.iter().enumerate().skip(1) {
            let last = index + 1 == geometry.len();
            if !last && distance_m(previous.0, point) < CHECK_SPACING_M {
                continue;
            }
            let inside = self.contains(point);
            if inside != previous.1 {
                crossings.push(self.crossing_between(previous.0, point, previous.1));
            }
            previous = (point, inside);
        }
        crossings
    }

    /// Where the straight line from `a` (inside or not, as `a_inside` says)
    /// to `b` crosses the border, found by halving to a few metres.
    fn crossing_between(&self, a: (f64, f64), b: (f64, f64), a_inside: bool) -> (f64, f64) {
        let (mut near, mut far) = (a, b);
        for _ in 0..24 {
            let mid = ((near.0 + far.0) / 2.0, (near.1 + far.1) / 2.0);
            if self.contains(mid) == a_inside {
                near = mid;
            } else {
                far = mid;
            }
        }
        ((near.0 + far.0) / 2.0, (near.1 + far.1) / 2.0)
    }

    /// Indexes of the slits within `radius_m` of any of the (lat, lon) points.
    pub fn slits_near(&self, points: &[(f64, f64)], radius_m: f64) -> BTreeSet<usize> {
        self.slits
            .iter()
            .enumerate()
            .filter(|(_, slit)| {
                points
                    .iter()
                    .any(|&(lat, lon)| slit.distance_m(lon, lat, radius_m) <= radius_m)
            })
            .map(|(index, _)| index)
            .collect()
    }

    /// Valhalla's `exclude_polygons` for these slits: rings of [lon, lat].
    pub fn exclude_polygons(&self, slits: &BTreeSet<usize>) -> Value {
        Value::Array(
            slits
                .iter()
                .filter_map(|&index| self.slits.get(index))
                .map(|slit| {
                    json!(slit
                        .ring
                        .iter()
                        .map(|&(lon, lat)| [round6(lon), round6(lat)])
                        .collect::<Vec<_>>())
                })
                .collect(),
        )
    }
}

fn round6(value: f64) -> f64 {
    (value * 1e6).round() / 1e6
}

/// Runs of consecutive border points whose segments lie in none of the other
/// countries (checked at each segment's midpoint).
fn runs_outside(ring: &[(f64, f64)], others: &[&Country]) -> Vec<Vec<(f64, f64)>> {
    let n = ring.len();
    let keep: Vec<bool> = (0..n)
        .map(|i| {
            let (a, b) = (ring[i], ring[(i + 1) % n]);
            let mid = ((a.0 + b.0) / 2.0, (a.1 + b.1) / 2.0);
            !others.iter().any(|other| other.contains(mid.0, mid.1))
        })
        .collect();
    let Some(dropped) = keep.iter().position(|keep| !keep) else {
        let mut closed = ring.to_vec();
        closed.push(ring[0]);
        return vec![closed];
    };
    // Start right after a dropped segment, so no run wraps around.
    let mut runs = Vec::new();
    let mut run: Vec<(f64, f64)> = Vec::new();
    for k in 0..n {
        let i = (dropped + 1 + k) % n;
        if keep[i] {
            if run.is_empty() {
                run.push(ring[i]);
            }
            run.push(ring[(i + 1) % n]);
        } else if !run.is_empty() {
            runs.push(std::mem::take(&mut run));
        }
    }
    if !run.is_empty() {
        runs.push(run);
    }
    runs
}

/// The run in pieces of [`SLIT_POINTS`] points, each closed into a thin ring
/// by coming back [`SLIT_WIDTH_M`] to its left.
fn slits_along(run: &[(f64, f64)]) -> Vec<Slit> {
    let mut slits = Vec::new();
    let mut start = 0;
    while start + 1 < run.len() {
        let part = &run[start..(start + SLIT_POINTS).min(run.len())];
        let mut ring = part.to_vec();
        ring.extend(offset_left(part, SLIT_WIDTH_M).into_iter().rev());
        ring.push(part[0]);
        let bbox = BBox::of(&ring);
        slits.push(Slit {
            ring,
            line: part.to_vec(),
            bbox,
        });
        start += SLIT_POINTS - 1;
    }
    slits
}

/// The polyline of (lon, lat) shifted `metres` to its left.
fn offset_left(points: &[(f64, f64)], metres: f64) -> Vec<(f64, f64)> {
    let shift = (metres / EARTH_RADIUS_M).to_degrees();
    (0..points.len())
        .map(|i| {
            let (lon, lat) = points[i];
            let a = points[i.saturating_sub(1)];
            let b = points[(i + 1).min(points.len() - 1)];
            let k = lat.to_radians().cos().max(1e-6);
            let (dx, dy) = ((b.0 - a.0) * k, b.1 - a.1);
            let norm = dx.hypot(dy);
            let (nx, ny) = if norm > 0.0 {
                (-dy / norm, dx / norm)
            } else {
                (0.0, 1.0)
            };
            (lon + nx * shift / k, lat + ny * shift)
        })
        .collect()
}

/// Reads the installed countries from the routing packages' folder: every
/// `routing-<land>.info` needs its `routing-<land>.poly`. `Ok(None)` without
/// packages, and also when one lacks its border (a package from before
/// borders were packed): an area without that country would close the way
/// into it.
pub fn load_dir(dir: &Path) -> io::Result<Option<LoadedArea>> {
    let mut names = Vec::new();
    match fs::read_dir(dir) {
        Ok(entries) => {
            for entry in entries {
                let name = entry?.file_name().to_string_lossy().into_owned();
                if let Some(country) = name
                    .strip_prefix("routing-")
                    .and_then(|rest| rest.strip_suffix(".info"))
                {
                    names.push(country.to_string());
                }
            }
        }
        Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(None),
        Err(error) => return Err(error),
    }
    if names.is_empty() {
        return Ok(None);
    }
    names.sort();
    let mut countries = Vec::new();
    for name in names {
        let path = dir.join(format!("routing-{name}.poly"));
        let text = match fs::read_to_string(&path) {
            Ok(text) => text,
            Err(error) if error.kind() == io::ErrorKind::NotFound => {
                warn!(
                    country = %name,
                    path = %path.display(),
                    "routing package without its border: routes are not kept inside the installed countries"
                );
                return Ok(None);
            }
            Err(error) => return Err(error),
        };
        let country = Country::parse(&name, &text).map_err(|reason| {
            io::Error::new(
                io::ErrorKind::InvalidData,
                format!("{}: {reason}", path.display()),
            )
        })?;
        countries.push(country);
    }
    Ok(Some(LoadedArea::new(countries)))
}

/// What a folder held when it was last read: names, sizes and times of the
/// routing package files.
type Fingerprint = Vec<(String, u64, Option<SystemTime>)>;

fn fingerprint(dir: &Path) -> Fingerprint {
    let mut files: Fingerprint = fs::read_dir(dir)
        .into_iter()
        .flatten()
        .flatten()
        .filter_map(|entry| {
            let name = entry.file_name().to_string_lossy().into_owned();
            if !name.starts_with("routing-") {
                return None;
            }
            let meta = entry.metadata().ok()?;
            Some((name, meta.len(), meta.modified().ok()))
        })
        .collect();
    files.sort();
    files
}

/// The loaded area of a folder, read again only when its routing package
/// files change (`carnine-install-maps` restarts Valhalla, not the backend).
#[derive(Debug)]
pub struct BorderCache {
    dir: PathBuf,
    state: Mutex<Option<(Fingerprint, Option<Arc<LoadedArea>>)>>,
}

impl BorderCache {
    pub fn new(dir: PathBuf) -> Self {
        Self {
            dir,
            state: Mutex::new(None),
        }
    }

    pub fn area(&self) -> Option<Arc<LoadedArea>> {
        let now = fingerprint(&self.dir);
        let mut state = self
            .state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        if let Some((seen, area)) = state.as_ref() {
            if *seen == now {
                return area.clone();
            }
        }
        let area = match load_dir(&self.dir) {
            Ok(area) => area.map(Arc::new),
            Err(error) => {
                warn!(dir = %self.dir.display(), %error, "cannot read the routing packages' borders");
                None
            }
        };
        match &area {
            Some(area) => info!(
                countries = ?area.country_names(),
                slits = area.slit_count(),
                "routes stay inside the installed countries"
            ),
            None if !now.is_empty() => {
                info!(dir = %self.dir.display(), "routes are not kept inside countries")
            }
            None => {}
        }
        *state = Some((now, area.clone()));
        area
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A square "country" from (lon0, lat0) to (lon1, lat1) as a .poly.
    fn square(name: &str, lon0: f64, lat0: f64, lon1: f64, lat1: f64) -> String {
        format!(
            "{name}\n1\n {lon0} {lat0}\n {lon1} {lat0}\n {lon1} {lat1}\n {lon0} {lat1}\nEND\nEND\n"
        )
    }

    fn country(name: &str, lon0: f64, lat0: f64, lon1: f64, lat1: f64) -> Country {
        Country::parse(name, &square(name, lon0, lat0, lon1, lat1)).unwrap()
    }

    #[test]
    fn reads_a_poly_with_a_hole() {
        let text =
            "germany\n1\n 0 0\n 10 0\n 10 10\n 0 10\nEND\n!2\n 4 4\n 6 4\n 6 6\n 4 6\nEND\nEND\n";
        let germany = Country::parse("de", text).unwrap();
        assert!(germany.contains(1.0, 1.0));
        assert!(!germany.contains(5.0, 5.0), "inside the hole");
        assert!(!germany.contains(11.0, 5.0));
        for broken in [
            "",
            "x\n1\n 0 0\n 1 0\nEND\nEND\n",
            "x\n1\n 0 0\n 1 zero\n 1 1\nEND\nEND\n",
            "x\n1\n 0 0\n 1 0\n 1 1\n",
            "x\n!1\n 0 0\n 1 0\n 1 1\nEND\nEND\n",
        ] {
            assert!(Country::parse("x", broken).is_err(), "{broken:?}");
        }
    }

    #[test]
    fn the_shared_border_gets_no_slit() {
        // Two squares side by side, overlapping a little as Geofabrik's do.
        let west = country("w", 0.0, 0.0, 1.01, 1.0);
        let east = country("e", 0.99, 0.0, 2.0, 1.0);
        let area = LoadedArea::new(vec![west.clone(), east]);
        let near = |lon: f64, lat: f64| !area.slits_near(&[(lat, lon)], 5_000.0).is_empty();
        // 5 km is about 0.045°: the middle of the shared border has no slit
        // near it, the outer borders have.
        assert!(!near(1.0, 0.5));
        assert!(near(0.0, 0.5));
        assert!(near(2.0, 0.5));
        assert!(near(1.5, 1.0));
        assert!(area.contains((0.5, 1.5)));
        assert!(!area.contains((0.5, 2.5)));

        let alone = LoadedArea::new(vec![west]);
        assert!(!alone.slits_near(&[(0.5, 1.0)], 5_000.0).is_empty());
    }

    #[test]
    fn slits_are_thin_closed_rings_of_few_points() {
        let area = LoadedArea::new(vec![country("a", 10.0, 47.0, 11.0, 48.0)]);
        assert!(area.slit_count() >= 1);
        for slit in &area.slits {
            assert_eq!(slit.ring.first(), slit.ring.last());
            assert!(slit.ring.len() <= 2 * SLIT_POINTS + 1);
            // Each border point has its partner SLIT_WIDTH_M away on the way back.
            let k = slit.line.len();
            assert_eq!(slit.ring.len(), 2 * k + 1);
            for i in 0..k {
                let (a, b) = (slit.ring[i], slit.ring[2 * k - 1 - i]);
                let width = distance_m((a.1, a.0), (b.1, b.0));
                assert!((width - SLIT_WIDTH_M).abs() < 1.0, "{width}");
            }
        }
        let polygons = area.exclude_polygons(&(0..area.slit_count()).collect());
        let first = &polygons[0];
        assert!(first[0][0].as_f64().unwrap() >= 9.9, "longitude first");
    }

    #[test]
    fn finds_where_a_route_leaves_and_comes_back() {
        let area = LoadedArea::new(vec![country("a", 10.0, 47.0, 11.0, 48.0)]);
        // (lat, lon): inside, out over the east border, back in.
        let route = [
            (47.5, 10.5),
            (47.5, 10.9),
            (47.5, 11.2),
            (47.6, 11.2),
            (47.6, 10.8),
        ];
        let crossings = area.crossings(&route);
        assert_eq!(crossings.len(), 2);
        assert!((crossings[0].1 - 11.0).abs() < 1e-5, "{crossings:?}");
        assert!(area.crossings(&route[..2]).is_empty());
        assert!(area.crossings(&[]).is_empty());
        let near = area.slits_near(&crossings, 5_000.0);
        assert!(!near.is_empty());
        assert!(near.len() < area.slit_count() || area.slit_count() == 1);
    }

    #[test]
    fn close_points_are_skipped_but_the_last_is_checked() {
        let area = LoadedArea::new(vec![country("a", 10.0, 47.0, 11.0, 48.0)]);
        // Steps of about 100 m up to the border, the last point just outside.
        let mut route: Vec<(f64, f64)> =
            (0..10).map(|i| (47.5, 10.99 + i as f64 * 0.0009)).collect();
        route.push((47.5, 11.0005));
        assert_eq!(area.crossings(&route).len(), 1);
    }

    fn temp_dir(tag: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("carnine-border-{tag}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn loads_the_installed_countries_and_needs_every_border() {
        let dir = temp_dir("load");
        assert!(load_dir(&dir).unwrap().is_none(), "no packages");
        assert!(load_dir(&dir.join("missing")).unwrap().is_none());

        fs::write(dir.join("routing-de.info"), "land=de\n").unwrap();
        fs::write(
            dir.join("routing-de.poly"),
            square("de", 6.0, 47.0, 15.0, 55.0),
        )
        .unwrap();
        let area = load_dir(&dir).unwrap().expect("one country");
        assert_eq!(area.country_names(), vec!["de"]);

        // A second package without its border switches the area off.
        fs::write(dir.join("routing-at.info"), "land=at\n").unwrap();
        assert!(load_dir(&dir).unwrap().is_none());
        fs::write(
            dir.join("routing-at.poly"),
            square("at", 9.5, 46.3, 17.2, 49.1),
        )
        .unwrap();
        assert_eq!(
            load_dir(&dir).unwrap().unwrap().country_names(),
            vec!["at", "de"]
        );

        fs::write(dir.join("routing-at.poly"), "at\n1\n 1 2\nEND\nEND\n").unwrap();
        assert!(load_dir(&dir).is_err());
        fs::remove_dir_all(&dir).unwrap();
    }

    #[test]
    fn the_cache_reads_again_only_after_a_change() {
        let dir = temp_dir("cache");
        let cache = BorderCache::new(dir.clone());
        assert!(cache.area().is_none());
        fs::write(dir.join("routing-de.info"), "land=de\n").unwrap();
        fs::write(
            dir.join("routing-de.poly"),
            square("de", 6.0, 47.0, 15.0, 55.0),
        )
        .unwrap();
        let first = cache.area().expect("installed");
        let again = cache.area().expect("still installed");
        assert!(Arc::ptr_eq(&first, &again), "read once");
        fs::remove_file(dir.join("routing-de.info")).unwrap();
        fs::remove_file(dir.join("routing-de.poly")).unwrap();
        assert!(cache.area().is_none(), "removed");
        fs::remove_dir_all(&dir).unwrap();
    }
}
