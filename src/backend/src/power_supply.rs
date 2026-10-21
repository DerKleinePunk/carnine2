//! The car power supply AuPrV1_1 (docs/23-power-supply.md, firmware in
//! `firmware/powersupply/`) on a serial line.
//!
//! The supply switches the Pi on with the ignition (KL15) and has a watchdog:
//! once the Pi runs, it expects a sign of life (`+`) at least every few
//! seconds or cuts the power. The backend sends one every second from the
//! moment the line is open, so it also counts while the supply still waits
//! for the Pi to boot. `+` is harmless in every state; the firmware only
//! raises its alive counter (capped at 3) and answers ACK. The one exception
//! is a silent supply last seen outside PIBOOT and RUN: then the backend
//! sends nothing, so the module's bootloader can start the firmware (see
//! [`holds_back`]).
//!
//! Every second the supply sends four telegrams `STX <id> <payload> ETX`:
//! ignition, alive counter, state and input voltage. With its debug output on
//! (`#`) text lines come in between; they go to the debug log. What the supply
//! reports is kept in a [`PowerSupplyHub`] for SystemService. When the supply
//! goes to POWEROFF (ignition off), [`shut_down_on_poweroff`] shuts the Pi
//! down through logind. `$` on a shutdown of our own and the service mode
//! follow later (#36).
//!
//! Rel3 switches the amplifier's remote input (REM). The firmware never
//! closes it by itself and opens it once when it goes to POWEROFF; a `3`
//! arriving later would close it again. So the backend closes it (`3`) only
//! while the supply is in RUN and the UI has reported ready, and opens it
//! (`6`) when RUN ends or the backend stops, before the audio output closes.
//!
//! Once the supply talks on a connection (again after it fell silent) the
//! backend asks for the firmware version (`v`); the answer is a text line
//! such as `V2.4.1`, logged and kept in the status.

use std::fs::File;
use std::io::{Read, Write};
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Condvar, Mutex, MutexGuard};
use std::time::{Duration, Instant};

use anyhow::{Context, Result};
use tokio::sync::watch;
use tracing::{debug, error, info, warn};

use crate::serial_line::{configure_line, set_blocking};

const STX: u8 = 0x02;
const ETX: u8 = 0x03;
const ACK: u8 = 0x06;
const ID_KL15: u8 = 0x10;
const ID_ALIVE: u8 = 0x11;
const ID_STATE: u8 = 0x12;
const ID_COMMAND_RESULT: u8 = 0x13;
const ID_VOLTAGE: u8 = 0x14;
/// The longest telegram payload is a voltage in tenths ("300" for 30.0 V);
/// anything longer is a torn telegram.
const MAX_PAYLOAD: usize = 8;
/// Debug text lines longer than this are cut; the firmware's are short.
const MAX_TEXT_LINE: usize = 160;

/// The sign of life.
const ALIVE: &[u8] = b"+";
/// Relay 2 (terminal Rel3, the amplifier's REM) on and off. Both count as a
/// sign of life in the firmware too.
const AMPLIFIER_ON: &[u8] = b"3";
const AMPLIFIER_OFF: &[u8] = b"6";
/// Asks for the firmware version; not a sign of life, so it goes with one.
const VERSION_QUERY: &[u8] = b"v";
/// The supply answers `v` at once; without an answer this long it is noted.
const VERSION_ANSWER_TIMEOUT: Duration = Duration::from_secs(5);
/// The amplifier comes on this long after the UI reported ready, so it does
/// not pick up the click of an audio output that has only just opened.
const AMPLIFIER_ON_DELAY: Duration = Duration::from_secs(2);
/// A stop waits at most this long for the sender to get `6` out.
const AMPLIFIER_OFF_WAIT: Duration = Duration::from_secs(2);
/// After `6` the relay drops and the amplifier mutes before the audio output
/// closes; amplifiers take some tens of milliseconds.
const AMPLIFIER_OFF_SETTLE: Duration = Duration::from_millis(300);
/// The firmware counts the alive counter down once a second.
const ALIVE_INTERVAL: Duration = Duration::from_secs(1);
/// Wait before reopening a line that vanished or failed.
const RETRY_INTERVAL: Duration = Duration::from_secs(3);
/// While the line keeps failing the same way, one reminder at warn this often
/// (an hour at RETRY_INTERVAL); the attempts in between log at debug only.
const RETRY_REMINDER_EVERY: u64 = 1200;
/// The supply reports every second; this long without a telegram it counts
/// as gone (switched off, cable loose).
const SILENCE_TIMEOUT: Duration = Duration::from_secs(3);
/// In RUN the counter normally reads 2 (the firmware counts down before it
/// reports, our `+` follows); 1 means a sign of life came late.
const ALIVE_LOW: u8 = 1;
/// The input voltage is logged at info when it moved this far (tenths of a
/// volt) since last logged, e.g. when the engine is started.
const VOLTAGE_LOG_STEP: u16 = 5;

/// The supply's state machine (`STATE_*` in the firmware).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SupplyState {
    /// Everything off, waiting for the ignition.
    Idle,
    /// Display and HDMI splitter on, power-on delay running.
    PowerOn,
    /// The Pi has power and time to boot; the watchdog does not count yet.
    PiBoot,
    /// Normal operation; the watchdog counts.
    Run,
    /// Amplifier off, the Pi's power goes off when the timer runs out.
    PowerOff,
}

impl SupplyState {
    fn from_digit(digit: u8) -> Option<Self> {
        Some(match digit {
            b'0' => Self::Idle,
            b'1' => Self::PowerOn,
            b'2' => Self::PiBoot,
            b'3' => Self::Run,
            b'4' => Self::PowerOff,
            _ => return None,
        })
    }
}

/// One thing the supply sent.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Telegram {
    /// Ignition (KL15) on or off.
    Ignition(bool),
    /// The watchdog's alive counter, 0 to 3.
    Alive(u8),
    State(SupplyState),
    /// Input voltage in tenths of a volt.
    Voltage(u16),
    /// Answer to a command: ACK or NACK.
    CommandResult(bool),
    /// A line of the firmware's debug output, outside any telegram.
    Text(String),
}

/// Picks telegrams out of the byte stream; bytes outside `STX … ETX` are the
/// firmware's debug text and come out line by line.
#[derive(Debug, Default)]
pub struct TelegramParser {
    frame: Option<Vec<u8>>,
    /// The current frame grew too long; the rest up to ETX is dropped.
    overflow: bool,
    text: Vec<u8>,
}

impl TelegramParser {
    /// Feeds one byte; returns what this byte completes, if anything.
    pub fn push(&mut self, byte: u8) -> Option<Telegram> {
        if byte == STX {
            // A new start drops a frame that never ended.
            self.frame = Some(Vec::with_capacity(MAX_PAYLOAD + 1));
            self.overflow = false;
            return self.take_text();
        }
        let Some(frame) = self.frame.as_mut() else {
            return self.push_text(byte);
        };
        if byte != ETX {
            if frame.len() > MAX_PAYLOAD {
                self.overflow = true;
            } else {
                frame.push(byte);
            }
            return None;
        }
        let frame = self.frame.take()?;
        if std::mem::take(&mut self.overflow) {
            return None;
        }
        let (&id, payload) = frame.split_first()?;
        match id {
            ID_KL15 => match payload {
                b"0" => Some(Telegram::Ignition(false)),
                b"1" => Some(Telegram::Ignition(true)),
                _ => None,
            },
            ID_ALIVE => number(payload).map(|count| Telegram::Alive(count.min(255) as u8)),
            ID_STATE => match payload {
                [digit] => SupplyState::from_digit(*digit).map(Telegram::State),
                _ => None,
            },
            ID_VOLTAGE => number(payload).map(|tenths| Telegram::Voltage(tenths.min(65535) as u16)),
            ID_COMMAND_RESULT => match payload {
                [result] => Some(Telegram::CommandResult(*result == ACK)),
                _ => None,
            },
            _ => None,
        }
    }

