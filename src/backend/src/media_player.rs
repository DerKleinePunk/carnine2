use std::path::Path;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use anyhow::{anyhow, bail, Context, Result};
use rand::seq::SliceRandom;
use rand::thread_rng;
use tokio::sync::broadcast;

use crate::audio_engine::{self, AudioEngine, Playback};
use crate::carnine::{
    AudioEvent, AudioEventType, PlayerEvent, PlayerEventType, PlayerState, RepeatMode,
};
use crate::config::AudioConfig;

#[derive(Debug, Clone, Copy, Default)]
enum PlaybackState {
    #[default]
    Stopped,
    Playing,
    Paused,
}

pub struct MediaPlayer {
    engine: Box<dyn AudioEngine>,
    playback: Mutex<Option<Box<dyn Playback>>>,
    state: Mutex<PlaybackState>,
    queue: Mutex<Vec<String>>,
    queue_entry_ids: Mutex<Vec<i64>>,
    queue_index: Mutex<Option<usize>>,
    playlist_id: Mutex<Option<i64>>,
    media_path: Mutex<Option<String>>,
    position_ms: Mutex<i64>,
    started_at: Mutex<Option<Instant>>,
    repeat_mode: Mutex<RepeatMode>,
    shuffle_enabled: Mutex<bool>,
    shuffle_order: Mutex<Vec<usize>>,
    shuffle_position: Mutex<usize>,
    events: broadcast::Sender<PlayerEvent>,
    audio_events: broadcast::Sender<AudioEvent>,
}

impl Default for MediaPlayer {
    fn default() -> Self {
        let (events, _) = broadcast::channel(32);
        let (audio_events, _) = broadcast::channel(32);
        Self {
            engine: Box::new(audio_engine::ExternalProcessAudioEngine::default()),
            playback: Mutex::new(None),
            state: Mutex::new(PlaybackState::default()),
            queue: Mutex::new(Vec::new()),
            queue_entry_ids: Mutex::new(Vec::new()),
            queue_index: Mutex::new(None),
            playlist_id: Mutex::new(None),
            media_path: Mutex::new(None),
            position_ms: Mutex::new(0),
            started_at: Mutex::new(None),
            repeat_mode: Mutex::new(RepeatMode::RepeatOff),
            shuffle_enabled: Mutex::new(false),
            shuffle_order: Mutex::new(Vec::new()),
            shuffle_position: Mutex::new(0),
            events,
            audio_events,
        }
    }
}

impl MediaPlayer {
    pub fn from_audio_config(config: &AudioConfig) -> Self {
        Self {
            engine: Box::new(audio_engine::ExternalProcessAudioEngine::from_config(
                config,
            )),
            ..Self::default()
        }
    }

    pub(crate) fn with_engine(engine: Box<dyn AudioEngine>) -> Self {
        Self {
            engine,
            ..Self::default()
        }
    }

    pub fn execute(&self, command: &str, parameters: &str) -> Result<String> {
        let result = match command.trim().to_ascii_lowercase().as_str() {
            "play" | "resume" => self.play(parameters),
            "pause" => self.pause(),
            "stop" => self.stop(),
            "next" => self.next(),
            "previous" => self.previous(),
            "restart" => self.switch_track(0),
            "queue-entry" => self.play_queue_entry(parameters),
            unknown => Err(anyhow!("unknown media command: {unknown}")),
        };
        if let Err(error) = &result {
            self.publish(PlayerEventType::PlayerError, error.to_string());
        }
        result
    }

    pub fn subscribe_events(&self) -> broadcast::Receiver<PlayerEvent> {
        self.events.subscribe()
    }

    pub fn subscribe_audio_events(&self) -> broadcast::Receiver<AudioEvent> {
        self.audio_events.subscribe()
    }

    pub fn audio_event_sender(&self) -> broadcast::Sender<AudioEvent> {
        self.audio_events.clone()
    }

    pub fn snapshot_event(&self) -> PlayerEvent {
        PlayerEvent {
            event: PlayerEventType::PlayerSnapshot as i32,
            state: Some(self.player_state()),
            message: "current player state".to_string(),
        }
    }

    pub fn position_event(&self) -> PlayerEvent {
        PlayerEvent {
            event: PlayerEventType::PlayerPositionChanged as i32,
            state: Some(self.player_state()),
            message: "playback position updated".to_string(),
        }
    }

