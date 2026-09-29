use std::collections::HashMap;
use std::hash::{Hash, Hasher};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};

use anyhow::{Context, Result};
use rusqlite::{params, Connection};

const CURRENT_SCHEMA_VERSION: i64 = 6;

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
    pub cover_path: Option<String>,
}

#[derive(Debug, PartialEq, Eq)]
pub struct PlaylistEntry {
    pub id: i64,
    pub playlist_id: i64,
    pub media_id: i64,
    pub position: i64,
}

#[derive(Debug, PartialEq, Eq)]
pub struct ResumeState {
    pub playlist_id: Option<i64>,
    pub playlist_entry_id: Option<i64>,
    pub position_ms: i64,
    pub resume_mode: String,
    /// Proto name of the repeat mode, e.g. `REPEAT_QUEUE`.
    pub repeat_mode: String,
    pub shuffle_enabled: bool,
}

#[derive(Debug, PartialEq, Eq)]
pub struct PlaylistRecord {
    pub id: i64,
    pub name: String,
}

#[derive(Debug, Default, serde::Deserialize)]
struct ProbeFormat {
    duration: Option<String>,
    tags: Option<std::collections::HashMap<String, String>>,
}

#[derive(Debug, serde::Deserialize)]
struct ProbeOutput {
    format: ProbeFormat,
}

#[derive(Debug, Default)]
struct AudioMetadata {
    title: Option<String>,
    artist: Option<String>,
    duration_ms: i64,
}

/// Size and modification time of a file; equal values mean "unchanged".
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct FileFingerprint {
    size: i64,
    mtime_ms: i64,
}

impl FileFingerprint {
    fn of(path: &Path) -> Option<Self> {
        let metadata = std::fs::metadata(path).ok()?;
        let mtime_ms = metadata
            .modified()
            .ok()?
            .duration_since(std::time::UNIX_EPOCH)
            .ok()?
            .as_millis();
        Some(Self {
            size: i64::try_from(metadata.len()).ok()?,
            mtime_ms: i64::try_from(mtime_ms).ok()?,
        })
    }
}

/// Reads what a scan stores about a file; the real one runs ffprobe/ffmpeg.
trait MediaReader {
    fn metadata(&self, path: &Path) -> Result<AudioMetadata>;
    fn cover(&self, path: &Path, cache_dir: &Path) -> Result<Option<String>>;
}

struct ToolReader;

impl MediaReader for ToolReader {
    fn metadata(&self, path: &Path) -> Result<AudioMetadata> {
        read_audio_metadata(path)
    }

