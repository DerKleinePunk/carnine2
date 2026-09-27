//! The car power supply AuPrV1_1 (docs/23-power-supply.md, firmware in
//! `firmware/powersupply/`) on a serial line.
//!
//! The supply switches the Pi on with the ignition (KL15) and has a watchdog:
//! once the Pi runs, it expects a sign of life (`+`) at least every few
//! seconds or cuts the power. The backend sends one every second from the
//! moment the line is open, so it also counts while the supply still waits
//! for the Pi to boot. `+` is harmless in every state; the firmware only
//! raises its alive counter (capped at 3) and answers ACK.
//!
//! Every second the supply sends four telegrams `STX <id> <payload> ETX`:
//! ignition, alive counter, state and input voltage. With its debug output on
//! (`#`) text lines come in between; they go to the debug log. What the supply
//! reports is kept in a [`PowerSupplyHub`] for SystemService. Shutting down on
//! POWEROFF, `$` on a shutdown of our own and the service mode follow later
//! (#36).

use std::fs::File;
use std::io::{Read, Write};
use std::os::unix::fs::OpenOptionsExt;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
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
/// The firmware counts the alive counter down once a second.
const ALIVE_INTERVAL: Duration = Duration::from_secs(1);
/// Wait before reopening a line that vanished or failed.
const RETRY_INTERVAL: Duration = Duration::from_secs(3);
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
}

impl PowerSupplyStatus {
    /// What a client watches for; the alive counter moves every second and
    /// is left out.
    fn watched(&self) -> (bool, bool, Option<bool>, Option<SupplyState>, Option<u16>) {
        (
            self.configured,
            self.connected,
            self.ignition,
            self.state,
            self.voltage_tenths,
        )
    }
}

/// Latest status for SystemService; subscribers are woken on changes of
/// everything but the alive counter.
#[derive(Debug, Clone)]
pub struct PowerSupplyHub {
    sender: Arc<watch::Sender<PowerSupplyStatus>>,
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
        }
    }

    pub fn current(&self) -> PowerSupplyStatus {
        *self.sender.borrow()
    }

    pub fn subscribe(&self) -> watch::Receiver<PowerSupplyStatus> {
        self.sender.subscribe()
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

/// Talks to the supply on `device`, reopening it whenever it fails or is not
/// there yet. Runs on its own threads.
pub fn spawn(hub: PowerSupplyHub, device: PathBuf, baud: u32) {
    std::thread::Builder::new()
        .name("power-supply".to_string())
        .spawn(move || loop {
            info!(device = %device.display(), baud, "opening power supply serial line");
            match run_line(&hub, &device, baud) {
                Ok(()) => warn!(device = %device.display(), "power supply serial line closed"),
                Err(err) => {
                    warn!(device = %device.display(), error = %format!("{err:#}"), "power supply serial line failed")
                }
            }
            hub.update(|status| status.connected = false);
            std::thread::sleep(RETRY_INTERVAL);
        })
        .map(|_| ())
        .unwrap_or_else(|err| error!(error = %err, "could not start the power supply thread"));
}

/// One connection: a sender thread writes the sign of life every second and
/// notices silence, while this thread reads telegrams, until either fails.
fn run_line(hub: &PowerSupplyHub, device: &Path, baud: u32) -> Result<()> {
    let file = open_line(device, baud)?;
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
    while !stop.load(Ordering::Relaxed) {
        line.write_all(ALIVE).context("sending the sign of life")?;
        let quiet = last_heard
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .elapsed()
            > SILENCE_TIMEOUT;
        if quiet && !silent {
            warn!("power supply silent, no telegram for a while");
            hub.update(|status| status.connected = false);
        }
        silent = quiet;
        std::thread::sleep(ALIVE_INTERVAL);
    }
    Ok(())
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
            if matches!(telegram, Telegram::Text(_)) {
                log.log(&telegram, &hub.current());
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
        assert!(run_line(&hub, Path::new("/nonexistent/powersupply"), 38400).is_err());
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
}
