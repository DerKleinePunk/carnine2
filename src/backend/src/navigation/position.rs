//! The backend's own position: one hub holding the latest state, fed either by
//! a GPS mouse (NMEA over a serial device) or by replaying a recorded tour.

use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use anyhow::{Context, Result};
use chrono::{NaiveDateTime, NaiveTime};
use tokio::sync::watch;
use tracing::{error, info, warn};

use super::nmea::{self, Rmc, Sentence};

/// Pause between two replayed fixes when the recording gives no usable time.
const DEFAULT_REPLAY_INTERVAL: Duration = Duration::from_secs(1);
/// Gaps in a recording longer than this are shortened, so a receiver that
/// dropped out for minutes does not stall the demo.
const MAX_REPLAY_INTERVAL: Duration = Duration::from_secs(5);
/// Wait before reopening a serial device that vanished or failed.
const SERIAL_RETRY_INTERVAL: Duration = Duration::from_secs(3);

/// Where fixes come from.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SourceKind {
    None,
    Serial,
    Replay,
}

/// One position report.
#[derive(Debug, Clone, PartialEq)]
pub struct Fix {
    /// `false` while the receiver has no valid position; the coordinates are
    /// then the last ones it reported and must not be shown.
    pub valid: bool,
    pub latitude: f64,
    pub longitude: f64,
    pub heading_degrees: Option<f64>,
    pub speed_mps: Option<f64>,
    pub accuracy_meters: Option<f64>,
    pub timestamp_utc_ms: Option<i64>,
}

/// What the hub currently knows.
#[derive(Debug, Clone, PartialEq)]
pub struct PositionState {
    pub source: SourceKind,
    /// `None` until the source delivered its first sentence.
    pub fix: Option<Fix>,
}

/// Latest position, shared with every stream. A `watch` channel fits: a slow
/// client only ever needs the newest fix, never a backlog.
#[derive(Debug, Clone)]
pub struct PositionHub {
    sender: watch::Sender<PositionState>,
}

impl PositionHub {
    pub fn new(source: SourceKind) -> Self {
        let (sender, _) = watch::channel(PositionState { source, fix: None });
        Self { sender }
    }

    pub fn current(&self) -> PositionState {
        self.sender.borrow().clone()
    }

    pub fn subscribe(&self) -> watch::Receiver<PositionState> {
        self.sender.subscribe()
    }

    pub fn publish(&self, fix: Fix) {
        self.sender.send_modify(|state| state.fix = Some(fix));
    }
}

/// One replayed fix and how long to wait before it.
#[derive(Debug, Clone, PartialEq)]
pub struct ReplayStep {
    pub delay: Duration,
    pub fix: Fix,
}

/// Turns a recorded NMEA log into replay steps, one per `RMC` sentence, paced
/// by the recorded times. The HDOP of the preceding `GGA` goes into the fix.
pub fn replay_steps(log: &str) -> Vec<ReplayStep> {
    let mut steps = Vec::new();
    let mut hdop: Option<f64> = None;
    let mut previous_time: Option<NaiveTime> = None;
    for line in log.lines() {
        match nmea::parse_sentence(line) {
            Some(Sentence::Gga { hdop: value }) => hdop = value,
            Some(Sentence::Rmc(rmc)) => {
                let delay = match (previous_time, rmc.time) {
                    (Some(previous), Some(current)) => replay_delay(previous, current),
                    _ => DEFAULT_REPLAY_INTERVAL,
                };
                previous_time = rmc.time.or(previous_time);
                // Replayed fixes are stamped when sent (see run_replay).
                steps.push(ReplayStep {
                    delay: if steps.is_empty() {
                        Duration::ZERO
                    } else {
                        delay
                    },
                    fix: fix_from_rmc(&rmc, hdop, None),
                });
            }
            None => {}
        }
    }
    steps
}

fn replay_delay(previous: NaiveTime, current: NaiveTime) -> Duration {
    let mut millis = (current - previous).num_milliseconds();
    if millis < 0 {
        // Crossed midnight.
        millis += 24 * 60 * 60 * 1000;
    }
    match u64::try_from(millis) {
        Ok(0) | Err(_) => DEFAULT_REPLAY_INTERVAL,
        Ok(millis) => Duration::from_millis(millis).min(MAX_REPLAY_INTERVAL),
    }
}

