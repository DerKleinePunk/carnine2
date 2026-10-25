//! Probe, not product code: tolerating typos in the place search with an
//! `fst` index of the words in a names database.
//!
//!   cargo run --release --example fst_probe -- build <names.db> <words.fst>
//!   cargo run --release --example fst_probe -- search <names.db> <words.fst> <word>...
//!
//! `build` reads every word of the `name` column from the FTS5 index (so they
//! are folded exactly like the search folds them: lower case, accents off)
//! and writes them with their document count as an fst map. `search` looks
//! up each test word as today (every word a prefix term, plus its spelling
//! without written-out umlauts); only when that finds nothing it allows
//! typos: words starting within edit distance 1 (from 4 characters) or 2
//! (from 8), the common ones first. It prints times and the first hits.

use std::env;
use std::fs;
use std::path::Path;
use std::time::Instant;

use anyhow::{bail, Context, Result};
use fst::automaton::Levenshtein;
use fst::{Automaton, IntoStreamer, Map, MapBuilder, Streamer};
use rusqlite::{Connection, OpenFlags};

const TYPE_PRIORITY: [&str; 5] = [
    "place",
    "poi",
    "mountain_peak",
    "water_name",
    "transportation_name",
];
/// Hits per search, and candidates fetched per hit, as in places.rs.
const LIMIT: usize = 15;
const CANDIDATE_FACTOR: usize = 10;
/// Spellings kept per typed word, the most frequent first.
const VARIANTS_PER_WORD: usize = 12;

fn main() -> Result<()> {
    let args: Vec<String> = env::args().skip(1).collect();
    match args.first().map(String::as_str) {
        Some("build") if args.len() == 3 => build(Path::new(&args[1]), Path::new(&args[2])),
        Some("search") if args.len() >= 4 => {
            search(Path::new(&args[1]), Path::new(&args[2]), &args[3..])
        }
        _ => bail!("usage: fst_probe build <names.db> <words.fst> | search <names.db> <words.fst> <word>..."),
    }
}

fn open(database: &Path) -> Result<Connection> {
    Connection::open_with_flags(
        database,
        OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX,
    )
    .with_context(|| format!("opening {}", database.display()))
}

fn build(database: &Path, output: &Path) -> Result<()> {
    let started = Instant::now();
    let connection = open(database)?;
    // fts5vocab lives in the temp schema, so the database stays read-only.
    connection.execute_batch("CREATE VIRTUAL TABLE temp.vocab USING fts5vocab(main, names, col);")?;
    let mut statement = connection
        .prepare("SELECT term, doc FROM temp.vocab WHERE col = 'name' ORDER BY term")?;
    let mut rows = statement.query([])?;
    let mut builder = MapBuilder::new(fs::File::create(output)?)?;
    let mut words = 0u64;
    while let Some(row) = rows.next()? {
        let term: String = row.get(0)?;
        let documents: i64 = row.get(1)?;
        // fts5vocab sorts by the database's collation; fst needs byte order,
        // which is the same for these terms. Anything out of order is skipped.
        if builder.insert(&term, u64::try_from(documents).unwrap_or(0)).is_ok() {
            words += 1;
        }
    }
    builder.finish()?;
    let read = started.elapsed();
    println!(
        "build: {words} words, {:.1} s, fst {} bytes, peak RSS {} kB",
        read.as_secs_f64(),
        fs::metadata(output)?.len(),
        peak_rss_kb()
    );
    Ok(())
}

fn search(database: &Path, index: &Path, words: &[String]) -> Result<()> {
    let started = Instant::now();
    let map = Map::new(fs::read(index)?)?;
    let connection = open(database)?;
    println!(
        "load: fst {} bytes in {:.0} ms, peak RSS {} kB",
        map.as_fst().size(),
        started.elapsed().as_secs_f64() * 1000.0,
        peak_rss_kb()
    );
    for query in words {
        let folded = fold(query);
        // As today: every word a prefix term, plus the spelling without
        // umlauts ("muecke" also as "mucke", "giessen" also as "gießen").
        let spellings = spellings(&folded);
        let started = Instant::now();
        let today = run(&connection, &[spellings.clone()], true)?;
        let today_ms = started.elapsed().as_secs_f64() * 1000.0;

        if !today.is_empty() {
            println!(
                "{query}: today {today_ms:.1} ms {} hits [{}] | {} | no typo search needed",
                today.len(),
                first(&ranked(today, &spellings)),
                spellings.join(" ")
            );
            continue;
        }
        // Typos only when nothing is found: words within distance 1 (from 4
        // characters) or 2 (from 8; a swap of two letters already costs 2),
        // the common ones first, a close one counting ten times.
        let started = Instant::now();
        let variants = variants(&map, &folded)?;
        let expand_ms = started.elapsed().as_secs_f64() * 1000.0;
        let found = if variants.is_empty() {
            Vec::new()
        } else {
            ranked(run(&connection, &[variants.clone()], false)?, &variants)
        };
        let typo_ms = started.elapsed().as_secs_f64() * 1000.0;
        println!(
            "{query}: today {today_ms:.1} ms 0 hits | typo {typo_ms:.1} ms (of it fst {expand_ms:.1} ms) {} hits [{}] | {}",
            found.len(),
            first(&found),
            variants.join(" ")
        );
    }
    println!("peak RSS {} kB", peak_rss_kb());
    Ok(())
}

