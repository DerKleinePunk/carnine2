//! Periodic health sampling for the Raspberry Pi the head unit runs on.
//!
//! CPU temperature and load are cheap to read and are sampled on a short
//! cadence; disk usage needs a `statvfs` per filesystem and changes slowly, so
//! it runs on its own, much slower cadence. Both live in the same snapshot:
//! readers always get the latest CPU values together with the most recent disk
//! values, each with its own timestamp.
//!
//! Nothing here blocks the gRPC handlers - the sampler writes into a shared
//! snapshot, and `GetSystemMetrics` only reads that cache.

use std::collections::HashSet;
use std::fs;
use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use anyhow::{Context, Result};
use tokio::sync::broadcast;
use tracing::{debug, info, warn};

use crate::carnine::{DiskUsage, SystemMetrics};

/// Capacity of the broadcast channel behind `StreamSystemMetrics`. A client
/// that falls this far behind loses samples rather than stalling the sampler.
const EVENT_CHANNEL_CAPACITY: usize = 16;
/// Logged as a warning once the CPU crosses this; the bcm2711 starts throttling
/// at 80 °C.
const TEMPERATURE_WARN_CELSIUS: f64 = 75.0;
/// Logged as a warning once a monitored filesystem crosses this.
const DISK_USAGE_WARN_PERCENT: f64 = 90.0;

/// Shared, always-readable snapshot plus the fan-out for streaming clients.
#[derive(Debug)]
pub struct SystemMetricsHandle {
    latest: Mutex<SystemMetrics>,
    events: broadcast::Sender<SystemMetrics>,
}

impl Default for SystemMetricsHandle {
    fn default() -> Self {
        Self {
            latest: Mutex::new(SystemMetrics::default()),
            events: broadcast::channel(EVENT_CHANNEL_CAPACITY).0,
        }
    }
}

impl SystemMetricsHandle {
    pub fn new() -> Self {
        Self::default()
    }

    /// Last sampled snapshot. Before the first sample this is the zeroed
    /// default, which callers can recognise by `sampled_at_unix_ms == 0`.
    pub fn latest(&self) -> SystemMetrics {
        self.latest
            .lock()
            .expect("system metrics snapshot mutex poisoned")
            .clone()
    }

    pub fn subscribe(&self) -> broadcast::Receiver<SystemMetrics> {
        self.events.subscribe()
    }

    /// Lets the gRPC-level tests in `main` drive a handle without running the
    /// sampler task; the production path publishes only from `run`.
    #[cfg(test)]
    pub(crate) fn publish_for_test(&self, metrics: SystemMetrics) {
        self.publish(metrics);
    }

    fn publish(&self, metrics: SystemMetrics) {
        *self
            .latest
            .lock()
            .expect("system metrics snapshot mutex poisoned") = metrics.clone();
        // No receivers is the normal case while no client streams metrics.
        let _ = self.events.send(metrics);
    }
}

/// How often the two groups of values are sampled, and which filesystems the
/// disk group covers.
#[derive(Debug, Clone)]
pub struct SamplerSettings {
    pub cpu_interval: Duration,
    pub disk_interval: Duration,
    pub disk_paths: Vec<PathBuf>,
}

pub fn spawn(handle: Arc<SystemMetricsHandle>, settings: SamplerSettings) {
    tokio::spawn(async move { run(handle, settings).await });
}

