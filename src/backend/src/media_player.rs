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

    fn play(&self, input_path: &str) -> Result<String> {
        let mut playback = self
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
        *playback = Some(self.engine.start(input_path)?);
        *self
            .state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = PlaybackState::Playing;
        Ok("playback started".to_string())
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
            .state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = PlaybackState::Stopped;
        Ok("playback stopped".to_string())
    }
}
