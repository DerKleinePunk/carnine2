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
    /// Optional: configurations written before health sampling existed stay
    /// valid and get the defaults below.
    #[serde(default)]
    pub system: SystemConfig,
}

#[derive(Debug, Clone, Deserialize, serde::Serialize)]
pub struct ServerConfig {
    /// Primary gRPC transport (ADR-002): a Unix domain socket local to this
    /// machine. Frontend and backend run as the same user in production, so
    /// this needs no separate auth layer - only filesystem permissions.
    pub socket_path: PathBuf,
    /// Optional TCP loopback fallback, off by default. Only needed in
    /// development setups where client and server do not share a
    /// kernel/socket namespace, e.g. a Windows-hosted Flutter debug build
    /// talking to a backend running inside WSL2. Must stay unset in the
    /// versioned configuration and the generated image (docs/07-deployment.md).
    #[serde(default)]
    pub tcp_address: Option<String>,
    /// Permissions for the socket file, as an octal string such as `"0660"`.
    /// Unset means `0600`: only the `carnine` user itself, which is what
    /// production runs (docs/07-deployment.md §7.4). Widening this to `0660`
    /// lets every member of the `carnine` group connect - useful on a test
    /// device where a second login needs to reach the service, and a
    /// deliberate weakening everywhere else. Overridable through
    /// `CARNINE_SOCKET_MODE`, which is how the test Pi sets it: a systemd
    /// drop-in survives a deployment, this file does not.
    #[serde(default)]
    pub socket_mode: Option<String>,
}

/// Permissions the socket gets when `socket_mode` says nothing.
pub const DEFAULT_SOCKET_MODE: u32 = 0o600;

impl ServerConfig {
    /// Parsed `socket_mode`, or the default when unset.
    pub fn socket_permissions(&self) -> Result<u32> {
        let Some(mode) = &self.socket_mode else {
            return Ok(DEFAULT_SOCKET_MODE);
        };
        let parsed = u32::from_str_radix(mode.trim(), 8)
            .with_context(|| format!("server.socket_mode {mode} is not an octal file mode"))?;
        if parsed > 0o777 {
            anyhow::bail!("server.socket_mode {mode} sets bits outside the permission bits");
        }
        if parsed & 0o007 != 0 {
            anyhow::bail!("server.socket_mode {mode} would expose the socket to every account");
        }
        Ok(parsed)
    }
}

#[derive(Debug, Clone, Deserialize, serde::Serialize)]
pub struct MediaConfig {
    pub database_path: PathBuf,
    pub folders: Vec<PathBuf>,
    pub supported_formats: Vec<String>,
    pub rescan_on_start: bool,
    pub resume_mode: String,
    pub cover_cache_dir: PathBuf,
}

#[derive(Debug, Clone, Deserialize, serde::Serialize)]
pub struct AudioConfig {
    pub navigation_interrupt: String,
}

#[derive(Debug, Clone, Deserialize, serde::Serialize)]
pub struct SystemConfig {
    /// Cadence for CPU temperature and load.
    #[serde(default = "default_metrics_interval_seconds")]
    pub metrics_interval_seconds: u64,
    /// Cadence for disk usage. Each sample costs a `statvfs` per filesystem and
    /// the value barely moves, so this is deliberately much slower.
    #[serde(default = "default_disk_metrics_interval_seconds")]
    pub disk_metrics_interval_seconds: u64,
    /// Filesystems to report. Empty means the default: the root filesystem
    /// plus every `media.folders` entry, deduplicated per filesystem.
    #[serde(default)]
    pub disk_paths: Vec<PathBuf>,
}

fn default_metrics_interval_seconds() -> u64 {
    30
}

fn default_disk_metrics_interval_seconds() -> u64 {
    300
}

impl Default for SystemConfig {
    fn default() -> Self {
        Self {
            metrics_interval_seconds: default_metrics_interval_seconds(),
            disk_metrics_interval_seconds: default_disk_metrics_interval_seconds(),
            disk_paths: Vec::new(),
        }
    }
}

#[derive(Debug, Clone, Deserialize, serde::Serialize)]
pub struct LoggingConfig {
    pub directory: PathBuf,
    pub level: String,
}