    fn cover(&self, path: &Path, cache_dir: &Path) -> Result<Option<String>> {
        extract_cover_art(path, cache_dir)
    }
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
        if version < 2 {
            self.connection.execute_batch(
                "ALTER TABLE media ADD COLUMN cover_path TEXT;
                INSERT INTO schema_migrations (version) VALUES (2);",
            )?;
        }
        if version < 3 {
            self.connection.execute_batch(
                "CREATE TABLE ui_state (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    last_page TEXT NOT NULL DEFAULT ''
                );
                INSERT INTO schema_migrations (version) VALUES (3);",
            )?;
        }
        if version < 4 {
            // Repeat and shuffle were lost on every backend restart (#29).
            self.connection.execute_batch(
                "ALTER TABLE resume_state ADD COLUMN repeat_mode TEXT NOT NULL DEFAULT 'REPEAT_OFF';
                ALTER TABLE resume_state ADD COLUMN shuffle_enabled INTEGER NOT NULL DEFAULT 0;
                INSERT INTO schema_migrations (version) VALUES (4);",
            )?;
        }
        if version < 5 {
            // Navigation switches set over gRPC that must survive a restart.
            self.connection.execute_batch(
                "CREATE TABLE navigation_state (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    track_recording INTEGER NOT NULL DEFAULT 0
                );
                INSERT INTO schema_migrations (version) VALUES (5);",
            )?;
        }
        if version < 6 {
            // Size and modification time of the file a row was read from, so a
            // rescan skips unchanged files instead of running ffprobe and
            // ffmpeg on every one of them again (#43). NULL means "read again".
            self.connection.execute_batch(
                "ALTER TABLE media ADD COLUMN file_size INTEGER;
                ALTER TABLE media ADD COLUMN file_mtime_ms INTEGER;
                INSERT INTO schema_migrations (version) VALUES (6);",
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

    #[cfg(test)]
    pub fn upsert_media(&self, media: &MediaRecord) -> Result<i64> {
        self.connection.execute(
            "INSERT INTO media
                (source_id, path, title, artist, duration_ms, status, cover_path)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
             ON CONFLICT(source_id, path) DO UPDATE SET
                title = excluded.title,
                artist = excluded.artist,
                duration_ms = excluded.duration_ms,
                status = excluded.status,
                cover_path = excluded.cover_path",
            params![
                media.source_id,
                media.path,
                media.title,
                media.artist,
                media.duration_ms,
                media.status,
                media.cover_path
            ],
        )?;
        Ok(self.connection.query_row(
            "SELECT id FROM media WHERE source_id = ?1 AND path = ?2",
            params![media.source_id, media.path],
            |row| row.get(0),
        )?)
    }

    /// Like [`Self::upsert_media`], but an existing row keeps its title, artist
    /// and duration when `keep_metadata` is set, and its cover when
    /// `keep_cover` is set. A new row always takes the given values.
    /// `fingerprint` is the file's size and modification time, stored only
    /// when everything was read, so a failed read is tried again next scan.
    fn upsert_scanned_media(
        &self,
        media: &MediaRecord,
        keep_metadata: bool,
        keep_cover: bool,
        fingerprint: Option<FileFingerprint>,
    ) -> Result<()> {
        self.connection.execute(
            "INSERT INTO media
                (source_id, path, title, artist, duration_ms, status, cover_path,
                 file_size, file_mtime_ms)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?10, ?11)
             ON CONFLICT(source_id, path) DO UPDATE SET
                title = CASE WHEN ?8 THEN media.title ELSE excluded.title END,
                artist = CASE WHEN ?8 THEN media.artist ELSE excluded.artist END,
                duration_ms = CASE WHEN ?8 THEN media.duration_ms ELSE excluded.duration_ms END,
                status = excluded.status,
                cover_path = CASE WHEN ?9 THEN media.cover_path ELSE excluded.cover_path END,
                file_size = excluded.file_size,
                file_mtime_ms = excluded.file_mtime_ms",
            params![
                media.source_id,
                media.path,
                media.title,
                media.artist,
                media.duration_ms,
                media.status,
                media.cover_path,
                keep_metadata,
                keep_cover,
                fingerprint.map(|value| value.size),
                fingerprint.map(|value| value.mtime_ms)
            ],
        )?;
        Ok(())
    }

    /// Id and stored fingerprint of every row of `source_id`, by path.
    fn scanned_media_by_path(
        &self,
        source_id: i64,
    ) -> Result<HashMap<String, (i64, Option<FileFingerprint>)>> {
        let mut statement = self
            .connection
            .prepare("SELECT id, path, file_size, file_mtime_ms FROM media WHERE source_id = ?1")?;
        let rows = statement.query_map([source_id], |row| {
            let size: Option<i64> = row.get(2)?;
            let mtime_ms: Option<i64> = row.get(3)?;
            Ok((
                row.get::<_, String>(1)?,
                (
                    row.get::<_, i64>(0)?,
                    size.zip(mtime_ms)
                        .map(|(size, mtime_ms)| FileFingerprint { size, mtime_ms }),
                ),
            ))
        })?;
        Ok(rows.collect::<rusqlite::Result<HashMap<_, _>>>()?)
    }

    pub fn search_media(&self, query: &str) -> Result<Vec<MediaRecord>> {
        let pattern = format!("%{}%", query.trim());
        let mut statement = self.connection.prepare(
            "SELECT id, source_id, path, title, artist, duration_ms, status, cover_path
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
                cover_path: row.get(7)?,
            })
        })?;
        Ok(rows.collect::<rusqlite::Result<Vec<_>>>()?)
    }

    pub fn media_by_id(&self, media_id: i64) -> Result<Option<MediaRecord>> {
        let mut statement = self.connection.prepare(
            "SELECT id, source_id, path, title, artist, duration_ms, status, cover_path
             FROM media WHERE id = ?1",
        )?;
        let mut rows = statement.query([media_id])?;
        let Some(row) = rows.next()? else {
            return Ok(None);
        };
        Ok(Some(MediaRecord {
            id: row.get(0)?,
            source_id: row.get(1)?,
            path: row.get(2)?,
            title: row.get(3)?,
            artist: row.get(4)?,
            duration_ms: row.get(5)?,
            status: row.get(6)?,
            cover_path: row.get(7)?,
        }))
    }

    /// The scanned duration of the file at `path`, if the library knows it.
    /// A path is unique per source only; any known duration will do.
    pub fn duration_by_path(&self, path: &str) -> Result<Option<i64>> {
        let mut statement = self.connection.prepare(
            "SELECT duration_ms FROM media
             WHERE path = ?1 AND duration_ms > 0 ORDER BY id LIMIT 1",
        )?;
        let mut rows = statement.query([path])?;
        Ok(match rows.next()? {
            Some(row) => Some(row.get(0)?),
            None => None,
        })
    }

    pub fn playlist_cover_path(&self, playlist_id: i64) -> Result<Option<String>> {
        let mut statement = self.connection.prepare(
            "SELECT media.cover_path
             FROM playlist_entries
             JOIN media ON media.id = playlist_entries.media_id
             WHERE playlist_entries.playlist_id = ?1 AND media.cover_path IS NOT NULL
             ORDER BY playlist_entries.position
             LIMIT 1",
        )?;
        let mut rows = statement.query([playlist_id])?;
        let Some(row) = rows.next()? else {
            return Ok(None);
        };
        Ok(row.get(0)?)
    }

    pub fn create_playlist(&self, name: &str) -> Result<i64> {
        self.connection
            .execute("INSERT INTO playlists (name) VALUES (?1)", [name.trim()])?;
        Ok(self.connection.last_insert_rowid())
    }

    pub fn playlist_name(&self, playlist_id: i64) -> Result<String> {
        Ok(self.connection.query_row(
            "SELECT name FROM playlists WHERE id = ?1",
            [playlist_id],
            |row| row.get(0),
        )?)
    }

    pub fn playlists(&self) -> Result<Vec<PlaylistRecord>> {
        let mut statement = self
            .connection
            .prepare("SELECT id, name FROM playlists ORDER BY name COLLATE NOCASE, id")?;
        let rows = statement.query_map([], |row| {
            Ok(PlaylistRecord {
                id: row.get(0)?,
                name: row.get(1)?,
            })
        })?;
        Ok(rows.collect::<rusqlite::Result<Vec<_>>>()?)
    }

    pub fn add_playlist_entry(&self, playlist_id: i64, media_id: i64) -> Result<i64> {
        let position: i64 = self.connection.query_row(
            "SELECT COALESCE(MAX(position), -1) + 1
             FROM playlist_entries WHERE playlist_id = ?1",
            [playlist_id],
            |row| row.get(0),
        )?;
        self.connection.execute(
            "INSERT INTO playlist_entries (playlist_id, media_id, position)
             VALUES (?1, ?2, ?3)",
            params![playlist_id, media_id, position],
        )?;
        Ok(self.connection.last_insert_rowid())
    }

    pub fn playlist_entries(&self, playlist_id: i64) -> Result<Vec<PlaylistEntry>> {
        let mut statement = self.connection.prepare(
            "SELECT id, playlist_id, media_id, position
             FROM playlist_entries WHERE playlist_id = ?1 ORDER BY position",
        )?;
        let rows = statement.query_map([playlist_id], |row| {
            Ok(PlaylistEntry {
                id: row.get(0)?,
                playlist_id: row.get(1)?,
                media_id: row.get(2)?,
                position: row.get(3)?,
            })
        })?;
        Ok(rows.collect::<rusqlite::Result<Vec<_>>>()?)
    }

    pub fn playlist_media_paths(&self, playlist_id: i64) -> Result<Vec<(i64, String)>> {
        let mut statement = self.connection.prepare(
            "SELECT playlist_entries.id, media.path
             FROM playlist_entries
             JOIN media ON media.id = playlist_entries.media_id
             WHERE playlist_entries.playlist_id = ?1
             ORDER BY playlist_entries.position",
        )?;
        let rows = statement.query_map([playlist_id], |row| Ok((row.get(0)?, row.get(1)?)))?;
        Ok(rows.collect::<rusqlite::Result<Vec<_>>>()?)
    }

    pub fn save_resume_state(&self, state: &ResumeState) -> Result<()> {
        self.connection.execute(
            "INSERT INTO resume_state
                (id, playlist_id, playlist_entry_id, position_ms, resume_mode,
                 repeat_mode, shuffle_enabled)
             VALUES (1, ?1, ?2, ?3, ?4, ?5, ?6)
             ON CONFLICT(id) DO UPDATE SET
                playlist_id = excluded.playlist_id,
                playlist_entry_id = excluded.playlist_entry_id,
                position_ms = excluded.position_ms,
                resume_mode = excluded.resume_mode,
                repeat_mode = excluded.repeat_mode,
                shuffle_enabled = excluded.shuffle_enabled",
            params![
                state.playlist_id,
                state.playlist_entry_id,
                state.position_ms,
                state.resume_mode,
                state.repeat_mode,
                state.shuffle_enabled
            ],
        )?;
        Ok(())
    }

    pub fn load_resume_state(&self) -> Result<Option<ResumeState>> {
        let mut statement = self.connection.prepare(
            "SELECT playlist_id, playlist_entry_id, position_ms, resume_mode,
                    repeat_mode, shuffle_enabled
             FROM resume_state WHERE id = 1",
        )?;
        let mut rows = statement.query([])?;
        let Some(row) = rows.next()? else {
            return Ok(None);
        };
        Ok(Some(ResumeState {
            playlist_id: row.get(0)?,
            playlist_entry_id: row.get(1)?,
            position_ms: row.get(2)?,
            resume_mode: row.get(3)?,
            repeat_mode: row.get(4)?,
            shuffle_enabled: row.get(5)?,
        }))
    }

    pub fn save_last_page(&self, page: &str) -> Result<()> {
        self.connection.execute(
            "INSERT INTO ui_state (id, last_page) VALUES (1, ?1)
             ON CONFLICT(id) DO UPDATE SET last_page = excluded.last_page",
            [page],
        )?;
        Ok(())
    }

    /// The page saved last, or an empty string when there is none.
    pub fn load_last_page(&self) -> Result<String> {
        let mut statement = self
            .connection
            .prepare("SELECT last_page FROM ui_state WHERE id = 1")?;
        let mut rows = statement.query([])?;
        Ok(match rows.next()? {
            Some(row) => row.get(0)?,
            None => String::new(),
        })
    }

    pub fn save_track_recording(&self, enabled: bool) -> Result<()> {
        self.connection.execute(
            "INSERT INTO navigation_state (id, track_recording) VALUES (1, ?1)
             ON CONFLICT(id) DO UPDATE SET track_recording = excluded.track_recording",
            [enabled],
        )?;
        Ok(())
    }

    /// Whether track recording was switched on; off when never set.
    pub fn load_track_recording(&self) -> Result<bool> {
        let mut statement = self
            .connection
            .prepare("SELECT track_recording FROM navigation_state WHERE id = 1")?;
        let mut rows = statement.query([])?;
        Ok(match rows.next()? {
            Some(row) => row.get(0)?,
            None => false,
        })
    }

    /// Stops after the current file once `cancel` is set, e.g. while the
    /// backend shuts down, and then leaves every status as it was.
    pub fn rescan_folder(
        &self,
        folder: &Path,
        supported_formats: &[String],
        cover_cache_dir: &Path,
        cancel: &AtomicBool,
    ) -> Result<usize> {
        self.rescan_folder_with(
            folder,
            supported_formats,
            cover_cache_dir,
            &ToolReader,
            cancel,
        )
    }

    /// The scan behind [`Self::rescan_folder`], with the ffprobe/ffmpeg calls
    /// behind `reader` so tests can count them.
    ///
    /// Nothing is marked `MISSING` up front any more: a scan that ends early
    /// (the backend restarted mid-scan) used to leave every file not yet
    /// reached as `MISSING` (#43). Files whose size and modification time
    /// match the stored ones are not read again. The status changes of all
    /// unchanged and all vanished files go in one short transaction at the
    /// end; a transaction around the whole scan would block every other
    /// writer (resume state, playlists) for as long as the scan runs.
    fn rescan_folder_with(
        &self,
        folder: &Path,
        supported_formats: &[String],
        cover_cache_dir: &Path,
        reader: &dyn MediaReader,
        cancel: &AtomicBool,
    ) -> Result<usize> {
        let source_uri = folder.to_string_lossy().into_owned();
        let source_id = self.upsert_source(&source_uri, "AVAILABLE")?;
        let discovered = find_audio_files(folder, supported_formats)?;
        let mut known = self.scanned_media_by_path(source_id)?;
        let mut unchanged_ids = Vec::new();
        let mut read = 0_usize;
        for (index, path) in discovered.iter().enumerate() {
            if cancel.load(Ordering::Relaxed) {
                // What the next scan still has to read, for the log in the car.
                tracing::warn!(
                    folder = %folder.display(),
                    read,
                    unchanged = unchanged_ids.len(),
                    left = discovered.len() - index,
                    "scan cancelled"
                );
                anyhow::bail!("scan of {} cancelled", folder.display());
            }
            let path_text = path.to_string_lossy().into_owned();
            let fingerprint = FileFingerprint::of(path);
            if let Some((id, stored)) = known.remove(&path_text) {
                if stored.is_some() && stored == fingerprint {
                    unchanged_ids.push(id);
                    continue;
                }
            }
            let fallback_title = path
                .file_stem()
                .and_then(|value| value.to_str())
                .unwrap_or_default()
                .to_string();
            // A failed read (ffprobe/ffmpeg missing or broken) must not wipe what
            // an earlier scan stored; only a successful read replaces it.
            let metadata = reader.metadata(path);
            let cover = reader.cover(path, cover_cache_dir);
            read += 1;
            let keep_metadata = metadata.is_err();
            let keep_cover = cover.is_err();
            let read_everything = !keep_metadata && !keep_cover;
            let metadata = metadata.unwrap_or_default();
            self.upsert_scanned_media(
                &MediaRecord {
                    id: 0,
                    source_id,
                    path: path_text,
                    title: metadata.title.unwrap_or(fallback_title),
                    artist: metadata.artist.unwrap_or_default(),
                    duration_ms: metadata.duration_ms,
                    status: "AVAILABLE".to_string(),
                    cover_path: cover.unwrap_or(None),
                },
                keep_metadata,
                keep_cover,
                fingerprint.filter(|_| read_everything),
            )?;
        }
        // Whatever is left in `known` was not found on disk this time.
        let transaction = self.connection.unchecked_transaction()?;
        {
            let mut available =
                transaction.prepare("UPDATE media SET status = 'AVAILABLE' WHERE id = ?1")?;
            for id in &unchanged_ids {
                available.execute([id])?;
            }
            let mut missing =
                transaction.prepare("UPDATE media SET status = 'MISSING' WHERE id = ?1")?;
            for (id, _) in known.values() {
                missing.execute([id])?;
            }
        }
        transaction.commit()?;
        Ok(discovered.len())
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

/// Whether ffprobe and ffmpeg can be started. Without them a scan still runs,
/// because each file's metadata and cover errors are dropped, but every title
/// ends up as its file name without artist, duration or cover.
pub fn media_tools_available() -> bool {
    ["ffprobe", "ffmpeg"].iter().all(|tool| {
        Command::new(tool)
            .arg("-version")
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .status()
            .is_ok_and(|status| status.success())
    })
}

fn read_audio_metadata(path: &Path) -> Result<AudioMetadata> {
    let output = Command::new("ffprobe")
        .args([
            "-v",
            "error",
            "-show_entries",
            "format=duration:format_tags=title,artist",
            "-of",
            "json",
            &path.to_string_lossy(),
        ])
        .output()
        .with_context(|| format!("failed to start ffprobe for {}", path.display()))?;
    if !output.status.success() {
        anyhow::bail!("ffprobe failed for {}", path.display());
    }
    let parsed: ProbeOutput = serde_json::from_slice(&output.stdout)
        .with_context(|| format!("failed to parse ffprobe output for {}", path.display()))?;
    let tags = parsed.format.tags.unwrap_or_default();
    let tag = |name: &str| {
        tags.iter()
            .find(|(key, _)| key.eq_ignore_ascii_case(name))
            .map(|(_, value)| value.trim().to_string())
            .filter(|value| !value.is_empty())
    };
    let duration_ms = parsed
        .format
        .duration
        .and_then(|duration| duration.parse::<f64>().ok())
        .filter(|duration| duration.is_finite() && *duration >= 0.0)
        .map(|duration| (duration * 1_000.0).round() as i64)
        .unwrap_or_default();
    Ok(AudioMetadata {
        title: tag("title"),
        artist: tag("artist"),
        duration_ms,
    })
}

fn extract_cover_art(path: &Path, cache_dir: &Path) -> Result<Option<String>> {
    let output = Command::new("ffmpeg")
        .args([
            "-v",
            "error",
            "-i",
            &path.to_string_lossy(),
            "-an",
            "-c:v",
            "copy",
            "-f",
            "image2pipe",
            "-",
        ])
        .output()
        .with_context(|| format!("failed to start ffmpeg for {}", path.display()))?;
    if output.status.success() && !output.stdout.is_empty() {
        return store_cover_image(&output.stdout, cache_dir).map(Some);
    }

    let Some(folder_cover) = path.parent().and_then(find_folder_cover_image) else {
        return Ok(None);
    };
    let bytes = std::fs::read(&folder_cover)
        .with_context(|| format!("failed to read folder cover art {}", folder_cover.display()))?;
    if bytes.is_empty() {
        return Ok(None);
    }
    store_cover_image(&bytes, cache_dir).map(Some)
}

fn store_cover_image(bytes: &[u8], cache_dir: &Path) -> Result<String> {
    let extension = match bytes.get(0..4) {
        Some([0xFF, 0xD8, ..]) => "jpg",
        Some([0x89, 0x50, 0x4E, 0x47]) => "png",
        _ => "jpg",
    };
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    bytes.hash(&mut hasher);
    let file_name = format!("{:016x}.{extension}", hasher.finish());
    let file_path = cache_dir.join(&file_name);
    if !file_path.exists() {
        std::fs::write(&file_path, bytes)
            .with_context(|| format!("failed to write cover art {}", file_path.display()))?;
    }
    Ok(file_name)
}

const FOLDER_COVER_NAMES: [&str; 4] = ["cover.jpg", "cover.png", "folder.jpg", "folder.png"];

/// Looks for a folder-level cover image (as written by tools like Windows
/// Media Player) next to an audio file that has no embedded artwork.
pub fn find_folder_cover_image(dir: &Path) -> Option<PathBuf> {
    let entries = std::fs::read_dir(dir).ok()?;
    let mut album_art_large: Option<PathBuf> = None;
    let mut album_art_small: Option<PathBuf> = None;
    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_file() {
            continue;
        }
        let Some(file_name) = path.file_name().and_then(|name| name.to_str()) else {
            continue;
        };
        let lower = file_name.to_ascii_lowercase();
        if FOLDER_COVER_NAMES.contains(&lower.as_str()) {
            return Some(path);
        }
        if lower.starts_with("albumart") && (lower.ends_with(".jpg") || lower.ends_with(".png")) {
            if lower.contains("large") {
                album_art_large.get_or_insert(path);
            } else {
                album_art_small.get_or_insert(path);
            }
        }
    }
    album_art_large.or(album_art_small)
}

