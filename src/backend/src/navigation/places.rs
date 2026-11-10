//! Place search over the names database the map tools build next to the tiles
//! (`extract_names_to_sqlite.py` in flutter_local_map: an FTS5 table `names`).
//!
//! Ranking follows the map library's `OfflineGeocoder` (local_map 0.5.1), so a
//! search reads the same in the demo app and in carnine2: exact names before
//! those that only start that way, within each places before POIs before
//! peaks, water and streets, and with `near` each group ordered by distance.
//!
//! Databases built since September 2026 carry each name's area (`context`)
//! and a grid cell in the index (`cell`). Only with them "Hauptstraße
//! Alsfeld" finds the street in Alsfeld and `near` searches the surroundings
//! first; older ones are searched across the whole country.
//!
//! Umlauts written out ("Muecke", "Giessen", "Strasse") also find the names
//! spelled with them. When a search finds nothing, the word index
//! (`word_index`) puts close words in for misspelled ones (#172).

use std::collections::HashSet;
use std::path::Path;

use anyhow::{Context, Result};
use rusqlite::types::Value;
use rusqlite::{Connection, OpenFlags};

use super::word_index::{fold, WordIndex};

/// Results when the request asks for none in particular.
pub const DEFAULT_LIMIT: usize = 15;
/// Hard cap, so a client cannot ask the Pi for the whole index.
const MAX_LIMIT: usize = 100;
/// This many candidates per requested result are fetched first; FTS knows
/// nothing about distance or exact names, and "Hauptstraße" exists a thousand
/// times.
const CANDIDATE_FACTOR: usize = 10;
/// With `near`, hits within this radius come before the rest of the country.
const NEAR_RADIUS_METERS: f64 = 50_000.0;
/// The surroundings are searched from this many characters on. A single
/// letter matches hundreds of thousands of names, and sorting them all by
/// distance takes seconds on the Pi.
const NEAR_MIN_CHARS: usize = 3;
/// Side of the grid cells in degrees, SEARCH_GRID_DEG in the script.
const GRID_DEGREES: f64 = 0.5;
pub(super) const METERS_PER_DEGREE: f64 = 111_195.0;

/// Type names as the extraction script writes them, in ranking order.
const TYPE_PRIORITY: [&str; 5] = [
    "place",
    "poi",
    "mountain_peak",
    "water_name",
    "transportation_name",
];

/// Named spots without inhabitants (field names, often just a street name as
/// a point, squares, fields) rank like streets; otherwise a "Bahnhofstrasse"
/// in the Simmental beats the one in Zurich.
const UNPOPULATED_PLACES: [&str; 6] = [
    "locality",
    "square",
    "field",
    "plot",
    "allotments",
    "city_block",
];

#[derive(Debug, Clone, PartialEq)]
pub struct PlaceRecord {
    pub name: String,
    pub latitude: f64,
    pub longitude: f64,
    pub zoom: u32,
    pub kind: String,
    pub detail: Option<String>,
    /// The locality the hit belongs to (for a place the larger one nearby);
    /// `None` with older databases and for regions.
    pub area: Option<String>,
}

/// What the database offers beyond the original schema.
struct Schema {
    /// `context` holds each name's area.
    has_area: bool,
    /// Type and grid cell are in the index.
    has_grid: bool,
}

/// Searches `database` for `query` without a word index: a misspelled word
/// finds nothing. The tests compare against it.
#[cfg(test)]
pub fn search(
    database: &Path,
    query: &str,
    limit: usize,
    near: Option<(f64, f64)>,
) -> Result<Vec<PlaceRecord>> {
    search_with(database, query, limit, near, None)
}

/// Searches `database` for `query`. An empty query finds nothing. Only when
/// nothing is found and `index` is there, misspelled words are searched as
/// the close words of the index; a query spelled right runs as without it.
pub fn search_with(
    database: &Path,
    query: &str,
    limit: usize,
    near: Option<(f64, f64)>,
    index: Option<&WordIndex>,
) -> Result<Vec<PlaceRecord>> {
    let query = query.trim();
    let words: Vec<&str> = query.split_whitespace().collect();
    if words.is_empty() {
        return Ok(Vec::new());
    }
    let limit = match limit {
        0 => DEFAULT_LIMIT,
        limit => limit.min(MAX_LIMIT),
    };
    let fetch = limit * CANDIDATE_FACTOR;
    let connection = Connection::open_with_flags(
        database,
        OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX,
    )
    .with_context(|| format!("opening names database {}", database.display()))?;
    let schema = schema(&connection)?;
    let terms: Vec<Vec<String>> = words.iter().map(|word| word_terms(word)).collect();
    let expression = match_expression(&terms, schema.has_area);
    let candidates = find_candidates(&connection, &schema, &expression, query, near, fetch)?;
    if !candidates.is_empty() {
        return Ok(ranked(candidates, query, near, limit));
    }
    let Some((terms, corrected)) = index.and_then(|index| with_typos(index, &words, terms)) else {
        return Ok(Vec::new());
    };
    let expression = match_expression(&terms, schema.has_area);
    let candidates = find_candidates(&connection, &schema, &expression, query, near, fetch)?;
    // Ranked as if the most common close word had been typed: "Frankfrut"
    // as "Frankfurt" finds the city first.
    Ok(ranked(candidates, &corrected, near, limit))
}

