//! Where a position lies, in words: street, locality and district, from the
//! `reverse_*` tables of the names database (since September 2026). Follows
//! `OfflineGeocoder.nameAt` in local_map 0.5.0; with an older database there
//! is no answer.

use std::path::Path;

use anyhow::{Context, Result};
use rusqlite::{Connection, OpenFlags};

use super::places::METERS_PER_DEGREE;

/// How far a street may be to count as the one the car is on. The points lie
/// every 100 m along the line, so up to 50 m beside it, plus GPS error.
const STREET_RADIUS_METERS: f64 = 80.0;

/// Places are looked for this far; the largest reach below is 15 km.
const PLACE_RADIUS_METERS: f64 = 15_000.0;

/// Road classes that are not streets one drives on.
const NOT_STREETS: [&str; 6] = ["rail", "transit", "ferry", "aerialway", "raceway", "busway"];

/// Surcharge in metres for ways that should only win when no proper street is
/// near: car park lanes, field and foot paths.
fn street_penalty(detail: Option<&str>) -> f64 {
    match detail {
        Some("service") => 25.0,
        Some("track" | "path") => 40.0,
        _ => 0.0,
    }
}

/// Weight and reach in metres per kind of locality. The distance is divided
/// by the weight: a city 1.7 km away beats its own quarter at 1 km, a village
/// at 800 m the hamlet at its edge at 500 m.
fn locality_class(detail: Option<&str>) -> Option<(f64, f64)> {
    match detail? {
        "city" => Some((4.0, 15_000.0)),
        "town" => Some((2.5, 8_000.0)),
        "municipality" => Some((2.0, 6_000.0)),
        "village" => Some((1.5, 4_000.0)),
        "hamlet" => Some((0.7, 1_500.0)),
        "isolated_dwelling" | "farm" => Some((0.4, 500.0)),
        _ => None,
    }
}

