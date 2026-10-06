use std::sync::Mutex;

use anyhow::Result;
use tracing::{info, warn};

pub trait AudioEngine: Send + Sync {
    fn start(&self, input_path: &str) -> Result<Box<dyn Playback>>;

    fn shutdown(&self) -> Result<()> {
        Ok(())
    }

    fn start_at(&self, input_path: &str, position_ms: i64) -> Result<Box<dyn Playback>> {
        let _ = position_ms;
        self.start(input_path)
    }

    /// False while there is no output device to play on.
    fn output_available(&self) -> bool {
        true
    }
}

pub trait Playback: Send {
    fn pause(&self) -> Result<()>;
    fn resume(&self) -> Result<()>;
    fn stop(self: Box<Self>) -> Result<()>;

    /// Fades the playback to `gain` (0..1), e.g. music under a spoken
    /// announcement. An engine without levels ignores it.
    fn set_gain(&self, _gain: f32) -> Result<()> {
        Ok(())
    }

    // True only once playback reached the track's natural end on its own,
    // never as a result of an explicit stop() — the auto-advance watcher
    // polls this to tell "track ended" apart from "user stopped it".
    fn is_finished(&self) -> bool {
        false
    }
}

/// Opens the real output engine; see [`RetryingAudioEngine`].
pub type EngineFactory = Box<dyn Fn() -> Result<Box<dyn AudioEngine>> + Send + Sync>;

/// Returned by [`RetryingAudioEngine`] while no output device can be opened,
/// so the player can tell it apart from a broken file.
#[derive(Debug)]
pub struct AudioOutputUnavailable(pub String);

impl std::fmt::Display for AudioOutputUnavailable {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(formatter, "no audio output available: {}", self.0)
    }
}

impl std::error::Error for AudioOutputUnavailable {}

/// Keeps the backend running without an audio device (#55).
///
/// The output is opened at startup as before. When that fails (no device,
/// HDMI without audio, a panel whose EDID has no audio block), playback
/// fails with [`AudioOutputUnavailable`] instead of taking the whole service
/// down, and each later start tries to open the device again, so HDMI that
/// comes up late still gets used.
pub struct RetryingAudioEngine {
    factory: EngineFactory,
    engine: Mutex<Option<Box<dyn AudioEngine>>>,
}

impl RetryingAudioEngine {
    pub fn new(factory: EngineFactory) -> Self {
        let engine = match factory() {
            Ok(engine) => Some(engine),
            Err(error) => {
                warn!(
                    error = format!("{error:#}"),
                    "audio output unavailable, running without sound"
                );
                None
            }
        };
        Self {
            factory,
            engine: Mutex::new(engine),
        }
    }

    fn with_engine<T>(&self, action: impl FnOnce(&dyn AudioEngine) -> Result<T>) -> Result<T> {
        let mut engine = self
            .engine
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        // An output that failed while running (#59) is replaced like a
        // missing one.
        if engine
            .as_ref()
            .is_some_and(|opened| !opened.output_available())
        {
            warn!("audio output failed, opening a new one");
            *engine = None;
        }
        if engine.is_none() {
            match (self.factory)() {
                Ok(opened) => {
                    info!("audio output opened on retry");
                    *engine = Some(opened);
                }
                Err(error) => {
                    return Err(AudioOutputUnavailable(format!("{error:#}")).into());
                }
            }
        }
        action(engine.as_deref().expect("engine was just opened"))
    }
}

impl AudioEngine for RetryingAudioEngine {
    fn start(&self, input_path: &str) -> Result<Box<dyn Playback>> {
        self.with_engine(|engine| engine.start(input_path))
    }

    fn start_at(&self, input_path: &str, position_ms: i64) -> Result<Box<dyn Playback>> {
        self.with_engine(|engine| engine.start_at(input_path, position_ms))
    }

    fn shutdown(&self) -> Result<()> {
        match self
            .engine
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .as_deref()
        {
            Some(engine) => engine.shutdown(),
            None => Ok(()),
        }
    }

    fn output_available(&self) -> bool {
        self.engine
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .as_ref()
            .is_some_and(|engine| engine.output_available())
    }
}

#[cfg(test)]
mod tests {
    use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
    use std::sync::Arc;

    use anyhow::{anyhow, Result};

    use super::{AudioEngine, AudioOutputUnavailable, Playback, RetryingAudioEngine};