/// The hits for `expression` per type, those around `near` first.
fn find_candidates(
    connection: &Connection,
    schema: &Schema,
    expression: &str,
    query: &str,
    near: Option<(f64, f64)>,
    fetch: usize,
) -> Result<Vec<PlaceRecord>> {
    // FTS returns hits without distance or ranking. With `near` the ones from
    // the surroundings come first, or of a thousand "Hauptstraße" an
    // arbitrary selection would be fetched.
    let mut candidates = Vec::new();
    if let Some(origin) =
        near.filter(|_| schema.has_grid && query.chars().count() >= NEAR_MIN_CHARS)
    {
        for kind in TYPE_PRIORITY {
            candidates.extend(query_names(
                connection,
                schema,
                expression,
                kind,
                Some(origin),
                fetch,
            )?);
        }
    }
    let mut seen: HashSet<_> = candidates.iter().map(identity).collect();
    let mut fetched = 0;
    for kind in TYPE_PRIORITY {
        if fetched >= fetch {
            break;
        }
        let records = query_names(connection, schema, expression, kind, None, fetch - fetched)?;
        fetched += records.len();
        for record in records {
            if seen.insert(identity(&record)) {
                candidates.push(record);
            }
        }
    }
    Ok(candidates)
}

/// Misspelled words of `words` (not the start of any word in the index, 4
/// characters or more) get the close words of the index as alternatives in
/// `terms`. Returns them with the query as if the most common close word had
/// been typed, or `None` when no word could be corrected.
fn with_typos(
    index: &WordIndex,
    words: &[&str],
    mut terms: Vec<Vec<String>>,
) -> Option<(Vec<Vec<String>>, String)> {
    let mut corrected = Vec::with_capacity(words.len());
    let mut any = false;
    for (word, alternatives) in words.iter().zip(terms.iter_mut()) {
        let folded = fold(word);
        let similar = if index.has_prefix(&folded) {
            Vec::new()
        } else {
            index.similar(&folded)
        };
        match similar.first() {
            Some(best) => {
                corrected.push(best.clone());
                alternatives.extend(similar.iter().map(|word| quoted(word)));
                any = true;
            }
            None => corrected.push((*word).to_string()),
        }
    }
    any.then(|| (terms, corrected.join(" ")))
}

/// Exact hits first ("Fulda" before "Fulda-Galerie", "Hauptstraße Alsfeld"
/// for the one in Alsfeld), then those that only start that way; within each
/// by rank, then cities before the rest, then by distance. A city or town
/// whose name starts with the whole query counts as exact:
/// "Frankfurt" means Frankfurt am Main, not the village "Frankfurt" in
/// Franconia. With `near` the rank is banded: inhabited
/// places, then everything within [`NEAR_RADIUS_METERS`], then the rest.
fn ranked(
    candidates: Vec<PlaceRecord>,
    query: &str,
    near: Option<(f64, f64)>,
    limit: usize,
) -> Vec<PlaceRecord> {
    let wanted = spellings(&fold(query));
    let street_key = |record: &PlaceRecord| (record.name.to_lowercase(), record.area.clone());
    // A POI named exactly like a street in the same locality (bus stop, info
    // board, car park "Hauptstraße") goes behind the streets. Only in the
    // same locality: a street "Hauptbahnhof" in Mainz must not push back the
    // main station in Frankfurt.
    let streets: HashSet<_> = candidates
        .iter()
        .filter(|record| record.kind == "transportation_name")
        .map(street_key)
        .collect();
    let mut keyed: Vec<_> = candidates
        .into_iter()
        .map(|record| {
            let name = fold(&record.name);
            let with_area = record
                .area
                .as_ref()
                .map(|area| format!("{name} {}", fold(area)));
            let exact = wanted.iter().any(|wanted| {
                name == *wanted
                    || with_area.as_ref() == Some(wanted)
                    || (is_city_or_town(&record) && starts_with_word(&name, wanted))
            });
            let type_rank = if record.kind == "poi" && streets.contains(&street_key(&record)) {
                5
            } else {
                search_rank(&record.kind, record.detail.as_deref())
            };
            let distance = near.map_or(0.0, |origin| {
                distance_meters(origin, (record.latitude, record.longitude))
            });
            // With `near` the surroundings come before the rest of the
            // country, or the station "Hauptstraße" in Freiburg beats the
            // street in Alsfeld. Inhabited places stay in front: "Berlin"
            // means the city, not the inn "Berlin" round the corner.
            let rank = match near {
                Some(_) if type_rank != 0 => {
                    let band = if distance > NEAR_RADIUS_METERS {
                        200
                    } else {
                        100
                    };
                    band + u16::from(type_rank)
                }
                _ => u16::from(type_rank),
            };
            (!exact, rank, !is_city(&record), distance, record)
        })
        .collect();
    // Stable: without `near` the order from the database stays within a group.
    keyed.sort_by(|a, b| {
        a.0.cmp(&b.0)
            .then(a.1.cmp(&b.1))
            .then(a.2.cmp(&b.2))
            .then(a.3.total_cmp(&b.3))
    });
    keyed
        .into_iter()
        .take(limit)
        .map(|(_, _, _, _, record)| record)
        .collect()
}

