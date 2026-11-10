//! Index of the words in the names database, for a place search that
//! tolerates typos (#172). FTS5 finds a word only when it is spelled right;
//! this `fst` map holds every word of the `name` column with the number of
//! names it occurs in, and finds the words close to a misspelled one.
//!
//! The backend builds the index itself, in the background and some time after
//! the start, and keeps it next to the database (`germany_names.db` →
//! `germany_names.words.fst`). An index older than the database is built
//! again. Until it is there, the search runs as without it. Measured on
//! 2026-10-25 with DACH (1.13 million words): 7.8 MB, built in 19 s on a Pi 4,
//! loaded in 11-28 ms.

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};
use std::thread;
use std::time::{Duration, Instant};

use anyhow::{Context, Result};
use fst::automaton::{Levenshtein, Str};
use fst::{Automaton, IntoStreamer, Map, MapBuilder, Streamer};
use rusqlite::{Connection, OpenFlags};
use tracing::{info, warn};

/// The index is built this long after the start, so it does not compete with
/// the map, the first route and the voice while the car starts.
pub const BUILD_DELAY: Duration = Duration::from_secs(60);
/// Close spellings kept per typed word, the most common first.
const VARIANTS_PER_WORD: usize = 12;

/// The index once it is loaded; `None` until then or without one.
pub type SharedWordIndex = Arc<RwLock<Option<Arc<WordIndex>>>>;

pub struct WordIndex {
    map: Map<Vec<u8>>,
}

impl std::fmt::Debug for WordIndex {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("WordIndex")
            .field("words", &self.len())
            .finish()
    }
}

impl WordIndex {
    /// Where the index of `database` lives: next to it, `.words.fst` instead
    /// of `.db`.
    pub fn path_for(database: &Path) -> PathBuf {
        database.with_extension("words.fst")
    }

    /// Reads every word of the `name` column from the FTS5 index, so they are
    /// folded exactly as the search folds them (lower case, accents off).
    pub fn build(database: &Path) -> Result<Self> {
        let connection = Connection::open_with_flags(
            database,
            OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX,
        )
        .with_context(|| format!("opening names database {}", database.display()))?;
        // fts5vocab lives in the temp schema, so the database stays read-only.
        connection
            .execute_batch("CREATE VIRTUAL TABLE temp.vocab USING fts5vocab(main, names, col);")
            .context("reading the words of the names index")?;
        let mut statement = connection
            .prepare("SELECT term, doc FROM temp.vocab WHERE col = 'name' ORDER BY term")?;
        let mut rows = statement.query([])?;
        let mut builder = MapBuilder::memory();
        while let Some(row) = rows.next()? {
            let term: String = row.get(0)?;
            let names: i64 = row.get(1)?;
            // fst needs byte order, which fts5vocab keeps; a term out of order
            // would only be skipped.
            let _ = builder.insert(&term, u64::try_from(names).unwrap_or(0));
        }
        let map = Map::new(builder.into_inner()?).context("building the word index")?;
        Ok(Self { map })
    }

    pub fn load(path: &Path) -> Result<Self> {
        let bytes = fs::read(path).with_context(|| format!("reading {}", path.display()))?;
        let map =
            Map::new(bytes).with_context(|| format!("{} is no word index", path.display()))?;
        Ok(Self { map })
    }

    /// Writes the index next to its database; a reader never sees half a file.
    pub fn save(&self, path: &Path) -> Result<()> {
        let partial = path.with_extension(format!("fst.partial-{}", std::process::id()));
        fs::write(&partial, self.map.as_fst().as_bytes())
            .with_context(|| format!("writing {}", partial.display()))?;
        fs::rename(&partial, path).with_context(|| format!("renaming to {}", path.display()))
    }

    pub fn len(&self) -> usize {
        self.map.len()
    }

    /// Whether a word of the index starts with `word` (folded). Then FTS finds
    /// it as typed, and there is nothing to correct.
    pub fn has_prefix(&self, word: &str) -> bool {
        let automaton = Str::new(word).starts_with();
        self.map.search(automaton).into_stream().next().is_some()
    }

    /// Words of the index that start within reach of `word` (folded):
    /// "lauterbch" finds "lauterbach" and "lauterbacher". Edit distance 1 from
    /// 4 characters, 2 from 8 (two swapped letters already cost 2). The most
    /// common first, where a distance of 1 counts ten times.
    pub fn similar(&self, word: &str) -> Vec<String> {
        let length = word.chars().count();
        let mut scored: HashMap<String, u64> = HashMap::new();
        for (distance, min_chars, weight) in [(1u32, 4usize, 10u64), (2, 8, 1)] {
            if length < min_chars {
                break;
            }
            // A long word at distance 2 can exceed the automaton's size
            // limit; then distance 1 has to do.
            let Ok(automaton) = Levenshtein::new(word, distance) else {
                break;
            };
            let mut stream = self.map.search(automaton.starts_with()).into_stream();
            while let Some((key, names)) = stream.next() {
                let score = names.saturating_mul(weight);
                let entry = scored
                    .entry(String::from_utf8_lossy(key).into_owned())
                    .or_default();
                *entry = (*entry).max(score);
            }
        }
        let mut found: Vec<_> = scored.into_iter().collect();
        found.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));
        found
            .into_iter()
            .take(VARIANTS_PER_WORD)
            .map(|(word, _)| word)
            .collect()
    }
}