    pub fn position_ms(&self) -> i64 {
        let stored = *self
            .position_ms
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        let elapsed = self
            .started_at
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .map(|started| started.elapsed().as_millis() as i64)
            .unwrap_or(0);
        stored.saturating_add(elapsed)
    }

    pub fn playlist_id(&self) -> Option<i64> {
        *self
            .playlist_id
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    pub fn playlist_entry_id(&self) -> Option<i64> {
        let index = *self
            .queue_index
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        index.and_then(|index| {
            self.queue_entry_ids
                .lock()
                .unwrap_or_else(|poisoned| poisoned.into_inner())
                .get(index)
                .copied()
        })
    }

    pub fn state(&self) -> &'static str {
        match *self
            .state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
        {
            PlaybackState::Stopped => "stopped",
            PlaybackState::Playing => "playing",
            PlaybackState::Paused => "paused",
        }
    }

    pub fn media_path(&self) -> String {
        self.media_path
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .clone()
            .unwrap_or_default()
    }

    pub fn player_state(&self) -> PlayerState {
        PlayerState {
            status: self.state().to_string(),
            media_path: self.media_path(),
            position_ms: self.position_ms(),
            duration_ms: 0,
            playlist_id: self.playlist_id().unwrap_or_default() as u64,
            repeat_mode: self.repeat_mode() as i32,
            shuffle_enabled: self.shuffle_enabled(),
        }
    }