/// Only cities go ahead regardless of distance: whoever types "Hausen" near
/// Alsfeld means the village nearby, not the town of that name near Hanau.
fn is_city(record: &PlaceRecord) -> bool {
    record.kind == "place" && record.detail.as_deref() == Some("city")
}

fn is_city_or_town(record: &PlaceRecord) -> bool {
    record.kind == "place" && matches!(record.detail.as_deref(), Some("city" | "town"))
}

/// `name` is `word` followed by more words: "frankfurt am main" and
/// "frankfurt (oder)" for "frankfurt", but not "frankfurter straße" or
/// "frankfurt-höchst".
fn starts_with_word(name: &str, word: &str) -> bool {
    name.strip_prefix(word)
        .and_then(|rest| rest.chars().next())
        .is_some_and(char::is_whitespace)
}

/// Place in the result list, smaller is higher up, as `searchRank` in the
/// library. Bus stops come after the streets: they are often named like the
/// street, and whoever types "Hauptstraße" means the street.
fn search_rank(kind: &str, detail: Option<&str>) -> u8 {
    match (kind, detail) {
        ("place", Some(detail)) if UNPOPULATED_PLACES.contains(&detail) => 4,
        ("place", _) => 0,
        ("poi", Some("bus")) => 5,
        ("poi", _) => 1,
        ("mountain_peak", _) => 2,
        ("water_name", _) => 3,
        ("transportation_name", _) => 4,
        _ => 99,
    }
}

fn schema(connection: &Connection) -> Result<Schema> {
    let columns = |table: &str| -> Result<Vec<String>> {
        let mut statement = connection.prepare(&format!("PRAGMA table_info({table})"))?;
        let names = statement
            .query_map([], |row| row.get::<_, String>(1))?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        Ok(names)
    };
    Ok(Schema {
        has_area: columns("names_meta")?
            .iter()
            .any(|column| column == "context"),
        has_grid: columns("names")?.iter().any(|column| column == "cell"),
    })
}

/// One FTS lookup for one type; with `near` limited to the surroundings and
/// ordered by distance.
fn query_names(
    connection: &Connection,
    schema: &Schema,
    expression: &str,
    kind: &str,
    near: Option<(f64, f64)>,
    fetch: usize,
) -> Result<Vec<PlaceRecord>> {
    // Measured by the library on a Pi 4 with DACH (5.3 million names): type
    // and surroundings belong into the MATCH expression, then the index does
    // them. As "type = ?" or a lat/lng filter behind the text search SQLite
    // checks every hit on its own - "Hau" nearby 2.2 s instead of 134 ms.
    let mut expression = expression.to_string();
    let mut sql = format!(
        "SELECT name, lat, lng, zoom, type, detail, {} FROM names WHERE names MATCH ?",
        if schema.has_area { "context" } else { "NULL" }
    );
    let mut params = Vec::new();
    if schema.has_grid {
        expression.push_str(&format!(" AND type : {}", quoted(kind)));
    } else {
        sql.push_str(" AND type = ?");
        params.push(Value::Text(kind.to_string()));
    }
    if let Some((lat, lon)) = near {
        let cos_lat = lat.to_radians().cos();
        let d_lat = NEAR_RADIUS_METERS / METERS_PER_DEGREE;
        let d_lon = d_lat / cos_lat.max(0.01);
        expression.push_str(&format!(
            " AND cell : ({})",
            cells_around(lat, lon, d_lat, d_lon).join(" OR ")
        ));
        sql.push_str(&format!(
            " AND lat BETWEEN ? AND ? AND lng BETWEEN ? AND ? \
             ORDER BY (lat - ?) * (lat - ?) + (lng - ?) * (lng - ?) * {}",
            cos_lat * cos_lat
        ));
        for value in [
            lat - d_lat,
            lat + d_lat,
            lon - d_lon,
            lon + d_lon,
            lat,
            lat,
            lon,
            lon,
        ] {
            params.push(Value::Real(value));
        }
    }
    sql.push_str(" LIMIT ?");
    params.insert(0, Value::Text(expression));
    params.push(Value::Integer(i64::try_from(fetch).unwrap_or(i64::MAX)));

    let mut statement = connection.prepare_cached(&sql)?;
    let records = statement
        .query_map(rusqlite::params_from_iter(params), |row| {
            Ok(PlaceRecord {
                name: row.get(0)?,
                latitude: row.get(1)?,
                longitude: row.get(2)?,
                zoom: u32::try_from(row.get::<_, i64>(3)?).unwrap_or(0),
                kind: row.get(4)?,
                detail: row.get(5)?,
                area: row.get(6)?,
            })
        })?
        .collect::<rusqlite::Result<Vec<_>>>()
        .context("reading names")?;
    Ok(records)
}