async fn run(handle: Arc<SystemMetricsHandle>, settings: SamplerSettings) {
    info!(
        cpu_interval_seconds = settings.cpu_interval.as_secs(),
        disk_interval_seconds = settings.disk_interval.as_secs(),
        disk_paths = ?settings.disk_paths,
        "system metrics sampler started"
    );

    let mut sampler = Sampler::new(settings.disk_paths.clone());
    // One timer drives everything, and the disk group is folded into the tick
    // it is due on. Two independent timers would let a disk tick publish a
    // snapshot whose CPU values are stale - or, on the very first tick, absent
    // entirely. The cost is that the disk cadence is rounded up to the next CPU
    // tick, which is exact for the defaults (300 is a multiple of 30).
    let mut ticks = tokio::time::interval(settings.cpu_interval);
    ticks.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
    // `None` means "never sampled", which is always due. Seeding this with a
    // timestamp instead would make the first tick depend on whether the
    // interval's deadline lands before or after that timestamp - it lands
    // before, by the microseconds it takes to construct the interval, so disks
    // would be skipped on the very first tick.
    let mut disks_due_at: Option<tokio::time::Instant> = None;

    loop {
        let now = ticks.tick().await;
        sampler.sample_cpu();

        let disks_due = disks_due_at.is_none_or(|due| now >= due);
        if disks_due {
            sampler.sample_disks();
            disks_due_at = Some(now + settings.disk_interval);
        }

        let metrics = sampler.snapshot();
        debug!(
            temperature_celsius = metrics.cpu_temperature_celsius,
            usage_percent = metrics.cpu_usage_percent,
            load_average_1m = metrics.load_average_1m,
            "sampled cpu metrics"
        );
        if let Some(temperature) = metrics.cpu_temperature_celsius {
            if temperature >= TEMPERATURE_WARN_CELSIUS {
                warn!(temperature_celsius = temperature, "cpu temperature high");
            }
        }
        if disks_due {
            for disk in &metrics.disks {
                if disk.used_percent >= DISK_USAGE_WARN_PERCENT {
                    warn!(
                        path = %disk.path,
                        mount_point = %disk.mount_point,
                        used_percent = disk.used_percent,
                        available_bytes = disk.available_bytes,
                        "filesystem nearly full"
                    );
                }
            }
            // The readable heartbeat in the log: once per disk cadence, not
            // once per CPU sample, so the log stays usable.
            info!(
                temperature_celsius = metrics.cpu_temperature_celsius,
                usage_percent = metrics.cpu_usage_percent,
                load_average_1m = metrics.load_average_1m,
                disks = metrics.disks.len(),
                "system health"
            );
        }
        handle.publish(metrics);
    }
}

/// Keeps the state the derived values need: the previous `/proc/stat` counters
/// for CPU utilisation, and the last disk reading so every CPU snapshot can
/// repeat it.
#[derive(Debug)]
struct Sampler {
    disk_paths: Vec<PathBuf>,
    previous_cpu_times: Option<CpuTimes>,
    metrics: SystemMetrics,
}

impl Sampler {
    fn new(disk_paths: Vec<PathBuf>) -> Self {
        Self {
            disk_paths,
            previous_cpu_times: None,
            metrics: SystemMetrics::default(),
        }
    }

    fn snapshot(&self) -> SystemMetrics {
        self.metrics.clone()
    }

    fn sample_cpu(&mut self) -> SystemMetrics {
        self.metrics.cpu_temperature_celsius = match read_cpu_temperature_celsius() {
            Ok(temperature) => Some(temperature),
            Err(error) => {
                debug!(%error, "cpu temperature unavailable");
                None
            }
        };

        match read_cpu_times() {
            Ok(times) => {
                self.metrics.cpu_usage_percent = self
                    .previous_cpu_times
                    .as_ref()
                    .and_then(|previous| times.usage_percent_since(previous));
                self.previous_cpu_times = Some(times);
            }
            Err(error) => {
                warn!(%error, "failed to read /proc/stat");
                self.metrics.cpu_usage_percent = None;
            }
        }

        match read_load_average() {
            Ok([one, five, fifteen]) => {
                self.metrics.load_average_1m = one;
                self.metrics.load_average_5m = five;
                self.metrics.load_average_15m = fifteen;
            }
            Err(error) => warn!(%error, "failed to read /proc/loadavg"),
        }

        self.metrics.cpu_count = std::thread::available_parallelism()
            .map(|count| count.get() as u32)
            .unwrap_or(0);
        self.metrics.uptime_seconds = read_uptime_seconds().unwrap_or(0);
        self.metrics.sampled_at_unix_ms = now_unix_ms();
        self.snapshot()
    }

    fn sample_disks(&mut self) {
        self.metrics.disks = collect_disk_usage(&self.disk_paths);
        self.metrics.disks_sampled_at_unix_ms = now_unix_ms();
    }
}

/// Aggregate jiffy counters from the `cpu` line of `/proc/stat`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct CpuTimes {
    total: u64,
    idle: u64,
}

impl CpuTimes {
    /// Share of non-idle time between two readings, 0..100. `None` when the
    /// counters did not advance, which happens if two samples land in the same
    /// jiffy or if the counters were reset.
    fn usage_percent_since(&self, previous: &Self) -> Option<f64> {
        let total_delta = self.total.checked_sub(previous.total)?;
        let idle_delta = self.idle.checked_sub(previous.idle)?;
        if total_delta == 0 || idle_delta > total_delta {
            return None;
        }
        let busy_delta = total_delta - idle_delta;
        Some(busy_delta as f64 * 100.0 / total_delta as f64)
    }
}

fn read_cpu_times() -> Result<CpuTimes> {
    parse_cpu_times(&fs::read_to_string("/proc/stat").context("failed to read /proc/stat")?)
}