    fn push_text(&mut self, byte: u8) -> Option<Telegram> {
        match byte {
            b'\r' | b'\n' => self.take_text(),
            // VT100 sequences and other control bytes are dropped.
            byte if byte.is_ascii_graphic() || byte == b' ' => {
                if self.text.len() < MAX_TEXT_LINE {
                    self.text.push(byte);
                }
                None
            }
            _ => None,
        }
    }

    fn take_text(&mut self) -> Option<Telegram> {
        let line = String::from_utf8_lossy(&self.text).trim().to_string();
        self.text.clear();
        (!line.is_empty()).then_some(Telegram::Text(line))
    }
}

fn number(digits: &[u8]) -> Option<u32> {
    if digits.is_empty() || !digits.iter().all(u8::is_ascii_digit) {
        return None;
    }
    std::str::from_utf8(digits).ok()?.parse().ok()
}

/// The supply's firmware version, as `v` reports it (`V2.4.1`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FirmwareVersion {
    pub major: u16,
    pub minor: u16,
    pub patch: u16,
}

impl FirmwareVersion {
    /// A text line that is a version and nothing else, e.g. `V2.4.1`.
    fn parse(line: &str) -> Option<Self> {
        let digits = line.trim().strip_prefix('V')?;
        let mut parts = digits.split('.');
        let mut part = || -> Option<u16> {
            let text = parts.next()?;
            if text.is_empty() || !text.bytes().all(|byte| byte.is_ascii_digit()) {
                return None;
            }
            text.parse().ok()
        };
        let version = Self {
            major: part()?,
            minor: part()?,
            patch: part()?,
        };
        parts.next().is_none().then_some(version)
    }
}

impl std::fmt::Display for FirmwareVersion {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "V{}.{}.{}", self.major, self.minor, self.patch)
    }
}

/// When to ask for the firmware version: once a connection talks, and again
/// after the supply fell silent (it may have restarted or been flashed).
#[derive(Debug, Default)]
struct VersionQuery {
    asked_at: Option<Instant>,
    warned: bool,
}

#[derive(Debug, PartialEq, Eq)]
enum VersionStep {
    Nothing,
    Ask,
    /// Asked VERSION_ANSWER_TIMEOUT ago and still no answer.
    NoAnswer,
}

impl VersionQuery {
    fn next(&mut self, status: &PowerSupplyStatus, now: Instant) -> VersionStep {
        let Some(asked_at) = self.asked_at else {
            if status.connected {
                self.asked_at = Some(now);
                return VersionStep::Ask;
            }
            return VersionStep::Nothing;
        };
        if status.firmware_version.is_none()
            && !self.warned
            && now.saturating_duration_since(asked_at) >= VERSION_ANSWER_TIMEOUT
        {
            self.warned = true;
            return VersionStep::NoAnswer;
        }
        VersionStep::Nothing
    }

    /// The supply fell silent: ask again once it talks.
    fn reset(&mut self) {
        *self = Self::default();
    }
}

/// What the supply last reported. Everything is `None` until it has said so.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct PowerSupplyStatus {
    /// `[power_supply] enabled`; without it nothing else is ever set.
    pub configured: bool,
    /// A telegram arrived within [`SILENCE_TIMEOUT`].
    pub connected: bool,
    pub ignition: Option<bool>,
    pub state: Option<SupplyState>,
    /// Input voltage in tenths of a volt.
    pub voltage_tenths: Option<u16>,
    pub alive: Option<u8>,
    /// From the answer to `v`, per connection.
    pub firmware_version: Option<FirmwareVersion>,
}

impl PowerSupplyStatus {
    /// What a client watches for; the alive counter moves every second and
    /// is left out.
    #[allow(clippy::type_complexity)]
    fn watched(
        &self,
    ) -> (
        bool,
        bool,
        Option<bool>,
        Option<SupplyState>,
        Option<u16>,
        Option<FirmwareVersion>,
    ) {
        (
            self.configured,
            self.connected,
            self.ignition,
            self.state,
            self.voltage_tenths,
            self.firmware_version,
        )
    }
}

/// Latest status for SystemService; subscribers are woken on changes of
/// everything but the alive counter.
#[derive(Debug, Clone)]
pub struct PowerSupplyHub {
    sender: Arc<watch::Sender<PowerSupplyStatus>>,
    amplifier: Arc<Amplifier>,
}

/// What the backend wants from the amplifier relay and what the line last
/// got; the sender thread turns the difference into `3` or `6`.
#[derive(Debug, Default)]
struct AmplifierRequest {
    /// `[power_supply] amplifier_relay`; without it neither `3` nor `6`.
    enabled: bool,
    /// When the UI reported ready.
    ready_since: Option<Instant>,
    /// The backend is stopping: off for good.
    stopping: bool,
    /// What the line last got, `None` on a new connection or after the
    /// supply went silent (it may have restarted with every relay open).
    sent: Option<bool>,
}

impl AmplifierRequest {
    /// Whether the amplifier should be on now.
    fn wanted(&self, status: &PowerSupplyStatus, now: Instant) -> bool {
        !self.stopping
            && status.state == Some(SupplyState::Run)
            && self
                .ready_since
                .is_some_and(|since| now.saturating_duration_since(since) >= AMPLIFIER_ON_DELAY)
    }

    /// The switch to send now, if any: on or off when that differs from
    /// what the line last got. A silent supply gets nothing and is switched
    /// afresh once it talks again.
    fn decide(&mut self, status: &PowerSupplyStatus, now: Instant) -> Option<bool> {
        if !self.enabled {
            return None;
        }
        if !status.connected {
            self.sent = None;
            return None;
        }
        let wanted = self.wanted(status, now);
        (self.sent != Some(wanted)).then_some(wanted)
    }
}

#[derive(Debug, Default)]
struct Amplifier {
    request: Mutex<AmplifierRequest>,
    /// Wakes the sender on a new request and a stop once `6` is out.
    changed: Condvar,
}

impl Amplifier {
    fn lock(&self) -> MutexGuard<'_, AmplifierRequest> {
        self.request
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }
}

/// A hub for a device without a supply.
impl Default for PowerSupplyHub {
    fn default() -> Self {
        Self::new(false)
    }
}

impl PowerSupplyHub {
    pub fn new(configured: bool) -> Self {
        let (sender, _) = watch::channel(PowerSupplyStatus {
            configured,
            ..PowerSupplyStatus::default()
        });
        Self {
            sender: Arc::new(sender),
            amplifier: Arc::default(),
        }
    }

    /// Lets the backend switch the amplifier on Rel3 (`[power_supply]
    /// amplifier_relay`).
    pub fn with_amplifier_relay(self, enabled: bool) -> Self {
        self.amplifier.lock().enabled = enabled;
        self
    }

    /// The UI is up: the amplifier may come on once the supply runs.
    pub fn ui_ready(&self) {
        let mut request = self.amplifier.lock();
        if request.ready_since.is_some() || request.stopping {
            return;
        }
        request.ready_since = Some(Instant::now());
        if request.enabled {
            info!("UI ready: the amplifier (Rel3) comes on while the power supply runs");
        }
        self.amplifier.changed.notify_all();
    }