    fn repeat_mode(&self) -> RepeatMode {
        *self
            .repeat_mode
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    fn shuffle_enabled(&self) -> bool {
        *self
            .shuffle_enabled
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    pub fn set_repeat_mode(&self, mode: RepeatMode) {
        *self
            .repeat_mode
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = mode;
    }

    pub fn set_shuffle_mode(&self, enabled: bool) {
        *self
            .shuffle_enabled
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = enabled;
        if enabled {
            self.reshuffle_from_current();
        }
    }

    fn reshuffle_from_current(&self) {
        let queue_len = self
            .queue
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .len();
        let current_index = *self
            .queue_index
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        *self
            .shuffle_order
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) =
            shuffled_order(queue_len, current_index);
        *self
            .shuffle_position
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = 0;
    }

    fn publish(&self, event: PlayerEventType, message: impl Into<String>) {
        let _ = self.events.send(PlayerEvent {
            event: event as i32,
            state: Some(self.player_state()),
            message: message.into(),
        });
    }

    fn publish_audio(&self, event: AudioEventType, message: impl Into<String>) {
        let _ = self.audio_events.send(AudioEvent {
            event: event as i32,
            message: message.into(),
        });
    }

    pub fn shutdown(&self) -> Result<()> {
        self.stop().map(|_| ())
    }

    pub fn shutdown_output(&self) -> Result<()> {
        self.engine.shutdown()
    }

    fn stop_active_playback(&self) -> Result<()> {
        let active_playback = self
            .playback
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .take();
        if let Some(active_playback) = active_playback {
            active_playback.stop()?;
        }
        *self
            .position_ms
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = 0;
        *self
            .started_at
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = None;
        Ok(())
    }

    pub fn play_playlist(
        &self,
        playlist_id: i64,
        entries: Vec<(i64, String)>,
        resume_entry_id: Option<i64>,
        resume_position_ms: i64,
        resume_mode: &str,
    ) -> Result<String> {
        if entries.is_empty() {
            bail!("playlist has no playable entries");
        }
        self.stop_active_playback()?;
        let selected_index = match resume_mode {
            "auto-play" | "start-last-title" | "restore_paused" => resume_entry_id
                .and_then(|entry_id| entries.iter().position(|(id, _)| *id == entry_id))
                .unwrap_or(0),
            mode => bail!("unsupported resume mode: {mode}"),
        };
        *self
            .queue
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) =
            entries.iter().map(|(_, path)| path.clone()).collect();
        *self
            .queue_entry_ids
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) =
            entries.iter().map(|(id, _)| *id).collect();
        *self
            .playlist_id
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(playlist_id);
        *self
            .queue_index
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(selected_index);
        *self
            .position_ms
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = if resume_mode == "start-last-title"
        {
            0
        } else {
            resume_position_ms.max(0)
        };
        *self
            .media_path
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) =
            Some(entries[selected_index].1.clone());
        *self
            .state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = PlaybackState::Paused;
        if self.shuffle_enabled() {
            self.reshuffle_from_current();
        }
        if resume_mode == "auto-play" {
            self.start_current_path()?;
        }
        Ok("playlist loaded".to_string())
    }

    fn play(&self, input_path: &str) -> Result<String> {
        let playback = self
            .playback
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        if let Some(active_playback) = playback.as_ref() {
            active_playback.resume()?;
            *self
                .state
                .lock()
                .unwrap_or_else(|poisoned| poisoned.into_inner()) = PlaybackState::Playing;
            *self
                .started_at
                .lock()
                .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(Instant::now());
            self.publish_audio(
                AudioEventType::AudioSourceResumeRequested,
                "audio source resume requested",
            );
            self.publish(PlayerEventType::PlayerResumed, "playback resumed");
            return Ok("playback resumed".to_string());
        }
        if input_path.is_empty() && !self.media_path().is_empty() {
            drop(playback);
            return self.start_current_path();
        }
        if input_path.is_empty() {
            bail!("play requires an audio file path in parameters");
        }
        if !Path::new(input_path).is_file() {
            bail!("audio file does not exist: {input_path}");
        }
        drop(playback);
        *self
            .queue
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = vec![input_path.to_string()];
        *self
            .queue_index
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(0);
        *self
            .playlist_id
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = None;
        *self
            .position_ms
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = 0;
        self.start_path(input_path)
    }

    fn start_current_path(&self) -> Result<String> {
        let path = self.media_path();
        if path.is_empty() {
            bail!("no current media");
        }
        self.start_path_at(&path, self.position_ms())
    }

    fn start_path(&self, input_path: &str) -> Result<String> {
        self.start_path_at(input_path, 0)
    }

    fn start_path_at(&self, input_path: &str, position_ms: i64) -> Result<String> {
        let started_playback = self.engine.start_at(input_path, position_ms)?;
        *self
            .playback
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(started_playback);
        *self
            .media_path
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(input_path.to_string());
        *self
            .state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = PlaybackState::Playing;
        *self
            .position_ms
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = position_ms.max(0);
        *self
            .started_at
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(Instant::now());
        self.publish_audio(AudioEventType::AudioSourceStarted, "audio source started");
        self.publish(PlayerEventType::PlayerPlaybackStarted, "playback started");
        Ok("playback started".to_string())
    }

    fn next(&self) -> Result<String> {
        self.switch_track(1)
    }

    fn previous(&self) -> Result<String> {
        self.switch_track(-1)
    }

    fn play_queue_entry(&self, index: &str) -> Result<String> {
        let index = index
            .parse::<usize>()
            .with_context(|| format!("invalid queue index: {index}"))?;
        self.switch_to_index(index)
    }

    fn switch_track(&self, direction: isize) -> Result<String> {
        let target_index = self
            .resolve_next_index(direction)
            .context("no adjacent track in queue")?;
        self.switch_to_index(target_index)
    }

    fn switch_to_index(&self, target_index: usize) -> Result<String> {
        let queue_len = self
            .queue
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .len();
        if target_index >= queue_len {
            bail!("queue index out of range: {target_index}");
        }
        let active_playback = self
            .playback
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .take();
        let Some(active_playback) = active_playback else {
            bail!("no active playback");
        };
        active_playback.stop()?;
        self.start_at_index(target_index)
    }

    fn start_at_index(&self, target_index: usize) -> Result<String> {
        let next_path = self
            .queue
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .get(target_index)
            .cloned()
            .with_context(|| format!("queue index out of range: {target_index}"))?;
        let started_playback = self.engine.start(&next_path)?;
        *self
            .playback
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(started_playback);
        *self
            .queue_index
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(target_index);
        *self
            .media_path
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(next_path);
        *self
            .state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = PlaybackState::Playing;
        *self
            .position_ms
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = 0;
        *self
            .started_at
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(Instant::now());
        self.publish(PlayerEventType::PlayerTrackChanged, "playback switched");
        Ok("playback switched".to_string())
    }

    /// Resolves the queue index to move to from the current position,
    /// honoring repeat/shuffle. `None` means there is nowhere to go (e.g.
    /// past the end of the queue with repeat off).
    fn resolve_next_index(&self, direction: isize) -> Option<usize> {
        let queue_len = self
            .queue
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .len();
        if queue_len == 0 {
            return None;
        }
        let repeat_mode = self.repeat_mode();
        let current_index = *self
            .queue_index
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        if repeat_mode == RepeatMode::RepeatTrack {
            return current_index;
        }
        if self.shuffle_enabled() {
            return self.resolve_next_shuffled_index(direction, queue_len, repeat_mode);
        }
        let current_index = current_index?;
        let raw_next = current_index as isize + direction;
        if raw_next < 0 {
            return (repeat_mode == RepeatMode::RepeatQueue).then(|| queue_len - 1);
        }
        if raw_next as usize >= queue_len {
            return (repeat_mode == RepeatMode::RepeatQueue).then_some(0);
        }
        Some(raw_next as usize)
    }

    fn resolve_next_shuffled_index(
        &self,
        direction: isize,
        queue_len: usize,
        repeat_mode: RepeatMode,
    ) -> Option<usize> {
        let mut order = self
            .shuffle_order
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        if order.len() != queue_len {
            *order = shuffled_order(queue_len, None);
        }
        let mut position = self
            .shuffle_position
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        let raw_next = *position as isize + direction;
        if raw_next < 0 {
            return None;
        }
        if raw_next as usize >= order.len() {
            if repeat_mode != RepeatMode::RepeatQueue {
                return None;
            }
            *order = shuffled_order(queue_len, None);
            *position = 0;
            return order.first().copied();
        }
        *position = raw_next as usize;
        order.get(*position).copied()
    }

    fn is_active_track_finished(&self) -> bool {
        let playing = matches!(
            *self
                .state
                .lock()
                .unwrap_or_else(|poisoned| poisoned.into_inner()),
            PlaybackState::Playing
        );
        if !playing {
            return false;
        }
        self.playback
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .as_ref()
            .is_some_and(|playback| playback.is_finished())
    }

    fn handle_track_finished(&self) {
        let active_playback = self
            .playback
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .take();
        if let Some(active_playback) = active_playback {
            if let Err(error) = active_playback.stop() {
                self.publish(PlayerEventType::PlayerError, error.to_string());
                return;
            }
        }
        match self.resolve_next_index(1) {
            Some(next_index) => {
                if let Err(error) = self.start_at_index(next_index) {
                    self.publish(PlayerEventType::PlayerError, error.to_string());
                }
            }
            None => {
                *self
                    .position_ms
                    .lock()
                    .unwrap_or_else(|poisoned| poisoned.into_inner()) = 0;
                *self
                    .started_at
                    .lock()
                    .unwrap_or_else(|poisoned| poisoned.into_inner()) = None;
                *self
                    .state
                    .lock()
                    .unwrap_or_else(|poisoned| poisoned.into_inner()) = PlaybackState::Stopped;
                self.publish(PlayerEventType::PlayerQueueFinished, "playlist finished");
            }
        }
    }

    fn pause(&self) -> Result<String> {
        let playback = self
            .playback
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        playback.as_ref().context("no active playback")?.pause()?;
        let position_ms = self.position_ms();
        *self
            .state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = PlaybackState::Paused;
        *self
            .position_ms
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = position_ms;
        *self
            .started_at
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = None;
        self.publish_audio(
            AudioEventType::AudioSourcePauseRequested,
            "audio source pause requested",
        );
        self.publish(PlayerEventType::PlayerPaused, "playback paused");
        Ok("playback paused".to_string())
    }

    fn stop(&self) -> Result<String> {
        let mut playback = self
            .playback
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        let position_ms = self.position_ms();
        if let Some(active_playback) = playback.take() {
            self.publish_audio(
                AudioEventType::AudioSourceStopRequested,
                "audio source stop requested",
            );
            active_playback.stop()?;
            self.publish_audio(AudioEventType::AudioDecoderStopped, "audio decoder stopped");
            self.publish_audio(AudioEventType::AudioSourceRemoved, "audio source removed");
        }
        *self
            .media_path
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = None;
        *self
            .position_ms
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = position_ms;
        *self
            .started_at
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = None;
        *self
            .state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = PlaybackState::Stopped;
        self.publish(PlayerEventType::PlayerStopped, "playback stopped");
        Ok("playback stopped".to_string())
    }

    /// Spawns a background task that polls for natural track completion
    /// and auto-advances (honoring repeat/shuffle), independent of whether
    /// any gRPC client is subscribed to the player event stream.
    pub fn spawn_completion_watcher(player: Arc<MediaPlayer>) {
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_millis(250));
            loop {
                interval.tick().await;
                if player.is_active_track_finished() {
                    let player = Arc::clone(&player);
                    let _ =
                        tokio::task::spawn_blocking(move || player.handle_track_finished()).await;
                }
            }
        });
    }
}

