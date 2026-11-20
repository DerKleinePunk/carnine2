//! Reverse gear (#137): one event "in / out / unknown", whatever the source.
//!
//! The source is set in `[reverse_gear]`: a GPIO input (e.g. an optocoupler
//! on the reversing light pulling the line to ground), a demo source set over
//! gRPC for WSL and the trade fair, or nothing. CAN follows with the CAN
//! adapter. The frontend sees the same status for every source.

use std::io;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use tokio::sync::watch;
use tracing::{info, warn};

use crate::config::{GpioBias, ReverseGearConfig, ReverseGearSource};

/// How long the GPIO thread waits before it tries to open the line again.
pub const RETRY_INTERVAL: Duration = Duration::from_secs(5);

/// How long one wait for an edge lasts; bounds how late a stop is noticed.
const EDGE_WAIT: Duration = Duration::from_secs(1);

/// Whether the reverse gear is in.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum Gear {
    /// Not known: no source, the line cannot be read, or the demo source has
    /// not been set yet. Never taken for "out".
    #[default]
    Unknown,
    Out,
    In,
}

impl Gear {
    fn from_active(active: bool) -> Self {
        if active {
            Gear::In
        } else {
            Gear::Out
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ReverseGearStatus {
    pub source: ReverseGearSource,
    pub gear: Gear,
    /// When `gear` last changed, 0 while it never has.
    pub changed_at_unix_ms: i64,
}

impl ReverseGearStatus {
    pub fn configured(&self) -> bool {
        self.source != ReverseGearSource::None
    }
}

/// `SetReverseGear` outside of `source = "demo"`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NotDemoSource(pub ReverseGearSource);

/// Latest status for SystemService; subscribers are woken on every change of
/// the gear.
#[derive(Debug, Clone)]
pub struct ReverseGearHub {
    sender: Arc<watch::Sender<ReverseGearStatus>>,
}

impl Default for ReverseGearHub {
    fn default() -> Self {
        Self::new(ReverseGearSource::None)
    }
}

impl ReverseGearHub {
    pub fn new(source: ReverseGearSource) -> Self {
        let (sender, _) = watch::channel(ReverseGearStatus {
            source,
            gear: Gear::Unknown,
            changed_at_unix_ms: 0,
        });
        Self {
            sender: Arc::new(sender),
        }
    }

    pub fn current(&self) -> ReverseGearStatus {
        *self.sender.borrow()
    }

    pub fn subscribe(&self) -> watch::Receiver<ReverseGearStatus> {
        self.sender.subscribe()
    }

    /// Sets the gear from the demo source; refused for every other source,
    /// so a client cannot overrule the car.
    pub fn set_demo(&self, gear: Gear) -> Result<ReverseGearStatus, NotDemoSource> {
        let source = self.current().source;
        if source != ReverseGearSource::Demo {
            return Err(NotDemoSource(source));
        }
        self.set_gear(gear);
        Ok(self.current())
    }

    /// The source read `gear`; wakes subscribers and logs only on a change.
    fn set_gear(&self, gear: Gear) {
        self.sender.send_if_modified(|status| {
            if status.gear == gear {
                return false;
            }
            info!(source = ?status.source, from = ?status.gear, to = ?gear, "reverse gear changed");
            status.gear = gear;
            status.changed_at_unix_ms = now_unix_ms();
            true
        });
    }
}

fn now_unix_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|elapsed| i64::try_from(elapsed.as_millis()).unwrap_or(i64::MAX))
        .unwrap_or(0)
}

/// What the GPIO line is requested with.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LineSettings {
    pub chip: PathBuf,
    pub line: u32,
    pub active_low: bool,
    pub bias: GpioBias,
    /// Done by the kernel (gpio-cdev debounce_period); zero turns it off.
    pub debounce: Duration,
}

impl LineSettings {
    /// `None` unless `source = "gpio"` with a line (which `validate` makes
    /// sure of).
    pub fn from_config(config: &ReverseGearConfig) -> Option<Self> {
        if config.source != ReverseGearSource::Gpio {
            return None;
        }
        Some(Self {
            chip: config.gpio_chip.clone(),
            line: config.gpio_line?,
            active_low: config.active_low,
            bias: config.bias,
            debounce: Duration::from_millis(u64::from(config.debounce_ms)),
        })
    }
}

