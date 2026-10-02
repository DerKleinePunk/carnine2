//! Switches and sliders of the "Technik" page (ControlService). What an id
//! means in hardware comes from `[[controls]]` in the configuration; the UI
//! only sees id, name, type and state.
//!
//! Chips: the MCP23017 port expander (switches on its 16 pins) and "demo",
//! which only keeps what is set - for WSL and for trying sliders without
//! hardware. Another chip type adds a [`Binding`] variant and its driver.

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
const DEFAULT_MCP23017_ADDRESS: u16 = 0x20;

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
    Mcp23017 { bus: PathBuf, address: u16, pin: u8 },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Control {
    pub id: String,
    pub name: String,
    pub kind: Kind,
    pub restore: bool,
    pub binding: Binding,
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
                }
            }
            other => return Err(format!("control {id}: unknown chip {other:?}")),
        };
        Ok(Self {
            id: id.to_owned(),
            name: entry.name.trim().to_owned(),
            kind,
            restore: entry.restore.unwrap_or(kind == Kind::Slider),
            binding,
        })
    }

    fn off_value(&self) -> Value {
        match self.kind {
            Kind::Switch => Value::On(false),
            Kind::Slider => Value::Level(LEVEL_MIN),
        }
    }
}

/// Writes to devices on an I2C bus; the real one goes through /dev/i2c-N.
pub trait I2cBus: Send {
    fn write(&mut self, address: u16, bytes: &[u8]) -> io::Result<()>;
}

/// Opens the bus at a path, e.g. /dev/i2c-1.
pub type BusOpener = Box<dyn Fn(&Path) -> io::Result<Box<dyn I2cBus>> + Send + Sync>;

/// /dev/i2c-N through the I2C_SLAVE ioctl.
struct LinuxI2cBus {
    file: std::fs::File,
}

impl I2cBus for LinuxI2cBus {
    fn write(&mut self, address: u16, bytes: &[u8]) -> io::Result<()> {
        use std::io::Write;
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
        let written = self.file.write(bytes)?;
        if written != bytes.len() {
            return Err(io::Error::new(
                io::ErrorKind::WriteZero,
                format!("wrote {written} of {} bytes", bytes.len()),
            ));
        }
        Ok(())
    }
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