    struct SilentPlayback;

    impl Playback for SilentPlayback {
        fn pause(&self) -> Result<()> {
            Ok(())
        }
        fn resume(&self) -> Result<()> {
            Ok(())
        }
        fn stop(self: Box<Self>) -> Result<()> {
            Ok(())
        }
    }

    struct SilentEngine;

    impl AudioEngine for SilentEngine {
        fn start(&self, _input_path: &str) -> Result<Box<dyn Playback>> {
            Ok(Box::new(SilentPlayback))
        }
    }

    /// A factory that fails until `device_present` is set, counting calls.
    fn factory(device_present: Arc<AtomicBool>, calls: Arc<AtomicUsize>) -> super::EngineFactory {
        Box::new(move || {
            calls.fetch_add(1, Ordering::SeqCst);
            if device_present.load(Ordering::SeqCst) {
                Ok(Box::new(SilentEngine) as Box<dyn AudioEngine>)
            } else {
                Err(anyhow!("snd_pcm_open failed"))
            }
        })
    }

    #[test]
    fn opens_the_output_once_when_the_device_is_there() {
        let calls = Arc::new(AtomicUsize::new(0));
        let engine =
            RetryingAudioEngine::new(factory(Arc::new(AtomicBool::new(true)), calls.clone()));

        assert!(engine.output_available());
        assert!(engine.start("/music/a.mp3").is_ok());
        assert!(engine.start_at("/music/a.mp3", 5_000).is_ok());
        assert_eq!(calls.load(Ordering::SeqCst), 1);
    }

    #[test]
    fn without_a_device_starts_fail_with_a_typed_error() {
        let engine = RetryingAudioEngine::new(factory(
            Arc::new(AtomicBool::new(false)),
            Arc::new(AtomicUsize::new(0)),
        ));

        assert!(!engine.output_available());
        let error = match engine.start("/music/a.mp3") {
            Ok(_) => panic!("start must fail without a device"),
            Err(error) => error,
        };
        assert!(error.downcast_ref::<AudioOutputUnavailable>().is_some());
        assert!(engine.shutdown().is_ok());
    }

    /// Plays, until `broken` is set: then it reports no output, like a
    /// cpal engine whose stream failed.
    struct BreakableEngine {
        broken: Arc<AtomicBool>,
    }

    impl AudioEngine for BreakableEngine {
        fn start(&self, _input_path: &str) -> Result<Box<dyn Playback>> {
            if self.broken.load(Ordering::SeqCst) {
                return Err(anyhow!("stream failed"));
            }
            Ok(Box::new(SilentPlayback))
        }

        fn output_available(&self) -> bool {
            !self.broken.load(Ordering::SeqCst)
        }
    }

    #[test]
    fn an_output_that_fails_while_running_is_replaced_on_the_next_start() {
        let calls = Arc::new(AtomicUsize::new(0));
        let broken = Arc::new(AtomicBool::new(false));
        let factory_calls = calls.clone();
        let factory_broken = broken.clone();
        let engine = RetryingAudioEngine::new(Box::new(move || {
            factory_calls.fetch_add(1, Ordering::SeqCst);
            // Every new engine starts healthy; the shared flag is reset.
            factory_broken.store(false, Ordering::SeqCst);
            Ok(Box::new(BreakableEngine {
                broken: factory_broken.clone(),
            }) as Box<dyn AudioEngine>)
        }));
        assert!(engine.start("/music/a.mp3").is_ok());

        broken.store(true, Ordering::SeqCst);
        assert!(!engine.output_available());

        assert!(engine.start("/music/b.mp3").is_ok());
        assert!(engine.output_available());
        assert_eq!(calls.load(Ordering::SeqCst), 2);
    }

    #[test]
    fn a_device_that_appears_later_is_used_on_the_next_start() {
        let device_present = Arc::new(AtomicBool::new(false));
        let calls = Arc::new(AtomicUsize::new(0));
        let engine = RetryingAudioEngine::new(factory(device_present.clone(), calls.clone()));
        assert!(engine.start("/music/a.mp3").is_err());

        device_present.store(true, Ordering::SeqCst);

        assert!(engine.start("/music/a.mp3").is_ok());
        assert!(engine.output_available());
        assert!(engine.start("/music/b.mp3").is_ok());
        assert_eq!(calls.load(Ordering::SeqCst), 3);
    }
}
