use std::path::Path;
use std::sync::Mutex;
use std::time::Instant;

use anyhow::{anyhow, bail, Context, Result};
use tokio::sync::broadcast;

use crate::audio_engine::{self, AudioEngine, Playback};
use crate::carnine::{PlayerEvent, PlayerState};
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
    events: broadcast::Sender<PlayerEvent>,
}

impl Default for MediaPlayer {
    fn default() -> Self {
        let (events, _) = broadcast::channel(32);
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
            events,
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
            self.publish("error", error.to_string());
        }
        result
    }

    pub fn subscribe_events(&self) -> broadcast::Receiver<PlayerEvent> {
        self.events.subscribe()
    }

    pub fn snapshot_event(&self) -> PlayerEvent {
        PlayerEvent {
            event: "snapshot".to_string(),
            state: Some(self.player_state()),
            message: "current player state".to_string(),
        }
    }

    pub fn position_event(&self) -> PlayerEvent {
        PlayerEvent {
            event: "position_changed".to_string(),
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

    fn player_state(&self) -> PlayerState {
        PlayerState {
            status: self.state().to_string(),
            media_path: self.media_path(),
            position_ms: self.position_ms(),
            duration_ms: 0,
            playlist_id: self.playlist_id().unwrap_or_default() as u64,
        }
    }

    fn publish(&self, event: &str, message: impl Into<String>) {
        let _ = self.events.send(PlayerEvent {
            event: event.to_string(),
            state: Some(self.player_state()),
            message: message.into(),
        });
    }

    pub fn shutdown(&self) -> Result<()> {
        self.stop().map(|_| ())
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
            self.publish("resumed", "playback resumed");
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
        self.publish("playback_started", "playback started");
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
        let index = self
            .queue_index
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .context("no active queue")?;
        let queue = self
            .queue
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        let next_index = index as isize + direction;
        if next_index < 0 || next_index >= queue.len() as isize {
            bail!("no adjacent track in queue");
        }
        drop(queue);
        self.switch_to_index(next_index as usize)
    }

    fn switch_to_index(&self, target_index: usize) -> Result<String> {
        let mut index = self
            .queue_index
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        let queue = self
            .queue
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        if target_index >= queue.len() {
            bail!("queue index out of range: {target_index}");
        }
        let next_path = queue[target_index].clone();
        drop(queue);
        let mut playback = self
            .playback
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        let Some(active_playback) = playback.take() else {
            bail!("no active playback");
        };
        active_playback.stop()?;
        let started_playback = self.engine.start(&next_path)?;
        *playback = Some(started_playback);
        *index = Some(target_index);
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
        self.publish("track_changed", "playback switched");
        Ok("playback switched".to_string())
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
        self.publish("paused", "playback paused");
        Ok("playback paused".to_string())
    }

    fn stop(&self) -> Result<String> {
        let mut playback = self
            .playback
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        if let Some(active_playback) = playback.take() {
            active_playback.stop()?;
        }
        *self
            .media_path
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = None;
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
        self.publish("stopped", "playback stopped");
        Ok("playback stopped".to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::MediaPlayer;
    use crate::config::AudioConfig;

    fn player() -> MediaPlayer {
        MediaPlayer::from_audio_config(&AudioConfig {
            backend: "alsa".to_string(),
            device: "default".to_string(),
            sample_rate: 44_100,
            channels: 2,
            navigation_interrupt: "pause_music".to_string(),
        })
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

        assert_eq!(event.event, "position_changed");
        assert_eq!(
            event.state.expect("position state should exist").status,
            "stopped"
        );
        assert_eq!(event.message, "playback position updated");
    }
}
