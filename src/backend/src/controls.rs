//! Switches and sliders of the "Technik" page (ControlService). What an id
//! means in hardware comes from `[[controls]]` in the configuration; the UI
//! only sees id, name, type and state.
//!
//! Chips: the MCP23017 port expander (switches on its 16 pins), "pwm" (a
//! sysfs PWM channel of the Pi: sliders as duty cycle, e.g. the case fan)
//! and "demo", which only keeps what is set - for WSL and for trying sliders
//! without hardware. Another chip type adds a [`Binding`] variant and its
//! driver.
//!
//! The display backlight is a "pwm" control too, built from
//! `[display.backlight]` with the id [`BACKLIGHT_ID`]: hidden from the
//! "Technik" page, set through SystemService for the options.

use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::sync::Mutex;

use tokio::sync::broadcast;
use tracing::{error, info, warn};

use crate::carnine as proto;
use crate::config::ControlConfig;

pub const LEVEL_MIN: u32 = 0;
pub const LEVEL_MAX: u32 = 100;

const DEFAULT_BUS: &str = "/dev/i2c-1";
const DEFAULT_GPIO_CHIP: &str = "/dev/gpiochip0";
/// /RESET low this long restarts the MCP23017 (datasheet: 1 µs), and the
/// same again before it is talked to.
const RESET_SETTLE: std::time::Duration = std::time::Duration::from_millis(1);
const DEFAULT_MCP23017_ADDRESS: u16 = 0x20;
const DEFAULT_PWM_CHIP: &str = "/sys/class/pwm/pwmchip0";
const DEFAULT_PWM_FREQUENCY_HZ: u32 = 100;
/// Above this the period would be under a microsecond.
const MAX_PWM_FREQUENCY_HZ: u32 = 1_000_000;
const MAX_KICK: std::time::Duration = std::time::Duration::from_secs(5);
/// How long an exported channel may take until udev has handed its files to
/// the gpio group (61-carnine-pwm.rules).
const PWM_EXPORT_WAIT: std::time::Duration = std::time::Duration::from_secs(2);

pub use crate::config::BACKLIGHT_ID;