    /// Switches the amplifier off for good and waits until `6` is out and
    /// the amplifier has muted, so the audio output can close without a
    /// click in the speakers. Blocks for a moment; returns at once when the
    /// amplifier is not on.
    pub fn switch_amplifier_off(&self) {
        let mut request = self.amplifier.lock();
        request.stopping = true;
        if !request.enabled || request.sent != Some(true) {
            return;
        }
        self.amplifier.changed.notify_all();
        let (request, waited) = self
            .amplifier
            .changed
            .wait_timeout_while(request, AMPLIFIER_OFF_WAIT, |request| {
                request.sent == Some(true)
            })
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        drop(request);
        if waited.timed_out() {
            warn!("amplifier (Rel3) not switched off in time, stopping anyway");
            return;
        }
        std::thread::sleep(AMPLIFIER_OFF_SETTLE);
    }

    /// The next switch for the line, see [`AmplifierRequest::decide`].
    fn amplifier_switch(&self) -> Option<bool> {
        let status = self.current();
        let mut request = self.amplifier.lock();
        let before = request.sent;
        let switch = request.decide(&status, Instant::now());
        if request.sent != before {
            self.amplifier.changed.notify_all();
        }
        switch
    }

    /// The line got `3` (`true`) or `6`.
    fn amplifier_sent(&self, on: bool) {
        let before = self.amplifier.lock().sent.replace(on);
        if on {
            info!("amplifier (Rel3) on");
        } else if before == Some(true) {
            info!(state = ?self.current().state, "amplifier (Rel3) off");
        } else {
            debug!("amplifier (Rel3) off");
        }
        self.amplifier.changed.notify_all();
    }

    /// A new connection: the relay's state is not known.
    fn amplifier_unknown(&self) {
        self.amplifier.lock().sent = None;
        self.amplifier.changed.notify_all();
    }

    /// Sleeps up to `interval`; a new request wakes it early.
    fn wait_for_amplifier_request(&self, interval: Duration) {
        let request = self.amplifier.lock();
        let _ = self.amplifier.changed.wait_timeout(request, interval);
    }

    pub fn current(&self) -> PowerSupplyStatus {
        *self.sender.borrow()
    }

    pub fn subscribe(&self) -> watch::Receiver<PowerSupplyStatus> {
        self.sender.subscribe()
    }

    /// Whether the UI has been reported ready, for tests of the service.
    #[cfg(test)]
    pub fn ui_reported(&self) -> bool {
        self.amplifier.lock().ready_since.is_some()
    }

    /// Sets the whole status, for tests of the service on top.
    #[cfg(test)]
    pub fn set(&self, status: PowerSupplyStatus) {
        self.sender.send_replace(status);
    }

    fn update(&self, change: impl FnOnce(&mut PowerSupplyStatus)) {
        self.sender.send_if_modified(|status| {
            let before = status.watched();
            change(status);
            status.watched() != before
        });
    }
}

/// Logs what matters of each telegram: ignition and state at info, a late
/// sign of life and a refused command as warnings, the voltage at info only
/// when it moved noticeably, debug text at debug.
#[derive(Debug, Default)]
struct TelegramLog {
    voltage_logged: Option<u16>,
    alive_low: bool,
}

impl TelegramLog {
    fn log(&mut self, telegram: &Telegram, before: &PowerSupplyStatus) {
        match telegram {
            Telegram::Ignition(on) if before.ignition != Some(*on) => {
                info!(ignition = on, "power supply ignition (KL15)");
            }
            Telegram::State(state) if before.state != Some(*state) => {
                info!(state = ?state, "power supply state");
            }
            Telegram::Alive(count) => {
                let low = before.state == Some(SupplyState::Run) && *count <= ALIVE_LOW;
                if low && !self.alive_low {
                    warn!(
                        alive = count,
                        "power supply alive counter low, a sign of life came late"
                    );
                }
                self.alive_low = low;
            }
            Telegram::Voltage(tenths) => {
                let moved = self
                    .voltage_logged
                    .is_none_or(|logged| logged.abs_diff(*tenths) >= VOLTAGE_LOG_STEP);
                if moved {
                    self.voltage_logged = Some(*tenths);
                    info!(
                        volts = f64::from(*tenths) / 10.0,
                        "power supply input voltage"
                    );
                } else if before.voltage_tenths != Some(*tenths) {
                    debug!(
                        volts = f64::from(*tenths) / 10.0,
                        "power supply input voltage"
                    );
                }
            }
            Telegram::CommandResult(false) => warn!("power supply refused a command"),
            Telegram::Text(line) => debug!(line = %line, "power supply debug output"),
            _ => {}
        }
    }
}

fn apply(status: &mut PowerSupplyStatus, telegram: &Telegram) {
    status.connected = true;
    match *telegram {
        Telegram::Ignition(on) => status.ignition = Some(on),
        Telegram::State(state) => status.state = Some(state),
        Telegram::Voltage(tenths) => status.voltage_tenths = Some(tenths),
        Telegram::Alive(count) => status.alive = Some(count),
        Telegram::CommandResult(_) | Telegram::Text(_) => {}
    }
}

/// How loud a retry of the serial line is logged. Without a supply, or with
/// it switched off, the line fails every few seconds the same way; that
/// filled the log with thousands of identical warnings a day. Now the first
/// failure and every new kind of failure log at warn, the repeats at debug
/// with an hourly reminder, and the line opening again at info with how many
/// attempts it took (as with the audio output, #59).
#[derive(Debug, Default)]
struct RetryLog {
    failing: Option<String>,
    repeats: u64,
}

#[derive(Debug, PartialEq, Eq)]
enum RetryNotice {
    /// A failure not seen just before: log it at warn.
    New,
    /// The same failure again: debug only.
    Repeat,
    /// The same failure for an hour now, `attempts` in a row: warn once more.
    Reminder { attempts: u64 },
}

impl RetryLog {
    fn failed(&mut self, problem: String) -> RetryNotice {
        if self.failing.as_deref() == Some(problem.as_str()) {
            self.repeats += 1;
            if self.repeats.is_multiple_of(RETRY_REMINDER_EVERY) {
                RetryNotice::Reminder {
                    attempts: self.repeats + 1,
                }
            } else {
                RetryNotice::Repeat
            }
        } else {
            self.failing = Some(problem);
            self.repeats = 0;
            RetryNotice::New
        }
    }

    /// The line opened: the failed attempts in a row before, if there were.
    fn opened(&mut self) -> Option<u64> {
        let attempts = self.failing.take().map(|_| self.repeats + 1);
        self.repeats = 0;
        attempts
    }

    /// Whether the line is failing right now, so an attempt logs quietly.
    fn failing(&self) -> bool {
        self.failing.is_some()
    }
}

/// Talks to the supply on `device`, reopening it whenever it fails or is not
/// there yet. Runs on its own threads.
pub fn spawn(hub: PowerSupplyHub, device: PathBuf, baud: u32) {
    std::thread::Builder::new()
        .name("power-supply".to_string())
        .spawn(move || {
            let mut retries = RetryLog::default();
            loop {
                if retries.failing() {
                    debug!(device = %device.display(), baud, "opening power supply serial line");
                } else {
                    info!(device = %device.display(), baud, "opening power supply serial line");
                }
                let problem = match open_line(&device, baud) {
                    Err(err) => format!("{err:#}"),
                    Ok(file) => {
                        if let Some(attempts) = retries.opened() {
                            info!(device = %device.display(), attempts, "power supply serial line back");
                        }
                        match run_line(&hub, file) {
                            Ok(()) => "closed".to_string(),
                            Err(err) => format!("{err:#}"),
                        }
                    }
                };
                match retries.failed(problem.clone()) {
                    RetryNotice::New => {
                        warn!(device = %device.display(), error = %problem, "power supply serial line failed; retrying quietly every {}s", RETRY_INTERVAL.as_secs())
                    }
                    RetryNotice::Repeat => {
                        debug!(device = %device.display(), error = %problem, "power supply serial line failed again")
                    }
                    RetryNotice::Reminder { attempts } => {
                        warn!(device = %device.display(), error = %problem, attempts, "power supply serial line still failing")
                    }
                }
                hub.update(|status| status.connected = false);
                std::thread::sleep(RETRY_INTERVAL);
            }
        })
        .map(|_| ())
        .unwrap_or_else(|err| error!(error = %err, "could not start the power supply thread"));
}