fn shuffled_order(len: usize, pinned_first: Option<usize>) -> Vec<usize> {
    let mut order: Vec<usize> = (0..len).collect();
    match pinned_first.filter(|index| *index < len) {
        Some(pinned) => {
            order.retain(|&index| index != pinned);
            order.shuffle(&mut thread_rng());
            order.insert(0, pinned);
        }
        None => order.shuffle(&mut thread_rng()),
    }
    order
}

#[cfg(test)]
mod tests {
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::sync::Arc;

    use super::MediaPlayer;
    use crate::audio_engine::{AudioEngine, Playback};
    use crate::carnine::{PlayerEventType, RepeatMode};
    use crate::config::AudioConfig;
    use anyhow::Result;

    fn player() -> MediaPlayer {
        MediaPlayer::from_audio_config(&AudioConfig {
            backend: "alsa".to_string(),
            device: "default".to_string(),
            sample_rate: 44_100,
            channels: 2,
            navigation_interrupt: "pause_music".to_string(),
        })
    }

    struct FakePlayback {
        finished: Arc<AtomicBool>,
    }

    impl Playback for FakePlayback {
        fn pause(&self) -> Result<()> {
            Ok(())
        }
        fn resume(&self) -> Result<()> {
            Ok(())
        }
        fn stop(self: Box<Self>) -> Result<()> {
            Ok(())
        }
        fn is_finished(&self) -> bool {
            self.finished.load(Ordering::Acquire)
        }
    }

