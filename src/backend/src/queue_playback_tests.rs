//! Queue playback with real files (#2).
//!
//! The media player tests elsewhere drive a fake engine. These play short WAV
//! files the test writes itself through the real engine: FFmpeg decodes them
//! into the ring buffers, the mixer renders them, and only the sound card is
//! replaced by an output thread that listens. Each track is a constant tone
//! of its own level, so the rendered samples tell which track was audible and
//! for how long.

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use crate::carnine::{PlayerEventType, RepeatMode};
use crate::cpal_audio_engine::engine_with_null_output;
use crate::media_player::MediaPlayer;

const SAMPLE_RATE: u32 = 44_100;
/// 10 ms per block, rendered about as fast as a sound card would take it.
const PERIOD_FRAMES: usize = 441;
const PACE: Duration = Duration::from_millis(10);
/// Frames of one level it takes to count as "heard". A fade sweeps through
/// the lower levels for a few hundred frames; a track plays for thousands.
const MIN_HEARD_FRAMES: usize = 2_000;
const LEVEL_TOLERANCE: f32 = 0.002;
const WAIT: Duration = Duration::from_secs(10);

/// Level of track `number` (1-based): 0.1, 0.2, 0.3 ...
fn level(number: usize) -> f32 {
    number as f32 * 0.1
}

/// A folder of test tracks, removed again when the test ends.
#[derive(Debug)]
struct Tracks {
    folder: PathBuf,
    paths: Vec<String>,
}

impl Tracks {
    /// `count` stereo WAV files of `seconds` each, track n at `level(n)`.
    fn write(name: &str, count: usize, seconds: f32) -> Self {
        let folder =
            std::env::temp_dir().join(format!("carnine-queue-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&folder);
        std::fs::create_dir_all(&folder).expect("track folder should be writable");
        let paths = (1..=count)
            .map(|number| {
                let path = folder.join(format!("track-{number}.wav"));
                write_constant_wav(&path, level(number), seconds);
                path.to_string_lossy().into_owned()
            })
            .collect();
        Self { folder, paths }
    }

    /// The tracks as playlist entries, entry id 100 + track number.
    fn entries(&self) -> Vec<(i64, String)> {
        self.paths
            .iter()
            .enumerate()
            .map(|(index, path)| (101 + index as i64, path.clone()))
            .collect()
    }

    fn entry_id(number: usize) -> i64 {
        100 + number as i64
    }
}

impl Drop for Tracks {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.folder);
    }
}

/// 16-bit stereo PCM WAV holding one constant sample value.
fn write_constant_wav(path: &Path, level: f32, seconds: f32) {
    let frames = (SAMPLE_RATE as f32 * seconds) as u32;
    let sample = ((level * i16::MAX as f32).round() as i16).to_le_bytes();
    let data_bytes = frames * 4;
    let mut wav = Vec::with_capacity(44 + data_bytes as usize);
    wav.extend_from_slice(b"RIFF");
    wav.extend_from_slice(&(36 + data_bytes).to_le_bytes());
    wav.extend_from_slice(b"WAVEfmt ");
    wav.extend_from_slice(&16_u32.to_le_bytes());
    wav.extend_from_slice(&1_u16.to_le_bytes()); // PCM
    wav.extend_from_slice(&2_u16.to_le_bytes()); // channels
    wav.extend_from_slice(&SAMPLE_RATE.to_le_bytes());
    wav.extend_from_slice(&(SAMPLE_RATE * 4).to_le_bytes()); // bytes per second
    wav.extend_from_slice(&4_u16.to_le_bytes()); // bytes per frame
    wav.extend_from_slice(&16_u16.to_le_bytes()); // bits per sample
    wav.extend_from_slice(b"data");
    wav.extend_from_slice(&data_bytes.to_le_bytes());
    for _ in 0..frames {
        wav.extend_from_slice(&sample);
        wav.extend_from_slice(&sample);
    }
    std::fs::write(path, wav).expect("track should be writable");
}

/// What the null output rendered: runs of (track number or 0, frames).
#[derive(Debug, Default)]
struct Heard {
    runs: Vec<(usize, usize)>,
}

impl Heard {
    fn record(&mut self, block: &[f32]) {
        for frame in block.as_chunks::<2>().0 {
            let track = (1..=9)
                .find(|number| (frame[0] - level(*number)).abs() < LEVEL_TOLERANCE)
                .unwrap_or(0);
            match self.runs.last_mut() {
                Some((last, frames)) if *last == track => *frames += 1,
                _ => self.runs.push((track, 1)),
            }
        }
    }