/// Waits until the supply reports POWEROFF, then runs `shut_down` once.
///
/// The firmware finishes POWEROFF even when the ignition comes back and then
/// takes the power (docs/23, States), so the Pi goes down at once, not after
/// a delay; the supply allows 15 s and the backend itself needs up to 10 s to
/// stop. A supply already in POWEROFF when the backend starts counts too.
pub async fn shut_down_on_poweroff<F>(hub: PowerSupplyHub, shut_down: F)
where
    F: FnOnce() -> Result<()> + Send + 'static,
{
    let mut updates = hub.subscribe();
    loop {
        if updates.borrow_and_update().state == Some(SupplyState::PowerOff) {
            break;
        }
        if updates.changed().await.is_err() {
            return;
        }
    }
    info!("power supply in POWEROFF (ignition off): shutting the Pi down");
    match tokio::task::spawn_blocking(shut_down).await {
        Ok(Ok(())) => {}
        Ok(Err(err)) => error!(error = %format!("{err:#}"), "shutting the Pi down failed"),
        Err(err) => error!(error = %err, "shutting the Pi down failed"),
    }
}

/// Asks logind to power off. The backend runs as `carnine`; the package's
/// polkit rule (`60-carnine-backend-power.rules`) allows exactly this.
pub fn power_off() -> Result<()> {
    let status = std::process::Command::new("systemctl")
        .args(["poweroff", "--no-wall"])
        .status()
        .context("running systemctl poweroff")?;
    anyhow::ensure!(status.success(), "systemctl poweroff exited with {status}");
    Ok(())
}

/// Whether the frontend's unit is already active, i.e. it reported ready
/// before (Type=notify, it tells systemd after ReportUiReady). It does not
/// report again when only the backend restarts, e.g. after a package update;
/// then this stands in for it. Anything but a clear "active" counts as no.
pub fn frontend_already_up() -> bool {
    std::process::Command::new("systemctl")
        .args(["is-active", "--quiet", "carnine-frontend.service"])
        .stderr(std::process::Stdio::null())
        .status()
        .is_ok_and(|status| status.success())
}

/// One connection: a sender thread writes the sign of life every second and
/// notices silence, while this thread reads telegrams, until either fails.
fn run_line(hub: &PowerSupplyHub, file: File) -> Result<()> {
    hub.amplifier_unknown();
    hub.update(|status| status.firmware_version = None);
    let writer = file
        .try_clone()
        .context("duplicating the line for sending")?;
    let stop = Arc::new(AtomicBool::new(false));
    let last_heard = Arc::new(Mutex::new(Instant::now()));
    let sender = {
        let stop = Arc::clone(&stop);
        let last_heard = Arc::clone(&last_heard);
        let hub = hub.clone();
        std::thread::Builder::new()
            .name("power-supply-alive".to_string())
            .spawn(move || send_alive(writer, &hub, &last_heard, &stop))
            .context("starting the sender thread")?
    };
    let read = read_telegrams(file, hub, &last_heard, &stop);
    stop.store(true, Ordering::Relaxed);
    let sent = sender.join().unwrap_or_else(|_| Ok(()));
    read.and(sent)
}

fn open_line(device: &Path, baud: u32) -> Result<File> {
    // Non-blocking so the open does not wait for a carrier, and no
    // controlling terminal for the service; reads block again afterwards.
    let file = std::fs::OpenOptions::new()
        .read(true)
        .write(true)
        .custom_flags(libc::O_NOCTTY | libc::O_NONBLOCK)
        .open(device)
        .with_context(|| format!("opening {}", device.display()))?;
    let terminal =
        configure_line(&file, baud).with_context(|| format!("setting up {}", device.display()))?;
    set_blocking(&file).with_context(|| format!("setting up {}", device.display()))?;
    if terminal {
        info!(device = %device.display(), baud, "power supply serial line opened");
    } else {
        info!(device = %device.display(), "power supply line is not a terminal, using it as is");
    }
    Ok(file)
}

fn send_alive(
    mut line: File,
    hub: &PowerSupplyHub,
    last_heard: &Mutex<Instant>,
    stop: &AtomicBool,
) -> Result<()> {
    let mut silent = false;
    let mut holding_back = false;
    let mut version = VersionQuery::default();
    while !stop.load(Ordering::Relaxed) {
        let quiet = last_heard
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .elapsed()
            > SILENCE_TIMEOUT;
        if quiet && !silent {
            warn!("power supply silent, no telegram for a while");
            hub.update(|status| {
                status.connected = false;
                status.firmware_version = None;
            });
            version.reset();
        }
        silent = quiet;
        let hold_back = holds_back(quiet, hub.current().state);
        if hold_back && !holding_back {
            info!("power supply silent outside PIBOOT/RUN: sending nothing until it talks, so its bootloader can start the firmware");
        }
        holding_back = hold_back;
        if !hold_back {
            match hub.amplifier_switch() {
                Some(on) => {
                    line.write_all(if on { AMPLIFIER_ON } else { AMPLIFIER_OFF })
                        .context("switching the amplifier")?;
                    hub.amplifier_sent(on);
                }
                None => line.write_all(ALIVE).context("sending the sign of life")?,
            }
            match version.next(&hub.current(), Instant::now()) {
                VersionStep::Ask => line
                    .write_all(VERSION_QUERY)
                    .context("asking for the firmware version")?,
                VersionStep::NoAnswer => {
                    warn!("power supply did not report its firmware version (no answer to v)")
                }
                VersionStep::Nothing => {}
            }
        }
        hub.wait_for_amplifier_request(ALIVE_INTERVAL);
    }
    Ok(())
}

/// Whether the sender stays quiet: the supply is silent and was last seen
/// (if at all) outside PIBOOT and RUN.
///
/// After every reset the module first runs its bootloader, which starts the
/// firmware only once the line has been quiet for a few seconds; a sign of
/// life every second keeps it there for good (21.10.2026: Pi on USB-C, module
/// switched on later, silent until the Pi stopped sending). The firmware
/// reports every second without being asked, so silence costs nothing there.
/// In PIBOOT and RUN the signs of life go on: if only our receive side failed
/// (a loose wire), the supply must not miss them and cut the power.
fn holds_back(quiet: bool, last_state: Option<SupplyState>) -> bool {
    quiet && !matches!(last_state, Some(SupplyState::PiBoot | SupplyState::Run))
}

