//! The backend's own position: one hub holding the latest state, fed either by
//! a GPS mouse (NMEA over a serial device) or by replaying a recorded tour.

use std::fs::File;
use std::io::{BufRead, BufReader};
use std::os::fd::AsRawFd;
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use anyhow::{Context, Result};
use chrono::{NaiveDate, NaiveDateTime, NaiveTime, TimeDelta};
use tokio::sync::watch;
use tracing::{error, info, warn};

use super::clock::ClockSetter;
use super::nmea::{self, Rmc, Sentence};

/// Pause between two replayed fixes when the recording gives no usable time.
const DEFAULT_REPLAY_INTERVAL: Duration = Duration::from_secs(1);
/// Gaps in a recording longer than this are shortened, so a receiver that
/// dropped out for minutes does not stall the demo.
const MAX_REPLAY_INTERVAL: Duration = Duration::from_secs(5);
/// Wait before reopening a serial device that vanished or failed.
const SERIAL_RETRY_INTERVAL: Duration = Duration::from_secs(3);
/// GPS week numbers wrap every 1024 weeks. A receiver whose firmware predates
/// a wrap reports a date 19.6 years too early, the time of day stays right.
const GPS_WEEK_ROLLOVER_WEEKS: i64 = 1024;
/// No receiver can report a date before this code was written; the system
/// clock may be further back on a device without RTC and network.
const EARLIEST_GPS_DATE: NaiveDate = match NaiveDate::from_ymd_opt(2026, 1, 1) {
    Some(date) => date,
    None => panic!("valid date"),
};

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

/// GPS time of an `RMC` sentence, when it has both date and time.
fn gps_datetime(rmc: &Rmc) -> Option<NaiveDateTime> {
    Some(NaiveDateTime::new(rmc.date?, rmc.time?))
}

/// Moves a date that lies more than a day before `reference` forward by
/// whole week-number rollovers. A receiver with a correct date is never
/// earlier than the reference, which never runs ahead of the real time: it is
/// the later of the system clock (at worst the time it was last saved) and
/// [`EARLIEST_GPS_DATE`].
fn correct_week_rollover(reported: NaiveDateTime, reference: NaiveDateTime) -> NaiveDateTime {
    let rollover = TimeDelta::weeks(GPS_WEEK_ROLLOVER_WEEKS);
    let mut corrected = reported;
    // Bounded: four rollovers are 78 years, far beyond any real receiver.
    for _ in 0..4 {
        if corrected + TimeDelta::days(1) >= reference {
            break;
        }
        corrected += rollover;
    }
    corrected
}

