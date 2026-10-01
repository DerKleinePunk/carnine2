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
    /// Optional: without it the backend does not talk to a power supply.
    #[serde(default)]
    pub power_supply: PowerSupplyConfig,
    /// Optional: defaults of the reversing camera; what the settings page
    /// saves overrides them (CameraService).
    #[serde(default)]
    pub camera: CameraConfig,
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
    /// Where the volume survives a restart. Optional: configurations written
    /// before it existed keep the path that used to be fixed in the code.
    #[serde(default = "default_volume_state_path")]
    pub volume_state_path: PathBuf,
}

pub fn default_volume_state_path() -> PathBuf {
    PathBuf::from("/var/lib/carnine/audio-volume")
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
    /// From here on the CPU counts as overheated, and every UI shows a
    /// warning that has to be confirmed (#70). The Pi 4 throttles at 80 °C.
    #[serde(default = "default_cpu_temperature_warn_celsius")]
    pub cpu_temperature_warn_celsius: f64,
    /// Overheated ends only below this, so a reading around the warn
    /// threshold does not make the warning come and go.
    #[serde(default = "default_cpu_temperature_clear_celsius")]
    pub cpu_temperature_clear_celsius: f64,
    /// Cadence while the CPU is at or above the clear threshold.
    #[serde(default = "default_warm_metrics_interval_seconds")]
    pub warm_metrics_interval_seconds: u64,
}

fn default_metrics_interval_seconds() -> u64 {
    30
}

fn default_cpu_temperature_warn_celsius() -> f64 {
    75.0
}

fn default_cpu_temperature_clear_celsius() -> f64 {
    70.0
}

fn default_warm_metrics_interval_seconds() -> u64 {
    5
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
            cpu_temperature_warn_celsius: default_cpu_temperature_warn_celsius(),
            cpu_temperature_clear_celsius: default_cpu_temperature_clear_celsius(),
            warm_metrics_interval_seconds: default_warm_metrics_interval_seconds(),
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
    /// Line speed of `serial_device`. 4800 is the NMEA 0183 standard rate;
    /// USB CDC receivers (`ttyACM`) ignore it, USB serial adapters (`ttyUSB`)
    /// and UARTs need the receiver's rate.
    #[serde(default = "default_serial_baud")]
    pub serial_baud: u32,
    /// Set the system clock from the first valid GPS fix while NTP has not
    /// synchronized it (no RTC, no network in the car). Needs CAP_SYS_TIME.
    #[serde(default)]
    pub set_system_clock: bool,
    /// Where SetTrackRecording writes the receiver's raw NMEA, one file per
    /// drive. Unset means recording is not available.
    #[serde(default)]
    pub track_directory: Option<PathBuf>,
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
    /// FTS5 names index built next to the tiles (`<map>_names.db`). Unset
    /// means place search answers UNAVAILABLE.
    #[serde(default)]
    pub names_database: Option<PathBuf>,
}

/// Line speeds the serial devices (GPS receivers, the power supply) use.
pub const SERIAL_BAUD_RATES: [u32; 6] = [4800, 9600, 19200, 38400, 57600, 115200];

fn default_serial_baud() -> u32 {
    4800
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
            serial_baud: default_serial_baud(),
            set_system_clock: false,
            track_directory: None,
            replay_file: None,
            replay_loop: default_replay_loop(),
            valhalla_url: default_valhalla_url(),
            map_region: String::new(),
            names_database: None,
        }
    }
}

/// Video norm of the reversing camera's signal.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Deserialize, serde::Serialize)]
#[serde(rename_all = "lowercase")]
pub enum CameraNormSetting {
    #[default]
    Ntsc,
    Pal,
}

/// Highest grabber input the backend accepts; the STK1160 has 0-4.
pub const MAX_CAMERA_INPUT: u32 = 15;

/// Whether `device` may be a camera: a V4L2 node, by number or by the stable
/// /dev/v4l/ links udev makes.
pub fn is_camera_device(device: &str) -> bool {
    let numbered = device
        .strip_prefix("/dev/video")
        .is_some_and(|number| !number.is_empty() && number.bytes().all(|b| b.is_ascii_digit()));
    let linked = device
        .strip_prefix("/dev/v4l/")
        .is_some_and(|rest| !rest.is_empty() && !rest.split('/').any(|part| part == ".."));
    numbered || linked
}

/// Defaults of the reversing camera: the video grabber on the camera page.
#[derive(Debug, Clone, Deserialize, serde::Serialize)]
pub struct CameraConfig {
    #[serde(default = "default_camera_device")]
    pub device: String,
    #[serde(default)]
    pub norm: CameraNormSetting,
    #[serde(default)]
    pub input: u32,
}