    /// Latch first, then the direction: a pin turns into an output already
    /// at its right level.
    fn initialise(&mut self, opener: &BusOpener) -> io::Result<()> {
        let [latch_a, latch_b] = self.latch.to_le_bytes();
        let [inputs_a, inputs_b] = (!self.used_pins).to_le_bytes();
        let address = self.address;
        let bus = self.bus(opener)?;
        bus.write(address, &[MCP23017_OLATA, latch_a, latch_b])?;
        bus.write(address, &[MCP23017_IODIRA, inputs_a, inputs_b])
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
    opener: BusOpener,
    database_path: Option<PathBuf>,
}

/// Keeps the state of every control and drives the chips. Clients read the
/// list, subscribe to changes and set values through it.
pub struct ControlHub {
    inner: Mutex<Inner>,
    changes: broadcast::Sender<ControlState>,
}

impl ControlHub {
    /// Builds the controls from the configuration, skipping broken entries
    /// and duplicate ids with an error in the log, restores the saved values
    /// and puts them on the chips. A chip that does not answer leaves its
    /// controls unavailable; [`ControlHub::retry_unavailable`] tries again.
    pub fn new(
        entries: &[ControlConfig],
        opener: BusOpener,
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
            if let Binding::Mcp23017 { bus, address, pin } = &control.binding {
                let chip = chips
                    .entry((bus.clone(), *address))
                    .or_insert_with(|| Mcp23017 {
                        bus_path: bus.clone(),
                        address: *address,
                        bus: None,
                        used_pins: 0,
                        latch: 0,
                        available: false,
                        missing_reported: false,
                    });
                if chip.used_pins & (1 << pin) != 0 {
                    warn!(id = %control.id, pin, "MCP23017 pin used by two controls");
                }
                chip.used_pins |= 1 << pin;
                if state.value == Value::On(true) {
                    chip.latch |= 1 << pin;
                }
            }
        }
        let (changes, _) = broadcast::channel(64);
        let hub = Self {
            inner: Mutex::new(Inner {
                controls,
                states,
                chips,
                opener,
                database_path,
            }),
            changes,
        };
        {
            let mut inner = hub.lock();
            let keys: Vec<ChipKey> = inner.chips.keys().cloned().collect();
            for key in keys {
                Self::bring_up(&mut inner, &key);
            }
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
        let Inner { chips, opener, .. } = inner;
        let chip = chips.get_mut(key).expect("known chip");
        match chip.initialise(opener) {
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

    /// Changes after the current states; [`ControlHub::states`] first, then
    /// this, gives a client the full picture.
    pub fn subscribe(&self) -> broadcast::Receiver<ControlState> {
        self.changes.subscribe()
    }

    pub fn set(&self, id: &str, value: Value) -> Result<ControlState, SetError> {
        let mut inner = self.lock();
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

        if let Binding::Mcp23017 { bus, address, pin } = &control.binding {
            let key = (bus.clone(), *address);
            let Inner { chips, opener, .. } = &mut *inner;
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
                chip.initialise(opener)
            };
            if let Err(error) = result {
                chip.latch = previous;
                chip.available = false;
                chip.missing_reported = true;
                chip.bus = None;
                warn!(id, error = %error, "setting a control failed");
                for state in Self::refresh_availability(&mut inner) {
                    let _ = self.changes.send(state);
                }
                return Err(SetError::Unavailable(error.to_string()));
            }
            chip.available = true;
            chip.missing_reported = false;
            for state in Self::refresh_availability(&mut inner) {
                if state.id != id {
                    let _ = self.changes.send(state);
                }
            }
        }

        let state = ControlState {
            id: id.to_owned(),
            value,
            available: true,
        };
        inner.states[index] = state.clone();
        if let Some(path) = &inner.database_path {
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
        info!(id, ?value, "control set");
        let _ = self.changes.send(state.clone());
        Ok(state)
    }

    /// Tries the chips that did not answer again and puts the current
    /// values on them; meant to run every few seconds.
    pub fn retry_unavailable(&self) {
        let mut inner = self.lock();
        let keys: Vec<ChipKey> = inner
            .chips
            .iter()
            .filter(|(_, chip)| !chip.available)
            .map(|(key, _)| key.clone())
            .collect();
        if keys.is_empty() {
            return;
        }
        for key in keys {
            Self::bring_up(&mut inner, &key);
        }
        for state in Self::refresh_availability(&mut inner) {
            let _ = self.changes.send(state);
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
        // Subscribe before taking the snapshot, so no change falls between.
        let changes = tokio_stream::wrappers::BroadcastStream::new(self.hub.subscribe())
            .filter_map(|change| change.ok().map(|state| Ok(state_to_proto(&state))));
        let current: Vec<_> = self
            .hub
            .states()
            .iter()
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

    /// What the fake bus saw, and whether it answers.
    #[derive(Default)]
    struct BusLog {
        writes: Vec<(u16, Vec<u8>)>,
        broken: bool,
    }

    struct FakeBus(Arc<StdMutex<BusLog>>);

    impl I2cBus for FakeBus {
        fn write(&mut self, address: u16, bytes: &[u8]) -> io::Result<()> {
            let mut log = self.0.lock().unwrap();
            if log.broken {
                return Err(io::Error::from_raw_os_error(libc::EREMOTEIO));
            }
            log.writes.push((address, bytes.to_vec()));
            Ok(())
        }
    }

    fn fake_opener(log: &Arc<StdMutex<BusLog>>) -> BusOpener {
        let log = Arc::clone(log);
        Box::new(move |_| Ok(Box::new(FakeBus(Arc::clone(&log))) as Box<dyn I2cBus>))
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
        let hub = ControlHub::new(&entries, fake_opener(&log), None);

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
        let hub = ControlHub::new(&entries, fake_opener(&log), None);

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
        let hub = ControlHub::new(&entries, fake_opener(&log), None);
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
        let hub = ControlHub::new(&entries, fake_opener(&log), None);

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
        let hub = ControlHub::new(&entries, fake_opener(&log), None);

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
        let hub = ControlHub::new(&entries, fake_opener(&log), None);
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
        let hub = ControlHub::new(&entries, fake_opener(&log), None);
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
            let hub = ControlHub::new(&entries, fake_opener(&log), Some(path.clone()));
            hub.set("light", Value::On(true)).unwrap();
            hub.set("dimmer", Value::Level(70)).unwrap();
            hub.set("pump", Value::On(true)).unwrap();
        }

        let restarted = ControlHub::new(&entries, fake_opener(&log), Some(path.clone()));
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
        let hub = std::sync::Arc::new(ControlHub::new(&entries, fake_opener(&log), None));
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
}