    struct FakeAudioEngine {
        finished: Arc<AtomicBool>,
    }

    impl AudioEngine for FakeAudioEngine {
        fn start(&self, _input_path: &str) -> Result<Box<dyn Playback>> {
            self.finished.store(false, Ordering::Release);
            Ok(Box::new(FakePlayback {
                finished: Arc::clone(&self.finished),
            }))
        }
    }

    /// A player whose active track's "finished" state can be toggled from
    /// the test, to deterministically simulate a natural track end without
    /// real audio/ffmpeg.
    fn player_with_finish_control() -> (MediaPlayer, Arc<AtomicBool>) {
        let finished = Arc::new(AtomicBool::new(false));
        let engine = FakeAudioEngine {
            finished: Arc::clone(&finished),
        };
        (MediaPlayer::with_engine(Box::new(engine)), finished)
    }

    #[test]
    fn restores_saved_playlist_entry_and_position_without_starting_audio() {
        let player = player();

        player
            .play_playlist(
                7,
                vec![
                    (11, "/music/first.mp3".to_string()),
                    (12, "/music/last.mp3".to_string()),
                ],
                Some(12),
                12_345,
                "restore_paused",
            )
            .expect("playlist should load");

        assert_eq!(player.playlist_id(), Some(7));
        assert_eq!(player.playlist_entry_id(), Some(12));
        assert_eq!(player.position_ms(), 12_345);
        assert_eq!(player.state(), "paused");
        assert_eq!(player.media_path(), "/music/last.mp3");
    }

    #[test]
    fn start_last_title_resets_saved_position() {
        let player = player();

        player
            .play_playlist(
                7,
                vec![(11, "/music/first.mp3".to_string())],
                Some(11),
                12_345,
                "start-last-title",
            )
            .expect("playlist should load");

        assert_eq!(player.position_ms(), 0);
        assert_eq!(player.state(), "paused");
    }

    #[test]
    fn position_event_uses_the_live_player_state() {
        let player = player();

        let event = player.position_event();

        assert_eq!(event.event, PlayerEventType::PlayerPositionChanged as i32);
        assert_eq!(
            event.state.expect("position state should exist").status,
            "stopped"
        );
        assert_eq!(event.message, "playback position updated");
    }

    #[test]
    fn stopping_playback_preserves_resume_position() {
        let player = player();
        *player
            .position_ms
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = 12_345;

        player.stop().expect("playback should stop");

        assert_eq!(player.position_ms(), 12_345);
    }