fn rollover_reference() -> NaiveDateTime {
    let earliest = EARLIEST_GPS_DATE.and_time(NaiveTime::MIN);
    let now = chrono::Utc::now().naive_utc();
    now.max(earliest)
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
/// vanishes (a USB GPS mouse unplugged and replugged) or is not there yet.
/// Runs on a blocking thread. Any NMEA 0183 receiver works; `baud` is its line
/// speed; `clock` may set the system clock from the first valid fix.
pub fn spawn_serial(hub: PositionHub, device: PathBuf, baud: u32, mut clock: ClockSetter) {
    std::thread::Builder::new()
        .name("gps-serial".to_string())
        .spawn(move || loop {
            info!(device = %device.display(), baud, "opening GPS serial device");
            match read_serial(&hub, &device, baud, &mut clock) {
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

fn read_serial(hub: &PositionHub, device: &Path, baud: u32, clock: &mut ClockSetter) -> Result<()> {
    // Non-blocking so the open does not wait for a carrier the receiver never
    // raises, and no controlling terminal for the service. Reads block again
    // once the line is set up.
    let file = std::fs::OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOCTTY | libc::O_NONBLOCK)
        .open(device)
        .with_context(|| format!("opening {}", device.display()))?;
    let terminal =
        configure_line(&file, baud).with_context(|| format!("setting up {}", device.display()))?;
    set_blocking(&file).with_context(|| format!("setting up {}", device.display()))?;
    if terminal {
        info!(device = %device.display(), baud, "GPS serial device opened");
    } else {
        // A pipe or file standing in for a receiver, e.g. when testing in WSL.
        info!(device = %device.display(), "GPS source is not a terminal, reading it as is");
    }
    let mut rollover_logged = false;
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
                let timestamp = gps_datetime(&rmc).map(|reported| {
                    let corrected = correct_week_rollover(reported, rollover_reference());
                    if corrected != reported && !rollover_logged {
                        rollover_logged = true;
                        info!(
                            reported = %reported.date(),
                            corrected = %corrected.date(),
                            "GPS receiver reports a date before a week-number rollover, correcting it"
                        );
                    }
                    corrected.and_utc().timestamp_millis()
                });
                if let (true, Some(gps_ms)) = (rmc.valid, timestamp) {
                    clock.offer(gps_ms);
                }
                hub.publish(fix_from_rmc(&rmc, hdop, timestamp));
            }
            None => {}
        }
    }
}

/// Puts a terminal into raw mode at `baud`, so the kernel neither edits nor
/// echoes the receiver's lines. Returns `false`, without error, for anything
/// that is not a terminal.
fn configure_line(file: &File, baud: u32) -> Result<bool> {
    let speed = baud_constant(baud).with_context(|| format!("unsupported line speed {baud}"))?;
    let fd = file.as_raw_fd();
    // SAFETY: termios is plain old data; tcgetattr fills it before any use.
    let mut settings: libc::termios = unsafe { std::mem::zeroed() };
    // SAFETY: fd stays open for the duration of the call, settings is valid.
    if unsafe { libc::tcgetattr(fd, &mut settings) } != 0 {
        let err = std::io::Error::last_os_error();
        if err.raw_os_error() == Some(libc::ENOTTY) {
            return Ok(false);
        }
        return Err(err).context("reading the line settings");
    }
    // SAFETY: settings came from tcgetattr; the calls only modify it.
    unsafe {
        libc::cfmakeraw(&mut settings);
        libc::cfsetispeed(&mut settings, speed);
        libc::cfsetospeed(&mut settings, speed);
    }
    settings.c_cflag |= libc::CLOCAL | libc::CREAD;
    settings.c_cc[libc::VMIN] = 1;
    settings.c_cc[libc::VTIME] = 0;
    // SAFETY: fd is open, settings is a valid termios.
    if unsafe { libc::tcsetattr(fd, libc::TCSANOW, &settings) } != 0 {
        return Err(std::io::Error::last_os_error()).context("applying the line settings");
    }
    // Whatever arrived at the wrong speed before is garbage.
    // SAFETY: fd is open.
    unsafe { libc::tcflush(fd, libc::TCIFLUSH) };
    Ok(true)
}

fn baud_constant(baud: u32) -> Option<libc::speed_t> {
    Some(match baud {
        4800 => libc::B4800,
        9600 => libc::B9600,
        19200 => libc::B19200,
        38400 => libc::B38400,
        57600 => libc::B57600,
        115200 => libc::B115200,
        _ => return None,
    })
}

fn set_blocking(file: &File) -> Result<()> {
    let fd = file.as_raw_fd();
    // SAFETY: fd is open; F_GETFL/F_SETFL only touch its status flags.
    let flags = unsafe { libc::fcntl(fd, libc::F_GETFL) };
    if flags < 0 || unsafe { libc::fcntl(fd, libc::F_SETFL, flags & !libc::O_NONBLOCK) } < 0 {
        return Err(std::io::Error::last_os_error()).context("switching to blocking reads");
    }
    Ok(())
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
        let reported = gps_datetime(&rmc).expect("RMC has date and time");
        assert_eq!(reported.and_utc().timestamp_millis(), 1_525_184_102_000);
    }

    fn at(year: i32, month: u32, day: u32, hour: u32) -> NaiveDateTime {
        NaiveDate::from_ymd_opt(year, month, day)
            .unwrap()
            .and_hms_opt(hour, 0, 0)
            .unwrap()
    }

    #[test]
    fn week_rollover_moves_an_old_date_forward_by_1024_weeks() {
        // Seen on a real receiver on 2026-09-25: it reported 2007-02-09.
        let corrected = correct_week_rollover(at(2007, 2, 9, 14), at(2026, 9, 25, 10));
        assert_eq!(corrected, at(2026, 9, 25, 14));
        // Two rollovers back is corrected twice.
        let corrected = correct_week_rollover(at(1987, 6, 26, 14), at(2026, 9, 25, 10));
        assert_eq!(corrected, at(2026, 9, 25, 14));
    }

    #[test]
    fn week_rollover_leaves_a_current_date_alone() {
        let reference = at(2026, 9, 25, 10);
        assert_eq!(
            correct_week_rollover(at(2026, 9, 25, 14), reference),
            at(2026, 9, 25, 14)
        );
        // A system clock last saved yesterday is still no reason to move it.
        assert_eq!(
            correct_week_rollover(at(2026, 9, 24, 12), reference),
            at(2026, 9, 24, 12)
        );
        // Years after the last saved clock (device off for a long time).
        assert_eq!(
            correct_week_rollover(at(2030, 1, 1, 0), reference),
            at(2030, 1, 1, 0)
        );
    }

    #[test]
    fn rollover_reference_is_never_before_the_earliest_date() {
        assert!(rollover_reference() >= EARLIEST_GPS_DATE.and_time(NaiveTime::MIN));
    }

    #[test]
    fn serial_source_reads_a_plain_file_without_a_terminal() {
        // What a developer uses in WSL without a receiver: a file (or pipe)
        // of NMEA lines. Reading ends at EOF, the spawn loop would reopen it.
        let path = std::env::temp_dir().join(format!("carnine-nmea-{}.txt", std::process::id()));
        std::fs::write(&path, LOG).unwrap();
        let hub = PositionHub::new(SourceKind::Serial);
        read_serial(&hub, &path, 4800, &mut ClockSetter::new(false))
            .expect("a plain file is read as is");
        std::fs::remove_file(&path).unwrap();
        let fix = hub.current().fix.expect("the last RMC became the fix");
        assert!(fix.valid);
        assert_eq!(fix.accuracy_meters, Some(nmea::accuracy_from_hdop(1.2)));
        // 010518 is 2018: not a rollover case, but before EARLIEST_GPS_DATE -
        // hence moved on by 1024 weeks like a receiver stuck in 2018 would be.
        let timestamp = fix.timestamp_utc_ms.unwrap();
        assert!(
            timestamp
                >= EARLIEST_GPS_DATE
                    .and_time(NaiveTime::MIN)
                    .and_utc()
                    .timestamp_millis()
        );
    }

    #[test]
    fn a_missing_device_is_an_error_not_a_panic() {
        let hub = PositionHub::new(SourceKind::Serial);
        assert!(read_serial(
            &hub,
            Path::new("/nonexistent/gps"),
            4800,
            &mut ClockSetter::new(false)
        )
        .is_err());
        assert_eq!(hub.current().fix, None);
    }

    #[test]
    fn configure_line_sets_raw_mode_and_speed_on_a_terminal() {
        // A pseudo-terminal stands in for the serial adapter.
        // SAFETY: plain libc calls on a descriptor this test owns.
        let master = unsafe { libc::posix_openpt(libc::O_RDWR | libc::O_NOCTTY) };
        assert!(master >= 0, "posix_openpt");
        assert_eq!(unsafe { libc::grantpt(master) }, 0);
        assert_eq!(unsafe { libc::unlockpt(master) }, 0);
        let mut name = [0 as libc::c_char; 128];
        assert_eq!(
            unsafe { libc::ptsname_r(master, name.as_mut_ptr(), name.len()) },
            0
        );
        let slave_path = unsafe { std::ffi::CStr::from_ptr(name.as_ptr()) }
            .to_str()
            .unwrap()
            .to_string();
        let slave = std::fs::OpenOptions::new()
            .read(true)
            .custom_flags(libc::O_NOCTTY)
            .open(&slave_path)
            .unwrap();

        assert!(configure_line(&slave, 4800).unwrap());
        let mut settings: libc::termios = unsafe { std::mem::zeroed() };
        assert_eq!(
            unsafe { libc::tcgetattr(slave.as_raw_fd(), &mut settings) },
            0
        );
        assert_eq!(unsafe { libc::cfgetispeed(&settings) }, libc::B4800);
        assert_eq!(settings.c_lflag & (libc::ICANON | libc::ECHO), 0);
        assert!(configure_line(&slave, 4801).is_err());
        unsafe { libc::close(master) };
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