    /// The tracks heard, in order, each counted once per stretch.
    fn tracks(&self) -> Vec<usize> {
        let mut tracks: Vec<usize> = Vec::new();
        for (track, frames) in &self.runs {
            if *track != 0 && *frames >= MIN_HEARD_FRAMES && tracks.last() != Some(track) {
                tracks.push(*track);
            }
        }
        tracks
    }

    /// The track playing right now, if the last run is long enough to tell.
    fn current(&self) -> Option<usize> {
        self.runs
            .last()
            .filter(|(track, frames)| *track != 0 && *frames >= MIN_HEARD_FRAMES)
            .map(|(track, _)| *track)
    }

    /// Frames of `track`'s longest stretch.
    fn longest_stretch(&self, track: usize) -> usize {
        self.runs
            .iter()
            .filter(|(number, _)| *number == track)
            .map(|(_, frames)| *frames)
            .max()
            .unwrap_or(0)
    }
}

/// A player on the real engine with a listening null output.
fn listening_player() -> (MediaPlayer, Arc<Mutex<Heard>>) {
    let heard = Arc::new(Mutex::new(Heard::default()));
    let sink_heard = Arc::clone(&heard);
    let engine = engine_with_null_output(SAMPLE_RATE, PERIOD_FRAMES, PACE, move |block| {
        sink_heard
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .record(block);
    });
    (MediaPlayer::with_engine(Box::new(engine)), heard)
}

fn wait_for(what: &str, mut condition: impl FnMut() -> bool) {
    let deadline = Instant::now() + WAIT;
    while !condition() {
        assert!(Instant::now() < deadline, "timed out waiting for {what}");
        thread::sleep(Duration::from_millis(20));
    }
}

fn wait_until_heard(heard: &Arc<Mutex<Heard>>, track: usize) {
    wait_for(&format!("track {track} to be audible"), || {
        heard.lock().unwrap().current() == Some(track)
    });
}

#[test]
fn next_and_previous_switch_the_audible_track_and_stop_at_the_ends() {
    let tracks = Tracks::write("next-previous", 3, 5.0);
    let (player, heard) = listening_player();
    player
        .play_playlist(1, tracks.entries(), None, 0, "auto-play")
        .expect("playlist should start");
    wait_until_heard(&heard, 1);

    // The start of the queue: nothing before the first track.
    assert!(player.execute("previous", "").is_err());
    assert_eq!(player.playlist_entry_id(), Some(Tracks::entry_id(1)));
    assert_eq!(player.state(), "playing");

    player
        .execute("next", "")
        .expect("next should play track 2");
    wait_until_heard(&heard, 2);
    player
        .execute("next", "")
        .expect("next should play track 3");
    wait_until_heard(&heard, 3);
    assert_eq!(player.media_path(), tracks.paths[2]);

    // The end of the queue: nothing after the last track, and it keeps
    // playing rather than stopping.
    assert!(player.execute("next", "").is_err());
    assert_eq!(player.playlist_entry_id(), Some(Tracks::entry_id(3)));
    assert_eq!(player.state(), "playing");
    thread::sleep(Duration::from_millis(200));
    assert_eq!(heard.lock().unwrap().current(), Some(3));

    player
        .execute("previous", "")
        .expect("previous should play 2");
    wait_until_heard(&heard, 2);
    player
        .execute("previous", "")
        .expect("previous should play 1");
    wait_until_heard(&heard, 1);

    player.shutdown().expect("player should stop");
    assert_eq!(heard.lock().unwrap().tracks(), [1, 2, 3, 2, 1]);
}

#[test]
fn repeat_queue_wraps_at_both_ends_of_the_queue() {
    let tracks = Tracks::write("repeat-queue", 3, 5.0);
    let (player, heard) = listening_player();
    player.set_repeat_mode(RepeatMode::RepeatQueue);
    player
        .play_playlist(1, tracks.entries(), None, 0, "auto-play")
        .expect("playlist should start");
    wait_until_heard(&heard, 1);

    player
        .execute("previous", "")
        .expect("previous should wrap");
    wait_until_heard(&heard, 3);
    assert_eq!(player.playlist_entry_id(), Some(Tracks::entry_id(3)));

    player.execute("next", "").expect("next should wrap");
    wait_until_heard(&heard, 1);
    assert_eq!(player.playlist_entry_id(), Some(Tracks::entry_id(1)));

    player.shutdown().expect("player should stop");
    assert_eq!(heard.lock().unwrap().tracks(), [1, 3, 1]);
}

