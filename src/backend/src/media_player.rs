use std::path::Path;
use std::sync::Mutex;

use anyhow::{bail, Context, Result};

use crate::audio_engine::{self, AudioEngine, Playback};
use crate::config::AudioConfig;

#[derive(Debug, Clone, Copy, Default)]
enum PlaybackState {
    #[default]
    Stopped,
    Playing,
    Paused,
}

#[derive(Default)]
pub struct MediaPlayer {
    engine: audio_engine::ExternalProcessAudioEngine,
    playback: Mutex<Option<Box<dyn Playback>>>,
    state: Mutex<PlaybackState>,
    queue: Mutex<Vec<String>>,
    queue_index: Mutex<Option<usize>>,
    media_path: Mutex<Option<String>>,
}

impl MediaPlayer {
    pub fn from_audio_config(config: &AudioConfig) -> Self {
        Self {
            engine: audio_engine::ExternalProcessAudioEngine::from_config(config),
            ..Self::default()
        }
    }

    pub fn execute(&self, command: &str, parameters: &str) -> Result<String> {
        match command.trim().to_ascii_lowercase().as_str() {
            "play" | "resume" => self.play(parameters),
            "pause" => self.pause(),
            "stop" => self.stop(),
            "next" => self.next(),
            "previous" => self.previous(),
            unknown => bail!("unknown media command: {unknown}"),
        }
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

    pub fn shutdown(&self) -> Result<()> {
        self.stop().map(|_| ())
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
            return Ok("playback resumed".to_string());
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
        self.start_path(input_path)
    }

    fn start_path(&self, input_path: &str) -> Result<String> {
        let started_playback = self.engine.start(input_path)?;
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
        Ok("playback started".to_string())
    }

    fn next(&self) -> Result<String> {
        self.switch_track(1)
    }

    fn previous(&self) -> Result<String> {
        self.switch_track(-1)
    }

    fn switch_track(&self, direction: isize) -> Result<String> {
        let mut index = self
            .queue_index
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        let queue = self
            .queue
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        let current_index = index.context("no active queue")?;
        let next_index = current_index as isize + direction;
        if next_index < 0 || next_index >= queue.len() as isize {
            bail!("no adjacent track in queue");
        }
        let next_path = queue[next_index as usize].clone();
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
        *index = Some(next_index as usize);
        *self
            .media_path
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(next_path);
        *self
            .state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = PlaybackState::Playing;
        Ok("playback switched".to_string())
    }

    fn pause(&self) -> Result<String> {
        let playback = self
            .playback
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        playback.as_ref().context("no active playback")?.pause()?;
        *self
            .state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = PlaybackState::Paused;
        Ok("playback paused".to_string())
    }

    fn stop(&self) -> Result<String> {
        let mut playback = self
            .playback
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        let Some(active_playback) = playback.take() else {
            return Ok("playback already stopped".to_string());
        };
        active_playback.stop()?;
        *self
            .media_path
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = None;
        *self
            .queue_index
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = None;
        *self
            .state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = PlaybackState::Stopped;
        Ok("playback stopped".to_string())
    }
}