// MCP23017 registers with IOCON.BANK = 0 (the reset state): A and B side by
// side, so one write sets both halves.
const MCP23017_IODIRA: u8 = 0x00;
const MCP23017_OLATA: u8 = 0x14;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Switch,
    Slider,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Binding {
    Demo,
    Mcp23017 {
        bus: PathBuf,
        address: u16,
        pin: u8,
        /// GPIO chip and line that hold /RESET high, if the board needs it.
        reset: Option<(PathBuf, u32)>,
    },
    Pwm {
        chip: PathBuf,
        channel: u32,
        period_ns: u64,
        /// Duty cycle in percent at the lowest level above off.
        min_level: u32,
        /// Full duty for this long when switching on from off.
        kick: std::time::Duration,
        /// Level 0 stops the output (fan); without it 0 is `min_level`
        /// (backlight, never dark).
        off_at_zero: bool,
        /// Stop the output when the backend exits, like the MCP23017 reset.
        off_on_exit: bool,
    },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Control {
    pub id: String,
    pub name: String,
    pub kind: Kind,
    pub restore: bool,
    pub binding: Binding,
    /// Not listed for the "Technik" page (the backlight).
    pub hidden: bool,
    /// Goes to full while the CPU is overheated (`boost_on_overheat`).
    pub boost: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Value {
    On(bool),
    Level(u32),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ControlState {
    pub id: String,
    pub value: Value,
    pub available: bool,
}

#[derive(Debug, PartialEq, Eq)]
pub enum SetError {
    NotFound,
    InvalidValue(String),
    Unavailable(String),
}

impl Control {
    /// Checks one `[[controls]]` entry; the error says what is wrong.
    pub fn from_config(entry: &ControlConfig) -> Result<Self, String> {
        let id = entry.id.trim();
        if id.is_empty() {
            return Err("a control without id".to_owned());
        }
        if entry.name.trim().is_empty() {
            return Err(format!("control {id}: no name"));
        }
        let kind = match entry.kind.trim().to_ascii_lowercase().as_str() {
            "switch" => Kind::Switch,
            "slider" => Kind::Slider,
            other => return Err(format!("control {id}: unknown type {other:?}")),
        };
        let binding = match entry.chip.trim().to_ascii_lowercase().as_str() {
            "demo" => Binding::Demo,
            "mcp23017" => {
                if kind != Kind::Switch {
                    return Err(format!(
                        "control {id}: the MCP23017 only switches on and off"
                    ));
                }
                let pin = entry
                    .pin
                    .ok_or_else(|| format!("control {id}: an MCP23017 control needs a pin"))?;
                if pin > 15 {
                    return Err(format!("control {id}: MCP23017 pin {pin} is not 0-15"));
                }
                let address = entry.address.unwrap_or(DEFAULT_MCP23017_ADDRESS);
                if !(0x20..=0x27).contains(&address) {
                    return Err(format!(
                        "control {id}: MCP23017 address {address:#04x} is not 0x20-0x27"
                    ));
                }
                Binding::Mcp23017 {
                    bus: entry
                        .bus
                        .clone()
                        .unwrap_or_else(|| PathBuf::from(DEFAULT_BUS)),
                    address,
                    pin,
                    reset: entry.reset_gpio.map(|line| {
                        (
                            entry
                                .gpio_chip
                                .clone()
                                .unwrap_or_else(|| PathBuf::from(DEFAULT_GPIO_CHIP)),
                            line,
                        )
                    }),
                }
            }
            "pwm" => {
                let channel = entry
                    .channel
                    .ok_or_else(|| format!("control {id}: a PWM control needs a channel"))?;
                let frequency = entry.frequency.unwrap_or(DEFAULT_PWM_FREQUENCY_HZ);
                if !(1..=MAX_PWM_FREQUENCY_HZ).contains(&frequency) {
                    return Err(format!(
                        "control {id}: PWM frequency {frequency} Hz is not 1-{MAX_PWM_FREQUENCY_HZ}"
                    ));
                }
                let min_level = entry.min_level.unwrap_or(0);
                if min_level > LEVEL_MAX {
                    return Err(format!(
                        "control {id}: min_level {min_level} is not 0-{LEVEL_MAX}"
                    ));
                }
                let kick = std::time::Duration::from_millis(entry.kick_ms.unwrap_or(0));
                if kick > MAX_KICK {
                    return Err(format!(
                        "control {id}: kick_ms {} is more than {}",
                        kick.as_millis(),
                        MAX_KICK.as_millis()
                    ));
                }
                Binding::Pwm {
                    chip: entry
                        .pwm_chip
                        .clone()
                        .unwrap_or_else(|| PathBuf::from(DEFAULT_PWM_CHIP)),
                    channel,
                    period_ns: 1_000_000_000 / u64::from(frequency),
                    min_level,
                    kick,
                    off_at_zero: !entry.backlight,
                    off_on_exit: !entry.backlight,
                }
            }
            other => return Err(format!("control {id}: unknown chip {other:?}")),
        };
        if entry.backlight && (kind != Kind::Slider || !matches!(binding, Binding::Pwm { .. })) {
            return Err(format!("control {id}: the backlight is a PWM slider"));
        }
        if !entry.backlight && id == BACKLIGHT_ID {
            return Err(format!(
                "control {id}: the id is kept for [display.backlight]"
            ));
        }
        Ok(Self {
            id: id.to_owned(),
            name: entry.name.trim().to_owned(),
            kind,
            restore: entry.restore.unwrap_or(kind == Kind::Slider),
            binding,
            hidden: entry.backlight,
            boost: entry.boost_on_overheat.unwrap_or(false),
        })
    }

    /// The value without a saved one: off, but the backlight starts bright.
    fn off_value(&self) -> Value {
        match self.kind {
            Kind::Switch => Value::On(false),
            Kind::Slider if self.hidden => Value::Level(LEVEL_MAX),
            Kind::Slider => Value::Level(LEVEL_MIN),
        }
    }
}

/// Duty cycle in nanoseconds for a value of a PWM control: on and level
/// 100 are full, off and level 0 nothing (or `min_level` where 0 is not
/// off), the levels between spread over `min_level`..100 %.
fn pwm_duty_ns(value: Value, period_ns: u64, min_level: u32, off_at_zero: bool) -> u64 {
    let percent = match value {
        Value::On(true) => u64::from(LEVEL_MAX),
        Value::On(false) => 0,
        Value::Level(0) if off_at_zero => 0,
        Value::Level(level) => {
            let level = u64::from(level.min(LEVEL_MAX));
            let min = u64::from(min_level);
            min + (u64::from(LEVEL_MAX) - min) * level / u64::from(LEVEL_MAX)
        }
    };
    period_ns * percent / u64::from(LEVEL_MAX)
}

/// One PWM channel: period and duty cycle in nanoseconds, enabled.
pub trait PwmChannel: Send {
    fn apply(&mut self, period_ns: u64, duty_ns: u64) -> io::Result<()>;
    /// Stops the output (the line goes low).
    fn disable(&mut self) -> io::Result<()>;
}

/// Opens channel N of a PWM chip, e.g. /sys/class/pwm/pwmchip0.
pub type PwmOpener = Box<dyn Fn(&Path, u32) -> io::Result<Box<dyn PwmChannel>> + Send + Sync>;

/// A channel under /sys/class/pwm/pwmchipN/pwmM.
struct SysfsPwm {
    dir: PathBuf,
    period_ns: Option<u64>,
    enabled: bool,
}

impl SysfsPwm {
    fn write(&self, name: &str, value: impl std::fmt::Display) -> io::Result<()> {
        let path = self.dir.join(name);
        std::fs::write(&path, value.to_string())
            .map_err(|error| io::Error::new(error.kind(), format!("{}: {error}", path.display())))
    }
}

impl PwmChannel for SysfsPwm {
    /// The duty cycle may never exceed the period, so it goes to 0 before a
    /// new period and to its value after.
    fn apply(&mut self, period_ns: u64, duty_ns: u64) -> io::Result<()> {
        if self.period_ns != Some(period_ns) {
            self.write("duty_cycle", 0)?;
            self.write("period", period_ns)?;
            self.period_ns = Some(period_ns);
        }
        self.write("duty_cycle", duty_ns.min(period_ns))?;
        if !self.enabled {
            self.write("enable", 1)?;
            self.enabled = true;
        }
        Ok(())
    }

    fn disable(&mut self) -> io::Result<()> {
        self.write("enable", 0)?;
        self.enabled = false;
        Ok(())
    }
}

/// Exports the channel unless it is, then waits until its files can be
/// written: udev hands them to the gpio group only after the export.
pub fn linux_pwm_opener() -> PwmOpener {
    Box::new(|chip, channel| {
        let dir = chip.join(format!("pwm{channel}"));
        if !dir.exists() {
            std::fs::write(chip.join("export"), channel.to_string()).map_err(|error| {
                io::Error::new(
                    error.kind(),
                    format!(
                        "exporting PWM channel {channel} of {}: {error}",
                        chip.display()
                    ),
                )
            })?;
        }
        let started = std::time::Instant::now();
        loop {
            match std::fs::OpenOptions::new()
                .write(true)
                .open(dir.join("duty_cycle"))
            {
                Ok(_) => break,
                Err(error) if started.elapsed() >= PWM_EXPORT_WAIT => {
                    return Err(io::Error::new(
                        error.kind(),
                        format!("{}: {error}", dir.join("duty_cycle").display()),
                    ))
                }
                Err(_) => std::thread::sleep(std::time::Duration::from_millis(20)),
            }
        }
        Ok(Box::new(SysfsPwm {
            dir,
            period_ns: None,
            enabled: false,
        }) as Box<dyn PwmChannel>)
    })
}

/// One PWM channel in use: its driver while it can be driven.
struct PwmOutput {
    channel: Option<Box<dyn PwmChannel>>,
    available: bool,
    missing_reported: bool,
}

type PwmKey = (PathBuf, u32);

/// Writes to and reads from devices on an I2C bus; the real one goes
/// through /dev/i2c-N.
pub trait I2cBus: Send {
    fn write(&mut self, address: u16, bytes: &[u8]) -> io::Result<()>;
    /// Reads `buffer.len()` bytes starting at `register`.
    fn read(&mut self, address: u16, register: u8, buffer: &mut [u8]) -> io::Result<()>;
}

/// Opens the bus at a path, e.g. /dev/i2c-1.
pub type BusOpener = Box<dyn Fn(&Path) -> io::Result<Box<dyn I2cBus>> + Send + Sync>;

/// /dev/i2c-N through the I2C_SLAVE ioctl.
struct LinuxI2cBus {
    file: std::fs::File,
}

impl LinuxI2cBus {
    fn select(&mut self, address: u16) -> io::Result<()> {
        use std::os::fd::AsRawFd;
        const I2C_SLAVE: libc::c_ulong = 0x0703;
        // SAFETY: plain ioctl on an open descriptor with an integer argument.
        let result = unsafe {
            libc::ioctl(
                self.file.as_raw_fd(),
                I2C_SLAVE as _,
                libc::c_ulong::from(address),
            )
        };
        if result < 0 {
            return Err(io::Error::last_os_error());
        }
        Ok(())
    }
}

impl I2cBus for LinuxI2cBus {
    fn write(&mut self, address: u16, bytes: &[u8]) -> io::Result<()> {
        use std::io::Write;
        self.select(address)?;
        let written = self.file.write(bytes)?;
        if written != bytes.len() {
            return Err(io::Error::new(
                io::ErrorKind::WriteZero,
                format!("wrote {written} of {} bytes", bytes.len()),
            ));
        }
        Ok(())
    }

    /// Register pointer first, then the bytes; the MCP23017 keeps the
    /// pointer across the stop in between.
    fn read(&mut self, address: u16, register: u8, buffer: &mut [u8]) -> io::Result<()> {
        use std::io::Read;
        self.write(address, &[register])?;
        let read = self.file.read(buffer)?;
        if read != buffer.len() {
            return Err(io::Error::new(
                io::ErrorKind::UnexpectedEof,
                format!("read {read} of {} bytes", buffer.len()),
            ));
        }
        Ok(())
    }
}

/// An output line that holds a chip's /RESET.
pub trait ResetLine: Send {
    fn set(&mut self, high: bool) -> io::Result<()>;
}

/// Requests a GPIO line as output, already high, from a GPIO chip.
pub type ResetOpener = Box<dyn Fn(&Path, u32) -> io::Result<Box<dyn ResetLine>> + Send + Sync>;

struct CdevResetLine {
    request: gpiocdev::Request,
    line: u32,
}

impl ResetLine for CdevResetLine {
    fn set(&mut self, high: bool) -> io::Result<()> {
        let value = if high {
            gpiocdev::line::Value::Active
        } else {
            gpiocdev::line::Value::Inactive
        };
        self.request
            .set_value(self.line, value)
            .map_err(|error| io::Error::other(error.to_string()))
    }
}

pub fn linux_reset_opener() -> ResetOpener {
    Box::new(|chip, line| {
        let request = gpiocdev::Request::builder()
            .on_chip(chip)
            .with_consumer("carnine-backend")
            .with_line(line)
            .as_output(gpiocdev::line::Value::Active)
            .request()
            .map_err(|error| io::Error::other(error.to_string()))?;
        Ok(Box::new(CdevResetLine { request, line }) as Box<dyn ResetLine>)
    })
}

pub fn linux_bus_opener() -> BusOpener {
    Box::new(|path| {
        let file = std::fs::OpenOptions::new()
            .read(true)
            .write(true)
            .open(path)?;
        Ok(Box::new(LinuxI2cBus { file }) as Box<dyn I2cBus>)
    })
}

/// One MCP23017: which of its pins are configured, and their output latch.
struct Mcp23017 {
    bus_path: PathBuf,
    address: u16,
    bus: Option<Box<dyn I2cBus>>,
    used_pins: u16,
    latch: u16,
    available: bool,
    reset: Option<(PathBuf, u32)>,
    reset_line: Option<Box<dyn ResetLine>>,
    /// Its absence is in the log already; the retries every few seconds
    /// stay quiet until it answers again.
    missing_reported: bool,
}

impl Mcp23017 {
    fn bus(&mut self, opener: &BusOpener) -> io::Result<&mut Box<dyn I2cBus>> {
        if self.bus.is_none() {
            self.bus = Some(opener(&self.bus_path)?);
        }
        Ok(self.bus.as_mut().expect("just opened"))
    }

    /// Takes the chip out of reset where a GPIO holds it: the first time by
    /// requesting the line high, after that with a short low pulse, so a
    /// chip that stopped answering starts from scratch.
    fn release_reset(&mut self, reset_opener: &ResetOpener) -> io::Result<()> {
        let Some((chip, line)) = &self.reset else {
            return Ok(());
        };
        match self.reset_line.as_mut() {
            None => {
                let reset_line = reset_opener(chip, *line).map_err(|error| {
                    io::Error::new(
                        error.kind(),
                        format!("reset GPIO {line} on {}: {error}", chip.display()),
                    )
                })?;
                self.reset_line = Some(reset_line);
            }
            Some(reset_line) => {
                reset_line.set(false)?;
                std::thread::sleep(RESET_SETTLE);
                reset_line.set(true)?;
            }
        }
        std::thread::sleep(RESET_SETTLE);
        Ok(())
    }

    /// Latch first, then the direction: a pin turns into an output already
    /// at its right level.
    fn initialise(&mut self, opener: &BusOpener, reset_opener: &ResetOpener) -> io::Result<()> {
        self.release_reset(reset_opener)?;
        let [latch_a, latch_b] = self.latch.to_le_bytes();
        let [inputs_a, inputs_b] = (!self.used_pins).to_le_bytes();
        let address = self.address;
        let bus = self.bus(opener)?;
        bus.write(address, &[MCP23017_OLATA, latch_a, latch_b])?;
        bus.write(address, &[MCP23017_IODIRA, inputs_a, inputs_b])
    }

    /// Whether the chip still holds the directions it was given. A chip
    /// that lost its supply or saw a reset for a moment answers again but
    /// is back at all inputs, and writing the latch alone switches nothing.
    fn holds_setup(&mut self, opener: &BusOpener) -> io::Result<bool> {
        let expected = (!self.used_pins).to_le_bytes();
        let address = self.address;
        let mut directions = [0u8; 2];
        self.bus(opener)?
            .read(address, MCP23017_IODIRA, &mut directions)?;
        Ok(directions == expected)
    }

    fn write_latch(&mut self, opener: &BusOpener) -> io::Result<()> {
        let [latch_a, latch_b] = self.latch.to_le_bytes();
        let address = self.address;
        self.bus(opener)?
            .write(address, &[MCP23017_OLATA, latch_a, latch_b])
    }
}

type ChipKey = (PathBuf, u16);

struct Inner {
    controls: Vec<Control>,
    states: Vec<ControlState>,
    chips: HashMap<ChipKey, Mcp23017>,
    pwm_outputs: HashMap<PwmKey, PwmOutput>,
    opener: BusOpener,
    reset_opener: ResetOpener,
    pwm_opener: PwmOpener,
    database_path: Option<PathBuf>,
    /// Set by [`ControlHub::shut_down`]: nothing touches a chip after it, so
    /// the retry every few seconds cannot lift the reset again.
    shutting_down: bool,
    /// The CPU is overheated and the boosted controls run at full.
    boosting: bool,
    /// Own values of the boosted controls while `boosting`.
    normal: HashMap<String, Value>,
}

/// Keeps the state of every control and drives the chips. Clients read the
/// list, subscribe to changes and set values through it.
pub struct ControlHub {
    inner: Mutex<Inner>,
    changes: broadcast::Sender<ControlState>,
}

impl std::fmt::Debug for ControlHub {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("ControlHub")
            .field("states", &self.lock().states)
            .finish_non_exhaustive()
    }
}

impl ControlHub {
    /// Builds the controls from the configuration, skipping broken entries
    /// and duplicate ids with an error in the log, restores the saved values
    /// and puts them on the chips. A chip that does not answer leaves its
    /// controls unavailable; [`ControlHub::retry_unavailable`] tries again.
    pub fn new(
        entries: &[ControlConfig],
        opener: BusOpener,
        reset_opener: ResetOpener,
        database_path: Option<PathBuf>,
    ) -> Self {
        Self::with_pwm(
            entries,
            opener,
            reset_opener,
            linux_pwm_opener(),
            database_path,
        )
    }

    /// [`ControlHub::new`] with its own way to open PWM channels.
    pub fn with_pwm(
        entries: &[ControlConfig],
        opener: BusOpener,
        reset_opener: ResetOpener,
        pwm_opener: PwmOpener,
        database_path: Option<PathBuf>,
    ) -> Self {
        let mut controls: Vec<Control> = Vec::new();
        for entry in entries {
            match Control::from_config(entry) {
                Ok(control) if controls.iter().any(|known| known.id == control.id) => {
                    error!(id = %control.id, "control skipped: its id is used twice");
                }
                Ok(control) => controls.push(control),
                Err(reason) => error!(reason = %reason, "control skipped"),
            }
        }
        let saved = database_path
            .as_deref()
            .and_then(|path| {
                crate::database::Database::open(path)
                    .and_then(|database| database.load_control_states())
                    .map_err(|error| warn!(error = %error, "loading control states failed"))
                    .ok()
            })
            .unwrap_or_default();
        let states = controls
            .iter()
            .map(|control| {
                let saved = saved.get(&control.id).copied();
                let value = match (control.restore, control.kind, saved) {
                    (true, Kind::Switch, Some((Some(on), _))) => Value::On(on),
                    (true, Kind::Slider, Some((_, Some(level)))) => {
                        Value::Level(level.min(LEVEL_MAX))
                    }
                    _ => control.off_value(),
                };
                ControlState {
                    id: control.id.clone(),
                    value,
                    available: true,
                }
            })
            .collect::<Vec<_>>();

        let mut chips: HashMap<ChipKey, Mcp23017> = HashMap::new();
        for (control, state) in controls.iter().zip(&states) {
            if let Binding::Mcp23017 {
                bus,
                address,
                pin,
                reset,
            } = &control.binding
            {
                let chip = chips
                    .entry((bus.clone(), *address))
                    .or_insert_with(|| Mcp23017 {
                        bus_path: bus.clone(),
                        address: *address,
                        bus: None,
                        used_pins: 0,
                        latch: 0,
                        available: false,
                        reset: reset.clone(),
                        reset_line: None,
                        missing_reported: false,
                    });
                if chip.reset != *reset {
                    warn!(id = %control.id, "controls of one MCP23017 name different reset GPIOs; the first one counts");
                }
                if chip.used_pins & (1 << pin) != 0 {
                    warn!(id = %control.id, pin, "MCP23017 pin used by two controls");
                }
                chip.used_pins |= 1 << pin;
                if state.value == Value::On(true) {
                    chip.latch |= 1 << pin;
                }
            }
        }
        let mut pwm_outputs: HashMap<PwmKey, PwmOutput> = HashMap::new();
        for control in &controls {
            if let Binding::Pwm { chip, channel, .. } = &control.binding {
                if pwm_outputs.contains_key(&(chip.clone(), *channel)) {
                    warn!(id = %control.id, channel, "PWM channel used by two controls");
                }
                pwm_outputs.insert(
                    (chip.clone(), *channel),
                    PwmOutput {
                        channel: None,
                        available: false,
                        missing_reported: false,
                    },
                );
            }
        }
        let (changes, _) = broadcast::channel(64);
        let hub = Self {
            inner: Mutex::new(Inner {
                controls,
                states,
                chips,
                pwm_outputs,
                opener,
                reset_opener,
                pwm_opener,
                database_path,
                shutting_down: false,
                boosting: false,
                normal: HashMap::new(),
            }),
            changes,
        };
        {
            let mut inner = hub.lock();
            let keys: Vec<ChipKey> = inner.chips.keys().cloned().collect();
            for key in keys {
                Self::bring_up(&mut inner, &key);
            }
            Self::bring_up_pwm(&mut inner);
            Self::refresh_availability(&mut inner);
            info!(controls = inner.controls.len(), "controls ready");
        }
        hub
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, Inner> {
        self.inner
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    fn bring_up(inner: &mut Inner, key: &ChipKey) -> bool {
        let Inner {
            chips,
            opener,
            reset_opener,
            ..
        } = inner;
        let chip = chips.get_mut(key).expect("known chip");
        match chip.initialise(opener, reset_opener) {
            Ok(()) => {
                if !chip.available {
                    info!(bus = %key.0.display(), address = format!("{:#04x}", key.1), "MCP23017 answers");
                }
                chip.available = true;
                chip.missing_reported = false;
            }
            Err(error) => {
                if !chip.missing_reported {
                    warn!(bus = %key.0.display(), address = format!("{:#04x}", key.1), error = %error, "MCP23017 does not answer");
                    chip.missing_reported = true;
                }
                chip.available = false;
                chip.bus = None;
            }
        }
        chip.available
    }

    /// Opens the PWM channels that are not driven yet and puts the current
    /// value on them, a fan with its start-up kick.
    fn bring_up_pwm(inner: &mut Inner) {
        for index in 0..inner.controls.len() {
            let Binding::Pwm { chip, channel, .. } = &inner.controls[index].binding else {
                continue;
            };
            let key = (chip.clone(), *channel);
            if inner
                .pwm_outputs
                .get(&key)
                .is_some_and(|output| output.available)
            {
                continue;
            }
            let control = inner.controls[index].clone();
            let value = inner.states[index].value;
            let off = control.off_value();
            if let Err(error) = Self::drive_pwm(inner, &control, off, value) {
                let output = inner.pwm_outputs.get_mut(&key).expect("known channel");
                if !output.missing_reported {
                    warn!(id = %control.id, chip = %key.0.display(), channel = key.1, error = %error, "PWM channel cannot be driven");
                    output.missing_reported = true;
                }
            }
        }
    }

    /// Puts `value` on the PWM channel of `control`, opening it first if
    /// needed; from off to on a kick at full duty comes first. Marks the
    /// channel available or not.
    fn drive_pwm(
        inner: &mut Inner,
        control: &Control,
        previous: Value,
        value: Value,
    ) -> io::Result<()> {
        let Binding::Pwm {
            chip,
            channel,
            period_ns,
            min_level,
            kick,
            off_at_zero,
            ..
        } = &control.binding
        else {
            return Ok(());
        };
        let Inner {
            pwm_outputs,
            pwm_opener,
            ..
        } = inner;
        let output = pwm_outputs
            .get_mut(&(chip.clone(), *channel))
            .expect("known channel");
        let result = (|| {
            if output.channel.is_none() {
                output.channel = Some(pwm_opener(chip, *channel)?);
            }
            let driver = output.channel.as_mut().expect("just opened");
            let duty = pwm_duty_ns(value, *period_ns, *min_level, *off_at_zero);
            let was_off = !output.available
                || pwm_duty_ns(previous, *period_ns, *min_level, *off_at_zero) == 0;
            if duty > 0 && was_off && !kick.is_zero() {
                driver.apply(*period_ns, *period_ns)?;
                std::thread::sleep(*kick);
            }
            driver.apply(*period_ns, duty)
        })();
        match &result {
            Ok(()) => {
                if !output.available {
                    info!(id = %control.id, chip = %chip.display(), channel, "PWM channel driven");
                }
                output.available = true;
                output.missing_reported = false;
            }
            Err(_) => {
                output.available = false;
                output.channel = None;
            }
        }
        result
    }

    /// Sets `available` of every state from its chip; returns the states
    /// that changed.
    fn refresh_availability(inner: &mut Inner) -> Vec<ControlState> {
        let mut changed = Vec::new();
        for (control, state) in inner.controls.iter().zip(inner.states.iter_mut()) {
            let available = match &control.binding {
                Binding::Demo => true,
                Binding::Mcp23017 { bus, address, .. } => inner
                    .chips
                    .get(&(bus.clone(), *address))
                    .is_some_and(|chip| chip.available),
                Binding::Pwm { chip, channel, .. } => inner
                    .pwm_outputs
                    .get(&(chip.clone(), *channel))
                    .is_some_and(|output| output.available),
            };
            if state.available != available {
                state.available = available;
                changed.push(state.clone());
            }
        }
        changed
    }

    pub fn controls(&self) -> Vec<Control> {
        self.lock().controls.clone()
    }

    pub fn states(&self) -> Vec<ControlState> {
        self.lock().states.clone()
    }

    /// The state of one control, `None` for an unknown id.
    pub fn state(&self, id: &str) -> Option<ControlState> {
        self.lock()
            .states
            .iter()
            .find(|state| state.id == id)
            .cloned()
    }

    /// Changes after the current states; [`ControlHub::states`] first, then
    /// this, gives a client the full picture.
    pub fn subscribe(&self) -> broadcast::Receiver<ControlState> {
        self.changes.subscribe()
    }

    pub fn set(&self, id: &str, value: Value) -> Result<ControlState, SetError> {
        let mut inner = self.lock();
        if inner.shutting_down {
            return Err(SetError::Unavailable(
                "the backend is shutting down".to_owned(),
            ));
        }
        let index = inner
            .controls
            .iter()
            .position(|control| control.id == id)
            .ok_or(SetError::NotFound)?;
        let control = inner.controls[index].clone();
        match (control.kind, value) {
            (Kind::Switch, Value::On(_)) => {}
            (Kind::Slider, Value::Level(level)) if level <= LEVEL_MAX => {}
            (Kind::Slider, Value::Level(level)) => {
                return Err(SetError::InvalidValue(format!(
                    "level {level} is not {LEVEL_MIN}-{LEVEL_MAX}"
                )))
            }
            (Kind::Switch, Value::Level(_)) => {
                return Err(SetError::InvalidValue(format!("{id} is a switch")))
            }
            (Kind::Slider, Value::On(_)) => {
                return Err(SetError::InvalidValue(format!("{id} is a slider")))
            }
        }

        // While the CPU is overheated a boosted control stays at full; what
        // is set now is its own value for afterwards.
        if inner.boosting && control.boost {
            inner.normal.insert(id.to_owned(), value);
            Self::save(&inner, id, value);
            info!(id, ?value, "control set for after the overheat boost");
            let state = inner.states[index].clone();
            let _ = self.changes.send(state.clone());
            return Ok(state);
        }

        self.put_on_hardware(&mut inner, index, value)?;
        let state = ControlState {
            id: id.to_owned(),
            value,
            available: true,
        };
        inner.states[index] = state.clone();
        Self::save(&inner, id, value);
        info!(id, ?value, "control set");
        let _ = self.changes.send(state.clone());
        Ok(state)
    }

    /// Writes `value` of control `index` to its chip. On failure the
    /// controls of that chip turn unavailable (and are announced).
    fn put_on_hardware(
        &self,
        inner: &mut Inner,
        index: usize,
        value: Value,
    ) -> Result<(), SetError> {
        let control = inner.controls[index].clone();
        let id = control.id.as_str();
        if let Binding::Mcp23017 {
            bus, address, pin, ..
        } = &control.binding
        {
            let key = (bus.clone(), *address);
            let Inner {
                chips,
                opener,
                reset_opener,
                ..
            } = &mut *inner;
            let chip = chips.get_mut(&key).expect("known chip");
            let previous = chip.latch;
            if value == Value::On(true) {
                chip.latch |= 1 << pin;
            } else {
                chip.latch &= !(1 << pin);
            }
            // A chip that was away gets its whole setup again.
            let result = if chip.available {
                chip.write_latch(opener)
            } else {
                chip.initialise(opener, reset_opener)
            };
            if let Err(error) = result {
                chip.latch = previous;
                chip.available = false;
                chip.missing_reported = true;
                chip.bus = None;
                warn!(id, error = %error, "setting a control failed");
                for state in Self::refresh_availability(inner) {
                    let _ = self.changes.send(state);
                }
                return Err(SetError::Unavailable(error.to_string()));
            }
            chip.available = true;
            chip.missing_reported = false;
            for state in Self::refresh_availability(inner) {
                if state.id != id {
                    let _ = self.changes.send(state);
                }
            }
        }

        if matches!(control.binding, Binding::Pwm { .. }) {
            let previous = inner.states[index].value;
            if let Err(error) = Self::drive_pwm(inner, &control, previous, value) {
                warn!(id, error = %error, "setting a control failed");
                for state in Self::refresh_availability(inner) {
                    let _ = self.changes.send(state);
                }
                return Err(SetError::Unavailable(error.to_string()));
            }
            for state in Self::refresh_availability(inner) {
                if state.id != id {
                    let _ = self.changes.send(state);
                }
            }
        }
        Ok(())
    }

    fn save(inner: &Inner, id: &str, value: Value) {
        let Some(path) = &inner.database_path else {
            return;
        };
        let (switch_on, level) = match value {
            Value::On(on) => (Some(on), None),
            Value::Level(level) => (None, Some(level)),
        };
        if let Err(error) = crate::database::Database::open(path)
            .and_then(|database| database.save_control_state(id, switch_on, level))
        {
            warn!(id, error = %error, "saving a control state failed");
        }
    }

    /// Follows the CPU overheat warning (#70): on, every control with
    /// `boost_on_overheat` goes to full (on, 100 %) and keeps its own value
    /// aside; off, each goes back to its own value. Nothing of it is saved,
    /// so a restart during the warning starts from the own value.
    pub fn set_overheated(&self, overheated: bool) {
        let mut inner = self.lock();
        if inner.shutting_down || inner.boosting == overheated {
            return;
        }
        inner.boosting = overheated;
        if overheated {
            warn!("CPU overheated: boosting the controls with boost_on_overheat");
        } else {
            info!("CPU cooled down: boosted controls back to their own values");
        }
        for index in 0..inner.controls.len() {
            let control = inner.controls[index].clone();
            if !control.boost {
                continue;
            }
            let target = if overheated {
                let own = inner.states[index].value;
                inner.normal.insert(control.id.clone(), own);
                match control.kind {
                    Kind::Switch => Value::On(true),
                    Kind::Slider => Value::Level(LEVEL_MAX),
                }
            } else {
                inner
                    .normal
                    .remove(&control.id)
                    .unwrap_or(inner.states[index].value)
            };
            // A chip that does not answer keeps the old value in the state,
            // so its retry puts back what the state says.
            if self.put_on_hardware(&mut inner, index, target).is_ok() {
                inner.states[index].value = target;
                info!(id = %control.id, value = ?target, "control follows the CPU temperature");
                let _ = self.changes.send(inner.states[index].clone());
            }
        }
    }

    /// Puts every chip with a reset GPIO back into reset, which turns all
    /// its outputs off, and stops the PWM outputs that go off on exit (not
    /// the backlight), before the backend exits.
    pub fn shut_down(&self) {
        let mut inner = self.lock();
        inner.shutting_down = true;
        let stop: Vec<PwmKey> = inner
            .controls
            .iter()
            .filter_map(|control| match &control.binding {
                Binding::Pwm {
                    chip,
                    channel,
                    off_on_exit: true,
                    ..
                } => Some((chip.clone(), *channel)),
                _ => None,
            })
            .collect();
        for key in stop {
            if let Some(driver) = inner
                .pwm_outputs
                .get_mut(&key)
                .and_then(|output| output.channel.as_mut())
            {
                match driver.disable() {
                    Ok(()) => info!(chip = %key.0.display(), channel = key.1, "PWM output stopped"),
                    Err(error) => warn!(error = %error, "stopping a PWM output failed"),
                }
            }
        }
        for (key, chip) in inner.chips.iter_mut() {
            if let Some(reset_line) = chip.reset_line.as_mut() {
                match reset_line.set(false) {
                    Ok(()) => {
                        info!(bus = %key.0.display(), address = format!("{:#04x}", key.1), "MCP23017 held in reset")
                    }
                    Err(error) => warn!(error = %error, "putting the MCP23017 into reset failed"),
                }
            }
        }
    }

    /// Checks that the answering chips still hold their setup and sets up
    /// again those that lost it, then tries the chips that did not answer
    /// and puts the current values on them; meant to run every few seconds.
    pub fn retry_unavailable(&self) {
        let mut inner = self.lock();
        if inner.shutting_down {
            return;
        }
        let answering: Vec<ChipKey> = inner
            .chips
            .iter()
            .filter(|(_, chip)| chip.available)
            .map(|(key, _)| key.clone())
            .collect();
        for key in answering {
            Self::check_setup(&mut inner, &key);
        }
        let keys: Vec<ChipKey> = inner
            .chips
            .iter()
            .filter(|(_, chip)| !chip.available)
            .map(|(key, _)| key.clone())
            .collect();
        for key in keys {
            Self::bring_up(&mut inner, &key);
        }
        Self::bring_up_pwm(&mut inner);
        for state in Self::refresh_availability(&mut inner) {
            let _ = self.changes.send(state);
        }
    }

    /// Reads back the directions of an answering chip: lost → set up again
    /// (latch first, then the direction), no answer → unavailable until the
    /// retry finds it.
    fn check_setup(inner: &mut Inner, key: &ChipKey) {
        let Inner {
            chips,
            opener,
            reset_opener,
            ..
        } = inner;
        let chip = chips.get_mut(key).expect("known chip");
        let address = format!("{:#04x}", key.1);
        match chip.holds_setup(opener) {
            Ok(true) => {}
            Ok(false) => {
                warn!(bus = %key.0.display(), address, "MCP23017 lost its setup, setting it up again");
                if let Err(error) = chip.initialise(opener, reset_opener) {
                    warn!(bus = %key.0.display(), address, error = %error, "MCP23017 does not answer");
                    chip.available = false;
                    chip.missing_reported = true;
                    chip.bus = None;
                }
            }
            Err(error) => {
                warn!(bus = %key.0.display(), address, error = %error, "MCP23017 does not answer");
                chip.available = false;
                chip.missing_reported = true;
                chip.bus = None;
            }
        }
    }
}

/// ControlService: the [`ControlHub`] over gRPC.
pub struct ControlServiceImpl {
    hub: std::sync::Arc<ControlHub>,
}

impl ControlServiceImpl {
    pub fn new(hub: std::sync::Arc<ControlHub>) -> Self {
        Self { hub }
    }
}

fn state_to_proto(state: &ControlState) -> proto::ControlState {
    proto::ControlState {
        id: state.id.clone(),
        value: Some(match state.value {
            Value::On(on) => proto::control_state::Value::On(on),
            Value::Level(level) => proto::control_state::Value::Level(level),
        }),
        available: state.available,
    }
}

type StateStream = std::pin::Pin<
    Box<dyn tokio_stream::Stream<Item = Result<proto::ControlState, tonic::Status>> + Send>,
>;

#[tonic::async_trait]
impl proto::control_service_server::ControlService for ControlServiceImpl {
    async fn get_controls(
        &self,
        _request: tonic::Request<proto::Empty>,
    ) -> Result<tonic::Response<proto::ControlList>, tonic::Status> {
        let controls = self
            .hub
            .controls()
            .into_iter()
            .filter(|control| !control.hidden)
            .map(|control| {
                let (kind, min, max) = match control.kind {
                    Kind::Switch => (proto::ControlType::Switch, 0, 0),
                    Kind::Slider => (proto::ControlType::Slider, LEVEL_MIN, LEVEL_MAX),
                };
                proto::Control {
                    id: control.id,
                    name: control.name,
                    r#type: kind as i32,
                    min,
                    max,
                }
            })
            .collect();
        Ok(tonic::Response::new(proto::ControlList { controls }))
    }

    type StreamControlStatesStream = StateStream;

    async fn stream_control_states(
        &self,
        _request: tonic::Request<proto::Empty>,
    ) -> Result<tonic::Response<Self::StreamControlStatesStream>, tonic::Status> {
        use tokio_stream::StreamExt;
        // The backlight belongs to the options, not to this page.
        let hidden: std::collections::HashSet<String> = self
            .hub
            .controls()
            .into_iter()
            .filter(|control| control.hidden)
            .map(|control| control.id)
            .collect();
        let shown = move |state: &ControlState| !hidden.contains(&state.id);
        let shown_now = shown.clone();
        // Subscribe before taking the snapshot, so no change falls between.
        let changes = tokio_stream::wrappers::BroadcastStream::new(self.hub.subscribe())
            .filter_map(move |change| {
                change
                    .ok()
                    .filter(|state| shown(state))
                    .map(|state| Ok(state_to_proto(&state)))
            });
        let current: Vec<_> = self
            .hub
            .states()
            .iter()
            .filter(|state| shown_now(state))
            .map(|state| Ok(state_to_proto(state)))
            .collect();
        info!("control state stream opened");
        Ok(tonic::Response::new(Box::pin(
            tokio_stream::iter(current).chain(changes),
        )))
    }

    async fn set_control_state(
        &self,
        request: tonic::Request<proto::SetControlStateRequest>,
    ) -> Result<tonic::Response<proto::ControlState>, tonic::Status> {
        let proto::SetControlStateRequest { id, value } = request.into_inner();
        let value = match value {
            Some(proto::set_control_state_request::Value::On(on)) => Value::On(on),
            Some(proto::set_control_state_request::Value::Level(level)) => Value::Level(level),
            None => return Err(tonic::Status::invalid_argument("no value given")),
        };
        let hub = std::sync::Arc::clone(&self.hub);
        // I2C writes block; keep them off the async workers.
        let result = tokio::task::spawn_blocking(move || hub.set(&id, value))
            .await
            .map_err(|error| tonic::Status::internal(error.to_string()))?;
        match result {
            Ok(state) => Ok(tonic::Response::new(state_to_proto(&state))),
            Err(SetError::NotFound) => Err(tonic::Status::not_found("no such control")),
            Err(SetError::InvalidValue(reason)) => Err(tonic::Status::invalid_argument(reason)),
            Err(SetError::Unavailable(reason)) => Err(tonic::Status::unavailable(reason)),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{Arc, Mutex as StdMutex};

    /// What the fake bus saw, and whether it answers. `directions` is the
    /// chip's IODIRA/IODIRB as the writes left them; `None` is the power-on
    /// state, all inputs.
    #[derive(Default)]
    struct BusLog {
        writes: Vec<(u16, Vec<u8>)>,
        broken: bool,
        directions: Option<[u8; 2]>,
        reads: usize,
    }

    impl BusLog {
        /// The chip lost its supply for a moment: back at all inputs.
        fn forget_setup(&mut self) {
            self.directions = None;
        }
    }

    struct FakeBus(Arc<StdMutex<BusLog>>);

    impl I2cBus for FakeBus {
        fn write(&mut self, address: u16, bytes: &[u8]) -> io::Result<()> {
            let mut log = self.0.lock().unwrap();
            if log.broken {
                return Err(io::Error::from_raw_os_error(libc::EREMOTEIO));
            }
            if let [MCP23017_IODIRA, a, b] = bytes {
                log.directions = Some([*a, *b]);
            }
            log.writes.push((address, bytes.to_vec()));
            Ok(())
        }

        fn read(&mut self, _address: u16, register: u8, buffer: &mut [u8]) -> io::Result<()> {
            let mut log = self.0.lock().unwrap();
            if log.broken {
                return Err(io::Error::from_raw_os_error(libc::EREMOTEIO));
            }
            assert_eq!(register, MCP23017_IODIRA, "only the directions are read");
            log.reads += 1;
            buffer.copy_from_slice(&log.directions.unwrap_or([0xFF, 0xFF]));
            Ok(())
        }
    }

    fn fake_opener(log: &Arc<StdMutex<BusLog>>) -> BusOpener {
        let log = Arc::clone(log);
        Box::new(move |_| Ok(Box::new(FakeBus(Arc::clone(&log))) as Box<dyn I2cBus>))
    }

    fn no_reset() -> ResetOpener {
        Box::new(|_, _| panic!("no reset GPIO is configured"))
    }

    /// Records what happens on the reset line, in order with the bus.
    struct FakeReset(Arc<StdMutex<BusLog>>);

    impl ResetLine for FakeReset {
        fn set(&mut self, high: bool) -> io::Result<()> {
            let mut log = self.0.lock().unwrap();
            log.writes.push((0, vec![if high { 0xF1 } else { 0xF0 }]));
            Ok(())
        }
    }

    fn fake_reset(log: &Arc<StdMutex<BusLog>>) -> ResetOpener {
        let log = Arc::clone(log);
        Box::new(move |_, line| {
            assert_eq!(line, 17);
            // Requesting the line drives it high at once.
            log.lock().unwrap().writes.push((0, vec![0xF1]));
            Ok(Box::new(FakeReset(Arc::clone(&log))) as Box<dyn ResetLine>)
        })
    }

    fn entry(id: &str, kind: &str, chip: &str, pin: Option<u8>) -> ControlConfig {
        ControlConfig {
            id: id.to_owned(),
            name: format!("Name {id}"),
            kind: kind.to_owned(),
            chip: chip.to_owned(),
            pin,
            ..ControlConfig::default()
        }
    }

    fn last_latch(log: &Arc<StdMutex<BusLog>>) -> Vec<u8> {
        log.lock()
            .unwrap()
            .writes
            .iter()
            .rev()
            .find(|(_, bytes)| bytes[0] == MCP23017_OLATA)
            .map(|(_, bytes)| bytes.clone())
            .expect("a latch write")
    }

    // ---- PWM ----------------------------------------------------------

    /// What the fake PWM channels saw: per channel the applied (period,
    /// duty) pairs and "off" for a disable; `broken` makes opening fail.
    #[derive(Default)]
    struct PwmLog {
        events: Vec<(u32, Option<(u64, u64)>)>,
        broken: bool,
        opened: usize,
    }

    struct FakePwm {
        channel: u32,
        log: Arc<StdMutex<PwmLog>>,
    }

    impl PwmChannel for FakePwm {
        fn apply(&mut self, period_ns: u64, duty_ns: u64) -> io::Result<()> {
            let mut log = self.log.lock().unwrap();
            if log.broken {
                return Err(io::Error::from_raw_os_error(libc::ENODEV));
            }
            log.events.push((self.channel, Some((period_ns, duty_ns))));
            Ok(())
        }

        fn disable(&mut self) -> io::Result<()> {
            self.log.lock().unwrap().events.push((self.channel, None));
            Ok(())
        }
    }

    fn fake_pwm(log: &Arc<StdMutex<PwmLog>>) -> PwmOpener {
        let log = Arc::clone(log);
        Box::new(move |chip, channel| {
            assert_eq!(chip, Path::new(DEFAULT_PWM_CHIP));
            let mut guard = log.lock().unwrap();
            if guard.broken {
                return Err(io::Error::new(io::ErrorKind::NotFound, "no pwmchip0"));
            }
            guard.opened += 1;
            Ok(Box::new(FakePwm {
                channel,
                log: Arc::clone(&log),
            }) as Box<dyn PwmChannel>)
        })
    }

    fn fan(min_level: u32, kick_ms: u64) -> ControlConfig {
        ControlConfig {
            channel: Some(0),
            min_level: Some(min_level),
            kick_ms: Some(kick_ms),
            ..entry("case_fan", "slider", "pwm", None)
        }
    }

    fn pwm_hub(entries: &[ControlConfig], log: &Arc<StdMutex<PwmLog>>) -> ControlHub {
        let bus = Arc::new(StdMutex::new(BusLog::default()));
        ControlHub::with_pwm(entries, fake_opener(&bus), no_reset(), fake_pwm(log), None)
    }

    fn pwm_events(log: &Arc<StdMutex<PwmLog>>) -> Vec<(u32, Option<(u64, u64)>)> {
        std::mem::take(&mut log.lock().unwrap().events)
    }

    /// 100 Hz, the default for a control.
    const FAN_PERIOD: u64 = 10_000_000;

    #[test]
    fn pwm_levels_spread_over_min_level_and_zero_is_off_or_min() {
        let period = 1_000_000;
        assert_eq!(pwm_duty_ns(Value::Level(0), period, 30, true), 0);
        assert_eq!(pwm_duty_ns(Value::Level(100), period, 30, true), period);
        assert_eq!(pwm_duty_ns(Value::Level(50), period, 30, true), 650_000);
        assert_eq!(pwm_duty_ns(Value::Level(1), period, 30, true), 300_000);
        // Without off at zero (backlight) 0 is the floor, not dark.
        assert_eq!(pwm_duty_ns(Value::Level(0), period, 10, false), 100_000);
        assert_eq!(pwm_duty_ns(Value::On(true), period, 30, true), period);
        assert_eq!(pwm_duty_ns(Value::On(false), period, 30, true), 0);
        assert_eq!(pwm_duty_ns(Value::Level(40), period, 0, true), 400_000);
    }

    #[test]
    fn broken_pwm_entries_are_refused_with_a_reason() {
        let cases = [
            (entry("a", "slider", "pwm", None), "needs a channel"),
            (
                ControlConfig {
                    frequency: Some(0),
                    ..fan(0, 0)
                },
                "frequency",
            ),
            (
                ControlConfig {
                    frequency: Some(2_000_000),
                    ..fan(0, 0)
                },
                "frequency",
            ),
            (fan(101, 0), "min_level"),
            (fan(0, 6000), "kick_ms"),
            (
                ControlConfig {
                    channel: Some(1),
                    ..entry(BACKLIGHT_ID, "slider", "pwm", None)
                },
                "kept for [display.backlight]",
            ),
            (
                ControlConfig {
                    backlight: true,
                    ..entry(BACKLIGHT_ID, "slider", "demo", None)
                },
                "PWM slider",
            ),
        ];
        for (entry, reason) in cases {
            let error = Control::from_config(&entry).expect_err(reason);
            assert!(error.contains(reason), "{error} lacks {reason}");
        }
        let control = Control::from_config(&fan(30, 500)).unwrap();
        assert_eq!(
            control.binding,
            Binding::Pwm {
                chip: PathBuf::from(DEFAULT_PWM_CHIP),
                channel: 0,
                period_ns: FAN_PERIOD,
                min_level: 30,
                kick: std::time::Duration::from_millis(500),
                off_at_zero: true,
                off_on_exit: true,
            }
        );
        assert!(!control.hidden);
    }

    #[test]
    fn a_pwm_slider_sets_the_duty_cycle_and_a_fan_gets_its_kick_from_off() {
        let log = Arc::new(StdMutex::new(PwmLog::default()));
        let hub = pwm_hub(&[fan(30, 1)], &log);
        // Starts off: no saved level.
        assert_eq!(pwm_events(&log), [(0, Some((FAN_PERIOD, 0)))]);
        assert!(hub.states()[0].available);

        hub.set("case_fan", Value::Level(50)).unwrap();
        assert_eq!(
            pwm_events(&log),
            [
                (0, Some((FAN_PERIOD, FAN_PERIOD))),
                (0, Some((FAN_PERIOD, 6_500_000))),
            ],
            "full duty first, then the level"
        );
        hub.set("case_fan", Value::Level(100)).unwrap();
        assert_eq!(
            pwm_events(&log),
            [(0, Some((FAN_PERIOD, FAN_PERIOD)))],
            "no kick while running"
        );
        hub.set("case_fan", Value::Level(0)).unwrap();
        assert_eq!(pwm_events(&log), [(0, Some((FAN_PERIOD, 0)))]);
    }

    #[test]
    fn a_pwm_switch_is_full_or_nothing() {
        let log = Arc::new(StdMutex::new(PwmLog::default()));
        let hub = pwm_hub(
            &[ControlConfig {
                channel: Some(0),
                ..entry("fan", "switch", "pwm", None)
            }],
            &log,
        );
        pwm_events(&log);
        hub.set("fan", Value::On(true)).unwrap();
        hub.set("fan", Value::On(false)).unwrap();
        assert_eq!(
            pwm_events(&log),
            [
                (0, Some((FAN_PERIOD, FAN_PERIOD))),
                (0, Some((FAN_PERIOD, 0)))
            ]
        );
    }

    #[test]
    fn a_missing_pwm_chip_greys_out_and_comes_back_with_the_current_level() {
        let log = Arc::new(StdMutex::new(PwmLog {
            broken: true,
            ..PwmLog::default()
        }));
        let hub = pwm_hub(&[fan(0, 0)], &log);
        assert!(!hub.states()[0].available);
        let error = hub.set("case_fan", Value::Level(40)).unwrap_err();
        assert!(matches!(error, SetError::Unavailable(_)), "{error:?}");
        assert_eq!(
            hub.states()[0].value,
            Value::Level(0),
            "not taken on failure"
        );

        let mut changes = hub.subscribe();
        log.lock().unwrap().broken = false;
        hub.retry_unavailable();
        assert!(hub.states()[0].available);
        assert_eq!(changes.try_recv().unwrap().id, "case_fan");
        assert_eq!(pwm_events(&log), [(0, Some((FAN_PERIOD, 0)))]);
        // Once driven, the retry leaves it alone.
        hub.retry_unavailable();
        assert_eq!(log.lock().unwrap().opened, 1);
    }

    #[test]
    fn the_backlight_is_hidden_starts_bright_and_never_goes_dark() {
        let log = Arc::new(StdMutex::new(PwmLog::default()));
        let display = crate::config::DisplayConfig {
            backlight: Some(crate::config::BacklightConfig {
                channel: 1,
                ..Default::default()
            }),
        };
        let entries = [fan(0, 0), display.backlight_control().unwrap()];
        let hub = pwm_hub(&entries, &log);
        let backlight_period = 1_000_000; // 1 kHz
        assert_eq!(
            pwm_events(&log),
            [
                (0, Some((FAN_PERIOD, 0))),
                (1, Some((backlight_period, backlight_period)))
            ]
        );
        assert_eq!(hub.state(BACKLIGHT_ID).unwrap().value, Value::Level(100));
        hub.set(BACKLIGHT_ID, Value::Level(0)).unwrap();
        assert_eq!(
            pwm_events(&log),
            [(1, Some((backlight_period, 100_000)))],
            "0 is the 10 % floor"
        );

        // Exit: the fan stops, the backlight stays as it is.
        hub.shut_down();
        assert_eq!(pwm_events(&log), [(0, None)]);
    }

    #[tokio::test]
    async fn the_technik_page_does_not_see_the_backlight() {
        use proto::control_service_server::ControlService;
        use tokio_stream::StreamExt;
        let log = Arc::new(StdMutex::new(PwmLog::default()));
        let display = crate::config::DisplayConfig {
            backlight: Some(crate::config::BacklightConfig {
                channel: 1,
                ..Default::default()
            }),
        };
        let hub = Arc::new(pwm_hub(
            &[fan(0, 0), display.backlight_control().unwrap()],
            &log,
        ));
        let service = ControlServiceImpl::new(Arc::clone(&hub));
        let list = service
            .get_controls(tonic::Request::new(proto::Empty {}))
            .await
            .unwrap()
            .into_inner();
        let ids: Vec<_> = list.controls.iter().map(|c| c.id.as_str()).collect();
        assert_eq!(ids, ["case_fan"]);

        let mut stream = service
            .stream_control_states(tonic::Request::new(proto::Empty {}))
            .await
            .unwrap()
            .into_inner();
        assert_eq!(stream.next().await.unwrap().unwrap().id, "case_fan");
        let hub_for_set = Arc::clone(&hub);
        tokio::task::spawn_blocking(move || {
            hub_for_set.set(BACKLIGHT_ID, Value::Level(50)).unwrap();
            hub_for_set.set("case_fan", Value::Level(20)).unwrap();
        })
        .await
        .unwrap();
        assert_eq!(
            stream.next().await.unwrap().unwrap().id,
            "case_fan",
            "the backlight change is not streamed"
        );
    }

    #[test]
    fn boosted_controls_run_full_while_overheated_and_return_to_their_own_value() {
        let path =
            std::env::temp_dir().join(format!("carnine-boost-{}.sqlite3", std::process::id()));
        let _ = std::fs::remove_file(&path);
        let log = Arc::new(StdMutex::new(PwmLog::default()));
        let bus = Arc::new(StdMutex::new(BusLog::default()));
        let entries = [
            ControlConfig {
                boost_on_overheat: Some(true),
                ..fan(0, 0)
            },
            ControlConfig {
                boost_on_overheat: Some(true),
                ..entry("pump", "switch", "demo", None)
            },
            entry("dimmer", "slider", "demo", None),
        ];
        let open = |log: &Arc<StdMutex<PwmLog>>| {
            ControlHub::with_pwm(
                &entries,
                fake_opener(&bus),
                no_reset(),
                fake_pwm(log),
                Some(path.clone()),
            )
        };
        let hub = open(&log);
        hub.set("case_fan", Value::Level(50)).unwrap();
        hub.set("dimmer", Value::Level(20)).unwrap();
        pwm_events(&log);
        let mut changes = hub.subscribe();

        hub.set_overheated(true);
        hub.set_overheated(true); // no second transition
        assert_eq!(pwm_events(&log), [(0, Some((FAN_PERIOD, FAN_PERIOD)))]);
        let values: Vec<Value> = hub.states().into_iter().map(|s| s.value).collect();
        assert_eq!(
            values,
            [Value::Level(100), Value::On(true), Value::Level(20)]
        );
        let announced: Vec<String> = std::iter::from_fn(|| changes.try_recv().ok())
            .map(|state| state.id)
            .collect();
        assert_eq!(announced, ["case_fan", "pump"]);

        // Set during the warning: own value for afterwards, the fan stays full.
        let state = hub.set("case_fan", Value::Level(30)).unwrap();
        assert_eq!(state.value, Value::Level(100));
        assert!(pwm_events(&log).is_empty());

        // A restart during the warning starts from the own value.
        drop(hub);
        let restarted_log = Arc::new(StdMutex::new(PwmLog::default()));
        let restarted = open(&restarted_log);
        assert_eq!(restarted.states()[0].value, Value::Level(30));
        restarted.set_overheated(true);
        assert_eq!(restarted.states()[0].value, Value::Level(100));

        restarted.set_overheated(false);
        assert_eq!(
            pwm_events(&restarted_log).last(),
            Some(&(0, Some((FAN_PERIOD, 3_000_000))))
        );
        let values: Vec<Value> = restarted.states().into_iter().map(|s| s.value).collect();
        assert_eq!(
            values,
            [Value::Level(30), Value::On(false), Value::Level(20)]
        );
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn the_sysfs_channel_is_exported_set_in_order_and_disabled() {
        let chip = std::env::temp_dir().join(format!("carnine-pwmchip-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&chip);
        std::fs::create_dir_all(&chip).unwrap();
        // A fake sysfs: writing "export" does not create pwm0 by itself, so
        // the directory is made after the export the way the kernel would.
        std::fs::write(chip.join("export"), "").unwrap();
        let channel_dir = chip.join("pwm0");
        std::fs::create_dir_all(&channel_dir).unwrap();
        for name in ["period", "duty_cycle", "enable"] {
            std::fs::write(channel_dir.join(name), "").unwrap();
        }
        let mut channel = linux_pwm_opener()(&chip, 0).expect("opens");
        let read = |name: &str| std::fs::read_to_string(channel_dir.join(name)).unwrap();
        channel.apply(10_000_000, 2_500_000).unwrap();
        assert_eq!(read("period"), "10000000");
        assert_eq!(read("duty_cycle"), "2500000");
        assert_eq!(read("enable"), "1");
        // A shorter period: duty to 0 first (checked by the kernel), here
        // only the end state is visible.
        channel.apply(1_000_000, 5_000_000).unwrap();
        assert_eq!(read("period"), "1000000");
        assert_eq!(read("duty_cycle"), "1000000", "never above the period");
        channel.disable().unwrap();
        assert_eq!(read("enable"), "0");

        // A channel that is not there and does not appear: the export fails
        // without a writable export file.
        let error = linux_pwm_opener()(&chip.join("missing"), 3)
            .err()
            .expect("no chip");
        assert!(
            error.to_string().contains("exporting PWM channel 3"),
            "{error}"
        );
        std::fs::remove_dir_all(&chip).unwrap();
    }

    #[test]
    fn broken_entries_are_skipped_not_fatal() {
        let entries = vec![
            entry("light", "switch", "mcp23017", Some(0)),
            entry("", "switch", "demo", None),
            entry("fan", "slider", "mcp23017", Some(1)),
            entry("pump", "valve", "demo", None),
            entry("horn", "switch", "mcp23017", Some(16)),
            entry("light", "switch", "demo", None),
            entry("dimmer", "slider", "demo", None),
        ];
        let log = Arc::new(StdMutex::new(BusLog::default()));
        let hub = ControlHub::new(&entries, fake_opener(&log), no_reset(), None);

        let ids: Vec<String> = hub.controls().into_iter().map(|c| c.id).collect();
        assert_eq!(ids, ["light", "dimmer"]);
    }

    #[test]
    fn the_mcp23017_starts_with_its_pins_as_outputs_and_off() {
        let entries = vec![
            entry("a0", "switch", "mcp23017", Some(0)),
            entry("b1", "switch", "mcp23017", Some(9)),
        ];
        let log = Arc::new(StdMutex::new(BusLog::default()));
        let hub = ControlHub::new(&entries, fake_opener(&log), no_reset(), None);

        let writes = log.lock().unwrap().writes.clone();
        // Latch (all off) before direction; only pins 0 and 9 are outputs.
        assert_eq!(
            writes,
            [
                (0x20, vec![MCP23017_OLATA, 0x00, 0x00]),
                (0x20, vec![MCP23017_IODIRA, 0xFE, 0xFD]),
            ]
        );
        assert!(hub
            .states()
            .iter()
            .all(|state| state.available && state.value == Value::On(false)));
    }

    #[test]
    fn switching_writes_the_latch_and_tells_subscribers() {
        let entries = vec![
            entry("a0", "switch", "mcp23017", Some(0)),
            entry("b1", "switch", "mcp23017", Some(9)),
        ];
        let log = Arc::new(StdMutex::new(BusLog::default()));
        let hub = ControlHub::new(&entries, fake_opener(&log), no_reset(), None);
        let mut changes = hub.subscribe();

        hub.set("b1", Value::On(true)).unwrap();
        assert_eq!(last_latch(&log), [MCP23017_OLATA, 0x00, 0x02]);
        hub.set("a0", Value::On(true)).unwrap();
        assert_eq!(last_latch(&log), [MCP23017_OLATA, 0x01, 0x02]);
        hub.set("b1", Value::On(false)).unwrap();
        assert_eq!(last_latch(&log), [MCP23017_OLATA, 0x01, 0x00]);

        let first = changes.try_recv().unwrap();
        assert_eq!(first.id, "b1");
        assert_eq!(first.value, Value::On(true));
    }

    #[test]
    fn wrong_values_and_ids_are_refused() {
        let entries = vec![
            entry("light", "switch", "demo", None),
            entry("dimmer", "slider", "demo", None),
        ];
        let log = Arc::new(StdMutex::new(BusLog::default()));
        let hub = ControlHub::new(&entries, fake_opener(&log), no_reset(), None);

        assert_eq!(hub.set("nope", Value::On(true)), Err(SetError::NotFound));
        assert!(matches!(
            hub.set("light", Value::Level(5)),
            Err(SetError::InvalidValue(_))
        ));
        assert!(matches!(
            hub.set("dimmer", Value::On(true)),
            Err(SetError::InvalidValue(_))
        ));
        assert!(matches!(
            hub.set("dimmer", Value::Level(101)),
            Err(SetError::InvalidValue(_))
        ));
        assert_eq!(
            hub.set("dimmer", Value::Level(0)).unwrap().value,
            Value::Level(0)
        );
        assert_eq!(
            hub.set("dimmer", Value::Level(100)).unwrap().value,
            Value::Level(100)
        );
    }

    #[test]
    fn the_demo_chip_keeps_what_is_set() {
        let entries = vec![entry("dimmer", "slider", "demo", None)];
        let log = Arc::new(StdMutex::new(BusLog::default()));
        let hub = ControlHub::new(&entries, fake_opener(&log), no_reset(), None);

        hub.set("dimmer", Value::Level(42)).unwrap();

        assert_eq!(hub.states()[0].value, Value::Level(42));
        assert!(hub.states()[0].available);
        assert!(log.lock().unwrap().writes.is_empty());
    }

    #[test]
    fn a_missing_chip_greys_out_its_controls_and_comes_back() {
        let entries = vec![
            entry("a0", "switch", "mcp23017", Some(0)),
            entry("dimmer", "slider", "demo", None),
        ];
        let log = Arc::new(StdMutex::new(BusLog {
            broken: true,
            ..BusLog::default()
        }));
        let hub = ControlHub::new(&entries, fake_opener(&log), no_reset(), None);
        let mut changes = hub.subscribe();

        assert!(!hub.states()[0].available);
        assert!(hub.states()[1].available);
        assert!(matches!(
            hub.set("a0", Value::On(true)),
            Err(SetError::Unavailable(_))
        ));
        assert_eq!(hub.states()[0].value, Value::On(false));

        log.lock().unwrap().broken = false;
        hub.retry_unavailable();

        assert!(hub.states()[0].available);
        let back = changes.try_recv().unwrap();
        assert_eq!((back.id.as_str(), back.available), ("a0", true));
        // The chip was set up again before it counted as back.
        let writes = log.lock().unwrap().writes.clone();
        assert_eq!(writes.last().unwrap().1[0], MCP23017_IODIRA);
    }

    #[test]
    fn a_chip_lost_while_switching_is_reported_and_reset_on_return() {
        let entries = vec![entry("a0", "switch", "mcp23017", Some(0))];
        let log = Arc::new(StdMutex::new(BusLog::default()));
        let hub = ControlHub::new(&entries, fake_opener(&log), no_reset(), None);
        let mut changes = hub.subscribe();

        log.lock().unwrap().broken = true;
        assert!(matches!(
            hub.set("a0", Value::On(true)),
            Err(SetError::Unavailable(_))
        ));
        let lost = changes.try_recv().unwrap();
        assert!(!lost.available);

        log.lock().unwrap().broken = false;
        hub.set("a0", Value::On(true)).unwrap();
        let writes = log.lock().unwrap().writes.clone();
        let tail: Vec<u8> = writes.iter().rev().take(2).map(|(_, b)| b[0]).collect();
        // Back with latch and direction, not the latch alone.
        assert_eq!(tail, [MCP23017_IODIRA, MCP23017_OLATA]);
        assert!(hub.states()[0].available);
    }

    #[test]
    fn a_chip_that_forgot_its_setup_is_set_up_again_with_the_current_values() {
        // jeep-pi 04.10.2026: found again, then a moment without supply while
        // plugging; it answered with IODIRA 0xff and switching did nothing.
        let entries = vec![
            entry("a0", "switch", "mcp23017", Some(0)),
            entry("b1", "switch", "mcp23017", Some(9)),
        ];
        let log = Arc::new(StdMutex::new(BusLog::default()));
        let hub = ControlHub::new(&entries, fake_opener(&log), no_reset(), None);
        hub.set("a0", Value::On(true)).unwrap();
        assert_eq!(log.lock().unwrap().directions, Some([0xFE, 0xFD]));

        log.lock().unwrap().forget_setup();
        let before = log.lock().unwrap().writes.len();
        hub.retry_unavailable();

        let log = log.lock().unwrap();
        assert_eq!(log.directions, Some([0xFE, 0xFD]));
        let again: Vec<&Vec<u8>> = log.writes[before..].iter().map(|(_, b)| b).collect();
        // The switched-on output comes back on, and only then turns into an
        // output, as at start-up.
        assert_eq!(
            again,
            [
                &vec![MCP23017_OLATA, 0x01, 0x00],
                &vec![MCP23017_IODIRA, 0xFE, 0xFD]
            ]
        );
        assert!(hub.states().iter().all(|state| state.available));
        assert_eq!(hub.states()[0].value, Value::On(true));
    }

    #[test]
    fn a_chip_that_holds_its_setup_is_only_read() {
        let entries = vec![entry("a0", "switch", "mcp23017", Some(0))];
        let log = Arc::new(StdMutex::new(BusLog::default()));
        let hub = ControlHub::new(&entries, fake_opener(&log), no_reset(), None);
        let before = log.lock().unwrap().writes.len();

        hub.retry_unavailable();
        hub.retry_unavailable();

        let log = log.lock().unwrap();
        assert_eq!(log.writes.len(), before);
        assert_eq!(log.reads, 2);
    }

    #[test]
    fn a_chip_that_stops_answering_between_switches_greys_out_and_comes_back() {
        let entries = vec![entry("a0", "switch", "mcp23017", Some(0))];
        let log = Arc::new(StdMutex::new(BusLog::default()));
        let hub = ControlHub::new(&entries, fake_opener(&log), no_reset(), None);
        let mut changes = hub.subscribe();

        log.lock().unwrap().broken = true;
        hub.retry_unavailable();
        assert!(!hub.states()[0].available);
        assert!(!changes.try_recv().unwrap().available);

        log.lock().unwrap().broken = false;
        log.lock().unwrap().forget_setup();
        hub.retry_unavailable();
        assert!(hub.states()[0].available);
        assert!(changes.try_recv().unwrap().available);
        assert_eq!(log.lock().unwrap().directions, Some([0xFE, 0xFF]));
    }

    #[test]
    fn sliders_restore_their_level_switches_start_off() {
        let path =
            std::env::temp_dir().join(format!("carnine-controls-{}.sqlite3", std::process::id()));
        let _ = std::fs::remove_file(&path);
        let entries = vec![
            entry("light", "switch", "demo", None),
            entry("dimmer", "slider", "demo", None),
            ControlConfig {
                restore: Some(true),
                ..entry("pump", "switch", "demo", None)
            },
        ];
        let log = Arc::new(StdMutex::new(BusLog::default()));
        {
            let hub = ControlHub::new(&entries, fake_opener(&log), no_reset(), Some(path.clone()));
            hub.set("light", Value::On(true)).unwrap();
            hub.set("dimmer", Value::Level(70)).unwrap();
            hub.set("pump", Value::On(true)).unwrap();
        }

        let restarted =
            ControlHub::new(&entries, fake_opener(&log), no_reset(), Some(path.clone()));
        let values: Vec<Value> = restarted.states().into_iter().map(|s| s.value).collect();
        assert_eq!(
            values,
            [Value::On(false), Value::Level(70), Value::On(true)]
        );
        let _ = std::fs::remove_file(&path);
    }

    #[tokio::test]
    async fn the_service_lists_streams_and_sets() {
        use proto::control_service_server::ControlService;
        use tokio_stream::StreamExt;

        let entries = vec![
            entry("light", "switch", "demo", None),
            entry("dimmer", "slider", "demo", None),
        ];
        let log = Arc::new(StdMutex::new(BusLog::default()));
        let hub = std::sync::Arc::new(ControlHub::new(
            &entries,
            fake_opener(&log),
            no_reset(),
            None,
        ));
        let service = ControlServiceImpl::new(std::sync::Arc::clone(&hub));

        let list = service
            .get_controls(tonic::Request::new(proto::Empty {}))
            .await
            .unwrap()
            .into_inner()
            .controls;
        assert_eq!(list.len(), 2);
        assert_eq!(
            (list[0].id.as_str(), list[0].name.as_str(), list[0].r#type()),
            ("light", "Name light", proto::ControlType::Switch)
        );
        assert_eq!(
            (list[1].r#type(), list[1].min, list[1].max),
            (proto::ControlType::Slider, 0, 100)
        );

        let mut stream = service
            .stream_control_states(tonic::Request::new(proto::Empty {}))
            .await
            .unwrap()
            .into_inner();
        let first = stream.next().await.unwrap().unwrap();
        let second = stream.next().await.unwrap().unwrap();
        assert_eq!(first.value, Some(proto::control_state::Value::On(false)));
        assert_eq!(second.value, Some(proto::control_state::Value::Level(0)));

        let set = |id: &str, value| {
            service.set_control_state(tonic::Request::new(proto::SetControlStateRequest {
                id: id.to_owned(),
                value,
            }))
        };
        let applied = set(
            "dimmer",
            Some(proto::set_control_state_request::Value::Level(55)),
        )
        .await
        .unwrap()
        .into_inner();
        assert_eq!(applied.value, Some(proto::control_state::Value::Level(55)));
        let pushed = tokio::time::timeout(std::time::Duration::from_secs(2), stream.next())
            .await
            .unwrap()
            .unwrap()
            .unwrap();
        assert_eq!(pushed, applied);

        let code = |result: Result<tonic::Response<proto::ControlState>, tonic::Status>| {
            result.unwrap_err().code()
        };
        assert_eq!(
            code(
                set(
                    "nope",
                    Some(proto::set_control_state_request::Value::On(true))
                )
                .await
            ),
            tonic::Code::NotFound
        );
        assert_eq!(
            code(
                set(
                    "light",
                    Some(proto::set_control_state_request::Value::Level(1))
                )
                .await
            ),
            tonic::Code::InvalidArgument
        );
        assert_eq!(code(set("light", None).await), tonic::Code::InvalidArgument);
    }

    #[test]
    fn a_reset_gpio_releases_the_chip_before_it_is_talked_to() {
        let entries = vec![ControlConfig {
            reset_gpio: Some(17),
            ..entry("a0", "switch", "mcp23017", Some(0))
        }];
        let log = Arc::new(StdMutex::new(BusLog::default()));
        let hub = ControlHub::new(&entries, fake_opener(&log), fake_reset(&log), None);

        let steps: Vec<u8> = log
            .lock()
            .unwrap()
            .writes
            .iter()
            .map(|(_, b)| b[0])
            .collect();
        // Reset high first, then latch and direction.
        assert_eq!(steps, [0xF1, MCP23017_OLATA, MCP23017_IODIRA]);
        assert!(hub.states()[0].available);

        hub.shut_down();
        assert_eq!(log.lock().unwrap().writes.last().unwrap().1, [0xF0]);
    }

    #[test]
    fn after_shut_down_nothing_lifts_the_reset_again() {
        // As on carnine-pc without the board: the chip never answers, so the
        // retry every five seconds keeps pulsing the reset - and the backend
        // still runs for a few seconds after the shutdown began.
        let entries = vec![ControlConfig {
            reset_gpio: Some(17),
            ..entry("a0", "switch", "mcp23017", Some(0))
        }];
        let log = Arc::new(StdMutex::new(BusLog {
            broken: true,
            ..BusLog::default()
        }));
        let hub = ControlHub::new(&entries, fake_opener(&log), fake_reset(&log), None);

        hub.shut_down();
        hub.retry_unavailable();
        assert!(matches!(
            hub.set("a0", Value::On(true)),
            Err(SetError::Unavailable(_))
        ));

        assert_eq!(log.lock().unwrap().writes.last().unwrap().1, [0xF0]);
    }

    #[test]
    fn a_chip_that_came_back_gets_a_reset_pulse_first() {
        let entries = vec![ControlConfig {
            reset_gpio: Some(17),
            ..entry("a0", "switch", "mcp23017", Some(0))
        }];
        let log = Arc::new(StdMutex::new(BusLog {
            broken: true,
            ..BusLog::default()
        }));
        let hub = ControlHub::new(&entries, fake_opener(&log), fake_reset(&log), None);
        assert!(!hub.states()[0].available);

        log.lock().unwrap().broken = false;
        log.lock().unwrap().writes.clear();
        hub.retry_unavailable();

        let steps: Vec<u8> = log
            .lock()
            .unwrap()
            .writes
            .iter()
            .map(|(_, b)| b[0])
            .collect();
        assert_eq!(steps, [0xF0, 0xF1, MCP23017_OLATA, MCP23017_IODIRA]);
        assert!(hub.states()[0].available);
    }
}