fn fix_from_rmc(rmc: &Rmc, hdop: Option<f64>, timestamp_utc_ms: Option<i64>) -> Fix {
    Fix {
        valid: rmc.valid,
        latitude: rmc.latitude,
        longitude: rmc.longitude,
        heading_degrees: rmc.course_degrees,
        speed_mps: rmc.speed_mps,
        accuracy_meters: hdop.map(nmea::accuracy_from_hdop),
        timestamp_utc_ms,
    }
}

/// GPS time of an `RMC` sentence in Unix milliseconds, when it has both parts.
fn gps_timestamp_ms(rmc: &Rmc) -> Option<i64> {
    let (date, time) = (rmc.date?, rmc.time?);
    Some(NaiveDateTime::new(date, time).and_utc().timestamp_millis())
}

fn now_unix_ms() -> Option<i64> {
    let elapsed = SystemTime::now().duration_since(UNIX_EPOCH).ok()?;
    i64::try_from(elapsed.as_millis()).ok()
}

/// Reads and parses a recorded tour. Done once at startup: the same steps
/// feed the replay and the map-matched replay route.
pub fn load_replay(path: &Path) -> Result<Vec<ReplayStep>> {
    let log = std::fs::read_to_string(path)
        .with_context(|| format!("reading position replay {}", path.display()))?;
    let steps = replay_steps(&log);
    if steps.is_empty() {
        anyhow::bail!("position replay {} has no RMC sentences", path.display());
    }
    Ok(steps)
}

/// The tour's valid positions with standstill collapsed, as map-matching
/// wants them: the same point repeated only weighs the match towards it.
pub fn trace_points(steps: &[ReplayStep]) -> Vec<(f64, f64)> {
    let mut points: Vec<(f64, f64)> = Vec::new();
    for step in steps.iter().filter(|step| step.fix.valid) {
        let point = (step.fix.latitude, step.fix.longitude);
        if points.last() != Some(&point) {
            points.push(point);
        }
    }
    points
}

/// Replays `steps` into `hub`, forever if `looped`.
pub async fn run_replay(hub: PositionHub, steps: Vec<ReplayStep>, name: String, looped: bool) {
    info!(replay = %name, fixes = steps.len(), looped, "position replay started");
    loop {
        for step in &steps {
            tokio::time::sleep(step.delay).await;
            let mut fix = step.fix.clone();
            // A recording's own timestamps are years old.
            fix.timestamp_utc_ms = now_unix_ms();
            hub.publish(fix);
        }
        if !looped {
            info!(replay = %name, "position replay finished");
            return;
        }
        info!(replay = %name, "position replay restarting from the beginning");
        tokio::time::sleep(DEFAULT_REPLAY_INTERVAL).await;
    }
}

/// Reads NMEA from a serial device into `hub`, reopening it whenever it
/// vanishes (a USB GPS mouse unplugged and replugged). Runs on a blocking
/// thread; the line speed is left to the device (USB CDC receivers ignore it).
pub fn spawn_serial(hub: PositionHub, device: PathBuf) {
    std::thread::Builder::new()
        .name("gps-serial".to_string())
        .spawn(move || loop {
            info!(device = %device.display(), "opening GPS serial device");
            match read_serial(&hub, &device) {
                Ok(()) => warn!(device = %device.display(), "GPS serial device closed"),
                Err(err) => {
                    warn!(device = %device.display(), error = %format!("{err:#}"), "GPS serial device failed")
                }
            }
            std::thread::sleep(SERIAL_RETRY_INTERVAL);
        })
        .map(|_| ())
        .unwrap_or_else(|err| error!(error = %err, "could not start the GPS serial thread"));
}