/// A requested input line. "Active" is the logical level: with active_low a
/// line pulled to ground is active.
pub trait InputLine: Send {
    fn active(&mut self) -> io::Result<bool>;
    /// Waits up to `timeout` for an edge; `Some` with the level after it.
    fn wait_change(&mut self, timeout: Duration) -> io::Result<Option<bool>>;
}

pub type InputOpener = Box<dyn Fn(&LineSettings) -> io::Result<Box<dyn InputLine>> + Send + Sync>;

struct CdevInputLine {
    request: gpiocdev::Request,
    line: u32,
}

fn cdev_error(error: gpiocdev::Error) -> io::Error {
    io::Error::other(error.to_string())
}

impl InputLine for CdevInputLine {
    fn active(&mut self) -> io::Result<bool> {
        let value = self.request.value(self.line).map_err(cdev_error)?;
        Ok(value == gpiocdev::line::Value::Active)
    }

    fn wait_change(&mut self, timeout: Duration) -> io::Result<Option<bool>> {
        if !self.request.wait_edge_event(timeout).map_err(cdev_error)? {
            return Ok(None);
        }
        // Take the event off the queue, then read the level: after several
        // queued edges only the level now counts.
        self.request.read_edge_event().map_err(cdev_error)?;
        self.active().map(Some)
    }
}

pub fn linux_input_opener() -> InputOpener {
    Box::new(|settings| {
        let bias = match settings.bias {
            GpioBias::PullUp => gpiocdev::line::Bias::PullUp,
            GpioBias::PullDown => gpiocdev::line::Bias::PullDown,
            GpioBias::None => gpiocdev::line::Bias::Disabled,
        };
        let mut builder = gpiocdev::Request::builder();
        builder
            .on_chip(&settings.chip)
            .with_consumer("carnine-reverse-gear")
            .with_line(settings.line)
            .as_input()
            .with_bias(bias)
            .with_edge_detection(gpiocdev::line::EdgeDetection::BothEdges);
        if settings.active_low {
            builder.as_active_low();
        }
        if !settings.debounce.is_zero() {
            builder.with_debounce_period(settings.debounce);
        }
        let request = builder.request().map_err(cdev_error)?;
        Ok(Box::new(CdevInputLine {
            request,
            line: settings.line,
        }) as Box<dyn InputLine>)
    })
}

/// Starts the source `[reverse_gear]` names. GPIO reads in a thread of its
/// own; demo and none need nothing.
pub fn spawn(hub: ReverseGearHub, config: &ReverseGearConfig) {
    let Some(settings) = LineSettings::from_config(config) else {
        if config.source != ReverseGearSource::None {
            info!(source = ?config.source, "reverse gear source ready");
        }
        return;
    };
    info!(
        chip = %settings.chip.display(),
        line = settings.line,
        active_low = settings.active_low,
        bias = ?settings.bias,
        debounce_ms = settings.debounce.as_millis() as u64,
        "reverse gear: reading the GPIO line"
    );
    let spawned = std::thread::Builder::new()
        .name("reverse-gear".to_string())
        .spawn(move || {
            run_gpio(
                &hub,
                &settings,
                &linux_input_opener(),
                RETRY_INTERVAL,
                &|| true,
            )
        });
    if let Err(error) = spawned {
        warn!(%error, "reverse gear: cannot start the GPIO thread");
    }
}