/// The word and its spelling without umlauts written out (ae/oe/ue, ss for ß),
/// as the index holds them: accents off, ß kept.
fn spellings(word: &str) -> Vec<String> {
    let mut spellings = vec![word.to_string()];
    let plain = word
        .replace("ae", "a")
        .replace("oe", "o")
        .replace("ue", "u");
    for candidate in [plain.clone(), plain.replace("ss", "ß"), word.replace("ss", "ß")] {
        if !spellings.contains(&candidate) {
            spellings.push(candidate);
        }
    }
    spellings
}

/// Words of the index that start within reach of `word` ("lauterbch" finds
/// "lauterbach" and "lauterbacher"): distance 1 from 4 characters, 2 from 8.
/// Ordered by how common they are, a distance of 1 counting ten times.
fn variants(map: &Map<Vec<u8>>, word: &str) -> Result<Vec<String>> {
    let length = word.chars().count();
    let mut scored: std::collections::HashMap<String, u64> = std::collections::HashMap::new();
    for (distance, min_chars, weight) in [(1u32, 4usize, 10u64), (2, 8, 1)] {
        if length < min_chars {
            break;
        }
        let automaton = Levenshtein::new(word, distance)?.starts_with();
        let mut stream = map.search(automaton).into_stream();
        while let Some((key, documents)) = stream.next() {
            let score = documents.saturating_mul(weight);
            let entry = scored.entry(String::from_utf8_lossy(key).into_owned()).or_default();
            *entry = (*entry).max(score);
        }
    }
    let mut found: Vec<_> = scored.into_iter().collect();
    found.sort_by(|a, b| b.1.cmp(&a.1).then(a.0.cmp(&b.0)));
    Ok(found
        .into_iter()
        .take(VARIANTS_PER_WORD)
        .map(|(key, _)| key)
        .collect())
}

/// Exact names first, then names holding one of `words` as a whole word, the
/// earlier (more common) word first; otherwise the order of the types stays.
fn ranked(hits: Vec<(String, String)>, words: &[String]) -> Vec<(String, String)> {
    let bare: Vec<&str> = words.iter().map(|word| word.trim_end_matches('*')).collect();
    let mut keyed: Vec<_> = hits
        .into_iter()
        .map(|(name, kind)| {
            let folded = fold(&name);
            let exact = bare.iter().position(|word| *word == folded);
            let whole = bare.iter().position(|word| {
                folded
                    .split(|c: char| !c.is_alphanumeric())
                    .any(|part| part == *word)
            });
            (
                (exact.unwrap_or(usize::MAX), whole.unwrap_or(usize::MAX)),
                (name, kind),
            )
        })
        .collect();
    keyed.sort_by(|a, b| a.0.cmp(&b.0));
    keyed.into_iter().map(|(_, hit)| hit).collect()
}

/// Runs the search of places.rs without `near`: per type in ranking order
/// until enough candidates, then exact names first. `prefix` adds `*` to each
/// term (today's search); otherwise the terms are taken as given.
fn run(connection: &Connection, words: &[Vec<String>], prefix: bool) -> Result<Vec<(String, String)>> {
    let groups: Vec<String> = words
        .iter()
        .map(|alternatives| {
            let terms: Vec<String> = alternatives
                .iter()
                .map(|term| {
                    let (bare, star) = match term.strip_suffix('*') {
                        Some(bare) => (bare, "*"),
                        None => (term.as_str(), if prefix { "*" } else { "" }),
                    };
                    format!("\"{}\"{star}", bare.replace('"', "\"\""))
                })
                .collect();
            format!("name : ({})", terms.join(" OR "))
        })
        .collect();
    let expression = groups.join(" AND ");
    let fetch = LIMIT * CANDIDATE_FACTOR;
    let mut statement = connection.prepare_cached(
        "SELECT name, type FROM names WHERE names MATCH ? LIMIT ?",
    )?;
    let mut hits = Vec::new();
    for kind in TYPE_PRIORITY {
        if hits.len() >= fetch {
            break;
        }
        let typed = format!("({expression}) AND type : \"{kind}\"");
        let rows = statement.query_map(
            rusqlite::params![typed, i64::try_from(fetch - hits.len()).unwrap_or(0)],
            |row| Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?)),
        )?;
        for row in rows {
            hits.push(row?);
        }
    }
    Ok(hits)
}

fn first(hits: &[(String, String)]) -> String {
    hits.iter()
        .take(3)
        .map(|(name, kind)| format!("{name} ({kind})"))
        .collect::<Vec<_>>()
        .join(", ")
}

/// Lower case and the accents off, as FTS5's unicode61 tokenizer does for the
/// letters that occur here; ß stays ß there too.
fn fold(word: &str) -> String {
    word.to_lowercase()
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

fn peak_rss_kb() -> u64 {
    fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|status| {
            status
                .lines()
                .find(|line| line.starts_with("VmHWM:"))
                .and_then(|line| line.split_whitespace().nth(1)?.parse().ok())
        })
        .unwrap_or(0)
}
