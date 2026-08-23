use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Config {
    pub server: ServerConfig,
    pub media: MediaConfig,
    pub audio: AudioConfig,
    pub logging: LoggingConfig,
}

#[derive(Debug, Deserialize)]
pub struct ServerConfig {
    pub address: String,
}

#[derive(Debug, Deserialize)]
pub struct MediaConfig {
    pub database_path: PathBuf,
    pub folders: Vec<PathBuf>,
    pub supported_formats: Vec<String>,
    pub rescan_on_start: bool,
    pub resume_mode: String,
}

#[derive(Debug, Deserialize)]
pub struct AudioConfig {
    pub backend: String,
    pub device: String,
    pub sample_rate: u32,
    pub channels: u16,
    pub navigation_interrupt: String,
}

#[derive(Debug, Deserialize)]
pub struct LoggingConfig {
    pub directory: PathBuf,
    pub level: String,
}

impl Config {
    pub fn load() -> Result<(Self, PathBuf)> {
        let path = env::var_os("CARNINE_CONFIG")
            .map(PathBuf::from)
            .or_else(|| {
                let system_path = Path::new("/etc/carnine/config.yaml");
                system_path.is_file().then(|| system_path.to_path_buf())
            })
            .unwrap_or_else(|| PathBuf::from("../../resources/config/carnine.yaml"));
        let content = fs::read_to_string(&path)
            .with_context(|| format!("failed to read configuration {}", path.display()))?;
        let mut config: Config = serde_yaml::from_str(&content)
            .with_context(|| format!("failed to parse configuration {}", path.display()))?;
        if let Some(log_directory) = env::var_os("CARNINE_LOG_DIRECTORY") {
            config.logging.directory = PathBuf::from(log_directory);
        }
        Ok((config, path))
    }
}

#[cfg(test)]
mod tests {
    use super::Config;

    #[test]
    fn loads_repository_configuration() {
        let (config, path) = Config::load().expect("repository config should load");
        assert!(path.ends_with("resources/config/carnine.yaml"));
        assert_eq!(config.server.address, "[::1]:50051");
        assert_eq!(config.audio.device, "plughw:1,0");
    }
}