/// Grid cells touching the box around (lat, lon) as index words ("g281x378"),
/// as `grid_cell()` in the extraction script.
fn cells_around(lat: f64, lon: f64, d_lat: f64, d_lon: f64) -> Vec<String> {
    let row = |lat: f64| ((lat + 90.0) / GRID_DEGREES).floor() as i64;
    let col = |lon: f64| ((lon + 180.0) / GRID_DEGREES).floor() as i64;
    let mut cells = Vec::new();
    for r in row(lat - d_lat)..=row(lat + d_lat) {
        for c in col(lon - d_lon)..=col(lon + d_lon) {
            cells.push(format!("g{r}x{c}"));
        }
    }
    cells
}

/// A word of the input as FTS terms: quoted as a prefix, so "Frank" finds
/// while it is still being typed, and its spellings with umlauts as whole
/// words ("muecke" also as "mücke", which the index holds as "mucke").
/// Quoting keeps `-`, `:` and friends from being read as FTS syntax.
fn word_terms(word: &str) -> Vec<String> {
    let mut terms = vec![format!("{}*", quoted(word))];
    terms.extend(
        spellings(&fold(word))
            .iter()
            .skip(1)
            .map(|spelling| quoted(spelling)),
    );
    terms
}

/// `text` (folded) and its spellings with umlauts and ß for written-out
/// ae/oe/ue and ss, as far as they differ; `text` first.
fn spellings(text: &str) -> Vec<String> {
    let plain = text
        .replace("ae", "a")
        .replace("oe", "o")
        .replace("ue", "u");
    let mut spellings = vec![text.to_string()];
    for spelling in [
        plain.clone(),
        plain.replace("ss", "ß"),
        text.replace("ss", "ß"),
    ] {
        if !spellings.contains(&spelling) {
            spellings.push(spelling);
        }
    }
    spellings
}

fn quoted(text: &str) -> String {
    format!("\"{}\"", text.replace('"', "\"\""))
}

/// All words anywhere in name or area, but at least one in the name. So
/// "Hauptstraße Alsfeld" finds the Hauptstraße in Alsfeld, while "Alsfeld"
/// alone does not find every street there. Each word is one of its `terms`.
fn match_expression(terms: &[Vec<String>], has_area: bool) -> String {
    let in_name = |alternatives: &[String]| -> Vec<String> {
        alternatives
            .iter()
            .map(|term| format!("name : {term}"))
            .collect()
    };
    if terms.len() == 1 || !has_area {
        let words: Vec<String> = terms
            .iter()
            .map(|alternatives| format!("({})", in_name(alternatives).join(" OR ")))
            .collect();
        return words.join(" AND ");
    }
    let anywhere: Vec<String> = terms
        .iter()
        .map(|alternatives| format!("({})", alternatives.join(" OR ")))
        .collect();
    let in_name: Vec<String> = terms
        .iter()
        .flat_map(|alternatives| in_name(alternatives))
        .collect();
    format!(
        "({}) AND ({})",
        anywhere.join(" AND "),
        in_name.join(" OR ")
    )
}

fn identity(record: &PlaceRecord) -> (String, String, u64, u64) {
    (
        record.name.clone(),
        record.kind.clone(),
        record.latitude.to_bits(),
        record.longitude.to_bits(),
    )
}

/// Great-circle distance; plenty for ranking search hits.
fn distance_meters(a: (f64, f64), b: (f64, f64)) -> f64 {
    const EARTH_RADIUS_METERS: f64 = 6_371_000.0;
    let (lat1, lat2) = (a.0.to_radians(), b.0.to_radians());
    let d_lat = lat2 - lat1;
    let d_lon = (b.1 - a.1).to_radians();
    let h = (d_lat / 2.0).sin().powi(2) + lat1.cos() * lat2.cos() * (d_lon / 2.0).sin().powi(2);
    2.0 * EARTH_RADIUS_METERS * h.sqrt().asin()
}

#[cfg(test)]
pub(super) mod tests {
    use super::*;

    /// Row of a test database: name, lat, lng, type, detail, area.
    pub(in crate::navigation) type Row<'a> = (&'a str, f64, f64, &'a str, &'a str, Option<&'a str>);