fn parse_cpu_times(content: &str) -> Result<CpuTimes> {
    let line = content
        .lines()
        .find(|line| line.starts_with("cpu "))
        .context("/proc/stat has no aggregate cpu line")?;
    let fields: Vec<u64> = line
        .split_whitespace()
        .skip(1)
        // guest and guest_nice are already counted in user and nice, so taking
        // the first eight fields avoids counting them twice.
        .take(8)
        .map(|field| {
            field
                .parse::<u64>()
                .with_context(|| format!("unexpected /proc/stat field {field}"))
        })
        .collect::<Result<_>>()?;
    if fields.len() < 5 {
        anyhow::bail!("/proc/stat cpu line is too short: {line}");
    }
    // idle + iowait: both are time the CPU had nothing to run.
    let idle = fields[3] + fields[4];
    Ok(CpuTimes {
        total: fields.iter().sum(),
        idle,
    })
}

fn read_cpu_temperature_celsius() -> Result<f64> {
    let zone = cpu_thermal_zone().context("no cpu thermal zone found")?;
    let raw = fs::read_to_string(zone.join("temp"))
        .with_context(|| format!("failed to read {}", zone.join("temp").display()))?;
    parse_thermal_zone_temperature(&raw)
}

/// Prefers the zone whose `type` names the CPU (`cpu-thermal` on the Pi) and
/// falls back to the first zone on boards that label theirs differently.
fn cpu_thermal_zone() -> Option<PathBuf> {
    let mut zones: Vec<PathBuf> = fs::read_dir("/sys/class/thermal")
        .ok()?
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
        .filter(|path| {
            path.file_name()
                .and_then(|name| name.to_str())
                .is_some_and(|name| name.starts_with("thermal_zone"))
        })
        .collect();
    zones.sort();
    let labelled = zones.iter().find(|zone| {
        fs::read_to_string(zone.join("type"))
            .map(|zone_type| zone_type.trim().contains("cpu"))
            .unwrap_or(false)
    });
    labelled.cloned().or_else(|| zones.into_iter().next())
}

/// The thermal sysfs reports millidegrees Celsius.
fn parse_thermal_zone_temperature(raw: &str) -> Result<f64> {
    let millidegrees: i64 = raw
        .trim()
        .parse()
        .with_context(|| format!("unexpected thermal zone reading {:?}", raw.trim()))?;
    Ok(millidegrees as f64 / 1000.0)
}

fn read_load_average() -> Result<[f64; 3]> {
    parse_load_average(
        &fs::read_to_string("/proc/loadavg").context("failed to read /proc/loadavg")?,
    )
}

fn parse_load_average(content: &str) -> Result<[f64; 3]> {
    let mut fields = content.split_whitespace();
    let mut averages = [0.0_f64; 3];
    for (index, average) in averages.iter_mut().enumerate() {
        let field = fields
            .next()
            .with_context(|| format!("/proc/loadavg is missing field {index}"))?;
        *average = field
            .parse()
            .with_context(|| format!("unexpected /proc/loadavg field {field}"))?;
    }
    Ok(averages)
}

fn read_uptime_seconds() -> Result<u64> {
    let content = fs::read_to_string("/proc/uptime").context("failed to read /proc/uptime")?;
    let field = content
        .split_whitespace()
        .next()
        .context("/proc/uptime is empty")?;
    let seconds: f64 = field
        .parse()
        .with_context(|| format!("unexpected /proc/uptime field {field}"))?;
    Ok(seconds as u64)
}

fn now_unix_ms() -> i64 {
    chrono::Utc::now().timestamp_millis()
}

/// One `statvfs` per distinct filesystem. Paths that resolve to the same device
/// - on the Pi `/` and `/var/lib/carnine/media` usually do - are reported once,
/// under the first configured path that reached it.
fn collect_disk_usage(paths: &[PathBuf]) -> Vec<DiskUsage> {
    let mount_points = read_mount_points();
    let mut seen_devices: HashSet<u64> = HashSet::new();
    let mut usage = Vec::new();

    for path in paths {
        let metadata = match fs::metadata(path) {
            Ok(metadata) => metadata,
            Err(error) => {
                // A media folder on a removable volume is simply not there
                // while the stick is unplugged; that is not an error.
                debug!(path = %path.display(), %error, "skipping disk metrics for missing path");
                continue;
            }
        };
        if !seen_devices.insert(metadata.dev()) {
            continue;
        }
        match disk_usage_for(path, &mount_points) {
            Ok(entry) => usage.push(entry),
            Err(error) => {
                warn!(path = %path.display(), %error, "failed to read filesystem usage")
            }
        }
    }

    usage
}