/// Lower case and accents off, as FTS5's unicode61 tokenizer does for the
/// letters of German and its neighbours; ß stays ß there too.
pub fn fold(text: &str) -> String {
    text.to_lowercase()
        .chars()
        .map(|c| match c {
            'ä' | 'à' | 'á' | 'â' | 'ã' | 'å' => 'a',
            'ö' | 'ò' | 'ó' | 'ô' | 'õ' => 'o',
            'ü' | 'ù' | 'ú' | 'û' => 'u',
            'é' | 'è' | 'ê' | 'ë' => 'e',
            'í' | 'ì' | 'î' | 'ï' => 'i',
            'ç' => 'c',
            'ñ' => 'n',
            other => other,
        })
        .collect()
}

/// Whether the index at `index` was written after `database` changed or was
/// put in place. A new map package keeps the modification time of the
/// machine that built it (tar, `cp -p`), which may be older than the index of
/// the previous one; the change time (ctime) cannot be carried over.
fn is_fresh(database: &Path, index: &Path) -> bool {
    use std::os::unix::fs::MetadataExt;
    let (Ok(database), Ok(index)) = (fs::metadata(database), fs::metadata(index)) else {
        return false;
    };
    let nanos = |seconds: i64, nanos: i64| i128::from(seconds) * 1_000_000_000 + i128::from(nanos);
    let changed = nanos(database.mtime(), database.mtime_nsec())
        .max(nanos(database.ctime(), database.ctime_nsec()));
    nanos(index.mtime(), index.mtime_nsec()) >= changed
}

/// Loads the index of `database` at once when it is up to date; otherwise
/// builds it after `delay` on a thread of low priority and saves it. The
/// search uses it as soon as it is there.
pub fn spawn(database: PathBuf, delay: Duration) -> SharedWordIndex {
    let shared: SharedWordIndex = Arc::default();
    let slot = Arc::clone(&shared);
    let started = thread::Builder::new()
        .name("carnine-words".to_string())
        .spawn(move || {
            if let Some(index) = load_or_build(&database, delay) {
                *slot
                    .write()
                    .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(Arc::new(index));
            }
        });
    if let Err(err) = started {
        warn!(error = %err, "word index not started, place search without typos");
    }
    shared
}

fn load_or_build(database: &Path, delay: Duration) -> Option<WordIndex> {
    let path = WordIndex::path_for(database);
    if is_fresh(database, &path) {
        match WordIndex::load(&path) {
            Ok(index) => {
                info!(path = %path.display(), words = index.len(), "word index loaded");
                return Some(index);
            }
            Err(err) => {
                warn!(error = %format!("{err:#}"), "word index not readable, building it again")
            }
        }
    }
    if !database.exists() {
        return None;
    }
    thread::sleep(delay);
    lower_priority();
    let started = Instant::now();
    let index = match WordIndex::build(database) {
        Ok(index) => index,
        Err(err) => {
            warn!(error = %format!("{err:#}"), "word index not built, place search without typos");
            return None;
        }
    };
    // Without a writable folder it is built again at the next start, but it
    // works all the same.
    if let Err(err) = index.save(&path) {
        warn!(error = %format!("{err:#}"), "word index not saved");
    }
    info!(
        path = %path.display(),
        words = index.len(),
        build_ms = started.elapsed().as_millis() as u64,
        "word index built"
    );
    Some(index)
}

