//! Place search over the names database the map tools build next to the tiles
//! (`extract_names_to_sqlite.py` in flutter_local_map: an FTS5 table `names`).
//!
//! Ranking follows the map library's `OfflineGeocoder`, so a search reads the
//! same in the demo app and in carnine2: places before POIs before peaks,
//! water and streets; with `near`, more candidates per type ordered by
//! distance.

use std::path::Path;

use anyhow::{Context, Result};
use rusqlite::{Connection, OpenFlags};

/// Results when the request asks for none in particular.
pub const DEFAULT_LIMIT: usize = 15;
/// Hard cap, so a client cannot ask the Pi for the whole index.
const MAX_LIMIT: usize = 100;
/// With `near`, this many candidates per requested result are fetched first;
/// FTS knows nothing about distance, and "Hauptstraße" exists a thousand times.
const NEAR_CANDIDATE_FACTOR: usize = 10;

/// Type names as the extraction script writes them, in ranking order.
const TYPE_PRIORITY: [&str; 5] = [
    "place",
    "poi",
    "mountain_peak",
    "water_name",
    "transportation_name",
];

#[derive(Debug, Clone, PartialEq)]
pub struct PlaceRecord {
    pub name: String,
    pub latitude: f64,
    pub longitude: f64,
    pub zoom: u32,
    pub kind: String,
    pub detail: Option<String>,
}

/// Searches `database` for `query`. An empty query finds nothing.
pub fn search(
    database: &Path,
    query: &str,
    limit: usize,
    near: Option<(f64, f64)>,
) -> Result<Vec<PlaceRecord>> {
    let Some(fts_query) = fts_query(query) else {
        return Ok(Vec::new());
    };
    let limit = match limit {
        0 => DEFAULT_LIMIT,
        limit => limit.min(MAX_LIMIT),
    };
    let fetch = if near.is_some() {
        limit * NEAR_CANDIDATE_FACTOR
    } else {
        limit
    };
    let connection = Connection::open_with_flags(
        database,
        OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX,
    )
    .with_context(|| format!("opening names database {}", database.display()))?;
    let mut statement = connection.prepare(
        "SELECT name, lat, lng, zoom, type, detail FROM names
         WHERE names MATCH ?1
         ORDER BY CASE type
             WHEN 'place' THEN 0 WHEN 'poi' THEN 1 WHEN 'mountain_peak' THEN 2
             WHEN 'water_name' THEN 3 WHEN 'transportation_name' THEN 4 ELSE 5 END,
           rank
         LIMIT ?2",
    )?;
    let fetch = i64::try_from(fetch).unwrap_or(i64::MAX);
    let mut records = statement
        .query_map(rusqlite::params![fts_query, fetch], |row| {
            Ok(PlaceRecord {
                name: row.get(0)?,
                latitude: row.get(1)?,
                longitude: row.get(2)?,
                zoom: u32::try_from(row.get::<_, i64>(3)?).unwrap_or(0),
                kind: row.get(4)?,
                detail: row.get(5)?,
            })
        })?
        .collect::<rusqlite::Result<Vec<_>>>()
        .context("reading names")?;
    if let Some(origin) = near {
        // Stable sort: the type order from SQL stays, distance decides within it.
        records.sort_by(|a, b| {
            type_rank(&a.kind).cmp(&type_rank(&b.kind)).then_with(|| {
                distance_meters(origin, (a.latitude, a.longitude))
                    .total_cmp(&distance_meters(origin, (b.latitude, b.longitude)))
            })
        });
    }
    records.truncate(limit);
    Ok(records)
}

fn type_rank(kind: &str) -> usize {
    TYPE_PRIORITY
        .iter()
        .position(|known| *known == kind)
        .unwrap_or(TYPE_PRIORITY.len())
}

/// Turns what the user typed into an FTS5 query: every word a quoted prefix
/// term, all of them required. Quoting keeps `-`, `:` and friends from being
/// read as FTS syntax; the prefix finds "Frank" while it is still being typed.
fn fts_query(query: &str) -> Option<String> {
    let terms: Vec<String> = query
        .split_whitespace()
        .map(|word| format!("\"{}\"*", word.replace('"', "\"\"")))
        .collect();
    (!terms.is_empty()).then(|| terms.join(" "))
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
mod tests {
    use super::*;

    /// A names database with the extraction script's schema.
    fn names_db(rows: &[(&str, f64, f64, i64, &str)]) -> tempfile_path::TempDb {
        let db = tempfile_path::TempDb::new();
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

    mod tempfile_path {
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

    const ALSFELD: (f64, f64) = (50.7519, 9.2692);

    #[test]
    fn places_come_before_streets_and_prefixes_match() {
        let db = names_db(&[
            ("Alsfelder Straße", 50.10, 8.60, 16, "transportation_name"),
            ("Alsfeld", 50.7519, 9.2692, 12, "place"),
            ("Alsfeld Bahnhof", 50.75, 9.27, 16, "poi"),
        ]);
        let hits = search(&db.path, "alsf", 0, None).expect("search");
        let kinds: Vec<&str> = hits.iter().map(|hit| hit.kind.as_str()).collect();
        assert_eq!(kinds, ["place", "poi", "transportation_name"]);
        assert_eq!(hits[0].zoom, 12);
    }

    #[test]
    fn near_orders_by_distance_within_a_type() {
        let db = names_db(&[
            ("Hauptstraße", 50.11, 8.68, 16, "transportation_name"),
            ("Hauptstraße", 50.75, 9.27, 16, "transportation_name"),
            ("Hauptstraße", 51.31, 9.48, 16, "transportation_name"),
        ]);
        let hits = search(&db.path, "Hauptstraße", 2, Some(ALSFELD)).expect("search");
        assert_eq!(hits.len(), 2);
        assert!((hits[0].latitude - 50.75).abs() < 1e-9, "nearest first");
        assert!((hits[1].latitude - 51.31).abs() < 1e-9);
    }

    #[test]
    fn fts_syntax_in_the_query_is_taken_literally() {
        let db = names_db(&[("Bad Hersfeld-Rotenburg", 50.87, 9.70, 12, "place")]);
        let hits = search(&db.path, "hersfeld-rot", 0, None).expect("no FTS syntax error");
        assert_eq!(hits.len(), 1);
        assert!(search(&db.path, "\"", 0, None)
            .expect("quote alone")
            .is_empty());
        assert!(search(&db.path, "   ", 0, None).expect("blank").is_empty());
    }

    #[test]
    fn a_missing_database_is_an_error() {
        let missing = std::env::temp_dir().join("carnine-names-does-not-exist.db");
        assert!(search(&missing, "Alsfeld", 0, None).is_err());
    }

    #[test]
    fn distance_is_roughly_right() {
        // Alsfeld to Frankfurt city centre is about 83 km.
        let km = distance_meters(ALSFELD, (50.1109, 8.6821)) / 1000.0;
        assert!((80.0..86.0).contains(&km), "{km}");
    }
}