fn disk_usage_for(path: &Path, mount_points: &[PathBuf]) -> Result<DiskUsage> {
    let (total_bytes, available_bytes) = statvfs_bytes(path)?;
    let used_percent = if total_bytes == 0 {
        0.0
    } else {
        (total_bytes - available_bytes) as f64 * 100.0 / total_bytes as f64
    };
    Ok(DiskUsage {
        path: path.display().to_string(),
        mount_point: mount_point_for(path, mount_points).unwrap_or_default(),
        total_bytes,
        available_bytes,
        used_percent,
    })
}

/// Returns (total, available) in bytes. `f_bavail` rather than `f_bfree`: the
/// blocks reserved for root are not space the media library can use.
fn statvfs_bytes(path: &Path) -> Result<(u64, u64)> {
    use std::ffi::CString;
    use std::os::unix::ffi::OsStrExt;

    let c_path = CString::new(path.as_os_str().as_bytes())
        .with_context(|| format!("path {} contains a NUL byte", path.display()))?;
    let mut stat = std::mem::MaybeUninit::<libc::statvfs>::uninit();
    // SAFETY: c_path is a valid NUL-terminated string that outlives the call,
    // and stat points at writable, correctly sized and aligned storage.
    let result = unsafe { libc::statvfs(c_path.as_ptr(), stat.as_mut_ptr()) };
    if result != 0 {
        return Err(std::io::Error::last_os_error())
            .with_context(|| format!("statvfs failed for {}", path.display()));
    }
    // SAFETY: statvfs returned 0, so it initialised the struct.
    let stat = unsafe { stat.assume_init() };
    let block_size = stat.f_frsize as u64;
    Ok((
        stat.f_blocks as u64 * block_size,
        stat.f_bavail as u64 * block_size,
    ))
}

fn read_mount_points() -> Vec<PathBuf> {
    match fs::read_to_string("/proc/mounts") {
        Ok(content) => parse_mount_points(&content),
        Err(error) => {
            debug!(%error, "failed to read /proc/mounts; disk metrics carry no mount point");
            Vec::new()
        }
    }
}

fn parse_mount_points(content: &str) -> Vec<PathBuf> {
    content
        .lines()
        .filter_map(|line| line.split_whitespace().nth(1))
        // /proc/mounts escapes spaces and a few other characters as octal.
        .map(|mount_point| PathBuf::from(mount_point.replace("\\040", " ")))
        .collect()
}