pub fn find_audio_files(folder: &Path, supported_formats: &[String]) -> Result<Vec<PathBuf>> {
    let mut files = Vec::new();
    if !folder.is_dir() {
        return Ok(files);
    }
    for entry in std::fs::read_dir(folder)
        .with_context(|| format!("failed to read media folder {}", folder.display()))?
    {
        let path = entry?.path();
        if path.is_dir() {
            files.extend(find_audio_files(&path, supported_formats)?);
        } else if path.is_file()
            && path
                .extension()
                .and_then(|extension| extension.to_str())
                .map(|extension| {
                    supported_formats
                        .iter()
                        .any(|format| format.eq_ignore_ascii_case(extension))
                })
                .unwrap_or(false)
        {
            files.push(path);
        }
    }
    files.sort();
    Ok(files)
}

#[cfg(test)]
mod tests {
    use super::{
        extract_cover_art, find_folder_cover_image, read_audio_metadata, AudioMetadata, Database,
        MediaReader, MediaRecord, ResumeState, CURRENT_SCHEMA_VERSION,
    };
    use std::cell::{Cell, RefCell};
    use std::path::{Path, PathBuf};
    use std::sync::atomic::{AtomicBool, Ordering};

    /// Counts reads; fails for paths in `fail`, panics at `panic_at`, and
    /// sets `cancel_after_first` once the first file was read.
    #[derive(Default)]
    struct CountingReader {
        reads: RefCell<Vec<String>>,
        fail: RefCell<Vec<String>>,
        panic_at: Cell<Option<usize>>,
        cancel_after_first: Option<std::sync::Arc<AtomicBool>>,
    }

