use std::env;
use std::ffi::OsString;
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
    /// Optional: without it navigation runs with no position source.
    #[serde(default)]
    pub navigation: NavigationConfig,
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

/// Where the backend's own position comes from (ADR-021).
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Deserialize, serde::Serialize)]
#[serde(rename_all = "lowercase")]
pub enum PositionSourceSetting {
    #[default]
    None,
    /// GPS mouse: NMEA read from `serial_device`.
    Serial,
    /// Recorded NMEA tour replayed from `replay_file` (trade fair, tests).
    Replay,
}

#[derive(Debug, Clone, Deserialize, serde::Serialize)]
pub struct NavigationConfig {
    #[serde(default)]
    pub position_source: PositionSourceSetting,
    #[serde(default)]
    pub serial_device: Option<PathBuf>,
    #[serde(default)]
    pub replay_file: Option<PathBuf>,
    /// Start the replay again when it reaches the end.
    #[serde(default = "default_replay_loop")]
    pub replay_loop: bool,
    /// Base URL of the Valhalla service the backend routes with.
    #[serde(default = "default_valhalla_url")]
    pub valhalla_url: String,
    /// Region of the installed map data, reported to the frontend as is.
    #[serde(default)]
    pub map_region: String,
}

fn default_replay_loop() -> bool {
    true
}

fn default_valhalla_url() -> String {
    "http://127.0.0.1:8002".to_string()
}

impl Default for NavigationConfig {
    fn default() -> Self {
        Self {
            position_source: PositionSourceSetting::default(),
            serial_device: None,
            replay_file: None,
            replay_loop: default_replay_loop(),
            valhalla_url: default_valhalla_url(),
            map_region: String::new(),
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
        let navigation = &self.navigation;
        let missing =
            |path: &Option<PathBuf>| path.as_ref().is_none_or(|p| p.as_os_str().is_empty());
        match navigation.position_source {
            PositionSourceSetting::Serial if missing(&navigation.serial_device) => {
                anyhow::bail!(
                    "navigation.position_source = \"serial\" needs navigation.serial_device"
                )
            }
            PositionSourceSetting::Replay if missing(&navigation.replay_file) => {
                anyhow::bail!(
                    "navigation.position_source = \"replay\" needs navigation.replay_file"
                )
            }
            _ => {}
        }
        if !navigation.valhalla_url.starts_with("http://") {
            anyhow::bail!(
                "navigation.valhalla_url must be a plain http:// URL on this machine: {}",
                navigation.valhalla_url
            );
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
        Self::load_with_env(|key| env::var_os(key))
    }

    /// The whole of [`Config::load`], with the environment injected instead of
    /// read from the process. Tests pass `|_| None` so that they see the file
    /// as it is on disk; a developer shell that exports `CARNINE_SOCKET_PATH`
    /// or `CARNINE_TCP_ADDRESS` would otherwise make them fail for no reason.
    fn load_with_env(lookup: impl Fn(&str) -> Option<OsString>) -> Result<(Self, PathBuf)> {
        let path = lookup("CARNINE_CONFIG")
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
        if let Some(log_directory) = lookup("CARNINE_LOG_DIRECTORY") {
            config.logging.directory = PathBuf::from(log_directory);
        }
        if let Some(database_path) = lookup("CARNINE_DATABASE_PATH") {
            config.media.database_path = PathBuf::from(database_path);
        }
        if let Some(socket_path) = lookup("CARNINE_SOCKET_PATH") {
            config.server.socket_path = PathBuf::from(socket_path);
        }
        if let Some(socket_mode) = lookup("CARNINE_SOCKET_MODE") {
            config.server.socket_mode = Some(socket_mode.into_string().map_err(|value| {
                anyhow::anyhow!("CARNINE_SOCKET_MODE is not valid UTF-8: {value:?}")
            })?);
        }
        if let Some(tcp_address) = lookup("CARNINE_TCP_ADDRESS") {
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
    use std::ffi::OsString;

    #[test]
    fn loads_repository_configuration() {
        let (config, path) =
            Config::load_with_env(|_| None).expect("repository config should load");
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
    fn environment_overrides_replace_the_file_values() {
        let (config, _) = Config::load_with_env(|key| match key {
            "CARNINE_SOCKET_PATH" => Some(OsString::from("/tmp/carnine-dev.sock")),
            "CARNINE_SOCKET_MODE" => Some(OsString::from("0660")),
            "CARNINE_TCP_ADDRESS" => Some(OsString::from("127.0.0.1:50051")),
            _ => None,
        })
        .expect("overridden config should load");
        assert_eq!(
            config.server.socket_path,
            std::path::PathBuf::from("/tmp/carnine-dev.sock")
        );
        assert_eq!(
            config
                .server
                .socket_permissions()
                .expect("overridden mode should parse"),
            0o660
        );
        assert_eq!(
            config.server.tcp_address.as_deref(),
            Some("127.0.0.1:50051")
        );
    }

    #[test]
    fn falls_back_to_root_and_media_folders_for_disk_metrics() {
        let (mut config, _) =
            Config::load_with_env(|_| None).expect("repository config should load");
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
        let (mut config, _) =
            Config::load_with_env(|_| None).expect("repository config should load");

        config.server.socket_path = std::path::PathBuf::new();
        assert!(config.validate().is_err());

        let (mut config, _) =
            Config::load_with_env(|_| None).expect("repository config should load");
        config.server.tcp_address = Some("not-an-address".to_string());
        assert!(config.validate().is_err());

        let (mut config, _) =
            Config::load_with_env(|_| None).expect("repository config should load");
        config.logging.level = "not a filter".to_string();
        assert!(config.validate().is_err());

        let (mut config, _) =
            Config::load_with_env(|_| None).expect("repository config should load");
        config.system.metrics_interval_seconds = 0;
        assert!(config.validate().is_err());

        let (mut config, _) =
            Config::load_with_env(|_| None).expect("repository config should load");
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

    #[test]
    fn navigation_defaults_to_no_source_and_checks_source_paths() {
        use super::PositionSourceSetting;

        let (mut config, _) =
            Config::load_with_env(|_| None).expect("repository config should load");
        assert_eq!(
            config.navigation.position_source,
            PositionSourceSetting::None
        );
        assert_eq!(config.navigation.valhalla_url, "http://127.0.0.1:8002");
        assert!(config.navigation.replay_loop);

        config.navigation.position_source = PositionSourceSetting::Replay;
        assert!(config.validate().is_err());
        config.navigation.replay_file =
            Some(std::path::PathBuf::from("/var/lib/carnine/tour.nmea"));
        assert!(config.validate().is_ok());

        config.navigation.position_source = PositionSourceSetting::Serial;
        assert!(config.validate().is_err());
        config.navigation.serial_device = Some(std::path::PathBuf::from("/dev/ttyACM0"));
        assert!(config.validate().is_ok());

        config.navigation.valhalla_url = "https://example.org".to_string();
        assert!(config.validate().is_err());
    }

    #[test]
    fn parses_the_navigation_section() {
        let config: Config = toml::from_str(&format!(
            "{}\n[navigation]\nposition_source = \"replay\"\nreplay_file = \"/tmp/tour.nmea\"\nreplay_loop = false\nmap_region = \"hessen\"\n",
            std::fs::read_to_string("../../resources/config/carnine.toml")
                .expect("repository config should be readable")
        ))
        .expect("a navigation section must parse");
        assert_eq!(
            config.navigation.position_source,
            super::PositionSourceSetting::Replay
        );
        assert!(!config.navigation.replay_loop);
        assert_eq!(config.navigation.map_region, "hessen");
    }
}