fn read_telegrams(
    mut line: File,
    hub: &PowerSupplyHub,
    last_heard: &Mutex<Instant>,
    stop: &AtomicBool,
) -> Result<()> {
    let mut parser = TelegramParser::default();
    let mut log = TelegramLog::default();
    let mut buffer = [0u8; 64];
    while !stop.load(Ordering::Relaxed) {
        let read = line
            .read(&mut buffer)
            .context("reading from the power supply")?;
        if read == 0 {
            return Ok(());
        }
        for &byte in &buffer[..read] {
            let Some(telegram) = parser.push(byte) else {
                continue;
            };
            if let Telegram::Text(line) = &telegram {
                if let Some(version) = FirmwareVersion::parse(line) {
                    info!(version = %version, "power supply firmware");
                    hub.update(|status| status.firmware_version = Some(version));
                } else {
                    log.log(&telegram, &hub.current());
                }
                continue;
            }
            *last_heard
                .lock()
                .unwrap_or_else(|poisoned| poisoned.into_inner()) = Instant::now();
            let before = hub.current();
            if !before.connected {
                info!("power supply talking");
            }
            log.log(&telegram, &before);
            hub.update(|status| apply(status, &telegram));
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::serial_line::pseudo_terminal;

    #[test]
    fn a_line_failing_the_same_way_warns_once_then_hourly() {
        let mut retries = RetryLog::default();
        let missing = || "opening /dev/powersupply: No such file or directory".to_string();

        assert_eq!(retries.failed(missing()), RetryNotice::New);
        assert!(retries.failing());
        for attempt in 2..=RETRY_REMINDER_EVERY {
            assert_eq!(retries.failed(missing()), RetryNotice::Repeat, "{attempt}");
        }
        assert_eq!(
            retries.failed(missing()),
            RetryNotice::Reminder {
                attempts: RETRY_REMINDER_EVERY + 1
            }
        );
        assert_eq!(retries.failed(missing()), RetryNotice::Repeat);
    }

    #[test]
    fn a_new_kind_of_failure_warns_again() {
        let mut retries = RetryLog::default();
        assert_eq!(
            retries.failed("opening: missing".to_string()),
            RetryNotice::New
        );
        assert_eq!(
            retries.failed("opening: missing".to_string()),
            RetryNotice::Repeat
        );
        assert_eq!(
            retries.failed("setting up: not permitted".to_string()),
            RetryNotice::New
        );
    }

    #[test]
    fn opening_again_reports_the_attempts_and_starts_over() {
        let mut retries = RetryLog::default();
        assert_eq!(retries.opened(), None, "no failure before");
        for _ in 0..5 {
            retries.failed("opening: missing".to_string());
        }
        assert_eq!(retries.opened(), Some(5));
        assert!(!retries.failing());
        // The same failure after the line was open counts as new.
        assert_eq!(
            retries.failed("opening: missing".to_string()),
            RetryNotice::New
        );
    }

    /// The four telegrams the firmware sends every second.
    fn status_telegrams(kl15: u8, alive: &str, state: u8, tenths: &str) -> Vec<u8> {
        let mut bytes = vec![STX, ID_KL15, kl15, ETX, STX, ID_ALIVE];
        bytes.extend_from_slice(alive.as_bytes());
        bytes.extend_from_slice(&[ETX, STX, ID_STATE, state, ETX, STX, ID_VOLTAGE]);
        bytes.extend_from_slice(tenths.as_bytes());
        bytes.push(ETX);
        bytes
    }

    fn parse(bytes: &[u8]) -> Vec<Telegram> {
        let mut parser = TelegramParser::default();
        bytes.iter().filter_map(|&byte| parser.push(byte)).collect()
    }

    #[test]
    fn a_status_second_yields_its_four_telegrams() {
        assert_eq!(
            parse(&status_telegrams(b'1', "3", b'3', "134")),
            [
                Telegram::Ignition(true),
                Telegram::Alive(3),
                Telegram::State(SupplyState::Run),
                Telegram::Voltage(134),
            ]
        );
    }

    #[test]
    fn debug_text_between_telegrams_comes_out_line_by_line() {
        let mut bytes = b"\x1b[2JKL15: 1\r\nAlive time out !\r\n".to_vec();
        bytes.extend(status_telegrams(b'0', "0", b'4', "121"));
        bytes.extend_from_slice(b"POWEROFF\r\n");
        bytes.extend_from_slice(&[STX, ID_COMMAND_RESULT, ACK, ETX]);
        assert_eq!(
            parse(&bytes),
            [
                Telegram::Text("[2JKL15: 1".to_string()),
                Telegram::Text("Alive time out !".to_string()),
                Telegram::Ignition(false),
                Telegram::Alive(0),
                Telegram::State(SupplyState::PowerOff),
                Telegram::Voltage(121),
                Telegram::Text("POWEROFF".to_string()),
                Telegram::CommandResult(true),
            ]
        );
    }

    #[test]
    fn torn_and_unknown_telegrams_are_dropped() {
        let mut bytes = vec![STX, ID_KL15, b'1']; // no ETX, a new STX follows
        bytes.extend_from_slice(&[STX, ID_STATE, b'9', ETX]); // no such state
        bytes.extend_from_slice(&[STX, 0x42, b'1', ETX]); // unknown id
        bytes.extend_from_slice(&[STX, ID_VOLTAGE, b'1', b'x', ETX]); // not a number
        bytes.push(STX);
        bytes.extend(std::iter::repeat_n(b'1', 40)); // runaway payload
        bytes.push(ETX);
        bytes.extend_from_slice(&[STX, ID_STATE, b'2', ETX]);
        assert_eq!(parse(&bytes), [Telegram::State(SupplyState::PiBoot)]);
    }

    #[test]
    fn the_hub_wakes_subscribers_on_changes_but_not_on_the_alive_counter() {
        let hub = PowerSupplyHub::new(true);
        let mut receiver = hub.subscribe();
        receiver.mark_unchanged();

        // The first telegram also means the supply is there.
        hub.update(|status| apply(status, &Telegram::State(SupplyState::Run)));
        assert!(receiver.has_changed().unwrap());
        assert!(receiver.borrow_and_update().connected);

        hub.update(|status| apply(status, &Telegram::Alive(2)));
        assert!(!receiver.has_changed().unwrap());
        assert_eq!(hub.current().alive, Some(2));

        hub.update(|status| apply(status, &Telegram::Ignition(false)));
        assert!(receiver.has_changed().unwrap());
        assert_eq!(receiver.borrow_and_update().ignition, Some(false));

        hub.update(|status| apply(status, &Telegram::Ignition(false)));
        assert!(!receiver.has_changed().unwrap());
    }

    #[test]
    fn a_missing_device_is_an_error_not_a_panic() {
        let hub = PowerSupplyHub::new(true);
        assert!(open_line(Path::new("/nonexistent/powersupply"), 38400).is_err());
        assert!(!hub.current().connected);
    }

    #[test]
    fn the_line_sends_signs_of_life_and_reads_the_status() {
        let (mut master, slave_path) = pseudo_terminal();
        let hub = PowerSupplyHub::new(true);
        let stop = Arc::new(AtomicBool::new(false));
        let last_heard = Arc::new(Mutex::new(Instant::now()));
        let line = open_line(Path::new(&slave_path), 38400).expect("open the pseudo-terminal");
        let writer = line.try_clone().unwrap();
        let sender = {
            let (stop, last_heard, hub) = (Arc::clone(&stop), Arc::clone(&last_heard), hub.clone());
            std::thread::spawn(move || send_alive(writer, &hub, &last_heard, &stop))
        };
        let reader = {
            let (stop, last_heard, hub) = (Arc::clone(&stop), Arc::clone(&last_heard), hub.clone());
            std::thread::spawn(move || read_telegrams(line, &hub, &last_heard, &stop))
        };

        // The first sign of life goes out at once, the next a second later.
        let started = Instant::now();
        let mut received = Vec::new();
        let mut buffer = [0u8; 16];
        while received.len() < 2 {
            let read = master.read(&mut buffer).expect("read from the master side");
            received.extend_from_slice(&buffer[..read]);
        }
        assert_eq!(received, b"++");
        assert!(started.elapsed() >= Duration::from_millis(900));

        // The status goes the other way into the hub.
        let mut receiver = hub.subscribe();
        master
            .write_all(&status_telegrams(b'0', "2", b'4', "134"))
            .unwrap();
        let deadline = Instant::now() + Duration::from_secs(3);
        while receiver.borrow().voltage_tenths.is_none() && Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(10));
        }
        let status = *receiver.borrow_and_update();
        assert!(status.connected);
        assert_eq!(status.ignition, Some(false));
        assert_eq!(status.state, Some(SupplyState::PowerOff));
        assert_eq!(status.voltage_tenths, Some(134));
        assert_eq!(status.alive, Some(2));

        stop.store(true, Ordering::Relaxed);
        sender.join().unwrap().unwrap();
        // The reader returns once the master side sends again after `stop`.
        master.write_all(&[STX, ID_STATE, b'3', ETX]).unwrap();
        reader.join().unwrap().unwrap();
    }

    fn status_in(state: SupplyState) -> PowerSupplyStatus {
        PowerSupplyStatus {
            configured: true,
            connected: true,
            state: Some(state),
            ..PowerSupplyStatus::default()
        }
    }

    /// Runs the watcher with a counting stand-in for the real power-off.
    fn watch_counting(
        hub: &PowerSupplyHub,
    ) -> (
        Arc<std::sync::atomic::AtomicUsize>,
        tokio::task::JoinHandle<()>,
    ) {
        let calls = Arc::new(std::sync::atomic::AtomicUsize::new(0));
        let counted = Arc::clone(&calls);
        let task = tokio::spawn(shut_down_on_poweroff(hub.clone(), move || {
            counted.fetch_add(1, Ordering::SeqCst);
            Ok(())
        }));
        (calls, task)
    }

    #[tokio::test]
    async fn poweroff_shuts_the_pi_down_once() {
        let hub = PowerSupplyHub::new(true);
        let (calls, task) = watch_counting(&hub);

        for state in [SupplyState::PowerOn, SupplyState::PiBoot, SupplyState::Run] {
            hub.set(status_in(state));
            tokio::task::yield_now().await;
        }
        assert_eq!(
            calls.load(Ordering::SeqCst),
            0,
            "no shutdown before POWEROFF"
        );

        hub.set(status_in(SupplyState::PowerOff));
        tokio::time::timeout(Duration::from_secs(5), task)
            .await
            .expect("the watcher ends after the shutdown")
            .unwrap();
        assert_eq!(calls.load(Ordering::SeqCst), 1);
    }

    #[tokio::test]
    async fn without_poweroff_nothing_shuts_down() {
        let hub = PowerSupplyHub::new(true);
        let (calls, task) = watch_counting(&hub);

        // The ignition alone (KL15 off, still RUN) is not the signal: the
        // supply decides when to go to POWEROFF.
        hub.set(PowerSupplyStatus {
            ignition: Some(false),
            ..status_in(SupplyState::Run)
        });
        hub.set(status_in(SupplyState::Idle));
        tokio::time::sleep(Duration::from_millis(100)).await;

        assert_eq!(calls.load(Ordering::SeqCst), 0);
        assert!(!task.is_finished());
        task.abort();
    }

    #[tokio::test]
    async fn a_supply_already_in_poweroff_at_start_shuts_down() {
        let hub = PowerSupplyHub::new(true);
        hub.set(status_in(SupplyState::PowerOff));
        let (calls, task) = watch_counting(&hub);

        tokio::time::timeout(Duration::from_secs(5), task)
            .await
            .expect("the watcher ends after the shutdown")
            .unwrap();
        assert_eq!(calls.load(Ordering::SeqCst), 1);
    }

    #[tokio::test]
    async fn a_failing_shutdown_is_logged_not_a_panic() {
        let hub = PowerSupplyHub::new(true);
        hub.set(status_in(SupplyState::PowerOff));

        tokio::time::timeout(
            Duration::from_secs(5),
            shut_down_on_poweroff(hub, || anyhow::bail!("polkit said no")),
        )
        .await
        .expect("the watcher ends after the failed shutdown");
    }

    fn amplifier_request(enabled: bool) -> AmplifierRequest {
        AmplifierRequest {
            enabled,
            ..AmplifierRequest::default()
        }
    }

    #[test]
    fn the_amplifier_comes_on_only_after_the_ui_and_in_run() {
        let start = Instant::now();
        let mut request = amplifier_request(true);
        let run = status_in(SupplyState::Run);

        // Connected but no UI yet: the relay is set to off once, so its
        // state is known.
        assert_eq!(request.decide(&run, start), Some(false));
        request.sent = Some(false);
        assert_eq!(request.decide(&run, start), None);

        // UI ready, but the audio output gets a moment first.
        request.ready_since = Some(start);
        assert_eq!(
            request.decide(&run, start + Duration::from_millis(1900)),
            None
        );
        let later = start + AMPLIFIER_ON_DELAY;
        assert_eq!(request.decide(&run, later), Some(true));
        request.sent = Some(true);
        assert_eq!(
            request.decide(&run, later),
            None,
            "sent once, not every second"
        );

        // Before RUN the supply still boots the Pi: not yet.
        let mut booting = amplifier_request(true);
        booting.ready_since = Some(start);
        booting.sent = Some(false);
        assert_eq!(booting.decide(&status_in(SupplyState::PiBoot), later), None);
    }

    #[test]
    fn the_amplifier_goes_off_when_run_ends_or_the_backend_stops() {
        let start = Instant::now();
        let later = start + AMPLIFIER_ON_DELAY;
        let on = || AmplifierRequest {
            enabled: true,
            ready_since: Some(start),
            stopping: false,
            sent: Some(true),
        };

        // The firmware opened Rel3 once in POWEROFF; we say so too, so a `3`
        // can never follow.
        assert_eq!(
            on().decide(&status_in(SupplyState::PowerOff), later),
            Some(false)
        );

        let mut stopping = on();
        stopping.stopping = true;
        assert_eq!(
            stopping.decide(&status_in(SupplyState::Run), later),
            Some(false)
        );
    }

    #[test]
    fn a_silent_supply_is_switched_afresh_when_it_talks_again() {
        let start = Instant::now();
        let later = start + AMPLIFIER_ON_DELAY;
        let mut request = AmplifierRequest {
            enabled: true,
            ready_since: Some(start),
            stopping: false,
            sent: Some(true),
        };
        let silent = PowerSupplyStatus {
            connected: false,
            ..status_in(SupplyState::Run)
        };
        assert_eq!(
            request.decide(&silent, later),
            None,
            "nothing to a silent line"
        );
        assert_eq!(request.sent, None);
        // It may have restarted with every relay open.
        assert_eq!(
            request.decide(&status_in(SupplyState::Run), later),
            Some(true)
        );
    }

    #[test]
    fn without_the_amplifier_relay_nothing_is_switched() {
        let start = Instant::now();
        let mut request = amplifier_request(false);
        request.ready_since = Some(start);
        for state in [SupplyState::Run, SupplyState::PowerOff] {
            assert_eq!(
                request.decide(&status_in(state), start + AMPLIFIER_ON_DELAY),
                None
            );
        }
    }

    #[test]
    fn the_ui_counts_once_and_not_after_a_stop() {
        let hub = PowerSupplyHub::new(true).with_amplifier_relay(true);
        hub.ui_ready();
        let first = hub.amplifier.lock().ready_since;
        assert!(first.is_some());
        hub.ui_ready();
        assert_eq!(
            hub.amplifier.lock().ready_since,
            first,
            "a second report changes nothing"
        );

        let stopped = PowerSupplyHub::new(true).with_amplifier_relay(true);
        stopped.switch_amplifier_off();
        stopped.ui_ready();
        assert_eq!(stopped.amplifier.lock().ready_since, None);
    }

    #[test]
    fn switching_off_returns_at_once_when_the_amplifier_is_not_on() {
        let hub = PowerSupplyHub::new(true).with_amplifier_relay(true);
        let started = Instant::now();
        hub.switch_amplifier_off();
        assert!(started.elapsed() < AMPLIFIER_OFF_SETTLE);
        assert!(hub.amplifier.lock().stopping);
    }

    /// Reads from the master side until `wanted` has come, skipping signs
    /// of life; everything read goes into `seen`.
    fn read_until(master: &mut File, wanted: u8, seen: &mut Vec<u8>) {
        let deadline = Instant::now() + Duration::from_secs(6);
        let mut buffer = [0u8; 16];
        while !seen.contains(&wanted) {
            assert!(
                Instant::now() < deadline,
                "no {:?} in {:?}",
                wanted as char,
                seen
            );
            let read = master.read(&mut buffer).expect("read from the master side");
            seen.extend_from_slice(&buffer[..read]);
        }
    }

    #[test]
    fn the_line_switches_the_amplifier_on_in_run_and_off_on_stop() {
        let (mut master, slave_path) = pseudo_terminal();
        let hub = PowerSupplyHub::new(true).with_amplifier_relay(true);
        let stop = Arc::new(AtomicBool::new(false));
        let last_heard = Arc::new(Mutex::new(Instant::now()));
        let line = open_line(Path::new(&slave_path), 38400).expect("open the pseudo-terminal");
        let writer = line.try_clone().unwrap();
        let sender = {
            let (stop, last_heard, hub) = (Arc::clone(&stop), Arc::clone(&last_heard), hub.clone());
            std::thread::spawn(move || send_alive(writer, &hub, &last_heard, &stop))
        };
        let reader = {
            let (stop, last_heard, hub) = (Arc::clone(&stop), Arc::clone(&last_heard), hub.clone());
            std::thread::spawn(move || read_telegrams(line, &hub, &last_heard, &stop))
        };

        // RUN, UI ready long enough ago: `3` follows.
        hub.amplifier.lock().ready_since = Some(Instant::now() - AMPLIFIER_ON_DELAY);
        master
            .write_all(&status_telegrams(b'1', "3", b'3', "132"))
            .unwrap();
        let mut seen = Vec::new();
        read_until(&mut master, b'3', &mut seen);
        assert!(!seen.contains(&b'6'), "never off before on here: {seen:?}");

        // The stop waits for `6` and the amplifier to mute.
        let stopping = {
            let hub = hub.clone();
            std::thread::spawn(move || {
                let started = Instant::now();
                hub.switch_amplifier_off();
                started.elapsed()
            })
        };
        let mut after = Vec::new();
        read_until(&mut master, b'6', &mut after);
        let took = stopping.join().unwrap();
        assert!(took >= AMPLIFIER_OFF_SETTLE, "{took:?}");
        // The sender has just sent `3` and sleeps a second; the stop wakes it.
        assert!(
            took < AMPLIFIER_OFF_SETTLE + Duration::from_millis(500),
            "the sender woke at once: {took:?}"
        );
        assert_eq!(hub.amplifier.lock().sent, Some(false));

        stop.store(true, Ordering::Relaxed);
        sender.join().unwrap().unwrap();
        master.write_all(&[STX, ID_STATE, b'3', ETX]).unwrap();
        reader.join().unwrap().unwrap();
        // Nothing but signs of life after the `6`.
        assert!(after
            .iter()
            .skip_while(|&&b| b != b'6')
            .skip(1)
            .all(|&b| b == b'+'));
    }

    #[test]
    fn the_line_without_the_amplifier_relay_sends_only_signs_of_life() {
        let (mut master, slave_path) = pseudo_terminal();
        let hub = PowerSupplyHub::new(true).with_amplifier_relay(false);
        hub.ui_ready();
        hub.amplifier.lock().ready_since = Some(Instant::now() - AMPLIFIER_ON_DELAY);
        hub.update(|status| *status = status_in(SupplyState::Run));
        let stop = Arc::new(AtomicBool::new(false));
        let line = open_line(Path::new(&slave_path), 38400).expect("open the pseudo-terminal");
        let sender = {
            let (stop, hub) = (Arc::clone(&stop), hub.clone());
            let last_heard = Arc::new(Mutex::new(Instant::now()));
            std::thread::spawn(move || send_alive(line, &hub, &last_heard, &stop))
        };
        let mut seen = Vec::new();
        let mut buffer = [0u8; 16];
        while seen.iter().filter(|&&b| b == b'+').count() < 2 {
            let read = master.read(&mut buffer).unwrap();
            seen.extend_from_slice(&buffer[..read]);
        }
        stop.store(true, Ordering::Relaxed);
        sender.join().unwrap().unwrap();
        // Signs of life and the version question, never `3` or `6`.
        assert!(seen.iter().all(|&b| b == b'+' || b == b'v'), "{seen:?}");
    }

    #[test]
    fn a_version_line_is_recognised_and_nothing_else() {
        assert_eq!(
            FirmwareVersion::parse("V2.4.1"),
            Some(FirmwareVersion {
                major: 2,
                minor: 4,
                patch: 1
            })
        );
        assert_eq!(
            FirmwareVersion::parse("  V2.2.12 ")
                .map(|v| v.to_string())
                .as_deref(),
            Some("V2.2.12")
        );
        for line in [
            "Startup V2.4.1",
            "V2.4",
            "V2.4.1.0",
            "v2.4.1",
            "V2.x.1",
            "V..",
            "Command v",
            "KL15: 1",
            "Spannung (0,1V): 132",
        ] {
            assert_eq!(FirmwareVersion::parse(line), None, "{line:?}");
        }
    }

    #[test]
    fn the_version_is_asked_once_per_talking_connection() {
        let start = Instant::now();
        let mut query = VersionQuery::default();
        let silent = PowerSupplyStatus::default();
        let talking = status_in(SupplyState::PiBoot);

        assert_eq!(
            query.next(&silent, start),
            VersionStep::Nothing,
            "not before it talks"
        );
        assert_eq!(query.next(&talking, start), VersionStep::Ask);
        assert_eq!(
            query.next(&talking, start + Duration::from_secs(1)),
            VersionStep::Nothing
        );

        // Answered: no warning later.
        let answered = PowerSupplyStatus {
            firmware_version: FirmwareVersion::parse("V2.4.1"),
            ..talking
        };
        assert_eq!(
            query.next(&answered, start + VERSION_ANSWER_TIMEOUT * 2),
            VersionStep::Nothing
        );

        // After the supply fell silent it is asked again.
        query.reset();
        assert_eq!(
            query.next(&talking, start + Duration::from_secs(60)),
            VersionStep::Ask
        );
    }

    #[test]
    fn no_answer_is_noted_once() {
        let start = Instant::now();
        let mut query = VersionQuery::default();
        let talking = status_in(SupplyState::Run);
        assert_eq!(query.next(&talking, start), VersionStep::Ask);
        assert_eq!(
            query.next(
                &talking,
                start + VERSION_ANSWER_TIMEOUT - Duration::from_millis(1)
            ),
            VersionStep::Nothing
        );
        assert_eq!(
            query.next(&talking, start + VERSION_ANSWER_TIMEOUT),
            VersionStep::NoAnswer
        );
        assert_eq!(
            query.next(&talking, start + VERSION_ANSWER_TIMEOUT * 3),
            VersionStep::Nothing
        );
    }

    #[test]
    fn the_line_asks_for_the_version_and_keeps_the_answer() {
        let (mut master, slave_path) = pseudo_terminal();
        let hub = PowerSupplyHub::new(true);
        let stop = Arc::new(AtomicBool::new(false));
        let last_heard = Arc::new(Mutex::new(Instant::now()));
        let line = open_line(Path::new(&slave_path), 38400).expect("open the pseudo-terminal");
        let writer = line.try_clone().unwrap();
        let sender = {
            let (stop, last_heard, hub) = (Arc::clone(&stop), Arc::clone(&last_heard), hub.clone());
            std::thread::spawn(move || send_alive(writer, &hub, &last_heard, &stop))
        };
        let reader = {
            let (stop, last_heard, hub) = (Arc::clone(&stop), Arc::clone(&last_heard), hub.clone());
            std::thread::spawn(move || read_telegrams(line, &hub, &last_heard, &stop))
        };

        // Nothing but signs of life until the supply talks.
        let mut seen = Vec::new();
        let mut buffer = [0u8; 16];
        while seen.len() < 2 {
            let read = master.read(&mut buffer).unwrap();
            seen.extend_from_slice(&buffer[..read]);
        }
        assert!(!seen.contains(&b'v'), "{seen:?}");

        master
            .write_all(&status_telegrams(b'1', "2", b'2', "132"))
            .unwrap();
        read_until(&mut master, b'v', &mut seen);

        // The answer, between debug text as V2.3.0 sends it.
        let mut answer = b"Command v\r\nKL15: 1\r\nV2.4.1\r\n".to_vec();
        answer.extend_from_slice(&[STX, ID_COMMAND_RESULT, ACK, ETX]);
        master.write_all(&answer).unwrap();
        let deadline = Instant::now() + Duration::from_secs(3);
        while hub.current().firmware_version.is_none() && Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(10));
        }
        assert_eq!(
            hub.current()
                .firmware_version
                .map(|v| v.to_string())
                .as_deref(),
            Some("V2.4.1")
        );

        // Two more seconds: signs of life, no second question.
        master
            .write_all(&status_telegrams(b'1', "2", b'3', "132"))
            .unwrap();
        let mut more = Vec::new();
        while more.iter().filter(|&&b| b == b'+').count() < 2 {
            let read = master.read(&mut buffer).unwrap();
            more.extend_from_slice(&buffer[..read]);
        }
        assert!(!more.contains(&b'v'), "{more:?}");

        stop.store(true, Ordering::Relaxed);
        sender.join().unwrap().unwrap();
        master.write_all(&[STX, ID_STATE, b'3', ETX]).unwrap();
        reader.join().unwrap().unwrap();
    }

    #[test]
    fn only_a_silent_supply_outside_piboot_and_run_is_left_alone() {
        use SupplyState::*;
        for state in [None, Some(Idle), Some(PowerOn), Some(PowerOff)] {
            assert!(holds_back(true, state), "silent, {state:?}");
            assert!(!holds_back(false, state), "talking, {state:?}");
        }
        for state in [Some(PiBoot), Some(Run)] {
            assert!(!holds_back(true, state), "silent, {state:?}");
            assert!(!holds_back(false, state), "talking, {state:?}");
        }
    }

    /// Everything the master side gets within `window`, without blocking
    /// past it.
    fn read_for(master: &mut File, window: Duration) -> Vec<u8> {
        use std::os::fd::AsRawFd;
        let deadline = Instant::now() + window;
        let mut seen = Vec::new();
        let mut buffer = [0u8; 16];
        loop {
            let left = deadline.saturating_duration_since(Instant::now());
            if left.is_zero() {
                return seen;
            }
            let mut poll = libc::pollfd {
                fd: master.as_raw_fd(),
                events: libc::POLLIN,
                revents: 0,
            };
            // SAFETY: one valid pollfd for a descriptor that stays open.
            let ready = unsafe { libc::poll(&mut poll, 1, left.as_millis() as libc::c_int) };
            if ready > 0 {
                let read = master.read(&mut buffer).expect("read from the master side");
                seen.extend_from_slice(&buffer[..read]);
            }
        }
    }

    /// A sender and reader on a pseudo-terminal; the test plays the supply
    /// on `master`.
    struct LineUnderTest {
        master: File,
        stop: Arc<AtomicBool>,
        sender: std::thread::JoinHandle<Result<()>>,
        reader: std::thread::JoinHandle<Result<()>>,
    }

    impl LineUnderTest {
        fn finish(mut self) {
            self.stop.store(true, Ordering::Relaxed);
            self.sender.join().unwrap().unwrap();
            // The reader returns once the master side sends again after `stop`.
            self.master.write_all(&[STX, ID_STATE, b'3', ETX]).unwrap();
            self.reader.join().unwrap().unwrap();
        }
    }

    /// A line whose supply was last heard `ago` and last seen in `state`.
    fn silent_line(state: Option<SupplyState>, ago: Duration) -> LineUnderTest {
        let (master, slave_path) = pseudo_terminal();
        let hub = PowerSupplyHub::new(true);
        hub.update(|status| status.state = state);
        let stop = Arc::new(AtomicBool::new(false));
        let last_heard = Arc::new(Mutex::new(Instant::now() - ago));
        let line = open_line(Path::new(&slave_path), 38400).expect("open the pseudo-terminal");
        let writer = line.try_clone().unwrap();
        let sender = {
            let (stop, last_heard, hub) = (Arc::clone(&stop), Arc::clone(&last_heard), hub.clone());
            std::thread::spawn(move || send_alive(writer, &hub, &last_heard, &stop))
        };
        let reader = {
            let (stop, last_heard, hub) = (Arc::clone(&stop), Arc::clone(&last_heard), hub.clone());
            std::thread::spawn(move || read_telegrams(line, &hub, &last_heard, &stop))
        };
        LineUnderTest {
            master,
            stop,
            sender,
            reader,
        }
    }

    #[test]
    fn a_silent_supply_in_its_bootloader_gets_nothing_until_it_talks() {
        let mut line = silent_line(None, SILENCE_TIMEOUT + Duration::from_secs(1));

        let quiet = read_for(&mut line.master, Duration::from_millis(2500));
        assert!(quiet.is_empty(), "nothing to a silent supply: {quiet:?}");

        // The firmware has started and reports PIBOOT: signs of life again.
        line.master
            .write_all(&status_telegrams(b'1', "0", b'2', "133"))
            .unwrap();
        let talking = read_for(&mut line.master, Duration::from_millis(2500));
        assert!(talking.contains(&b'+'), "{talking:?}");

        line.finish();
    }

    #[test]
    fn a_silent_supply_last_seen_in_run_keeps_getting_signs_of_life() {
        let mut line = silent_line(
            Some(SupplyState::Run),
            SILENCE_TIMEOUT + Duration::from_secs(1),
        );

        let seen = read_for(&mut line.master, Duration::from_millis(2500));
        assert!(
            seen.iter().filter(|&&b| b == b'+').count() >= 2,
            "only our side may have lost it: {seen:?}"
        );

        line.finish();
    }

    #[test]
    fn a_new_line_sends_at_once_and_holds_back_once_silence_is_clear() {
        let mut line = silent_line(None, Duration::ZERO);

        // Unknown supply, just opened: signs of life as before ...
        let first = read_for(&mut line.master, Duration::from_millis(500));
        assert_eq!(first, b"+");
        // ... until SILENCE_TIMEOUT has passed without a telegram.
        let rest = read_for(
            &mut line.master,
            SILENCE_TIMEOUT + Duration::from_millis(500),
        );
        let last = read_for(&mut line.master, Duration::from_millis(2500));
        assert!(
            last.is_empty(),
            "silent by now, sent {rest:?} then {last:?}"
        );

        line.finish();
    }
}