/// The build reads the whole names index; it must not slow down the map or
/// the voice.
fn lower_priority() {
    // SAFETY: gettid has no preconditions; setpriority with the thread id
    // changes only this thread on Linux.
    let result = unsafe {
        let thread = libc::gettid() as libc::id_t;
        libc::setpriority(libc::PRIO_PROCESS, thread, 19)
    };
    if result != 0 {
        warn!(error = %std::io::Error::last_os_error(), "word index thread keeps its priority");
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::navigation::places::tests::{names_db, TempDb};

    fn index_of(names: &[&str]) -> (TempDb, WordIndex) {
        let rows: Vec<_> = names
            .iter()
            .map(|name| (*name, 50.0, 9.0, "place", "village", None))
            .collect();
        let db = names_db(&rows);
        let index = WordIndex::build(&db.path).expect("build");
        (db, index)
    }

    #[test]
    fn holds_the_folded_words_of_the_names() {
        let (_db, index) = index_of(&["Lauterbach", "Mücke", "Frankfurt am Main"]);
        // frankfurt, am, main, lauterbach, mucke
        assert_eq!(index.len(), 5);
        assert!(index.has_prefix("mucke"));
        assert!(index.has_prefix("lauter"));
        assert!(!index.has_prefix("lauterbch"));
    }

    #[test]
    fn finds_misspelled_words_the_common_ones_first() {
        let (_db, index) = index_of(&[
            "Lauterbach",
            "Lauterbach",
            "Lauterbacher Straße",
            "Frankfurt am Main",
            "Frankfurter Straße",
            "Frankfurt",
        ]);
        assert_eq!(index.similar("lauterbch"), ["lauterbach", "lauterbacher"]);
        // A swap of two letters costs 2: only from 8 characters.
        assert_eq!(index.similar("frankfrut")[0], "frankfurt");
        assert!(index.similar("fnak").is_empty(), "too far away");
        assert!(index.similar("lau").is_empty(), "too short for a guess");
    }

    #[test]
    fn saves_and_loads_the_same_index() {
        let (db, index) = index_of(&["Alsfeld", "Fulda"]);
        let path = WordIndex::path_for(&db.path);
        assert_eq!(path.extension().unwrap(), "fst");
        index.save(&path).expect("save");
        let loaded = WordIndex::load(&path).expect("load");
        let _ = fs::remove_file(&path);
        assert_eq!(loaded.len(), 2);
        assert!(loaded.has_prefix("fuld"));
    }

    #[test]
    fn an_index_older_than_its_database_is_stale() {
        let (db, index) = index_of(&["Alsfeld"]);
        let path = WordIndex::path_for(&db.path);
        index.save(&path).expect("save");
        assert!(is_fresh(&db.path, &path));
        let later = fs::metadata(&path).unwrap().modified().unwrap() + Duration::from_secs(5);
        fs::File::options()
            .write(true)
            .open(&db.path)
            .unwrap()
            .set_modified(later)
            .unwrap();
        assert!(!is_fresh(&db.path, &path));
        let _ = fs::remove_file(&path);
        assert!(!is_fresh(&db.path, &path), "no index at all");
    }

    #[test]
    fn a_database_put_in_place_with_an_old_date_is_newer_than_its_index() {
        // As a map package does: the new database keeps the date of the
        // machine that built it, older than the index of the previous one.
        let (db, index) = index_of(&["Alsfeld"]);
        let path = WordIndex::path_for(&db.path);
        index.save(&path).expect("save");
        thread::sleep(Duration::from_millis(20));
        let old = fs::metadata(&path).unwrap().modified().unwrap() - Duration::from_secs(86_400);
        fs::File::options()
            .write(true)
            .open(&db.path)
            .unwrap()
            .set_modified(old)
            .unwrap();
        assert!(
            !is_fresh(&db.path, &path),
            "replaced after the index was written"
        );
        let _ = fs::remove_file(&path);
    }

    #[test]
    fn a_fresh_index_is_loaded_without_waiting() {
        let (db, index) = index_of(&["Alsfeld"]);
        let path = WordIndex::path_for(&db.path);
        index.save(&path).expect("save");
        // An hour of delay would hang the test if it were not skipped.
        let loaded = load_or_build(&db.path, Duration::from_secs(3600)).expect("loaded");
        let _ = fs::remove_file(&path);
        assert_eq!(loaded.len(), 1);
    }

    #[test]
    fn a_missing_index_is_built_and_saved() {
        let (db, _) = index_of(&["Alsfeld", "Fulda"]);
        let path = WordIndex::path_for(&db.path);
        let _ = fs::remove_file(&path);
        let built = load_or_build(&db.path, Duration::ZERO).expect("built");
        assert_eq!(built.len(), 2);
        assert!(path.exists(), "saved for the next start");
        let _ = fs::remove_file(&path);
    }

    #[test]
    fn spawn_hands_the_index_to_the_search() {
        let (db, _) = index_of(&["Alsfeld"]);
        let path = WordIndex::path_for(&db.path);
        let shared = spawn(db.path.clone(), Duration::ZERO);
        let deadline = Instant::now() + Duration::from_secs(10);
        while shared.read().unwrap().is_none() && Instant::now() < deadline {
            thread::sleep(Duration::from_millis(10));
        }
        let _ = fs::remove_file(&path);
        assert!(shared.read().unwrap().is_some());
    }

    #[test]
    fn folds_like_the_fts_tokenizer() {
        assert_eq!(fold("Mücke"), "mucke");
        assert_eq!(fold("Gießen"), "gießen");
        assert_eq!(fold("Zürich Café"), "zurich cafe");
    }
}