    impl CountingReader {
        fn read_names(&self) -> Vec<String> {
            let mut names = self.reads.borrow().clone();
            names.sort();
            names
        }
    }

    impl MediaReader for CountingReader {
        fn metadata(&self, path: &Path) -> anyhow::Result<AudioMetadata> {
            let name = path.file_name().unwrap().to_string_lossy().into_owned();
            if self.panic_at.get() == Some(self.reads.borrow().len()) {
                panic!("scan aborted at {name}");
            }
            self.reads.borrow_mut().push(name.clone());
            if let Some(cancel) = &self.cancel_after_first {
                cancel.store(true, Ordering::Relaxed);
            }
            if self.fail.borrow().contains(&name) {
                anyhow::bail!("ffprobe failed for {name}");
            }
            Ok(AudioMetadata {
                title: Some(format!("Title {name}")),
                artist: Some("Artist".to_string()),
                duration_ms: 1_000,
            })
        }

        fn cover(&self, _path: &Path, _cache_dir: &Path) -> anyhow::Result<Option<String>> {
            Ok(None)
        }
    }

    /// A folder with the given files (content decides the size).
    fn scan_folder(name: &str, files: &[(&str, &[u8])]) -> PathBuf {
        let folder = std::env::temp_dir().join(format!("carnine-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&folder);
        std::fs::create_dir_all(&folder).expect("media folder should be created");
        for (file, content) in files {
            std::fs::write(folder.join(file), content).expect("file should be written");
        }
        folder
    }

    fn status_of(database: &Database, title_part: &str) -> String {
        database
            .search_media(title_part)
            .expect("search should work")[0]
            .status
            .clone()
    }

    fn rescan(database: &Database, folder: &Path, reader: &CountingReader) -> usize {
        database
            .rescan_folder_with(
                folder,
                &["mp3".to_string()],
                folder,
                reader,
                &AtomicBool::new(false),
            )
            .expect("rescan should succeed")
    }

    #[test]
    fn a_rescan_does_not_read_unchanged_files_again() {
        let folder = scan_folder("rescan-unchanged", &[("a.mp3", b"aa"), ("b.mp3", b"bb")]);
        let database = Database::open(":memory:").expect("database should open");
        let first = CountingReader::default();
        assert_eq!(rescan(&database, &folder, &first), 2);
        assert_eq!(first.read_names(), ["a.mp3", "b.mp3"]);

        let second = CountingReader::default();
        assert_eq!(rescan(&database, &folder, &second), 2);

        assert!(second.read_names().is_empty());
        assert_eq!(status_of(&database, "Title a.mp3"), "AVAILABLE");
        let _ = std::fs::remove_dir_all(folder);
    }

    #[test]
    fn a_changed_file_is_read_again() {
        let folder = scan_folder("rescan-changed", &[("a.mp3", b"aa"), ("b.mp3", b"bb")]);
        let database = Database::open(":memory:").expect("database should open");
        rescan(&database, &folder, &CountingReader::default());
        std::fs::write(folder.join("b.mp3"), b"longer now").expect("file should change");

        let second = CountingReader::default();
        rescan(&database, &folder, &second);

        assert_eq!(second.read_names(), ["b.mp3"]);
        let _ = std::fs::remove_dir_all(folder);
    }

    #[test]
    fn a_failed_read_is_tried_again_on_the_next_scan() {
        let folder = scan_folder("rescan-failed", &[("a.mp3", b"aa"), ("b.mp3", b"bb")]);
        let database = Database::open(":memory:").expect("database should open");
        let first = CountingReader::default();
        first.fail.borrow_mut().push("b.mp3".to_string());
        rescan(&database, &folder, &first);

        let second = CountingReader::default();
        rescan(&database, &folder, &second);

        assert_eq!(second.read_names(), ["b.mp3"]);
        assert_eq!(status_of(&database, "Title b.mp3"), "AVAILABLE");
        let _ = std::fs::remove_dir_all(folder);
    }

    #[test]
    fn a_scan_that_ends_early_leaves_no_file_missing() {
        let folder = scan_folder(
            "rescan-aborted",
            &[("a.mp3", b"aa"), ("b.mp3", b"bb"), ("c.mp3", b"cc")],
        );
        let database = Database::open(":memory:").expect("database should open");
        rescan(&database, &folder, &CountingReader::default());
        // Every file changes, so the next scan reads each one again ...
        for (file, content) in [("a.mp3", "aaa"), ("b.mp3", "bbb"), ("c.mp3", "ccc")] {
            std::fs::write(folder.join(file), content).expect("file should change");
        }
        // ... and stops after the first, the way a backend restart ends it.
        let aborted = CountingReader::default();
        aborted.panic_at.set(Some(1));
        let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            rescan(&database, &folder, &aborted)
        }));
        assert!(result.is_err());