#[test]
fn a_queue_entry_plays_that_track_and_an_index_past_the_end_changes_nothing() {
    let tracks = Tracks::write("queue-entry", 3, 5.0);
    let (player, heard) = listening_player();
    player
        .play_playlist(1, tracks.entries(), None, 0, "auto-play")
        .expect("playlist should start");
    wait_until_heard(&heard, 1);

    player
        .execute("queue-entry", "2")
        .expect("index 2 is the third track");
    wait_until_heard(&heard, 3);

    assert!(player.execute("queue-entry", "3").is_err());
    assert_eq!(player.playlist_entry_id(), Some(Tracks::entry_id(3)));
    thread::sleep(Duration::from_millis(200));
    assert_eq!(heard.lock().unwrap().current(), Some(3));

    player.shutdown().expect("player should stop");
    assert_eq!(heard.lock().unwrap().tracks(), [1, 3]);
}

#[test]
fn a_playlist_resumed_at_an_entry_starts_with_that_track() {
    let tracks = Tracks::write("resume-entry", 3, 5.0);
    let (player, heard) = listening_player();
    player
        .play_playlist(
            1,
            tracks.entries(),
            Some(Tracks::entry_id(2)),
            0,
            "auto-play",
        )
        .expect("playlist should start");
    wait_until_heard(&heard, 2);

    player
        .execute("next", "")
        .expect("next should play track 3");
    wait_until_heard(&heard, 3);

    player.shutdown().expect("player should stop");
    assert_eq!(heard.lock().unwrap().tracks(), [2, 3]);
}

/// Waits for the queue to run out through the real completion watcher.
async fn wait_for_queue_finished(
    mut events: tokio::sync::broadcast::Receiver<crate::carnine::PlayerEvent>,
) {
    let deadline = tokio::time::Instant::now() + WAIT;
    loop {
        let event = tokio::time::timeout_at(deadline, events.recv())
            .await
            .expect("timed out waiting for the end of the queue")
            .expect("player events should keep coming");
        if event.event == PlayerEventType::PlayerQueueFinished as i32 {
            return;
        }
    }
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn a_playlist_plays_every_track_in_order_and_stops_at_the_end() {
    let tracks = Tracks::write("in-order", 3, 1.0);
    let (player, heard) = listening_player();
    let player = Arc::new(player);
    MediaPlayer::spawn_completion_watcher(Arc::clone(&player));
    let events = player.subscribe_events();
    player
        .play_playlist(1, tracks.entries(), None, 0, "auto-play")
        .expect("playlist should start");

    wait_for_queue_finished(events).await;

    assert_eq!(player.state(), "stopped");
    assert_eq!(heard.lock().unwrap().tracks(), [1, 2, 3]);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn repeat_track_plays_the_same_file_again() {
    let tracks = Tracks::write("repeat-track", 2, 0.5);
    let (player, heard) = listening_player();
    player.set_repeat_mode(RepeatMode::RepeatTrack);
    let player = Arc::new(player);
    MediaPlayer::spawn_completion_watcher(Arc::clone(&player));
    player
        .play_playlist(1, tracks.entries(), None, 0, "auto-play")
        .expect("playlist should start");

    // Two stretches of track 1 with a gap between them - the replay - and
    // never track 2.
    wait_for("track 1 to play twice", || {
        let heard = heard.lock().unwrap();
        heard
            .runs
            .iter()
            .filter(|(track, frames)| *track == 1 && *frames >= MIN_HEARD_FRAMES)
            .count()
            >= 2
    });
    player.shutdown().expect("player should stop");
    assert!(!heard.lock().unwrap().tracks().contains(&2));
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn each_track_plays_to_its_end_before_the_next_one_starts() {
    let tracks = Tracks::write("to-the-end", 2, 1.0);
    let (player, heard) = listening_player();
    let player = Arc::new(player);
    MediaPlayer::spawn_completion_watcher(Arc::clone(&player));
    let events = player.subscribe_events();
    player
        .play_playlist(1, tracks.entries(), None, 0, "auto-play")
        .expect("playlist should start");

    wait_for_queue_finished(events).await;

    let heard = heard.lock().unwrap();
    // 1 s is 44 100 frames; allow a period for where the ring ran dry.
    for track in [1, 2] {
        let frames = heard.longest_stretch(track);
        assert!(
            frames >= SAMPLE_RATE as usize - 2 * PERIOD_FRAMES,
            "track {track} was heard for {frames} of {SAMPLE_RATE} frames"
        );
    }
}