/// Longest mount point that is a prefix of `path`, i.e. the filesystem the path
/// actually lives on.
fn mount_point_for(path: &Path, mount_points: &[PathBuf]) -> Option<String> {
    let path = fs::canonicalize(path).unwrap_or_else(|_| path.to_path_buf());
    mount_points
        .iter()
        .filter(|mount_point| path.starts_with(mount_point))
        .max_by_key(|mount_point| mount_point.as_os_str().len())
        .map(|mount_point| mount_point.display().to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_aggregate_cpu_line() {
        let times = parse_cpu_times("cpu  100 2 30 400 5 0 1 0 0 0\ncpu0 1 0 1 1 0 0 0 0 0 0\n")
            .expect("cpu line should parse");
        assert_eq!(times.total, 100 + 2 + 30 + 400 + 5 + 0 + 1 + 0);
        assert_eq!(times.idle, 405);
    }

    #[test]
    fn computes_cpu_usage_between_samples() {
        let previous = CpuTimes {
            total: 1000,
            idle: 800,
        };
        let current = CpuTimes {
            total: 1100,
            idle: 850,
        };
        let usage = current
            .usage_percent_since(&previous)
            .expect("usage should be computable");
        assert!((usage - 50.0).abs() < f64::EPSILON, "unexpected {usage}");
    }

    #[test]
    fn rejects_cpu_samples_that_did_not_advance() {
        let times = CpuTimes {
            total: 1000,
            idle: 800,
        };
        assert_eq!(times.usage_percent_since(&times), None);
        // Counters reset, e.g. after a container restart.
        let smaller = CpuTimes { total: 10, idle: 5 };
        assert_eq!(smaller.usage_percent_since(&times), None);
    }

    #[test]
    fn parses_thermal_zone_millidegrees() {
        let celsius = parse_thermal_zone_temperature("39433\n").expect("temperature should parse");
        assert!((celsius - 39.433).abs() < 1e-9, "unexpected {celsius}");
    }

    #[test]
    fn parses_load_average() {
        let averages =
            parse_load_average("1.25 0.85 0.41 3/187 1101\n").expect("load average should parse");
        assert_eq!(averages, [1.25, 0.85, 0.41]);
    }

    #[test]
    fn picks_the_longest_matching_mount_point() {
        let mount_points = vec![
            PathBuf::from("/"),
            PathBuf::from("/var"),
            PathBuf::from("/boot/firmware"),
        ];
        assert_eq!(
            mount_point_for(Path::new("/var/lib/carnine"), &mount_points),
            Some("/var".to_string())
        );
        assert_eq!(
            mount_point_for(Path::new("/srv"), &mount_points),
            Some("/".to_string())
        );
    }

    #[test]
    fn unescapes_spaces_in_mount_points() {
        let mounts = parse_mount_points(
            "/dev/sda1 /media/My\\040Music vfat rw 0 0\nproc /proc proc rw 0 0\n",
        );
        assert_eq!(
            mounts,
            vec![PathBuf::from("/media/My Music"), PathBuf::from("/proc")]
        );
    }

    #[test]
    fn reports_each_filesystem_once() {
        // The temporary directory and its child always share a device, so the
        // second path must be folded into the first.
        let directory = std::env::temp_dir();
        let usage = collect_disk_usage(&[directory.clone(), directory.join(".")]);
        assert_eq!(usage.len(), 1, "expected one filesystem, got {usage:?}");
        assert!(usage[0].total_bytes > 0);
        assert!(usage[0].used_percent >= 0.0 && usage[0].used_percent <= 100.0);
    }

    #[test]
    fn skips_paths_that_do_not_exist() {
        let usage = collect_disk_usage(&[PathBuf::from("/definitely/not/mounted/here")]);
        assert!(usage.is_empty(), "unexpected {usage:?}");
    }

    #[test]
    fn samples_the_running_system() {
        let mut sampler = Sampler::new(vec![std::env::temp_dir()]);
        let first = sampler.sample_cpu();
        // The very first sample has no predecessor to diff against.
        assert_eq!(first.cpu_usage_percent, None);
        assert!(first.sampled_at_unix_ms > 0);
        assert!(first.cpu_count > 0);
        assert!(first.disks.is_empty());

        sampler.sample_disks();
        let second = sampler.snapshot();
        assert_eq!(second.disks.len(), 1);
        assert!(second.disks_sampled_at_unix_ms > 0);
    }

    /// Regression: the first published snapshot must already carry both
    /// groups. Two failures hid here - a separate timer per group let the disk
    /// tick publish before any CPU sample existed, and seeding the disk
    /// deadline from `Instant::now()` made the first tick skip disks because
    /// the interval's deadline predates it by a few microseconds. The second
    /// one only shows under the real clock, so this test deliberately does not
    /// pause time; the short interval keeps it to a few milliseconds.
    #[tokio::test]
    async fn first_snapshot_carries_both_groups() {
        let handle = Arc::new(SystemMetricsHandle::new());
        let mut updates = handle.subscribe();
        spawn(
            Arc::clone(&handle),
            SamplerSettings {
                cpu_interval: Duration::from_millis(50),
                disk_interval: Duration::from_secs(300),
                disk_paths: vec![std::env::temp_dir()],
            },
        );

        let first = updates
            .recv()
            .await
            .expect("the sampler should publish immediately");
        assert!(first.sampled_at_unix_ms > 0, "cpu values are missing");
        assert!(first.cpu_count > 0);
        assert_eq!(
            first.disks.len(),
            1,
            "the first snapshot must already carry disk usage"
        );

        // A CPU tick that is not a disk tick keeps repeating the disk values
        // rather than dropping them.
        let second = updates
            .recv()
            .await
            .expect("the sampler should publish on the next tick");
        assert_eq!(second.disks.len(), 1);
        assert_eq!(
            second.disks_sampled_at_unix_ms,
            first.disks_sampled_at_unix_ms
        );
    }

    #[test]
    fn handle_publishes_to_subscribers() {
        let handle = SystemMetricsHandle::new();
        let mut receiver = handle.subscribe();
        assert_eq!(handle.latest().sampled_at_unix_ms, 0);

        handle.publish(SystemMetrics {
            sampled_at_unix_ms: 42,
            ..SystemMetrics::default()
        });

        assert_eq!(handle.latest().sampled_at_unix_ms, 42);
        assert_eq!(
            receiver
                .try_recv()
                .expect("subscriber should receive the sample")
                .sampled_at_unix_ms,
            42
        );
    }
}
