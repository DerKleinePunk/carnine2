use std::path::Path;

use anyhow::{Context, Result};
use rusqlite::{params, Connection};

const CURRENT_SCHEMA_VERSION: i64 = 1;

pub struct Database {
    connection: Connection,
}

#[derive(Debug, PartialEq, Eq)]
pub struct MediaRecord {
    pub id: i64,
    pub source_id: i64,
    pub path: String,
    pub title: String,
    pub artist: String,
    pub duration_ms: i64,
    pub status: String,
}

impl Database {
    pub fn open(path: impl AsRef<Path>) -> Result<Self> {
        let connection = Connection::open(path.as_ref())
            .with_context(|| format!("failed to open database {}", path.as_ref().display()))?;
        connection.execute_batch("PRAGMA foreign_keys = ON;")?;
        let database = Self { connection };
        database.migrate()?;
        Ok(database)
    }

    fn migrate(&self) -> Result<()> {
        self.connection.execute_batch(
            "CREATE TABLE IF NOT EXISTS schema_migrations (
                version INTEGER PRIMARY KEY,
                applied_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );",
        )?;
        let version: i64 = self.connection.query_row(
            "SELECT COALESCE(MAX(version), 0) FROM schema_migrations",
            [],
            |row| row.get(0),
        )?;
        if version < 1 {
            self.connection.execute_batch(
                "CREATE TABLE sources (
                    id INTEGER PRIMARY KEY,
                    uri TEXT NOT NULL UNIQUE,
                    status TEXT NOT NULL CHECK (status IN ('AVAILABLE', 'OFFLINE', 'MISSING'))
                );
                CREATE TABLE media (
                    id INTEGER PRIMARY KEY,
                    source_id INTEGER NOT NULL REFERENCES sources(id),
                    path TEXT NOT NULL,
                    title TEXT NOT NULL,
                    artist TEXT NOT NULL,
                    duration_ms INTEGER NOT NULL DEFAULT 0,
                    status TEXT NOT NULL CHECK (status IN ('AVAILABLE', 'OFFLINE', 'MISSING')),
                    UNIQUE (source_id, path)
                );
                CREATE TABLE playlists (
                    id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL UNIQUE
                );
                CREATE TABLE playlist_entries (
                    id INTEGER PRIMARY KEY,
                    playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
                    media_id INTEGER NOT NULL REFERENCES media(id),
                    position INTEGER NOT NULL,
                    UNIQUE (playlist_id, position)
                );
                CREATE TABLE resume_state (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    playlist_id INTEGER REFERENCES playlists(id),
                    playlist_entry_id INTEGER REFERENCES playlist_entries(id),
                    position_ms INTEGER NOT NULL DEFAULT 0,
                    resume_mode TEXT NOT NULL
                );
                INSERT INTO schema_migrations (version) VALUES (1);",
            )?;
        }
        if version > CURRENT_SCHEMA_VERSION {
            anyhow::bail!(
                "database schema version {version} is newer than supported version {CURRENT_SCHEMA_VERSION}"
            );
        }
        Ok(())
    }

    pub fn upsert_source(&self, uri: &str, status: &str) -> Result<i64> {
        self.connection.execute(
            "INSERT INTO sources (uri, status) VALUES (?1, ?2)
             ON CONFLICT(uri) DO UPDATE SET status = excluded.status",
            params![uri, status],
        )?;
        Ok(self
            .connection
            .query_row("SELECT id FROM sources WHERE uri = ?1", [uri], |row| {
                row.get(0)
            })?)
    }

    pub fn upsert_media(&self, media: &MediaRecord) -> Result<i64> {
        self.connection.execute(
            "INSERT INTO media
                (source_id, path, title, artist, duration_ms, status)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)
             ON CONFLICT(source_id, path) DO UPDATE SET
                title = excluded.title,
                artist = excluded.artist,
                duration_ms = excluded.duration_ms,
                status = excluded.status",
            params![
                media.source_id,
                media.path,
                media.title,
                media.artist,
                media.duration_ms,
                media.status
            ],
        )?;
        Ok(self.connection.query_row(
            "SELECT id FROM media WHERE source_id = ?1 AND path = ?2",
            params![media.source_id, media.path],
            |row| row.get(0),
        )?)
    }

    pub fn search_media(&self, query: &str) -> Result<Vec<MediaRecord>> {
        let pattern = format!("%{}%", query.trim());
        let mut statement = self.connection.prepare(
            "SELECT id, source_id, path, title, artist, duration_ms, status
             FROM media
             WHERE title LIKE ?1 COLLATE NOCASE OR artist LIKE ?1 COLLATE NOCASE
             ORDER BY artist COLLATE NOCASE, title COLLATE NOCASE, id",
        )?;
        let rows = statement.query_map([pattern], |row| {
            Ok(MediaRecord {
                id: row.get(0)?,
                source_id: row.get(1)?,
                path: row.get(2)?,
                title: row.get(3)?,
                artist: row.get(4)?,
                duration_ms: row.get(5)?,
                status: row.get(6)?,
            })
        })?;
        Ok(rows.collect::<rusqlite::Result<Vec<_>>>()?)
    }

    #[cfg(test)]
    fn schema_version(&self) -> Result<i64> {
        Ok(self
            .connection
            .query_row("SELECT MAX(version) FROM schema_migrations", [], |row| {
                row.get(0)
            })?)
    }
}

#[cfg(test)]
mod tests {
    use super::{Database, MediaRecord, CURRENT_SCHEMA_VERSION};

    #[test]
    fn creates_current_schema_and_is_idempotent() {
        let path = std::env::temp_dir().join(format!(
            "carnine-database-test-{}.sqlite3",
            std::process::id()
        ));
        let _ = std::fs::remove_file(&path);
        let database = Database::open(&path).expect("database should open");
        assert_eq!(
            database
                .schema_version()
                .expect("schema version should exist"),
            CURRENT_SCHEMA_VERSION
        );
        drop(database);

        let database = Database::open(&path).expect("database should reopen");
        assert_eq!(
            database
                .schema_version()
                .expect("schema version should exist"),
            CURRENT_SCHEMA_VERSION
        );
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn upserts_and_searches_media_records() {
        let database = Database::open(":memory:").expect("database should open");
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should be stored");
        let media = MediaRecord {
            id: 0,
            source_id,
            path: "/music/song.mp3".to_string(),
            title: "Road Home".to_string(),
            artist: "Kensington Road".to_string(),
            duration_ms: 175_000,
            status: "AVAILABLE".to_string(),
        };

        let first_id = database
            .upsert_media(&media)
            .expect("media should be stored");
        let second_id = database
            .upsert_media(&MediaRecord {
                title: "Road Home (Edit)".to_string(),
                ..media
            })
            .expect("media should be updated");
        assert_eq!(first_id, second_id);

        let results = database
            .search_media("kensington")
            .expect("media search should work");
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].title, "Road Home (Edit)");
        assert_eq!(results[0].id, first_id);
    }
}