impl Config {
    pub fn validate(&self) -> Result<()> {
        if self.server.socket_path.as_os_str().is_empty() {
            anyhow::bail!("server.socket_path must not be empty");
        }
        if let Some(tcp_address) = &self.server.tcp_address {
            tcp_address
                .parse::<std::net::SocketAddr>()
                .with_context(|| format!("invalid server tcp_address {tcp_address}"))?;
        }
        if self.media.database_path.as_os_str().is_empty()
            || self
                .media
                .folders
                .iter()
                .any(|path| path.as_os_str().is_empty())
            || self.media.cover_cache_dir.as_os_str().is_empty()
            || self.logging.directory.as_os_str().is_empty()
        {
            anyhow::bail!("configuration contains an empty path");
        }
        if !matches!(
            self.logging.level.trim().to_ascii_lowercase().as_str(),
            "trace" | "debug" | "info" | "warn" | "error"
        ) {
            anyhow::bail!("invalid log level: {}", self.logging.level);
        }
        self.server.socket_permissions()?;
        if self.system.metrics_interval_seconds == 0
            || self.system.disk_metrics_interval_seconds == 0
        {
            anyhow::bail!("system metric intervals must be greater than zero");
        }
        if self
            .system
            .disk_paths
            .iter()
            .any(|path| path.as_os_str().is_empty())
        {
            anyhow::bail!("system.disk_paths contains an empty path");
        }
        Ok(())
    }

    /// Filesystems the disk sampler probes: what `system.disk_paths` says, or
    /// the root filesystem plus the media folders when it says nothing.
    pub fn disk_metric_paths(&self) -> Vec<PathBuf> {
        if !self.system.disk_paths.is_empty() {
            return self.system.disk_paths.clone();
        }
        let mut paths = vec![PathBuf::from("/")];
        paths.extend(self.media.folders.iter().cloned());
        paths
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
        if let Some(socket_path) = env::var_os("CARNINE_SOCKET_PATH") {
            config.server.socket_path = PathBuf::from(socket_path);
        }
        if let Some(socket_mode) = env::var_os("CARNINE_SOCKET_MODE") {
            config.server.socket_mode = Some(socket_mode.into_string().map_err(|value| {
                anyhow::anyhow!("CARNINE_SOCKET_MODE is not valid UTF-8: {value:?}")
            })?);
        }
        if let Some(tcp_address) = env::var_os("CARNINE_TCP_ADDRESS") {
            config.server.tcp_address = Some(tcp_address.into_string().map_err(|value| {
                anyhow::anyhow!("CARNINE_TCP_ADDRESS is not valid UTF-8: {value:?}")
            })?);
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
        assert_eq!(
            config.server.socket_path,
            std::path::PathBuf::from("/run/carnine/carnine.sock")
        );
        assert_eq!(config.server.tcp_address, None);
        assert_eq!(config.server.socket_mode, None);
        assert_eq!(
            config
                .server
                .socket_permissions()
                .expect("default mode should parse"),
            0o600
        );
        assert_eq!(config.audio.navigation_interrupt, "pause_music");
        assert_eq!(config.system.metrics_interval_seconds, 30);
        assert_eq!(config.system.disk_metrics_interval_seconds, 300);
    }

    #[test]
    fn falls_back_to_root_and_media_folders_for_disk_metrics() {
        let (mut config, _) = Config::load().expect("repository config should load");
        config.system.disk_paths.clear();
        let paths = config.disk_metric_paths();
        assert_eq!(paths.first(), Some(&std::path::PathBuf::from("/")));
        assert_eq!(paths.len(), 1 + config.media.folders.len());

        config.system.disk_paths = vec![std::path::PathBuf::from("/srv")];
        assert_eq!(
            config.disk_metric_paths(),
            vec![std::path::PathBuf::from("/srv")]
        );
    }

    #[test]
    fn accepts_a_configuration_without_a_system_section() {
        let config: Config = toml::from_str(
            &std::fs::read_to_string("../../resources/config/carnine.toml")
                .expect("repository config should be readable")
                .replace("[system]", "[unused_section]"),
        )
        .expect("a config without [system] must stay valid");
        assert_eq!(config.system.metrics_interval_seconds, 30);
    }

    #[test]
    fn rejects_invalid_runtime_values() {
        let (mut config, _) = Config::load().expect("repository config should load");

        config.server.socket_path = std::path::PathBuf::new();
        assert!(config.validate().is_err());

        let (mut config, _) = Config::load().expect("repository config should load");
        config.server.tcp_address = Some("not-an-address".to_string());
        assert!(config.validate().is_err());

        let (mut config, _) = Config::load().expect("repository config should load");
        config.logging.level = "not a filter".to_string();
        assert!(config.validate().is_err());

        let (mut config, _) = Config::load().expect("repository config should load");
        config.system.metrics_interval_seconds = 0;
        assert!(config.validate().is_err());

        let (mut config, _) = Config::load().expect("repository config should load");
        config.server.socket_mode = Some("not-a-mode".to_string());
        assert!(config.validate().is_err());

        // World access would defeat the point of a filesystem-guarded socket.
        config.server.socket_mode = Some("0666".to_string());
        assert!(config.validate().is_err());

        config.server.socket_mode = Some("0660".to_string());
        assert!(config.validate().is_ok());
        assert_eq!(
            config
                .server
                .socket_permissions()
                .expect("0660 should parse"),
            0o660
        );
    }
}