fn default_camera_device() -> String {
    "/dev/video0".to_string()
}

impl Default for CameraConfig {
    fn default() -> Self {
        Self {
            device: default_camera_device(),
            norm: CameraNormSetting::default(),
            input: 0,
        }
    }
}

/// The car power supply AuPrV1_1 (docs/23-power-supply.md) on a serial line.
/// Its watchdog cuts the Pi off when the backend stops sending signs of life.
#[derive(Debug, Clone, Deserialize, serde::Serialize)]
pub struct PowerSupplyConfig {
    /// Off unless a supply is connected: on a device without one the backend
    /// would only retry opening the device.
    #[serde(default)]
    pub enabled: bool,
    /// The link the backend package's udev rule creates for uart5.
    #[serde(default = "default_power_supply_device")]
    pub device: PathBuf,
    /// The firmware's fixed line speed.
    #[serde(default = "default_power_supply_baud")]
    pub baud: u32,
}

fn default_power_supply_device() -> PathBuf {
    PathBuf::from("/dev/powersupply")
}

fn default_power_supply_baud() -> u32 {
    38400
}

impl Default for PowerSupplyConfig {
    fn default() -> Self {
        Self {
            enabled: false,
            device: default_power_supply_device(),
            baud: default_power_supply_baud(),
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
            || self.audio.volume_state_path.as_os_str().is_empty()
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
            || self.system.warm_metrics_interval_seconds == 0
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
        let (warn, clear) = (
            self.system.cpu_temperature_warn_celsius,
            self.system.cpu_temperature_clear_celsius,
        );
        if !(warn.is_finite() && clear.is_finite() && clear < warn) {
            anyhow::bail!(
                "system.cpu_temperature_clear_celsius ({clear}) must be below \
                 system.cpu_temperature_warn_celsius ({warn})"
            );
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
        if !SERIAL_BAUD_RATES.contains(&navigation.serial_baud) {
            anyhow::bail!(
                "navigation.serial_baud {} is not one of {:?}",
                navigation.serial_baud,
                SERIAL_BAUD_RATES
            );
        }
        let power_supply = &self.power_supply;
        if power_supply.enabled && power_supply.device.as_os_str().is_empty() {
            anyhow::bail!("power_supply.enabled needs power_supply.device");
        }
        if !SERIAL_BAUD_RATES.contains(&power_supply.baud) {
            anyhow::bail!(
                "power_supply.baud {} is not one of {:?}",
                power_supply.baud,
                SERIAL_BAUD_RATES
            );
        }
        if !is_camera_device(&self.camera.device) {
            anyhow::bail!(
                "camera.device must be /dev/video<n> or under /dev/v4l/: {}",
                self.camera.device
            );
        }
        if self.camera.input > MAX_CAMERA_INPUT {
            anyhow::bail!(
                "camera.input {} is above {MAX_CAMERA_INPUT}",
                self.camera.input
            );
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
        let mut table = read_table(&path)?;
        for drop_in in Self::drop_in_files(&path)? {
            merge_tables(&mut table, read_table(&drop_in)?);
        }
        let mut config: Config = toml::Value::Table(table)
            .try_into()
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

    /// Drop-ins for the configuration at `path`: the `*.toml` files in the
    /// directory beside it named after it, `/etc/carnine/config.d` for
    /// `/etc/carnine/config.toml`, in name order. [`Config::load`] lays each
    /// over the main file, so a later file wins. No package owns them and no
    /// deployment touches them, which is what keeps device-specific sections
    /// such as `[navigation]` alive across `deploy_pi.sh`. A missing directory
    /// means no drop-ins.
    pub fn drop_in_files(path: &Path) -> Result<Vec<PathBuf>> {
        let directory = path.with_extension("d");
        let entries = match fs::read_dir(&directory) {
            Ok(entries) => entries,
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(Vec::new()),
            Err(error) => {
                return Err(error).with_context(|| {
                    format!(
                        "failed to read configuration drop-ins {}",
                        directory.display()
                    )
                })
            }
        };
        let mut files = Vec::new();
        for entry in entries {
            let file = entry
                .with_context(|| {
                    format!(
                        "failed to read configuration drop-ins {}",
                        directory.display()
                    )
                })?
                .path();
            if file
                .extension()
                .is_some_and(|extension| extension == "toml")
                && file.is_file()
            {
                files.push(file);
            }
        }
        files.sort();
        Ok(files)
    }
}

fn read_table(path: &Path) -> Result<toml::Table> {
    let content = fs::read_to_string(path)
        .with_context(|| format!("failed to read configuration {}", path.display()))?;
    toml::from_str(&content)
        .with_context(|| format!("failed to parse configuration {}", path.display()))
}

/// Lays `overlay` over `base`: tables merge key by key, anything else
/// replaces what was there. A drop-in can so change one value of a section
/// without repeating the rest of it.
fn merge_tables(base: &mut toml::Table, overlay: toml::Table) {
    for (key, value) in overlay {
        match (base.get_mut(&key), value) {
            (Some(toml::Value::Table(existing)), toml::Value::Table(overlay)) => {
                merge_tables(existing, overlay)
            }
            (_, value) => {
                base.insert(key, value);
            }
        }
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
        assert_eq!(
            config.audio.volume_state_path,
            std::path::PathBuf::from("/var/lib/carnine/audio-volume")
        );
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
        assert_eq!(config.system.cpu_temperature_warn_celsius, 75.0);
        assert_eq!(config.system.cpu_temperature_clear_celsius, 70.0);
        assert_eq!(config.system.warm_metrics_interval_seconds, 5);
    }

    #[test]
    fn rejects_a_clear_threshold_at_or_above_the_warn_threshold() {
        let (mut config, _) =
            Config::load_with_env(|_| None).expect("repository config should load");
        assert!(config.validate().is_ok());

        config.system.cpu_temperature_clear_celsius = config.system.cpu_temperature_warn_celsius;
        assert!(config.validate().is_err());

        config.system.cpu_temperature_clear_celsius = f64::NAN;
        assert!(config.validate().is_err());

        let (mut config, _) =
            Config::load_with_env(|_| None).expect("repository config should load");
        config.system.warm_metrics_interval_seconds = 0;
        assert!(config.validate().is_err());
    }

    #[test]
    fn keeps_the_old_volume_state_path_when_the_key_is_missing() {
        let content = std::fs::read_to_string("../../resources/config/carnine.toml")
            .expect("repository config should be readable");
        let without_key: String = content
            .lines()
            .filter(|line| !line.starts_with("volume_state_path"))
            .map(|line| format!("{line}\n"))
            .collect();
        assert_ne!(without_key, content);
        let config: Config =
            toml::from_str(&without_key).expect("a config without the key must stay valid");
        assert_eq!(
            config.audio.volume_state_path,
            std::path::PathBuf::from("/var/lib/carnine/audio-volume")
        );
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
        config.audio.volume_state_path = std::path::PathBuf::new();
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
        config.navigation.serial_device = Some(std::path::PathBuf::from("/dev/gps"));
        assert!(config.validate().is_ok());

        assert_eq!(config.navigation.serial_baud, 4800);
        config.navigation.serial_baud = 9600;
        assert!(config.validate().is_ok());
        config.navigation.serial_baud = 4801;
        assert!(config.validate().is_err());
        config.navigation.serial_baud = 4800;

        config.navigation.valhalla_url = "https://example.org".to_string();
        assert!(config.validate().is_err());
    }

    #[test]
    fn power_supply_is_off_by_default_and_checks_its_line() {
        let (mut config, _) =
            Config::load_with_env(|_| None).expect("repository config should load");
        assert!(!config.power_supply.enabled);
        assert_eq!(
            config.power_supply.device,
            std::path::PathBuf::from("/dev/powersupply")
        );
        assert_eq!(config.power_supply.baud, 38400);

        config.power_supply.enabled = true;
        assert!(config.validate().is_ok());
        config.power_supply.baud = 38401;
        assert!(config.validate().is_err());
        config.power_supply.baud = 38400;
        config.power_supply.device = std::path::PathBuf::new();
        assert!(config.validate().is_err());
    }

    #[test]
    fn camera_defaults_to_ntsc_on_video0_and_checks_its_values() {
        let (mut config, _) =
            Config::load_with_env(|_| None).expect("repository config should load");
        assert_eq!(config.camera.device, "/dev/video0");
        assert_eq!(config.camera.norm, super::CameraNormSetting::Ntsc);
        assert_eq!(config.camera.input, 0);

        config.camera.device = "/dev/v4l/by-id/usb-grabber-video-index0".to_string();
        config.camera.input = super::MAX_CAMERA_INPUT;
        assert!(config.validate().is_ok());
        config.camera.input = super::MAX_CAMERA_INPUT + 1;
        assert!(config.validate().is_err());
        config.camera.input = 0;
        for device in [
            "/dev/sda",
            "/dev/video",
            "/dev/videoX",
            "/dev/v4l/",
            "/dev/v4l/../sda",
        ] {
            config.camera.device = device.to_string();
            assert!(config.validate().is_err(), "{device}");
        }
    }

    #[test]
    fn a_camera_drop_in_sets_the_norm() {
        let path = configuration_in("camera");
        write_drop_in(
            &path,
            "30-camera.toml",
            "[camera]\nnorm = \"pal\"\ninput = 4\n",
        );

        let config = load_from(&path).expect("config with a camera drop-in should load");
        assert_eq!(config.camera.norm, super::CameraNormSetting::Pal);
        assert_eq!(config.camera.input, 4);
        assert_eq!(config.camera.device, "/dev/video0", "default kept");

        write_drop_in(&path, "30-camera.toml", "[camera]\nnorm = \"secam\"\n");
        assert!(load_from(&path).is_err(), "unknown norm refused");
    }

    /// A copy of the repository configuration in its own directory, so a test
    /// can put drop-ins beside it.
    fn configuration_in(name: &str) -> std::path::PathBuf {
        let directory =
            std::env::temp_dir().join(format!("carnine-drop-in-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&directory);
        std::fs::create_dir_all(&directory).expect("test directory should be created");
        let path = directory.join("config.toml");
        std::fs::copy("../../resources/config/carnine.toml", &path)
            .expect("repository config should be copied");
        path
    }

    fn write_drop_in(path: &std::path::Path, name: &str, content: &str) {
        let directory = path.with_extension("d");
        std::fs::create_dir_all(&directory).expect("drop-in directory should be created");
        std::fs::write(directory.join(name), content).expect("drop-in should be written");
    }

    fn load_from(path: &std::path::Path) -> anyhow::Result<Config> {
        let path = path.as_os_str().to_owned();
        Config::load_with_env(|key| (key == "CARNINE_CONFIG").then(|| path.clone()))
            .map(|(config, _)| config)
    }

    #[test]
    fn a_drop_in_adds_a_section_and_changes_single_values() {
        let path = configuration_in("merge");
        write_drop_in(
            &path,
            "10-navigation.toml",
            "[navigation]\nposition_source = \"replay\"\nreplay_file = \"/var/lib/carnine/maps/tour.txt\"\nmap_region = \"hessen\"\n",
        );
        write_drop_in(&path, "20-logging.toml", "[logging]\nlevel = \"debug\"\n");

        let config = load_from(&path).expect("config with drop-ins should load");
        assert_eq!(
            config.navigation.position_source,
            super::PositionSourceSetting::Replay
        );
        assert_eq!(config.navigation.map_region, "hessen");
        assert_eq!(config.logging.level, "debug");
        // The rest of [logging] still comes from the main file.
        assert_eq!(
            config.logging.directory,
            std::path::PathBuf::from("/var/log/carnine")
        );
        let _ = std::fs::remove_dir_all(path.parent().expect("test directory"));
    }

    #[test]
    fn later_drop_ins_win_and_other_files_are_ignored() {
        let path = configuration_in("order");
        write_drop_in(&path, "20-late.toml", "[logging]\nlevel = \"warn\"\n");
        write_drop_in(&path, "10-early.toml", "[logging]\nlevel = \"debug\"\n");
        write_drop_in(
            &path,
            "30-left.toml.dpkg-old",
            "[logging]\nlevel = \"trace\"\n",
        );

        assert_eq!(
            Config::drop_in_files(&path)
                .expect("drop-ins should be listed")
                .iter()
                .map(|file| file.file_name().expect("file name").to_owned())
                .collect::<Vec<_>>(),
            vec!["10-early.toml", "20-late.toml"]
        );
        assert_eq!(
            load_from(&path).expect("config should load").logging.level,
            "warn"
        );
        let _ = std::fs::remove_dir_all(path.parent().expect("test directory"));
    }

    #[test]
    fn no_drop_in_directory_means_the_main_file_alone() {
        let path = configuration_in("none");
        assert!(Config::drop_in_files(&path)
            .expect("a missing directory is not an error")
            .is_empty());
        assert_eq!(
            load_from(&path).expect("config should load").logging.level,
            "info"
        );
        let _ = std::fs::remove_dir_all(path.parent().expect("test directory"));
    }

    #[test]
    fn a_broken_drop_in_names_itself_and_is_still_validated() {
        let path = configuration_in("broken");
        write_drop_in(&path, "10-broken.toml", "[navigation\n");
        let error = format!("{:#}", load_from(&path).expect_err("broken TOML must fail"));
        assert!(error.contains("10-broken.toml"), "{error}");
        let _ = std::fs::remove_dir_all(path.parent().expect("test directory"));

        let path = configuration_in("invalid");
        write_drop_in(
            &path,
            "10-navigation.toml",
            "[navigation]\nposition_source = \"replay\"\n",
        );
        let error = format!("{:#}", load_from(&path).expect_err("replay needs a file"));
        assert!(error.contains("replay_file"), "{error}");
        let _ = std::fs::remove_dir_all(path.parent().expect("test directory"));
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