    /// A names database in today's schema: area in `context`, type and grid
    /// cell in the index, rowid = id.
    pub(in crate::navigation) fn names_db(rows: &[Row]) -> TempDb {
        let db = TempDb::new();
        let connection = Connection::open(&db.path).expect("create db");
        connection
            .execute_batch(
                "CREATE VIRTUAL TABLE names USING fts5(
                    id UNINDEXED, name, lat UNINDEXED, lng UNINDEXED, zoom UNINDEXED,
                    type, detail, source_field UNINDEXED, context, cell,
                    prefix='1 2 3');
                 CREATE TABLE names_meta (id INTEGER PRIMARY KEY, name TEXT NOT NULL,
                    lat REAL NOT NULL, lng REAL NOT NULL, zoom INTEGER NOT NULL,
                    type TEXT NOT NULL, detail TEXT, source_field TEXT NOT NULL,
                    context TEXT);",
            )
            .expect("fts5 is compiled into the bundled SQLite");
        for (index, (name, lat, lng, kind, detail, area)) in rows.iter().enumerate() {
            let id = index as i64 + 1;
            let cell = cells_around(*lat, *lng, 0.0, 0.0).remove(0);
            connection
                .execute(
                    "INSERT INTO names (rowid, id, name, lat, lng, zoom, type, detail,
                        source_field, context, cell)
                     VALUES (?1, ?1, ?2, ?3, ?4, 14, ?5, ?6, 'name', ?7, ?8)",
                    rusqlite::params![id, name, lat, lng, kind, detail, area, cell],
                )
                .expect("insert");
            connection
                .execute(
                    "INSERT INTO names_meta VALUES (?1, ?2, ?3, ?4, 14, ?5, ?6, 'name', ?7)",
                    rusqlite::params![id, name, lat, lng, kind, detail, area],
                )
                .expect("insert meta");
        }
        db
    }

    /// A names database from before September 2026: no area, no grid, type
    /// not indexed.
    fn old_names_db(rows: &[(&str, f64, f64, i64, &str)]) -> TempDb {
        let db = TempDb::new();
        let connection = Connection::open(&db.path).expect("create db");
        connection
            .execute_batch(
                "CREATE VIRTUAL TABLE names USING fts5(
                    id UNINDEXED, name, lat UNINDEXED, lng UNINDEXED, zoom UNINDEXED,
                    type UNINDEXED, detail, source_field UNINDEXED)",
            )
            .expect("fts5 is compiled into the bundled SQLite");
        for (id, (name, lat, lng, zoom, kind)) in rows.iter().enumerate() {
            connection
                .execute(
                    "INSERT INTO names VALUES (?1, ?2, ?3, ?4, ?5, ?6, NULL, 'name')",
                    rusqlite::params![id as i64, name, lat, lng, zoom, kind],
                )
                .expect("insert");
        }
        db
    }

    pub(in crate::navigation) use temp_db::TempDb;

    mod temp_db {
        use std::path::PathBuf;
        use std::sync::atomic::{AtomicUsize, Ordering};

        static NEXT: AtomicUsize = AtomicUsize::new(0);

        pub struct TempDb {
            pub path: PathBuf,
        }

        impl TempDb {
            pub fn new() -> Self {
                let path = std::env::temp_dir().join(format!(
                    "carnine-names-test-{}-{}.db",
                    std::process::id(),
                    NEXT.fetch_add(1, Ordering::Relaxed)
                ));
                let _ = std::fs::remove_file(&path);
                Self { path }
            }
        }

        impl Drop for TempDb {
            fn drop(&mut self) {
                let _ = std::fs::remove_file(&self.path);
            }
        }
    }

    const ALSFELD: (f64, f64) = (50.75, 9.27);

    /// The library's test data: 200 "Hauptstraße" far in the north, the one
    /// in Alsfeld last, so without the near search it would miss the limit.
    fn area_db() -> TempDb {
        let far: Vec<(String, f64)> = (0..200)
            .map(|i| (format!("Nordort {i}"), 9.0 + f64::from(i) * 0.01))
            .collect();
        let mut rows: Vec<Row> = far
            .iter()
            .map(|(area, lng)| {
                (
                    "Hauptstraße",
                    53.5,
                    *lng,
                    "transportation_name",
                    "minor",
                    Some(area.as_str()),
                )
            })
            .collect();
        rows.extend([
            (
                "Alsfeld",
                50.752,
                9.268,
                "place",
                "town",
                Some("Lauterbach"),
            ),
            ("Rewe", 50.750, 9.270, "poi", "supermarket", Some("Alsfeld")),
            (
                "Hauptstraße",
                50.7505,
                9.2705,
                "poi",
                "bus",
                Some("Alsfeld"),
            ),
            (
                "Hauptstraße",
                50.7504,
                9.2704,
                "poi",
                "information",
                Some("Alsfeld"),
            ),
            (
                "Alsfelder Hof",
                53.5,
                9.0,
                "poi",
                "hotel",
                Some("Nordort 0"),
            ),
            (
                "Hauptstraße",
                53.5,
                9.1,
                "place",
                "locality",
                Some("Nordort 10"),
            ),
            (
                "Hauptbahnhof",
                50.107,
                8.663,
                "poi",
                "railway",
                Some("Frankfurt am Main"),
            ),
            (
                "Hauptbahnhof",
                49.999,
                8.259,
                "transportation_name",
                "minor",
                Some("Mainz"),
            ),
            (
                "Fulda-Galerie",
                50.74,
                9.26,
                "place",
                "suburb",
                Some("Alsfeld"),
            ),
            (
                "Hauptstraße",
                50.751,
                9.270,
                "transportation_name",
                "secondary",
                Some("Alsfeld"),
            ),
            (
                "Hauptstraße",
                47.998,
                7.842,
                "poi",
                "railway",
                Some("Freiburg im Breisgau"),
            ),
            ("Berlin", 52.517, 13.389, "place", "city", None),
            (
                "Berlin",
                50.749,
                9.271,
                "poi",
                "restaurant",
                Some("Alsfeld"),
            ),
        ]);
        names_db(&rows)
    }

    fn names(hits: &[PlaceRecord]) -> Vec<&str> {
        hits.iter().map(|hit| hit.name.as_str()).collect()
    }

    #[test]
    fn the_nearby_hauptstrasse_is_found_among_200_others() {
        let db = area_db();
        let hits = search(&db.path, "Hauptstraße", 3, Some(ALSFELD)).expect("search");
        assert_eq!(hits.len(), 3);
        assert_eq!(hits[0].area.as_deref(), Some("Alsfeld"));
        assert_eq!(
            hits[0].kind, "transportation_name",
            "the street before the bus stop of the same name"
        );
    }

    #[test]
    fn a_far_poi_goes_behind_the_street_nearby() {
        // The station "Hauptstraße" in Freiburg ranks 1, the street in
        // Alsfeld 4; with `near` the surroundings count first, and behind
        // Alsfeld Freiburg still comes before the far streets.
        let db = area_db();
        let hits = search(&db.path, "Hauptstraße", 5, Some(ALSFELD)).expect("search");
        assert_eq!(hits[0].kind, "transportation_name");
        let areas: Vec<_> = hits
            .iter()
            .map(|hit| hit.area.as_deref().unwrap())
            .collect();
        assert_eq!(
            areas[..4],
            ["Alsfeld", "Alsfeld", "Alsfeld", "Freiburg im Breisgau"]
        );
        assert!(areas[4].starts_with("Nordort"), "{areas:?}");
    }

    #[test]
    fn the_far_city_beats_the_poi_of_the_same_name_nearby() {
        let db = area_db();
        let hits = search(&db.path, "Berlin", 0, Some(ALSFELD)).expect("search");
        let kinds: Vec<_> = hits.iter().map(|hit| hit.kind.as_str()).collect();
        assert_eq!(kinds, ["place", "poi"]);
    }

    #[test]
    fn with_near_the_surroundings_come_before_the_rest_of_the_country() {
        // The library's test: from near Alsfeld, Kassel is ~64 km and
        // Frankfurt ~81 km away, both beyond the radius, where the POI is
        // ahead of the streets again.
        let db = old_names_db(&[
            ("Hauptstraße", 51.30, 9.50, 15, "transportation_name"),
            ("Hauptstraße", 50.75, 9.27, 15, "transportation_name"),
            ("Hauptstraße", 50.11, 8.68, 15, "transportation_name"),
            ("Hauptbahnhof", 50.10, 8.66, 14, "poi"),
        ]);
        let hits = search(&db.path, "Haupt", 0, Some((50.74, 9.25))).expect("search");
        let order: Vec<_> = hits
            .iter()
            .map(|hit| (hit.kind.as_str(), hit.latitude))
            .collect();
        assert_eq!(
            order,
            [
                ("transportation_name", 50.75),
                ("poi", 50.10),
                ("transportation_name", 51.30),
                ("transportation_name", 50.11),
            ]
        );
    }

    #[test]
    fn a_street_of_the_same_name_elsewhere_does_not_push_back_the_poi() {
        let db = area_db();
        let hits = search(&db.path, "Hauptbahnhof", 0, Some((50.11, 8.68))).expect("search");
        let areas: Vec<_> = hits.iter().map(|hit| hit.area.as_deref()).collect();
        assert_eq!(areas, [Some("Frankfurt am Main"), Some("Mainz")]);
    }

    #[test]
    fn the_place_comes_before_a_nearby_poi() {
        let db = area_db();
        let hits = search(&db.path, "Alsfeld", 0, Some((53.5, 9.0))).expect("search");
        assert_eq!(names(&hits), ["Alsfeld", "Alsfelder Hof"]);
    }

    #[test]
    fn name_and_area_together_find_the_right_street() {
        let db = area_db();
        let hits = search(&db.path, "Hauptstraße Alsfeld", 0, None).expect("search");
        let kinds: Vec<_> = hits.iter().map(|hit| hit.kind.as_str()).collect();
        assert_eq!(kinds, ["transportation_name", "poi", "poi"]);
        assert!(hits
            .iter()
            .all(|hit| hit.area.as_deref() == Some("Alsfeld")));
    }

    #[test]
    fn the_area_alone_does_not_find_every_street_there() {
        let db = area_db();
        let hits = search(&db.path, "Alsfeld", 0, None).expect("search");
        assert_eq!(names(&hits), ["Alsfeld", "Alsfelder Hof"]);
        assert_eq!(hits[0].area.as_deref(), Some("Lauterbach"));
    }

    /// Three places called "Frankfurt": the village in Franconia is named
    /// exactly that, the two cities only start that way.
    fn frankfurt_db() -> TempDb {
        names_db(&[
            (
                "Frankfurt",
                49.681,
                10.527,
                "place",
                "village",
                Some("Scheinfeld"),
            ),
            (
                "Frankfurter Straße",
                50.31,
                9.46,
                "transportation_name",
                "secondary",
                Some("Steinau an der Straße"),
            ),
            (
                "Frankfurt-Höchst",
                50.10,
                8.54,
                "place",
                "suburb",
                Some("Frankfurt am Main"),
            ),
            ("Frankfurt (Oder)", 52.341, 14.549, "place", "town", None),
            ("Frankfurt am Main", 50.111, 8.682, "place", "city", None),
        ])
    }

    #[test]
    fn frankfurt_means_the_city_not_the_village_of_that_name() {
        let db = frankfurt_db();
        // Behind the city the order of the database stays.
        let hits = search(&db.path, "Frankfurt", 0, None).expect("search");
        assert_eq!(
            names(&hits),
            [
                "Frankfurt am Main",
                "Frankfurt",
                "Frankfurt (Oder)",
                "Frankfurt-Höchst",
                "Frankfurter Straße",
            ]
        );
    }

    #[test]
    fn the_city_stays_ahead_of_the_village_nearby() {
        // From Würzburg the village is ~45 km away, Frankfurt ~100 km and
        // Frankfurt (Oder) ~450 km; only the city goes ahead of the village.
        let db = frankfurt_db();
        let hits = search(&db.path, "Frankfurt", 0, Some((49.79, 9.95))).expect("search");
        assert_eq!(
            names(&hits)[..3],
            ["Frankfurt am Main", "Frankfurt", "Frankfurt (Oder)"]
        );
    }

    #[test]
    fn a_town_does_not_push_back_the_village_nearby() {
        let db = names_db(&[
            ("Hausen", 50.13, 8.93, "place", "town", Some("Hanau")),
            ("Hausen", 50.86, 9.45, "place", "village", Some("Oberaula")),
        ]);
        let hits = search(&db.path, "Hausen", 0, Some(ALSFELD)).expect("search");
        let areas: Vec<_> = hits.iter().map(|hit| hit.area.as_deref()).collect();
        assert_eq!(areas, [Some("Oberaula"), Some("Hanau")]);
    }

    #[test]
    fn only_a_whole_word_counts_as_the_city_name() {
        // "Frankfurter Straße" and "Frankfurt-Höchst" start with the word but
        // are no city of that name.
        let db = frankfurt_db();
        // Frankfurt-Höchst is found through its area "Frankfurt am Main".
        let hits = search(&db.path, "Frankfurt am", 0, None).expect("search");
        assert_eq!(names(&hits), ["Frankfurt am Main", "Frankfurt-Höchst"]);
        let hits = search(&db.path, "Frankf", 0, None).expect("search");
        assert_eq!(names(&hits)[0], "Frankfurt am Main");
    }

    #[test]
    fn limit_holds_with_near() {
        let db = area_db();
        let hits = search(&db.path, "Hauptstraße", 2, Some(ALSFELD)).expect("search");
        assert_eq!(hits.len(), 2);
    }

    #[test]
    fn fts_syntax_in_the_query_is_taken_literally() {
        let db = area_db();
        let hits = search(&db.path, "Fulda-Gal", 0, None).expect("no FTS syntax error");
        assert_eq!(names(&hits), ["Fulda-Galerie"]);
        assert!(search(&db.path, "\"", 0, None)
            .expect("quote alone")
            .is_empty());
        assert!(search(&db.path, "   ", 0, None).expect("blank").is_empty());
    }

    #[test]
    fn an_old_database_is_still_searched() {
        let db = old_names_db(&[
            ("Alsfelder Straße", 50.10, 8.60, 16, "transportation_name"),
            ("Fulda-Galerie", 50.74, 9.26, 14, "place"),
            ("Fulda", 50.55, 9.68, 12, "place"),
            ("Alsfeld", 50.7519, 9.2692, 12, "place"),
            ("Alsfeld Bahnhof", 50.75, 9.27, 16, "poi"),
        ]);
        let hits = search(&db.path, "alsf", 0, Some(ALSFELD)).expect("search");
        let kinds: Vec<_> = hits.iter().map(|hit| hit.kind.as_str()).collect();
        assert_eq!(kinds, ["place", "poi", "transportation_name"]);
        assert_eq!(hits[0].zoom, 12);
        assert_eq!(hits[0].area, None);
        let hits = search(&db.path, "fulda", 0, Some((50.74, 9.25))).expect("search");
        assert_eq!(names(&hits), ["Fulda", "Fulda-Galerie"]);
    }

    #[test]
    fn a_missing_database_is_an_error() {
        let missing = std::env::temp_dir().join("carnine-names-does-not-exist.db");
        assert!(search(&missing, "Alsfeld", 0, None).is_err());
    }

    /// Names of the examples in #172; the shop "Muecke Moden" was all that
    /// "Muecke" found before.
    fn typo_db() -> (TempDb, WordIndex) {
        // In DACH "frankfurt" is in thousands of names, "frankruti" in one;
        // the close word "frankruti" counts ten times, so it takes more than
        // ten Frankfurts here to outweigh it, as in the real data.
        let districts: Vec<String> = (0..12).map(|i| format!("Frankfurt-Ort {i}")).collect();
        let mut rows: Vec<Row> = districts
            .iter()
            .map(|name| {
                (
                    name.as_str(),
                    50.1,
                    8.6,
                    "place",
                    "suburb",
                    Some("Frankfurt am Main"),
                )
            })
            .collect();
        rows.extend([
            ("Frankfurt am Main", 50.111, 8.682, "place", "city", None),
            ("Frankrüti", 47.36, 8.86, "place", "hamlet", Some("Bauma")),
            ("Lauterbach", 50.637, 9.395, "place", "town", None),
            (
                "Lauterbacher Straße",
                50.64,
                9.40,
                "transportation_name",
                "minor",
                Some("Lauterbach"),
            ),
            (
                "Bahnhofstraße",
                50.636,
                9.398,
                "transportation_name",
                "secondary",
                Some("Lauterbach"),
            ),
            (
                "Bahnhofstraße",
                50.75,
                9.27,
                "transportation_name",
                "secondary",
                Some("Alsfeld"),
            ),
            (
                "Muecke Moden",
                50.10,
                8.68,
                "poi",
                "clothes",
                Some("Frankfurt am Main"),
            ),
            (
                "Mücke",
                50.61,
                9.03,
                "place",
                "village",
                Some("Vogelsbergkreis"),
            ),
            ("Gießen", 50.584, 8.678, "place", "town", None),
            (
                "Giessen",
                51.79,
                4.87,
                "place",
                "village",
                Some("Woudrichem"),
            ),
            (
                "Frankfurter Straße",
                50.58,
                8.67,
                "transportation_name",
                "primary",
                Some("Gießen"),
            ),
        ]);
        let db = names_db(&rows);
        let index = WordIndex::build(&db.path).expect("word index");
        (db, index)
    }

    #[test]
    fn a_misspelled_city_is_found_through_the_word_index() {
        let (db, index) = typo_db();
        assert!(search(&db.path, "Frankfrut", 0, None)
            .expect("search")
            .is_empty());
        let hits = search_with(&db.path, "Frankfrut", 0, None, Some(&index)).expect("search");
        assert_eq!(names(&hits)[0], "Frankfurt am Main");
        let hits = search_with(&db.path, "Lauterbch", 0, None, Some(&index)).expect("search");
        assert_eq!(names(&hits)[..2], ["Lauterbach", "Lauterbacher Straße"]);
    }

    #[test]
    fn a_misspelled_street_is_found_in_its_town() {
        let (db, index) = typo_db();
        let hits = search_with(&db.path, "Bahnhofstrase", 0, None, Some(&index)).expect("search");
        assert_eq!(names(&hits), ["Bahnhofstraße", "Bahnhofstraße"]);
        // Only the misspelled word is replaced; the town still narrows it down.
        let hits = search_with(&db.path, "Bahnhofstrase Lauterbach", 0, None, Some(&index))
            .expect("search");
        assert_eq!(names(&hits), ["Bahnhofstraße"]);
        assert_eq!(hits[0].area.as_deref(), Some("Lauterbach"));
    }

    #[test]
    fn a_word_spelled_right_searches_as_without_the_index() {
        let (db, index) = typo_db();
        for query in ["Frankfurt", "Lauterb", "Bahnhofstraße Alsfeld", "Frank"] {
            assert_eq!(
                search_with(&db.path, query, 0, Some(ALSFELD), Some(&index)).expect("search"),
                search(&db.path, query, 0, Some(ALSFELD)).expect("search"),
                "{query}"
            );
        }
        // Nothing close enough: still nothing.
        assert!(search_with(&db.path, "Xyzzy", 0, None, Some(&index))
            .expect("search")
            .is_empty());
    }

    #[test]
    fn written_out_umlauts_find_the_names_with_them() {
        let (db, _) = typo_db();
        let hits = search(&db.path, "Muecke", 0, None).expect("search");
        assert_eq!(names(&hits), ["Mücke", "Muecke Moden"]);
        let hits = search(&db.path, "Giessen", 0, None).expect("search");
        let mut found = names(&hits);
        found.sort_unstable();
        assert_eq!(found, ["Giessen", "Gießen"]);
        let hits = search(&db.path, "Frankfurter Strasse", 0, None).expect("search");
        assert_eq!(names(&hits), ["Frankfurter Straße"]);
    }

    #[test]
    fn grid_cells_match_the_extraction_script() {
        // grid_cell(50.75, 9.27) in extract_names_to_sqlite.py.
        assert_eq!(cells_around(50.75, 9.27, 0.0, 0.0), ["g281x378"]);
        assert_eq!(cells_around(50.75, 9.27, 0.45, 0.7).len(), 9);
    }

    #[test]
    fn distance_is_roughly_right() {
        // Alsfeld to Frankfurt city centre is about 83 km.
        let km = distance_meters(ALSFELD, (50.1109, 8.6821)) / 1000.0;
        assert!((80.0..86.0).contains(&km), "{km}");
    }
}