fn read_serial(hub: &PositionHub, device: &Path) -> Result<()> {
    let file =
        std::fs::File::open(device).with_context(|| format!("opening {}", device.display()))?;
    info!(device = %device.display(), "GPS serial device opened");
    let mut hdop: Option<f64> = None;
    let mut reader = BufReader::new(file);
    let mut raw = Vec::new();
    loop {
        raw.clear();
        let read = reader.read_until(b'\n', &mut raw).context("reading NMEA")?;
        if read == 0 {
            return Ok(());
        }
        // Receivers emit ASCII; a torn or noisy line is simply skipped.
        let Ok(line) = std::str::from_utf8(&raw) else {
            continue;
        };
        match nmea::parse_sentence(line) {
            Some(Sentence::Gga { hdop: value }) => hdop = value,
            Some(Sentence::Rmc(rmc)) => {
                hub.publish(fix_from_rmc(&rmc, hdop, gps_timestamp_ms(&rmc)));
            }
            None => {}
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const LOG: &str = "\
$GPGGA,140906.149,5024.5978,N,00921.8766,E,0,00,,372.6,M,48.0,M,,0000*7C
$GPRMC,140906.149,V,5024.5978,N,00921.8766,E,,,010518,,,N*78
$GPGSA,A,1,,,,,,,,,,,,,,,*1E
$GNGGA,141502.000,5024.5968,N,00921.8742,E,1,08,1.2,372.6,M,48.0,M,,*44
$GPRMC,141502.000,A,5024.5968,N,00921.8742,E,22.35,184.27,010518,,,A*5C
";

    #[test]
    fn replay_builds_one_step_per_rmc_with_the_preceding_hdop() {
        let steps = replay_steps(LOG);
        assert_eq!(steps.len(), 2);
        assert!(!steps[0].fix.valid);
        assert_eq!(steps[0].fix.accuracy_meters, None);
        assert!(steps[1].fix.valid);
        assert_eq!(steps[1].fix.accuracy_meters, Some(6.0));
        assert_eq!(steps[1].fix.heading_degrees, Some(184.27));
    }

    #[test]
    fn replay_starts_at_once_and_caps_long_gaps() {
        let steps = replay_steps(LOG);
        assert_eq!(steps[0].delay, Duration::ZERO);
        // 14:09:06 -> 14:15:02 is a gap of almost six minutes.
        assert_eq!(steps[1].delay, MAX_REPLAY_INTERVAL);
    }

    #[test]
    fn replay_delay_follows_the_recorded_interval_and_midnight() {
        let t = |h, m, s, ms| NaiveTime::from_hms_milli_opt(h, m, s, ms).unwrap();
        assert_eq!(
            replay_delay(t(14, 9, 6, 149), t(14, 9, 7, 129)),
            Duration::from_millis(980)
        );
        assert_eq!(
            replay_delay(t(23, 59, 59, 500), t(0, 0, 0, 500)),
            Duration::from_secs(1)
        );
        assert_eq!(
            replay_delay(t(12, 0, 0, 0), t(12, 0, 0, 0)),
            DEFAULT_REPLAY_INTERVAL
        );
    }

    #[test]
    fn serial_fixes_carry_the_gps_time() {
        let Some(Sentence::Rmc(rmc)) = nmea::parse_sentence(
            "$GPRMC,141502.000,A,5024.5968,N,00921.8742,E,22.35,184.27,010518,,,A*5C",
        ) else {
            panic!("expected RMC");
        };
        // 2018-05-01T14:15:02Z
        assert_eq!(gps_timestamp_ms(&rmc), Some(1_525_184_102_000));
    }

    #[test]
    fn trace_points_skip_no_fix_and_standstill() {
        let mut steps = replay_steps(LOG);
        let standing = steps[1].clone();
        steps.push(standing.clone());
        let mut moved = standing;
        moved.fix.latitude += 0.001;
        steps.push(moved);
        let points = trace_points(&steps);
        assert_eq!(points.len(), 2, "no-fix dropped, repeated point collapsed");
        assert!(points[1].0 > points[0].0);
    }

    #[test]
    fn hub_hands_the_latest_fix_to_new_subscribers() {
        let hub = PositionHub::new(SourceKind::Replay);
        assert_eq!(hub.current().fix, None);
        let step = replay_steps(LOG).pop().unwrap();
        hub.publish(step.fix.clone());
        let receiver = hub.subscribe();
        assert_eq!(receiver.borrow().fix, Some(step.fix));
        assert_eq!(receiver.borrow().source, SourceKind::Replay);
    }
}