        for name in ["a.mp3", "b.mp3", "c.mp3"] {
            assert_eq!(status_of(&database, &format!("Title {name}")), "AVAILABLE");
        }
        let _ = std::fs::remove_dir_all(folder);
    }

    #[test]
    fn a_cancelled_scan_stops_after_the_current_file_and_changes_no_status() {
        let folder = scan_folder(
            "rescan-cancelled",
            &[("a.mp3", b"aa"), ("b.mp3", b"bb"), ("c.mp3", b"cc")],
        );
        let database = Database::open(":memory:").expect("database should open");
        rescan(&database, &folder, &CountingReader::default());
        for (file, content) in [("a.mp3", "aaa"), ("b.mp3", "bbb"), ("c.mp3", "ccc")] {
            std::fs::write(folder.join(file), content).expect("file should change");
        }
        std::fs::remove_file(folder.join("c.mp3")).expect("file should be removed");
        let cancel = std::sync::Arc::new(AtomicBool::new(false));
        let reader = CountingReader {
            cancel_after_first: Some(cancel.clone()),
            ..Default::default()
        };

        let result =
            database.rescan_folder_with(&folder, &["mp3".to_string()], &folder, &reader, &cancel);

        assert!(result.is_err());
        assert_eq!(reader.read_names().len(), 1);
        // c.mp3 is gone, but a cancelled scan must not decide that.
        assert_eq!(status_of(&database, "Title c.mp3"), "AVAILABLE");
        let _ = std::fs::remove_dir_all(folder);
    }

    #[test]
    fn a_file_that_comes_back_unchanged_is_available_again() {
        let folder = scan_folder("rescan-back", &[("a.mp3", b"aa"), ("b.mp3", b"bb")]);
        let database = Database::open(":memory:").expect("database should open");
        rescan(&database, &folder, &CountingReader::default());
        let parked = folder.with_extension("parked");
        std::fs::rename(folder.join("b.mp3"), &parked).expect("file should move away");
        rescan(&database, &folder, &CountingReader::default());
        assert_eq!(status_of(&database, "Title b.mp3"), "MISSING");

        std::fs::rename(&parked, folder.join("b.mp3")).expect("file should come back");
        let third = CountingReader::default();
        rescan(&database, &folder, &third);

        assert!(third.read_names().is_empty());
        assert_eq!(status_of(&database, "Title b.mp3"), "AVAILABLE");
        let _ = std::fs::remove_dir_all(folder);
    }

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
    fn keeps_the_track_recording_switch() {
        let database = Database::open(":memory:").expect("database should open");
        assert!(
            !database.load_track_recording().unwrap(),
            "off when never set"
        );
        database.save_track_recording(true).unwrap();
        assert!(database.load_track_recording().unwrap());
        database.save_track_recording(false).unwrap();
        assert!(!database.load_track_recording().unwrap());
    }

    #[test]
    fn failed_metadata_read_keeps_what_an_earlier_scan_stored() {
        let database = Database::open(":memory:").expect("database should open");
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should be stored");
        let tagged = MediaRecord {
            id: 0,
            source_id,
            path: "/music/11 Crazy.mp3".to_string(),
            title: "Crazy".to_string(),
            artist: "Aerosmith".to_string(),
            duration_ms: 316_000,
            status: "MISSING".to_string(),
            cover_path: Some("/covers/crazy.jpg".to_string()),
        };
        database
            .upsert_media(&tagged)
            .expect("media should be stored");
        let fallback = MediaRecord {
            id: 0,
            source_id,
            path: tagged.path.clone(),
            title: "11 Crazy".to_string(),
            artist: String::new(),
            duration_ms: 0,
            status: "AVAILABLE".to_string(),
            cover_path: None,
        };

        database
            .upsert_scanned_media(&fallback, true, true, None)
            .expect("rescan without tools should work");
        let kept = &database.search_media("crazy").expect("search should work")[0];
        assert_eq!(kept.title, "Crazy");
        assert_eq!(kept.artist, "Aerosmith");
        assert_eq!(kept.duration_ms, 316_000);
        assert_eq!(kept.cover_path.as_deref(), Some("/covers/crazy.jpg"));
        assert_eq!(kept.status, "AVAILABLE");

        database
            .upsert_scanned_media(&fallback, false, false, None)
            .expect("rescan with tools should work");
        let replaced = &database.search_media("crazy").expect("search should work")[0];
        assert_eq!(replaced.title, "11 Crazy");
        assert_eq!(replaced.cover_path, None);
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
            cover_path: None,
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

        assert_eq!(
            database
                .duration_by_path("/music/song.mp3")
                .expect("duration lookup should work"),
            Some(175_000)
        );
        assert_eq!(
            database
                .duration_by_path("/music/unknown.mp3")
                .expect("duration lookup should work"),
            None
        );
    }

    #[test]
    fn rescans_audio_files_and_marks_removed_files_missing() {
        let folder =
            std::env::temp_dir().join(format!("carnine-rescan-test-{}", std::process::id()));
        let nested = folder.join("nested");
        let _ = std::fs::remove_dir_all(&folder);
        std::fs::create_dir_all(&nested).expect("media folder should be created");
        let first_file = folder.join("first.mp3");
        let second_file = nested.join("second.ogg");
        std::fs::write(&first_file, b"test").expect("first file should be created");
        std::fs::write(&second_file, b"test").expect("second file should be created");

        let cover_cache_dir =
            std::env::temp_dir().join(format!("carnine-covers-test-{}", std::process::id()));
        std::fs::create_dir_all(&cover_cache_dir).expect("cover cache dir should be created");

        let database = Database::open(":memory:").expect("database should open");
        let formats = ["mp3".to_string(), "ogg".to_string()];
        assert_eq!(
            database
                .rescan_folder(&folder, &formats, &cover_cache_dir, &AtomicBool::new(false))
                .expect("rescan should succeed"),
            2
        );
        std::fs::remove_file(&first_file).expect("first file should be removed");
        assert_eq!(
            database
                .rescan_folder(&folder, &formats, &cover_cache_dir, &AtomicBool::new(false))
                .expect("second rescan should succeed"),
            1
        );
        let results = database
            .search_media("first")
            .expect("missing media should remain searchable");
        assert_eq!(results[0].status, "MISSING");
        let _ = std::fs::remove_dir_all(folder);
        let _ = std::fs::remove_dir_all(cover_cache_dir);
    }

    #[test]
    fn stores_ordered_playlist_entries_and_allows_duplicates() {
        let database = Database::open(":memory:").expect("database should open");
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should be stored");
        let media_id = database
            .upsert_media(&MediaRecord {
                id: 0,
                source_id,
                path: "/music/song.mp3".to_string(),
                title: "Song".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 1000,
                status: "AVAILABLE".to_string(),
                cover_path: None,
            })
            .expect("media should be stored");
        let playlist_id = database
            .create_playlist("Favorites")
            .expect("playlist should be created");

        let first_entry = database
            .add_playlist_entry(playlist_id, media_id)
            .expect("first entry should be added");
        let second_entry = database
            .add_playlist_entry(playlist_id, media_id)
            .expect("duplicate entry should be added");
        let entries = database
            .playlist_entries(playlist_id)
            .expect("entries should be loaded");

        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].id, first_entry);
        assert_eq!(entries[1].id, second_entry);
        assert_eq!(entries[0].media_id, entries[1].media_id);
        assert_eq!(entries[0].position, 0);
        assert_eq!(entries[1].position, 1);
    }

    #[test]
    fn saves_and_loads_the_last_page() {
        let database = Database::open(":memory:").expect("database should open");
        assert_eq!(database.load_last_page().expect("should load"), "");
        database.save_last_page("maps").expect("should save");
        database.save_last_page("media").expect("should overwrite");
        assert_eq!(database.load_last_page().expect("should load"), "media");
    }

    #[test]
    fn saves_and_loads_resume_state() {
        let database = Database::open(":memory:").expect("database should open");
        assert!(database
            .load_resume_state()
            .expect("resume state should load")
            .is_none());
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should be stored");
        let media_id = database
            .upsert_media(&MediaRecord {
                id: 0,
                source_id,
                path: "/music/song.mp3".to_string(),
                title: "Song".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 1000,
                status: "AVAILABLE".to_string(),
                cover_path: None,
            })
            .expect("media should be stored");
        let playlist_id = database
            .create_playlist("Resume")
            .expect("playlist should be created");
        let playlist_entry_id = database
            .add_playlist_entry(playlist_id, media_id)
            .expect("playlist entry should be added");
        let state = ResumeState {
            playlist_id: Some(playlist_id),
            playlist_entry_id: Some(playlist_entry_id),
            position_ms: 12_345,
            resume_mode: "restore_paused".to_string(),
            repeat_mode: "REPEAT_QUEUE".to_string(),
            shuffle_enabled: true,
        };
        database
            .save_resume_state(&state)
            .expect("resume state should save");
        assert_eq!(
            database
                .load_resume_state()
                .expect("resume state should load"),
            Some(state)
        );
    }

    #[test]
    fn reads_repository_audio_metadata() {
        let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../resources/musik/1-Here We Go Now (Single Edit).mp3");
        let metadata = read_audio_metadata(&path).expect("repository MP3 metadata should read");

        assert_eq!(
            metadata.title.as_deref(),
            Some("Here We Go Now (Single Edit)")
        );
        assert_eq!(metadata.artist.as_deref(), Some("Kensington Road"));
        assert!(metadata.duration_ms > 170_000);
    }

    #[test]
    fn extracting_cover_art_from_a_file_without_embedded_artwork_returns_none() {
        let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../resources/musik/1-Here We Go Now (Single Edit).mp3");
        let cache_dir =
            std::env::temp_dir().join(format!("carnine-cover-extract-test-{}", std::process::id()));
        std::fs::create_dir_all(&cache_dir).expect("cover cache dir should be created");

        let cover_path = extract_cover_art(&path, &cache_dir).expect("extraction should not error");

        assert_eq!(cover_path, None);
        let _ = std::fs::remove_dir_all(cache_dir);
    }

    #[test]
    fn extracting_cover_art_falls_back_to_a_folder_image_without_embedded_artwork() {
        let source = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../resources/musik/1-Here We Go Now (Single Edit).mp3");
        let album_dir = std::env::temp_dir().join(format!(
            "carnine-folder-cover-album-test-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&album_dir).expect("album dir should be created");
        let track_path = album_dir.join("track.mp3");
        std::fs::copy(&source, &track_path).expect("track should be copied into album dir");
        std::fs::write(
            album_dir.join("Folder.jpg"),
            [0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3],
        )
        .expect("folder cover should be written");
        assert_eq!(
            find_folder_cover_image(&album_dir),
            Some(album_dir.join("Folder.jpg"))
        );

        let cache_dir = std::env::temp_dir().join(format!(
            "carnine-cover-extract-folder-test-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&cache_dir).expect("cover cache dir should be created");

        let cover_path =
            extract_cover_art(&track_path, &cache_dir).expect("extraction should not error");

        let cover_path = cover_path.expect("folder cover should be used as fallback");
        assert!(cover_path.ends_with(".jpg"));
        assert!(cache_dir.join(&cover_path).exists());

        let _ = std::fs::remove_dir_all(album_dir);
        let _ = std::fs::remove_dir_all(cache_dir);
    }

    #[test]
    fn lists_playlists_in_stable_order() {
        let database = Database::open(":memory:").expect("database should open");
        database
            .create_playlist("zeta")
            .expect("first playlist should be created");
        database
            .create_playlist("Alpha")
            .expect("second playlist should be created");

        let playlists = database.playlists().expect("playlists should load");
        assert_eq!(
            playlists
                .iter()
                .map(|item| item.name.as_str())
                .collect::<Vec<_>>(),
            ["Alpha", "zeta"]
        );
    }

    #[test]
    fn playlist_name_resolves_saved_name_and_errors_for_unknown_id() {
        let database = Database::open(":memory:").expect("database should open");
        let playlist_id = database
            .create_playlist("Road Trip")
            .expect("playlist should be created");

        assert_eq!(
            database
                .playlist_name(playlist_id)
                .expect("playlist name should resolve"),
            "Road Trip"
        );
        assert!(database.playlist_name(playlist_id + 1).is_err());
    }

    #[test]
    fn create_playlist_rejects_duplicate_names() {
        let database = Database::open(":memory:").expect("database should open");
        database
            .create_playlist("Favorites")
            .expect("first playlist should be created");

        assert!(database.create_playlist("Favorites").is_err());
    }

    #[test]
    fn add_playlist_entry_rejects_unknown_playlist_or_media() {
        let database = Database::open(":memory:").expect("database should open");
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should be stored");
        let media_id = database
            .upsert_media(&MediaRecord {
                id: 0,
                source_id,
                path: "/music/song.mp3".to_string(),
                title: "Song".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 1000,
                status: "AVAILABLE".to_string(),
                cover_path: None,
            })
            .expect("media should be stored");
        let playlist_id = database
            .create_playlist("Favorites")
            .expect("playlist should be created");

        assert!(database
            .add_playlist_entry(playlist_id + 1, media_id)
            .is_err());
        assert!(database
            .add_playlist_entry(playlist_id, media_id + 1)
            .is_err());
    }

    #[test]
    fn playlist_media_paths_returns_entries_in_position_order() {
        let database = Database::open(":memory:").expect("database should open");
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should be stored");
        let first_media_id = database
            .upsert_media(&MediaRecord {
                id: 0,
                source_id,
                path: "/music/first.mp3".to_string(),
                title: "First".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 1000,
                status: "AVAILABLE".to_string(),
                cover_path: None,
            })
            .expect("first media should be stored");
        let second_media_id = database
            .upsert_media(&MediaRecord {
                id: 0,
                source_id,
                path: "/music/second.mp3".to_string(),
                title: "Second".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 1000,
                status: "AVAILABLE".to_string(),
                cover_path: None,
            })
            .expect("second media should be stored");
        let playlist_id = database
            .create_playlist("Favorites")
            .expect("playlist should be created");
        database
            .add_playlist_entry(playlist_id, first_media_id)
            .expect("first entry should be added");
        database
            .add_playlist_entry(playlist_id, second_media_id)
            .expect("second entry should be added");

        let paths = database
            .playlist_media_paths(playlist_id)
            .expect("media paths should load")
            .into_iter()
            .map(|(_, path)| path)
            .collect::<Vec<_>>();

        assert_eq!(paths, ["/music/first.mp3", "/music/second.mp3"]);
    }

    #[test]
    fn playlist_cover_path_returns_first_covered_entry_and_none_without_cover() {
        let database = Database::open(":memory:").expect("database should open");
        let source_id = database
            .upsert_source("/music", "AVAILABLE")
            .expect("source should be stored");
        let uncovered_media_id = database
            .upsert_media(&MediaRecord {
                id: 0,
                source_id,
                path: "/music/uncovered.mp3".to_string(),
                title: "Uncovered".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 1000,
                status: "AVAILABLE".to_string(),
                cover_path: None,
            })
            .expect("uncovered media should be stored");
        let playlist_id = database
            .create_playlist("Favorites")
            .expect("playlist should be created");
        database
            .add_playlist_entry(playlist_id, uncovered_media_id)
            .expect("first entry should be added");

        assert_eq!(
            database
                .playlist_cover_path(playlist_id)
                .expect("cover lookup should not error"),
            None
        );

        let covered_media_id = database
            .upsert_media(&MediaRecord {
                id: 0,
                source_id,
                path: "/music/covered.mp3".to_string(),
                title: "Covered".to_string(),
                artist: "Artist".to_string(),
                duration_ms: 1000,
                status: "AVAILABLE".to_string(),
                cover_path: Some("abc123.jpg".to_string()),
            })
            .expect("covered media should be stored");
        database
            .add_playlist_entry(playlist_id, covered_media_id)
            .expect("second entry should be added");

        assert_eq!(
            database
                .playlist_cover_path(playlist_id)
                .expect("cover lookup should not error"),
            Some("abc123.jpg".to_string())
        );
    }
}
