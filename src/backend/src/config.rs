use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use serde::Deserialize;

#[derive(Debug, Clone, Deserialize, serde::Serialize)]
pub struct Config {
    pub server: ServerConfig,
    pub media: MediaConfig,
    pub audio: AudioConfig,
    pub logging: LoggingConfig,
}

#[derive(Debug, Clone, Deserialize, serde::Serialize)]
pub struct ServerConfig {
    pub address: String,
}

#[derive(Debug, Clone, Deserialize, serde::Serialize)]
pub struct MediaConfig {
    pub database_path: PathBuf,
    pub folders: Vec<PathBuf>,
    pub supported_formats: Vec<String>,
    pub rescan_on_start: bool,
    pub resume_mode: String,
}

#[derive(Debug, Clone, Deserialize, serde::Serialize)]
pub struct AudioConfig {
    pub backend: String,
    pub device: String,
    pub sample_rate: u32,
    pub channels: u16,
    pub navigation_interrupt: String,
}

#[derive(Debug, Clone, Deserialize, serde::Serialize)]
pub struct LoggingConfig {
    pub directory: PathBuf,
    pub level: String,
}

impl Config {
    pub fn validate(&self) -> Result<()> {
        self.server
            .address
            .parse::<std::net::SocketAddr>()
            .with_context(|| format!("invalid server address {}", self.server.address))?;
        if self.media.database_path.as_os_str().is_empty()
            || self
                .media
                .folders
                .iter()
                .any(|path| path.as_os_str().is_empty())
            || self.logging.directory.as_os_str().is_empty()
        {
            anyhow::bail!("configuration contains an empty path");
        }
        if !matches!(self.audio.backend.as_str(), "alsa" | "pulse") {
            anyhow::bail!("unsupported audio backend: {}", self.audio.backend);
        }
        if self.audio.device.trim().is_empty() {
            anyhow::bail!("audio device must not be empty");
        }
        if !(8_000..=192_000).contains(&self.audio.sample_rate) {
            anyhow::bail!("audio sample rate must be between 8000 and 192000 Hz");
        }
        if !(1..=8).contains(&self.audio.channels) {
            anyhow::bail!("audio channels must be between 1 and 8");
        }
        if !matches!(
            self.logging.level.trim().to_ascii_lowercase().as_str(),
            "trace" | "debug" | "info" | "warn" | "error"
        ) {
            anyhow::bail!("invalid log level: {}", self.logging.level);
        }
        Ok(())
    }

    pub fn load() -> Result<(Self, PathBuf)> {
        let path = env::var_os("CARNINE_CONFIG")
            .map(PathBuf::from)
            .or_else(|| {
                let system_path = Path::new("/etc/carnine/config.toml");
                system_path.is_file().then(|| system_path.to_path_buf())
            })
            .unwrap_or_else(|| PathBuf::from("../../resources/config/carnine.toml"));
        let content = fs::read_to_string(&path)
            .with_context(|| format!("failed to read configuration {}", path.display()))?;
        let mut config: Config = toml::from_str(&content)
            .with_context(|| format!("failed to parse configuration {}", path.display()))?;
        if let Some(log_directory) = env::var_os("CARNINE_LOG_DIRECTORY") {
            config.logging.directory = PathBuf::from(log_directory);
        }
        if let Some(database_path) = env::var_os("CARNINE_DATABASE_PATH") {
            config.media.database_path = PathBuf::from(database_path);
        }
        if let Some(audio_backend) = env::var_os("CARNINE_AUDIO_BACKEND") {
            config.audio.backend = audio_backend.to_string_lossy().into_owned();
        }
        if let Some(audio_device) = env::var_os("CARNINE_AUDIO_DEVICE") {
            config.audio.device = audio_device.to_string_lossy().into_owned();
        }
        config.validate()?;
        Ok((config, path))
    }
}

#[cfg(test)]
mod tests {
    use super::Config;

    #[test]
    fn loads_repository_configuration() {
        let (config, path) = Config::load().expect("repository config should load");
        assert!(path.ends_with("resources/config/carnine.toml"));
        assert_eq!(config.server.address, "[::1]:50051");
        assert_eq!(config.audio.device, "plughw:1,0");
    }

    #[test]
    fn rejects_invalid_runtime_values() {
        let (mut config, _) = Config::load().expect("repository config should load");

        config.server.address = "not-an-address".to_string();
        assert!(config.validate().is_err());

        let (mut config, _) = Config::load().expect("repository config should load");
        config.audio.backend = "jack".to_string();
        assert!(config.validate().is_err());

        let (mut config, _) = Config::load().expect("repository config should load");
        config.audio.sample_rate = 7_999;
        assert!(config.validate().is_err());

        let (mut config, _) = Config::load().expect("repository config should load");
        config.audio.channels = 0;
        assert!(config.validate().is_err());

        let (mut config, _) = Config::load().expect("repository config should load");
        config.logging.level = "not a filter".to_string();
        assert!(config.validate().is_err());
    }
}