/// Reads the line until `keep_going` says stop: the level on opening, then
/// every edge. A line that cannot be opened or read makes the gear unknown
/// and is opened again after `retry`. Each new error is logged once.
pub fn run_gpio(
    hub: &ReverseGearHub,
    settings: &LineSettings,
    opener: &InputOpener,
    retry: Duration,
    keep_going: &dyn Fn() -> bool,
) {
    let mut last_error: Option<String> = None;
    let report = |what: &str, error: io::Error, last_error: &mut Option<String>| {
        hub.set_gear(Gear::Unknown);
        let message = format!("{what}: {error}");
        if last_error.as_deref() != Some(message.as_str()) {
            warn!(
                chip = %settings.chip.display(),
                line = settings.line,
                error = %message,
                retry_s = retry.as_secs(),
                "reverse gear: GPIO line not usable, gear unknown"
            );
            *last_error = Some(message);
        }
    };
    while keep_going() {
        let mut line = match opener(settings) {
            Ok(line) => line,
            Err(error) => {
                report("open", error, &mut last_error);
                std::thread::sleep(retry);
                continue;
            }
        };
        match line.active() {
            Ok(active) => {
                if last_error.take().is_some() {
                    info!(line = settings.line, "reverse gear: GPIO line usable again");
                }
                hub.set_gear(Gear::from_active(active));
            }
            Err(error) => {
                report("read", error, &mut last_error);
                std::thread::sleep(retry);
                continue;
            }
        }
        while keep_going() {
            match line.wait_change(EDGE_WAIT) {
                Ok(Some(active)) => hub.set_gear(Gear::from_active(active)),
                Ok(None) => {}
                Err(error) => {
                    report("wait for edge", error, &mut last_error);
                    std::thread::sleep(retry);
                    break;
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::VecDeque;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::Mutex;

    /// What a fake line answers, one step per call.
    #[derive(Debug, Clone)]
    enum Step {
        Level(bool),
        NoEdge,
        Fail,
    }

    struct FakeLine {
        steps: Arc<Mutex<VecDeque<Step>>>,
    }

    impl FakeLine {
        fn next(&mut self) -> io::Result<Option<bool>> {
            match self.steps.lock().unwrap().pop_front() {
                Some(Step::Level(level)) => Ok(Some(level)),
                Some(Step::NoEdge) | None => Ok(None),
                Some(Step::Fail) => Err(io::Error::other("line gone")),
            }
        }
    }

    impl InputLine for FakeLine {
        fn active(&mut self) -> io::Result<bool> {
            match self.next()? {
                Some(level) => Ok(level),
                None => Err(io::Error::other("no level scripted")),
            }
        }

        fn wait_change(&mut self, _timeout: Duration) -> io::Result<Option<bool>> {
            self.next()
        }
    }

    /// Per open: `Err` fails it, `Ok(steps)` gives a line with those steps.
    fn opener(
        opens: Vec<Result<Vec<Step>, ()>>,
        seen: Arc<Mutex<Vec<LineSettings>>>,
    ) -> InputOpener {
        let opens = Mutex::new(VecDeque::from(opens));
        Box::new(move |settings| {
            seen.lock().unwrap().push(settings.clone());
            match opens.lock().unwrap().pop_front() {
                Some(Ok(steps)) => Ok(Box::new(FakeLine {
                    steps: Arc::new(Mutex::new(steps.into())),
                }) as Box<dyn InputLine>),
                _ => Err(io::Error::new(io::ErrorKind::NotFound, "no such chip")),
            }
        })
    }

    fn settings() -> LineSettings {
        LineSettings {
            chip: PathBuf::from("/dev/gpiochip0"),
            line: 26,
            active_low: true,
            bias: GpioBias::PullUp,
            debounce: Duration::from_millis(50),
        }
    }

    /// Runs the loop for `rounds` checks of keep_going, recording the gear
    /// after each one.
    fn run(hub: &ReverseGearHub, opener: &InputOpener, rounds: usize) -> Vec<Gear> {
        let count = AtomicUsize::new(0);
        let seen = Mutex::new(Vec::new());
        run_gpio(hub, &settings(), opener, Duration::ZERO, &|| {
            seen.lock().unwrap().push(hub.current().gear);
            count.fetch_add(1, Ordering::SeqCst) < rounds
        });
        seen.into_inner().unwrap()
    }

    fn gpio_hub() -> ReverseGearHub {
        ReverseGearHub::new(ReverseGearSource::Gpio)
    }

    #[test]
    fn reads_the_level_on_opening_and_then_every_edge() {
        let hub = gpio_hub();
        let opener = opener(
            vec![Ok(vec![
                Step::Level(false),
                Step::NoEdge,
                Step::Level(true),
                Step::Level(false),
            ])],
            Arc::default(),
        );
        let gears = run(&hub, &opener, 5);
        // Open: out; no edge; in; out.
        assert_eq!(
            &gears[..5],
            &[Gear::Unknown, Gear::Out, Gear::Out, Gear::In, Gear::Out]
        );
        assert_ne!(hub.current().changed_at_unix_ms, 0);
    }

    #[test]
    fn a_line_that_does_not_open_is_unknown_until_it_does() {
        let hub = gpio_hub();
        let seen = Arc::new(Mutex::new(Vec::new()));
        let opener = opener(
            vec![Err(()), Err(()), Ok(vec![Step::Level(true)])],
            seen.clone(),
        );
        let gears = run(&hub, &opener, 4);
        assert_eq!(
            &gears[..4],
            &[Gear::Unknown, Gear::Unknown, Gear::Unknown, Gear::In]
        );
        assert_eq!(seen.lock().unwrap().len(), 3);
    }

    #[test]
    fn a_read_error_makes_the_gear_unknown_and_opens_the_line_again() {
        let hub = gpio_hub();
        let seen = Arc::new(Mutex::new(Vec::new()));
        let opener = opener(
            vec![
                Ok(vec![Step::Level(true), Step::Fail]),
                Ok(vec![Step::Level(false)]),
            ],
            seen.clone(),
        );
        let gears = run(&hub, &opener, 4);
        // open: In; edge wait fails: Unknown; reopened: Out.
        assert_eq!(
            &gears[..4],
            &[Gear::Unknown, Gear::In, Gear::Unknown, Gear::Out]
        );
        assert_eq!(seen.lock().unwrap().len(), 2);
    }

    #[test]
    fn the_line_is_requested_as_configured() {
        let config = ReverseGearConfig {
            source: ReverseGearSource::Gpio,
            debounce_ms: 120,
            gpio_chip: PathBuf::from("/dev/gpiochip4"),
            gpio_line: Some(6),
            active_low: false,
            bias: GpioBias::PullDown,
        };
        let expected = LineSettings {
            chip: PathBuf::from("/dev/gpiochip4"),
            line: 6,
            active_low: false,
            bias: GpioBias::PullDown,
            debounce: Duration::from_millis(120),
        };
        assert_eq!(LineSettings::from_config(&config), Some(expected.clone()));

        let hub = gpio_hub();
        let seen = Arc::new(Mutex::new(Vec::new()));
        let opener = opener(vec![Ok(vec![Step::Level(false)])], seen.clone());
        run_gpio(&hub, &expected, &opener, Duration::ZERO, &{
            let once = AtomicUsize::new(0);
            move || once.fetch_add(1, Ordering::SeqCst) < 1
        });
        assert_eq!(seen.lock().unwrap().as_slice(), &[expected]);
    }

    #[test]
    fn only_gpio_reads_a_line() {
        for source in [
            ReverseGearSource::None,
            ReverseGearSource::Demo,
            ReverseGearSource::Can,
        ] {
            let config = ReverseGearConfig {
                source,
                gpio_line: Some(26),
                ..ReverseGearConfig::default()
            };
            assert_eq!(LineSettings::from_config(&config), None, "{source:?}");
        }
    }

    #[test]
    fn only_the_demo_source_can_be_set() {
        let demo = ReverseGearHub::new(ReverseGearSource::Demo);
        assert_eq!(demo.current().gear, Gear::Unknown);
        assert!(demo.current().configured());
        let mut updates = demo.subscribe();
        let status = demo.set_demo(Gear::In).expect("demo can be set");
        assert_eq!(status.gear, Gear::In);
        assert!(updates.has_changed().unwrap());
        updates.mark_unchanged();
        let first_change = demo.current().changed_at_unix_ms;
        assert!(first_change > 0);
        // The same gear again is no change: no wake-up, same time.
        demo.set_demo(Gear::In).unwrap();
        assert!(!updates.has_changed().unwrap());
        assert_eq!(demo.current().changed_at_unix_ms, first_change);

        for source in [ReverseGearSource::None, ReverseGearSource::Gpio] {
            let hub = ReverseGearHub::new(source);
            assert_eq!(hub.set_demo(Gear::In), Err(NotDemoSource(source)));
            assert_eq!(hub.current().gear, Gear::Unknown);
        }
        assert!(!ReverseGearHub::default().current().configured());
    }
}