/// Districts named in addition to the locality when they are this near.
fn district_radius(detail: Option<&str>) -> Option<f64> {
    match detail? {
        "suburb" => Some(1_500.0),
        "quarter" => Some(800.0),
        "neighbourhood" => Some(500.0),
        "borough" => Some(2_000.0),
        _ => None,
    }
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct LocationName {
    /// Nearest street; on motorways often only the number ("A 5").
    pub street: Option<String>,
    /// City, municipality or village.
    pub locality: Option<String>,
    /// District or quarter, when one is near and named other than the
    /// locality.
    pub district: Option<String>,
}

/// The name at (lat, lon), `None` when nothing is known there or the
/// database has no `reverse_*` tables.
pub fn name_at(database: &Path, lat: f64, lon: f64) -> Result<Option<LocationName>> {
    let connection = Connection::open_with_flags(
        database,
        OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX,
    )
    .with_context(|| format!("opening names database {}", database.display()))?;
    let indexes: i64 = connection.query_row(
        "SELECT count(*) FROM sqlite_master WHERE type = 'index'
         AND name IN ('reverse_places_pos', 'reverse_streets_pos')",
        [],
        |row| row.get(0),
    )?;
    if indexes != 2 {
        return Ok(None);
    }

    let mut street = None;
    let mut best_street = f64::INFINITY;
    for (name, detail, meters) in points_around(
        &connection,
        "reverse_streets",
        lat,
        lon,
        STREET_RADIUS_METERS + 50.0,
    )? {
        if meters > STREET_RADIUS_METERS
            || detail.as_deref().is_some_and(|d| NOT_STREETS.contains(&d))
        {
            continue;
        }
        let score = meters + street_penalty(detail.as_deref());
        if score < best_street {
            best_street = score;
            street = Some(name);
        }
    }

    let mut locality = None;
    let mut best_locality = f64::INFINITY;
    let mut district = None;
    let mut best_district = f64::INFINITY;
    for (name, detail, meters) in
        points_around(&connection, "reverse_places", lat, lon, PLACE_RADIUS_METERS)?
    {
        if let Some((weight, reach)) = locality_class(detail.as_deref()) {
            let score = meters / weight;
            if meters <= reach && score < best_locality {
                best_locality = score;
                locality = Some(name.clone());
            }
        }
        if let Some(radius) = district_radius(detail.as_deref()) {
            if meters <= radius && meters < best_district {
                best_district = meters;
                district = Some(name);
            }
        }
    }
    if district == locality {
        district = None;
    }
    let name = LocationName {
        street,
        locality,
        district,
    };
    Ok((name != LocationName::default()).then_some(name))
}

/// All points of `table` in a square of 2 × `radius` around (lat, lon), with
/// name, kind and distance in metres.
fn points_around(
    connection: &Connection,
    table: &str,
    lat: f64,
    lon: f64,
    radius: f64,
) -> Result<Vec<(String, Option<String>, f64)>> {
    let cos_lat = lat.to_radians().cos();
    let d_lat = radius / METERS_PER_DEGREE;
    let d_lon = radius / (METERS_PER_DEGREE * cos_lat.max(0.01));
    let e5 = |degrees: f64| (degrees * 1e5).round() as i64;
    let mut statement = connection.prepare_cached(&format!(
        "SELECT n.name, n.detail, p.lat_e5, p.lng_e5
         FROM {table} p JOIN reverse_names n ON n.id = p.name_id
         WHERE p.lat_e5 BETWEEN ?1 AND ?2 AND p.lng_e5 BETWEEN ?3 AND ?4"
    ))?;
    let points = statement
        .query_map(
            rusqlite::params![
                e5(lat - d_lat),
                e5(lat + d_lat),
                e5(lon - d_lon),
                e5(lon + d_lon)
            ],
            |row| {
                let point_lat = row.get::<_, i64>(2)? as f64 / 1e5;
                let point_lon = row.get::<_, i64>(3)? as f64 / 1e5;
                // Over these short distances the flat projection does.
                let meters = METERS_PER_DEGREE
                    * ((point_lat - lat).powi(2) + ((point_lon - lon) * cos_lat).powi(2)).sqrt();
                Ok((row.get(0)?, row.get(1)?, meters))
            },
        )?
        .collect::<rusqlite::Result<Vec<_>>>()
        .context("reading reverse names")?;
    Ok(points)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::navigation::places::tests::TempDb;

    const STATION: (f64, f64) = (52.25300, 10.53960);
    const BORTFELD: (f64, f64) = (52.30000, 10.40000);

    /// `from` moved `north` metres north and `east` metres east, in 1e-5
    /// degrees as in the database.
    fn e5(from: (f64, f64), north: f64, east: f64) -> (i64, i64) {
        let lat = from.0 + north / METERS_PER_DEGREE;
        let lon = from.1 + east / (METERS_PER_DEGREE * from.0.to_radians().cos());
        ((lat * 1e5).round() as i64, (lon * 1e5).round() as i64)
    }

    /// The library's test data: what the real Braunschweig database holds at
    /// these spots.
    fn reverse_db() -> TempDb {
        let db = TempDb::new();
        let connection = Connection::open(&db.path).expect("create db");
        connection
            .execute_batch(
                "CREATE TABLE reverse_names (id INTEGER PRIMARY KEY, name TEXT NOT NULL,
                    type TEXT NOT NULL, detail TEXT);
                 CREATE TABLE reverse_places (name_id INTEGER NOT NULL,
                    lat_e5 INTEGER NOT NULL, lng_e5 INTEGER NOT NULL);
                 CREATE TABLE reverse_streets (name_id INTEGER NOT NULL,
                    lat_e5 INTEGER NOT NULL, lng_e5 INTEGER NOT NULL);",
            )
            .expect("schema");
        let points = [
            (
                "street",
                "Willy-Brandt-Platz",
                "primary",
                e5(STATION, 56.0, 0.0),
            ),
            (
                "street",
                "Braunschweig–Wieren",
                "rail",
                e5(STATION, -20.0, 0.0),
            ),
            (
                "street",
                "Kiss-and-Go Haltebucht",
                "service",
                e5(STATION, 0.0, 40.0),
            ),
            ("place", "Bebelhof", "quarter", e5(STATION, -700.0, 0.0)),
            ("place", "Braunschweig", "city", e5(STATION, 1700.0, 0.0)),
            (
                "place",
                "Marina Bortfeld",
                "hamlet",
                e5(BORTFELD, 0.0, 502.0),
            ),
            ("place", "Bortfeld", "village", e5(BORTFELD, 806.0, 0.0)),
        ];
        for (id, (kind, name, detail, (lat, lon))) in points.iter().enumerate() {
            connection
                .execute(
                    "INSERT INTO reverse_names VALUES (?1, ?2, ?3, ?4)",
                    rusqlite::params![id as i64, name, kind, detail],
                )
                .expect("insert name");
            let table = if *kind == "street" {
                "reverse_streets"
            } else {
                "reverse_places"
            };
            connection
                .execute(
                    &format!("INSERT INTO {table} VALUES (?1, ?2, ?3)"),
                    rusqlite::params![id as i64, lat, lon],
                )
                .expect("insert point");
        }
        connection
            .execute_batch(
                "CREATE INDEX reverse_places_pos ON reverse_places (lat_e5, lng_e5);
                 CREATE INDEX reverse_streets_pos ON reverse_streets (lat_e5, lng_e5);",
            )
            .expect("indexes");
        db
    }

    #[test]
    fn street_city_and_quarter_not_the_railway_nor_the_car_park_lane() {
        let db = reverse_db();
        let name = name_at(&db.path, STATION.0, STATION.1)
            .expect("lookup")
            .expect("a name");
        assert_eq!(name.street.as_deref(), Some("Willy-Brandt-Platz"));
        // The quarter is nearer, still the city is the locality.
        assert_eq!(name.locality.as_deref(), Some("Braunschweig"));
        assert_eq!(name.district.as_deref(), Some("Bebelhof"));
    }

    #[test]
    fn the_village_beats_the_nearer_hamlet() {
        let db = reverse_db();
        let name = name_at(&db.path, BORTFELD.0, BORTFELD.1)
            .expect("lookup")
            .expect("a name");
        assert_eq!(name.locality.as_deref(), Some("Bortfeld"));
        assert_eq!(name.street, None, "no street around");
    }

    #[test]
    fn nothing_near_is_none() {
        let db = reverse_db();
        assert_eq!(name_at(&db.path, 47.5, 12.0).expect("lookup"), None);
    }

    #[test]
    fn a_database_without_reverse_tables_has_no_answer() {
        let db = TempDb::new();
        Connection::open(&db.path)
            .expect("create db")
            .execute_batch("CREATE TABLE names_meta (id INTEGER PRIMARY KEY)")
            .expect("schema");
        assert_eq!(
            name_at(&db.path, STATION.0, STATION.1).expect("lookup"),
            None
        );
    }
}