    #[test]
    fn auto_advance_moves_to_next_track_when_current_finishes() {
        let (player, finished) = player_with_finish_control();
        player
            .play_playlist(
                1,
                vec![
                    (11, "/music/a.mp3".to_string()),
                    (12, "/music/b.mp3".to_string()),
                ],
                Some(11),
                0,
                "auto-play",
            )
            .expect("playlist should start");
        assert_eq!(player.media_path(), "/music/a.mp3");

        finished.store(true, Ordering::Release);
        player.handle_track_finished();

        assert_eq!(player.media_path(), "/music/b.mp3");
        assert_eq!(player.state(), "playing");
    }

    #[test]
    fn auto_advance_stops_and_publishes_queue_finished_at_end_with_repeat_off() {
        let (player, finished) = player_with_finish_control();
        let mut events = player.subscribe_events();
        player
            .play_playlist(
                1,
                vec![(11, "/music/a.mp3".to_string())],
                Some(11),
                0,
                "auto-play",
            )
            .expect("playlist should start");

        finished.store(true, Ordering::Release);
        player.handle_track_finished();

        assert_eq!(player.state(), "stopped");
        let mut saw_queue_finished = false;
        while let Ok(event) = events.try_recv() {
            saw_queue_finished |= event.event == PlayerEventType::PlayerQueueFinished as i32;
        }
        assert!(saw_queue_finished);
    }

    #[test]
    fn repeat_queue_wraps_to_first_track_when_auto_advancing_past_the_end() {
        let (player, finished) = player_with_finish_control();
        player
            .play_playlist(
                1,
                vec![
                    (11, "/music/a.mp3".to_string()),
                    (12, "/music/b.mp3".to_string()),
                ],
                Some(12),
                0,
                "auto-play",
            )
            .expect("playlist should start");
        player.set_repeat_mode(RepeatMode::RepeatQueue);

        finished.store(true, Ordering::Release);
        player.handle_track_finished();

        assert_eq!(player.media_path(), "/music/a.mp3");
        assert_eq!(player.state(), "playing");
    }

    #[test]
    fn repeat_track_replays_the_same_track_when_it_finishes() {
        let (player, finished) = player_with_finish_control();
        player
            .play_playlist(
                1,
                vec![(11, "/music/a.mp3".to_string())],
                Some(11),
                0,
                "auto-play",
            )
            .expect("playlist should start");
        player.set_repeat_mode(RepeatMode::RepeatTrack);

        finished.store(true, Ordering::Release);
        player.handle_track_finished();

        assert_eq!(player.media_path(), "/music/a.mp3");
        assert_eq!(player.state(), "playing");
    }

    #[test]
    fn shuffle_visits_every_track_exactly_once_before_a_track_repeats() {
        let (player, finished) = player_with_finish_control();
        player
            .play_playlist(
                1,
                vec![
                    (11, "a".to_string()),
                    (12, "b".to_string()),
                    (13, "c".to_string()),
                ],
                Some(11),
                0,
                "auto-play",
            )
            .expect("playlist should start");
        player.set_shuffle_mode(true);
        player.set_repeat_mode(RepeatMode::RepeatQueue);

        let mut visited = vec![player.media_path()];
        for _ in 0..2 {
            finished.store(true, Ordering::Release);
            player.handle_track_finished();
            visited.push(player.media_path());
        }
        let mut sorted = visited.clone();
        sorted.sort();
        assert_eq!(sorted, ["a", "b", "c"]);

        // The bag refills once exhausted instead of erroring out.
        finished.store(true, Ordering::Release);
        player.handle_track_finished();
        assert!(["a", "b", "c"].contains(&player.media_path().as_str()));
    }

    #[test]
    fn manual_next_wraps_with_repeat_queue_but_errors_with_repeat_off() {
        let (player, _finished) = player_with_finish_control();
        player
            .play_playlist(
                1,
                vec![
                    (11, "/music/a.mp3".to_string()),
                    (12, "/music/b.mp3".to_string()),
                ],
                Some(12),
                0,
                "auto-play",
            )
            .expect("playlist should start");

        assert!(player.execute("next", "").is_err());

        player.set_repeat_mode(RepeatMode::RepeatQueue);
        player
            .execute("next", "")
            .expect("next should wrap to the first track");
        assert_eq!(player.media_path(), "/music/a.mp3");

        player
            .execute("previous", "")
            .expect("previous should wrap to the last track with repeat=queue");
        assert_eq!(player.media_path(), "/music/b.mp3");
    }
}
