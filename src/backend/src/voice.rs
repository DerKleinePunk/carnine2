//! Spoken turn announcements: text to speech on the device.
//!
//! The map library says what to speak and when; this module turns the text
//! into a WAV file and hands it to the player, which plays it over the music.
//! Speech comes from sherpa-onnx (a Piper/VITS voice), loaded at run time from
//! `library_dir` - without the library or the voice the backend runs on with
//! no speech, so it starts and tests the same in WSL.
//!
//! Synthesis runs on one thread of its own, pinned to one core (`cpu`), so
//! the map's UI and raster threads keep the other three: measured on a Pi 4
//! (2026-10-06), the raster thread then waits no longer than without speech.
//! Texts announced ahead (`prepare`) are synthesized in the background and
//! kept, so the announcement itself only plays a file.

use std::collections::{HashMap, VecDeque};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::mpsc::{self, Receiver, Sender, TryRecvError};
use std::sync::{Arc, Mutex};
use std::thread;

use anyhow::{Context, Result};
use tracing::{info, warn};

use crate::config::VoiceConfig;
use crate::media_player::{AnnouncementLevels, AnnouncementPriority};

/// Synthesized speech, mono.
#[derive(Debug, Clone, PartialEq)]
pub struct Speech {
    pub samples: Vec<f32>,
    pub sample_rate: u32,
}

/// Turns text into speech.
pub trait Synthesizer: Send {
    fn synthesize(&mut self, text: &str) -> Result<Speech>;
}

/// Plays a finished announcement; the backend wires it to the media player.
pub type AnnouncementSink = Box<dyn Fn(&Path, AnnouncementPriority) + Send>;

/// Builds the synthesizer on the voice thread; it may take seconds (the
/// voice model is loaded there, not on the caller's thread).
pub type SynthesizerFactory = Box<dyn FnOnce() -> Result<Box<dyn Synthesizer>> + Send>;

/// How many synthesized texts stay on disk.
const CACHE_ENTRIES: usize = 200;

enum Command {
    Prepare(Vec<String>),
    /// With the moment it was asked for, to log how late it came out.
    Speak(String, AnnouncementPriority, std::time::Instant),
}

/// The voice: takes texts to prepare and to speak, works on its own thread.
pub struct Voice {
    commands: Mutex<Sender<Command>>,
    enabled: Arc<AtomicBool>,
    /// The voice loaded; until then, or when it failed, nothing is spoken.
    loaded: Arc<AtomicBool>,
}

impl Voice {
    /// Starts the voice thread. `cpu` pins it to that core when given.
    pub fn start(
        factory: SynthesizerFactory,
        cache_dir: PathBuf,
        cpu: Option<usize>,
        enabled: bool,
        sink: AnnouncementSink,
    ) -> Self {
        let (commands, receiver) = mpsc::channel();
        let enabled = Arc::new(AtomicBool::new(enabled));
        let loaded = Arc::new(AtomicBool::new(false));
        let thread_loaded = Arc::clone(&loaded);
        thread::Builder::new()
            .name("carnine-voice".to_string())
            .spawn(move || {
                if let Some(cpu) = cpu {
                    pin_to_cpu(cpu);
                }
                let synthesizer = match factory() {
                    Ok(synthesizer) => synthesizer,
                    Err(error) => {
                        warn!(error = %format!("{error:#}"), "no speech output: the voice did not load");
                        // Keep taking commands so callers never block or fail.
                        while receiver.recv().is_ok() {}
                        return;
                    }
                };
                thread_loaded.store(true, Ordering::Release);
                info!("voice ready");
                Worker::new(synthesizer, cache_dir, sink).run(receiver);
            })
            .expect("the voice thread starts");
        Self {
            commands: Mutex::new(commands),
            enabled,
            loaded,
        }
    }

    /// Whether a voice is loaded and speech can come out.
    pub fn available(&self) -> bool {
        self.loaded.load(Ordering::Acquire)
    }

    pub fn set_enabled(&self, enabled: bool) {
        self.enabled.store(enabled, Ordering::Release);
    }

    pub fn enabled(&self) -> bool {
        self.enabled.load(Ordering::Acquire)
    }

    /// Texts that may be spoken soon; synthesized in the background. A new
    /// list replaces one not yet worked through.
    pub fn prepare(&self, texts: Vec<String>) {
        if self.enabled() {
            self.send(Command::Prepare(texts));
        }
    }

    /// Speaks `text` now, from the cache when it was prepared.
    pub fn announce(&self, text: String, priority: AnnouncementPriority) {
        if self.enabled() && !text.trim().is_empty() {
            self.send(Command::Speak(text, priority, std::time::Instant::now()));
        }
    }

    fn send(&self, command: Command) {
        let _ = self
            .commands
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .send(command);
    }
}

/// Applies announcement and music levels; wired to the media player.
pub type LevelSetter = Box<dyn Fn(AnnouncementLevels) + Send + Sync>;

/// The voice with its settings: what the navigation service talks to.
pub struct VoiceControl {
    voice: Voice,
    voice_name: String,
    volume_percent: AtomicU32,
    music_under_percent: u32,
    set_levels: LevelSetter,
    /// Media database that keeps the settings; `None` in tests.
    database: Option<PathBuf>,
}

/// The settings as the options show them.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VoiceState {
    pub available: bool,
    pub enabled: bool,
    pub volume_percent: u32,
    pub voice: String,
}

impl std::fmt::Debug for VoiceControl {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        formatter
            .debug_struct("VoiceControl")
            .field("state", &self.state())
            .finish_non_exhaustive()
    }
}

impl VoiceControl {
    /// `saved` is what the options saved, overriding `config`.
    pub fn new(
        voice: Voice,
        config: &VoiceConfig,
        saved: (Option<bool>, Option<u32>),
        set_levels: LevelSetter,
        database: Option<PathBuf>,
    ) -> Self {
        voice.set_enabled(saved.0.unwrap_or(config.enabled));
        let control = Self {
            voice,
            voice_name: config.voice.clone(),
            volume_percent: AtomicU32::new(saved.1.unwrap_or(config.volume_percent).min(100)),
            music_under_percent: config.music_under_percent.min(100),
            set_levels,
            database,
        };
        control.apply_levels();
        control
    }

    pub fn state(&self) -> VoiceState {
        VoiceState {
            available: self.voice.available(),
            enabled: self.voice.enabled(),
            volume_percent: self.volume_percent.load(Ordering::Acquire),
            voice: self.voice_name.clone(),
        }
    }

    /// Changes what is given, saves it and answers with the new state; a
    /// loudness above 100 is refused.
    pub fn update(&self, enabled: Option<bool>, volume_percent: Option<u32>) -> Result<VoiceState> {
        if let Some(volume) = volume_percent {
            if volume > 100 {
                anyhow::bail!("volume_percent {volume} is above 100");
            }
            self.volume_percent.store(volume, Ordering::Release);
            self.apply_levels();
        }
        if let Some(enabled) = enabled {
            self.voice.set_enabled(enabled);
        }
        let state = self.state();
        info!(
            enabled = state.enabled,
            volume_percent = state.volume_percent,
            "voice settings changed"
        );
        if let Some(database) = &self.database {
            // Live already; a failed save only means the next start forgets it.
            if let Err(error) = crate::database::Database::open(database).and_then(|database| {
                database.save_voice_settings(state.enabled, state.volume_percent)
            }) {
                warn!(error = %format!("{error:#}"), "voice settings not saved");
            }
        }
        Ok(state)
    }

    pub fn prepare(&self, texts: Vec<String>) {
        self.voice.prepare(texts);
    }

    pub fn announce(&self, text: String, priority: AnnouncementPriority) {
        self.voice.announce(text, priority);
    }

    fn apply_levels(&self) {
        (self.set_levels)(AnnouncementLevels {
            volume: self.volume_percent.load(Ordering::Acquire) as f32 / 100.0,
            music_under: self.music_under_percent as f32 / 100.0,
        });
    }
}

struct Worker {
    synthesizer: Box<dyn Synthesizer>,
    cache_dir: PathBuf,
    sink: AnnouncementSink,
    cache: HashMap<String, PathBuf>,
    /// Cached texts, oldest first.
    order: VecDeque<String>,
    next_file: u64,
}

impl Worker {
    fn new(synthesizer: Box<dyn Synthesizer>, cache_dir: PathBuf, sink: AnnouncementSink) -> Self {
        if let Err(error) = std::fs::create_dir_all(&cache_dir) {
            warn!(dir = %cache_dir.display(), %error, "voice cache directory missing");
        }
        Self {
            synthesizer,
            cache_dir,
            sink,
            cache: HashMap::new(),
            order: VecDeque::new(),
            next_file: 0,
        }
    }

    fn run(mut self, receiver: Receiver<Command>) {
        let mut pending: VecDeque<String> = VecDeque::new();
        loop {
            // Waits only when there is nothing to prepare.
            let command = if pending.is_empty() {
                match receiver.recv() {
                    Ok(command) => Some(command),
                    Err(_) => return,
                }
            } else {
                match receiver.try_recv() {
                    Ok(command) => Some(command),
                    Err(TryRecvError::Empty) => None,
                    Err(TryRecvError::Disconnected) => return,
                }
            };
            match command {
                Some(Command::Prepare(texts)) => pending = texts.into(),
                Some(Command::Speak(text, priority, asked)) => {
                    // Announcements that queued up while one was synthesized
                    // are out of date; only the newest is spoken.
                    let mut newest = (text, priority, asked);
                    loop {
                        match receiver.try_recv() {
                            Ok(Command::Prepare(texts)) => pending = texts.into(),
                            Ok(Command::Speak(text, priority, asked)) => {
                                if priority >= newest.1 {
                                    newest = (text, priority, asked);
                                }
                            }
                            Err(_) => break,
                        }
                    }
                    let (text, priority, asked) = newest;
                    // The prepared sentences ahead of this one were for
                    // earlier steps of the maneuver; they will not come.
                    if let Some(index) = pending.iter().position(|queued| *queued == text) {
                        pending.drain(..=index);
                    }
                    if let Some(path) = self.speech_file(&text) {
                        (self.sink)(&path, priority);
                        info!(
                            text,
                            late_ms = asked.elapsed().as_millis() as u64,
                            "announcement spoken"
                        );
                    }
                }
                // One text at a time, so a Speak waits for at most one.
                None => {
                    if let Some(text) = pending.pop_front() {
                        self.speech_file(&text);
                    }
                }
            }
        }
    }

    /// The WAV file for `text`, synthesized now unless cached.
    fn speech_file(&mut self, text: &str) -> Option<PathBuf> {
        if let Some(path) = self.cache.get(text) {
            return Some(path.clone());
        }
        let started = std::time::Instant::now();
        let speech = match self.synthesizer.synthesize(text) {
            Ok(speech) => speech,
            Err(error) => {
                warn!(text, error = %format!("{error:#}"), "speech synthesis failed");
                return None;
            }
        };
        let path = self
            .cache_dir
            .join(format!("speech-{}.wav", self.next_file));
        self.next_file += 1;
        if let Err(error) = write_wav(&path, &speech) {
            warn!(path = %path.display(), %error, "writing speech failed");
            return None;
        }
        info!(
            text,
            synthesis_ms = started.elapsed().as_millis() as u64,
            audio_ms = (speech.samples.len() as u64 * 1000) / u64::from(speech.sample_rate.max(1)),
            "speech ready"
        );
        self.cache.insert(text.to_string(), path.clone());
        self.order.push_back(text.to_string());
        while self.order.len() > CACHE_ENTRIES {
            if let Some(oldest) = self.order.pop_front() {
                if let Some(old_path) = self.cache.remove(&oldest) {
                    let _ = std::fs::remove_file(old_path);
                }
            }
        }
        Some(path)
    }
}

/// Pins the calling thread to one core; logs and goes on when it fails.
fn pin_to_cpu(cpu: usize) {
    // SAFETY: cpu_set_t is plain data; sched_setaffinity(0, ..) changes only
    // the calling thread.
    let result = unsafe {
        let mut set: libc::cpu_set_t = std::mem::zeroed();
        libc::CPU_SET(cpu, &mut set);
        libc::sched_setaffinity(0, std::mem::size_of::<libc::cpu_set_t>(), &set)
    };
    if result != 0 {
        warn!(cpu, error = %std::io::Error::last_os_error(), "voice thread not pinned");
    }
}

/// Writes mono speech as 16-bit PCM WAV.
pub fn write_wav(path: &Path, speech: &Speech) -> Result<()> {
    let data_len = u32::try_from(speech.samples.len() * 2).context("speech too long for WAV")?;
    let mut bytes = Vec::with_capacity(44 + data_len as usize);
    bytes.extend_from_slice(b"RIFF");
    bytes.extend_from_slice(&(36 + data_len).to_le_bytes());
    bytes.extend_from_slice(b"WAVEfmt ");
    bytes.extend_from_slice(&16u32.to_le_bytes());
    bytes.extend_from_slice(&1u16.to_le_bytes()); // PCM
    bytes.extend_from_slice(&1u16.to_le_bytes()); // mono
    bytes.extend_from_slice(&speech.sample_rate.to_le_bytes());
    bytes.extend_from_slice(&(speech.sample_rate * 2).to_le_bytes());
    bytes.extend_from_slice(&2u16.to_le_bytes());
    bytes.extend_from_slice(&16u16.to_le_bytes());
    bytes.extend_from_slice(b"data");
    bytes.extend_from_slice(&data_len.to_le_bytes());
    for sample in &speech.samples {
        let value = (sample.clamp(-1.0, 1.0) * f32::from(i16::MAX)).round() as i16;
        bytes.extend_from_slice(&value.to_le_bytes());
    }
    // Written aside and renamed, so the player never reads half a file.
    let partial = path.with_extension("wav.part");
    std::fs::write(&partial, &bytes)
        .with_context(|| format!("failed to write {}", partial.display()))?;
    std::fs::rename(&partial, path)
        .with_context(|| format!("failed to move speech to {}", path.display()))?;
    Ok(())
}

/// sherpa-onnx's offline TTS through its C API, loaded with dlopen.
pub mod sherpa {
    use std::ffi::{c_char, c_void, CString};
    use std::path::Path;

    use anyhow::{bail, Context, Result};

    use super::{Speech, Synthesizer};

    /// The C API library; it finds libonnxruntime.so next to itself.
    pub const LIBRARY: &str = "libsherpa-onnx-c-api.so";

    // The structs below mirror sherpa-onnx v1.13.8's c-api.h field for field;
    // the library reads the whole config, so the layout must match exactly.
    #[repr(C)]
    struct Vits {
        model: *const c_char,
        lexicon: *const c_char,
        tokens: *const c_char,
        data_dir: *const c_char,
        noise_scale: f32,
        noise_scale_w: f32,
        length_scale: f32,
        dict_dir: *const c_char,
    }
    #[repr(C)]
    struct Matcha {
        acoustic_model: *const c_char,
        vocoder: *const c_char,
        lexicon: *const c_char,
        tokens: *const c_char,
        data_dir: *const c_char,
        noise_scale: f32,
        length_scale: f32,
        dict_dir: *const c_char,
    }
    #[repr(C)]
    struct Kokoro {
        model: *const c_char,
        voices: *const c_char,
        tokens: *const c_char,
        data_dir: *const c_char,
        length_scale: f32,
        dict_dir: *const c_char,
        lexicon: *const c_char,
        lang: *const c_char,
    }
    #[repr(C)]
    struct Kitten {
        model: *const c_char,
        voices: *const c_char,
        tokens: *const c_char,
        data_dir: *const c_char,
        length_scale: f32,
    }
    #[repr(C)]
    struct Zipvoice {
        tokens: *const c_char,
        encoder: *const c_char,
        decoder: *const c_char,
        vocoder: *const c_char,
        data_dir: *const c_char,
        lexicon: *const c_char,
        feat_scale: f32,
        t_shift: f32,
        target_rms: f32,
        guidance_scale: f32,
    }
    #[repr(C)]
    struct Pocket {
        lm_flow: *const c_char,
        lm_main: *const c_char,
        encoder: *const c_char,
        decoder: *const c_char,
        text_conditioner: *const c_char,
        vocab_json: *const c_char,
        token_scores_json: *const c_char,
        voice_embedding_cache_capacity: i32,
    }
    #[repr(C)]
    struct Supertonic {
        duration_predictor: *const c_char,
        text_encoder: *const c_char,
        vector_estimator: *const c_char,
        vocoder: *const c_char,
        tts_json: *const c_char,
        unicode_indexer: *const c_char,
        voice_style: *const c_char,
    }
    #[repr(C)]
    struct ModelConfig {
        vits: Vits,
        num_threads: i32,
        debug: i32,
        provider: *const c_char,
        matcha: Matcha,
        kokoro: Kokoro,
        kitten: Kitten,
        zipvoice: Zipvoice,
        pocket: Pocket,
        supertonic: Supertonic,
    }
    #[repr(C)]
    struct TtsConfig {
        model: ModelConfig,
        rule_fsts: *const c_char,
        max_num_sentences: i32,
        rule_fars: *const c_char,
        silence_scale: f32,
    }
    #[repr(C)]
    struct GeneratedAudio {
        samples: *const f32,
        n: i32,
        sample_rate: i32,
    }

    type Create = unsafe extern "C" fn(*const TtsConfig) -> *const c_void;
    type Destroy = unsafe extern "C" fn(*const c_void);
    type Generate =
        unsafe extern "C" fn(*const c_void, *const c_char, i32, f32) -> *const GeneratedAudio;
    type DestroyAudio = unsafe extern "C" fn(*const GeneratedAudio);

    pub struct SherpaSynthesizer {
        tts: *const c_void,
        generate: Generate,
        destroy: Destroy,
        destroy_audio: DestroyAudio,
        // Keeps the code behind the function pointers loaded.
        _library: libloading::Library,
    }

    // SAFETY: the TTS object is used from one thread at a time (the voice
    // thread owns the synthesizer).
    unsafe impl Send for SherpaSynthesizer {}

    impl SherpaSynthesizer {
        /// Loads the library from `library_dir` and the voice in `voice_dir`
        /// (one `*.onnx`, `tokens.txt`, `espeak-ng-data/`).
        pub fn load(library_dir: &Path, voice_dir: &Path, threads: i32) -> Result<Self> {
            let model = std::fs::read_dir(voice_dir)
                .with_context(|| format!("voice {} not found", voice_dir.display()))?
                .filter_map(|entry| entry.ok().map(|entry| entry.path()))
                .find(|path| {
                    path.extension()
                        .is_some_and(|extension| extension == "onnx")
                })
                .with_context(|| format!("no .onnx model in {}", voice_dir.display()))?;
            let tokens = voice_dir.join("tokens.txt");
            let data_dir = voice_dir.join("espeak-ng-data");
            if !tokens.is_file() || !data_dir.is_dir() {
                bail!("{} lacks tokens.txt or espeak-ng-data", voice_dir.display());
            }
            let library_path = library_dir.join(LIBRARY);
            // SAFETY: loading runs the library's initialisers; it is the
            // sherpa-onnx release we package.
            let library = unsafe { libloading::Library::new(&library_path) }
                .with_context(|| format!("cannot load {}", library_path.display()))?;
            // SAFETY: the symbols have these signatures in v1.13.8.
            let (create, destroy, generate, destroy_audio) = unsafe {
                (
                    *library.get::<Create>(b"SherpaOnnxCreateOfflineTts\0")?,
                    *library.get::<Destroy>(b"SherpaOnnxDestroyOfflineTts\0")?,
                    *library.get::<Generate>(b"SherpaOnnxOfflineTtsGenerate\0")?,
                    *library.get::<DestroyAudio>(b"SherpaOnnxDestroyOfflineTtsGeneratedAudio\0")?,
                )
            };
            let c = |path: &Path| {
                CString::new(path.to_string_lossy().as_bytes()).context("path with NUL")
            };
            let (model, tokens, data_dir) = (c(&model)?, c(&tokens)?, c(&data_dir)?);
            let provider = CString::new("cpu").expect("no NUL");
            // SAFETY: all-zero is a valid "unset" for every field (null
            // pointers, zero numbers); the needed ones are set below.
            let mut config: TtsConfig = unsafe { std::mem::zeroed() };
            config.model.vits.model = model.as_ptr();
            config.model.vits.tokens = tokens.as_ptr();
            config.model.vits.data_dir = data_dir.as_ptr();
            config.model.vits.noise_scale = 0.667;
            config.model.vits.noise_scale_w = 0.8;
            config.model.vits.length_scale = 1.0;
            config.model.num_threads = threads.max(1);
            config.model.provider = provider.as_ptr();
            config.max_num_sentences = 1;
            config.silence_scale = 0.2;
            // SAFETY: config and its strings live until the call returns;
            // sherpa-onnx copies what it keeps.
            let tts = unsafe { create(&config) };
            if tts.is_null() {
                bail!(
                    "sherpa-onnx did not accept the voice in {}",
                    voice_dir.display()
                );
            }
            Ok(Self {
                tts,
                generate,
                destroy,
                destroy_audio,
                _library: library,
            })
        }
    }

    impl Synthesizer for SherpaSynthesizer {
        fn synthesize(&mut self, text: &str) -> Result<Speech> {
            let text = CString::new(text).context("text with NUL")?;
            // SAFETY: tts is valid until drop; speaker 0, normal speed.
            let audio = unsafe { (self.generate)(self.tts, text.as_ptr(), 0, 1.0) };
            if audio.is_null() {
                bail!("sherpa-onnx produced no audio");
            }
            // SAFETY: audio points to n samples until it is destroyed below.
            let speech = unsafe {
                let generated = &*audio;
                let samples = if generated.samples.is_null() || generated.n <= 0 {
                    Vec::new()
                } else {
                    std::slice::from_raw_parts(generated.samples, generated.n as usize).to_vec()
                };
                let sample_rate = generated.sample_rate.max(1) as u32;
                (self.destroy_audio)(audio);
                Speech {
                    samples,
                    sample_rate,
                }
            };
            if speech.samples.is_empty() {
                bail!("sherpa-onnx produced empty audio");
            }
            Ok(speech)
        }
    }

    impl Drop for SherpaSynthesizer {
        fn drop(&mut self) {
            // SAFETY: created in load, destroyed once.
            unsafe { (self.destroy)(self.tts) };
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::mpsc::RecvTimeoutError;
    use std::time::Duration;

    /// Counts what it synthesizes; "fail" fails, "slow" takes 300 ms.
    struct Fake {
        calls: Arc<Mutex<Vec<String>>>,
    }

    impl Synthesizer for Fake {
        fn synthesize(&mut self, text: &str) -> Result<Speech> {
            self.calls.lock().unwrap().push(text.to_string());
            if text.starts_with("slow") {
                thread::sleep(Duration::from_millis(300));
            }
            if text == "fail" {
                anyhow::bail!("broken voice");
            }
            Ok(Speech {
                samples: vec![0.0, 0.5, -0.5, 1.5],
                sample_rate: 22_050,
            })
        }
    }

    struct Rig {
        voice: Voice,
        calls: Arc<Mutex<Vec<String>>>,
        played: Receiver<(PathBuf, AnnouncementPriority)>,
        dir: PathBuf,
    }

    impl Rig {
        fn new(name: &str) -> Self {
            let calls = Arc::new(Mutex::new(Vec::new()));
            let factory_calls = Arc::clone(&calls);
            let (played_sender, played) = mpsc::channel();
            let played_sender = Mutex::new(played_sender);
            let dir =
                std::env::temp_dir().join(format!("carnine-voice-{name}-{}", std::process::id()));
            let voice = Voice::start(
                Box::new(move || {
                    Ok(Box::new(Fake {
                        calls: factory_calls,
                    }) as Box<dyn Synthesizer>)
                }),
                dir.clone(),
                None,
                true,
                Box::new(move |path, priority| {
                    let _ = played_sender
                        .lock()
                        .unwrap()
                        .send((path.to_path_buf(), priority));
                }),
            );
            Self {
                voice,
                calls,
                played,
                dir,
            }
        }

        fn next_played(&self) -> Result<(PathBuf, AnnouncementPriority), RecvTimeoutError> {
            self.played.recv_timeout(Duration::from_secs(5))
        }

        /// Waits until the voice thread synthesized `count` texts.
        fn wait_for_calls(&self, count: usize) -> Vec<String> {
            for _ in 0..500 {
                let calls = self.calls.lock().unwrap().clone();
                if calls.len() >= count {
                    return calls;
                }
                thread::sleep(Duration::from_millis(10));
            }
            panic!("only {:?}", self.calls.lock().unwrap());
        }
    }

    impl Drop for Rig {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.dir);
        }
    }

    #[test]
    fn a_prepared_text_is_spoken_from_the_cache() {
        let rig = Rig::new("prepared");
        rig.voice.prepare(vec![
            "In 300 Metern rechts abbiegen.".into(),
            "Jetzt rechts abbiegen.".into(),
        ]);
        assert_eq!(rig.wait_for_calls(2).len(), 2);

        rig.voice.announce(
            "Jetzt rechts abbiegen.".into(),
            AnnouncementPriority::Maneuver,
        );
        let (path, priority) = rig.next_played().expect("played");
        assert_eq!(priority, AnnouncementPriority::Maneuver);
        assert!(path.starts_with(&rig.dir) && path.is_file());
        assert_eq!(rig.calls.lock().unwrap().len(), 2, "not synthesized again");
    }

    #[test]
    fn a_text_never_prepared_is_synthesized_when_announced() {
        let rig = Rig::new("unprepared");
        rig.voice.announce(
            "Die Route wird neu berechnet.".into(),
            AnnouncementPriority::Info,
        );
        let (_, priority) = rig.next_played().expect("played");
        assert_eq!(priority, AnnouncementPriority::Info);
        assert_eq!(rig.wait_for_calls(1), ["Die Route wird neu berechnet."]);
    }

    #[test]
    fn announcements_that_queue_up_are_dropped_for_the_newest() {
        let rig = Rig::new("queued");
        rig.voice
            .announce("slow first".into(), AnnouncementPriority::Maneuver);
        // Sent while the first one is synthesized.
        thread::sleep(Duration::from_millis(100));
        rig.voice
            .announce("old turn".into(), AnnouncementPriority::Maneuver);
        rig.voice
            .announce("newest turn".into(), AnnouncementPriority::Maneuver);
        rig.voice
            .announce("an information".into(), AnnouncementPriority::Info);

        rig.next_played().expect("the first plays");
        rig.next_played().expect("then one more");
        assert!(
            rig.played.recv_timeout(Duration::from_millis(300)).is_err(),
            "no backlog"
        );
        assert_eq!(
            rig.wait_for_calls(2),
            ["slow first", "newest turn"],
            "the newest turn instruction wins over older ones and the information"
        );
    }

    #[test]
    fn a_spoken_sentence_drops_the_prepared_ones_before_it() {
        let rig = Rig::new("drops");
        // The first one keeps the voice busy while the rest arrives.
        rig.voice.prepare(vec![
            "slow 1 km".into(),
            "400 m".into(),
            "300 m".into(),
            "now".into(),
        ]);
        thread::sleep(Duration::from_millis(100));
        rig.voice
            .announce("300 m".into(), AnnouncementPriority::Maneuver);
        rig.next_played().expect("played");
        assert_eq!(
            rig.wait_for_calls(3),
            ["slow 1 km", "300 m", "now"],
            "400 m skipped"
        );
        thread::sleep(Duration::from_millis(200));
        assert_eq!(rig.calls.lock().unwrap().len(), 3, "nothing else");
    }

    #[test]
    fn a_failing_text_plays_nothing_and_the_voice_goes_on() {
        let rig = Rig::new("failing");
        rig.voice
            .announce("fail".into(), AnnouncementPriority::Maneuver);
        rig.voice.announce(
            "Jetzt links abbiegen.".into(),
            AnnouncementPriority::Maneuver,
        );
        let (path, _) = rig.next_played().expect("the second one plays");
        assert!(path.is_file());
        assert!(
            rig.played.recv_timeout(Duration::from_millis(300)).is_err(),
            "nothing for the failed one"
        );
    }

    #[test]
    fn switched_off_it_neither_prepares_nor_speaks() {
        let rig = Rig::new("off");
        rig.voice.set_enabled(false);
        rig.voice.prepare(vec!["a".into()]);
        rig.voice
            .announce("b".into(), AnnouncementPriority::Maneuver);
        assert!(rig.played.recv_timeout(Duration::from_millis(300)).is_err());
        assert!(rig.calls.lock().unwrap().is_empty());
    }

    #[test]
    fn without_a_voice_announcements_are_taken_and_dropped() {
        let (sender, played) = mpsc::channel::<PathBuf>();
        let sender = Mutex::new(sender);
        let voice = Voice::start(
            Box::new(|| anyhow::bail!("no libsherpa-onnx-c-api.so")),
            std::env::temp_dir().join("carnine-voice-none"),
            None,
            true,
            Box::new(move |path, _| {
                let _ = sender.lock().unwrap().send(path.to_path_buf());
            }),
        );
        voice.prepare(vec!["a".into()]);
        voice.announce("b".into(), AnnouncementPriority::Maneuver);
        assert!(played.recv_timeout(Duration::from_millis(300)).is_err());
    }

    fn voice_control(
        config: &VoiceConfig,
        saved: (Option<bool>, Option<u32>),
    ) -> (VoiceControl, Arc<Mutex<Vec<AnnouncementLevels>>>) {
        let levels = Arc::new(Mutex::new(Vec::new()));
        let seen = Arc::clone(&levels);
        let voice = Voice::start(
            Box::new(|| anyhow::bail!("no voice in tests")),
            std::env::temp_dir().join("carnine-voice-control"),
            None,
            false,
            Box::new(|_, _| {}),
        );
        let control = VoiceControl::new(
            voice,
            config,
            saved,
            Box::new(move |level| seen.lock().unwrap().push(level)),
            None,
        );
        (control, levels)
    }

    #[test]
    fn the_saved_settings_win_over_the_configuration() {
        let config = VoiceConfig {
            volume_percent: 90,
            music_under_percent: 20,
            ..VoiceConfig::default()
        };
        let (control, levels) = voice_control(&config, (None, None));
        assert!(control.state().enabled, "on by default");
        assert_eq!(control.state().volume_percent, 90);
        assert_eq!(control.state().voice, "thorsten-medium");
        assert!(!control.state().available, "no voice loaded");
        assert_eq!(
            levels.lock().unwrap().last(),
            Some(&AnnouncementLevels {
                volume: 0.9,
                music_under: 0.2
            })
        );

        let (control, levels) = voice_control(&config, (Some(false), Some(40)));
        assert!(!control.state().enabled);
        assert_eq!(control.state().volume_percent, 40);
        assert_eq!(levels.lock().unwrap().last().unwrap().volume, 0.4);
    }

    #[test]
    fn settings_change_live_and_a_loudness_above_100_is_refused() {
        let (control, levels) = voice_control(&VoiceConfig::default(), (None, None));
        let state = control.update(Some(false), Some(55)).unwrap();
        assert!(!state.enabled);
        assert_eq!(state.volume_percent, 55);
        assert_eq!(levels.lock().unwrap().last().unwrap().volume, 0.55);

        assert!(control.update(None, Some(101)).is_err());
        assert_eq!(control.state().volume_percent, 55, "unchanged");
        let state = control.update(Some(true), None).unwrap();
        assert!(state.enabled);
        assert_eq!(state.volume_percent, 55, "only what is given changes");
    }

    #[test]
    fn the_wav_is_16_bit_mono_with_clamped_samples() {
        let path =
            std::env::temp_dir().join(format!("carnine-voice-wav-{}.wav", std::process::id()));
        write_wav(
            &path,
            &Speech {
                samples: vec![0.0, 1.0, -2.0],
                sample_rate: 22_050,
            },
        )
        .unwrap();
        let bytes = std::fs::read(&path).unwrap();
        let _ = std::fs::remove_file(&path);
        assert_eq!(&bytes[0..4], b"RIFF");
        assert_eq!(&bytes[8..16], b"WAVEfmt ");
        assert_eq!(u16::from_le_bytes([bytes[22], bytes[23]]), 1, "mono");
        assert_eq!(
            u32::from_le_bytes(bytes[24..28].try_into().unwrap()),
            22_050
        );
        assert_eq!(
            u32::from_le_bytes(bytes[40..44].try_into().unwrap()),
            6,
            "3 samples"
        );
        let samples: Vec<i16> = bytes[44..]
            .chunks(2)
            .map(|b| i16::from_le_bytes([b[0], b[1]]))
            .collect();
        assert_eq!(samples, [0, i16::MAX, -i16::MAX]);
    }

    /// Against the real library and a real voice, when they are given:
    /// CARNINE_TEST_SHERPA_LIB=<dir with libsherpa-onnx-c-api.so>
    /// CARNINE_TEST_SHERPA_VOICE=<voice dir>. Checks the C struct layout.
    #[test]
    fn the_real_sherpa_voice_speaks_when_installed() {
        let (Ok(library), Ok(voice)) = (
            std::env::var("CARNINE_TEST_SHERPA_LIB"),
            std::env::var("CARNINE_TEST_SHERPA_VOICE"),
        ) else {
            return;
        };
        let mut synthesizer =
            sherpa::SherpaSynthesizer::load(Path::new(&library), Path::new(&voice), 1)
                .expect("the voice loads");
        let speech = synthesizer
            .synthesize("In 300 Metern rechts abbiegen.")
            .expect("speech");
        let seconds = speech.samples.len() as f32 / speech.sample_rate as f32;
        assert_eq!(speech.sample_rate, 22_050);
        assert!((1.0..5.0).contains(&seconds), "{seconds} s");
        if let Ok(out) = std::env::var("CARNINE_TEST_SHERPA_OUT") {
            write_wav(Path::new(&out), &speech).unwrap();
        }
    }

    #[test]
    fn the_sherpa_voice_needs_its_files() {
        let empty =
            std::env::temp_dir().join(format!("carnine-voice-empty-{}", std::process::id()));
        std::fs::create_dir_all(&empty).unwrap();
        let error = match sherpa::SherpaSynthesizer::load(&empty, &empty, 1) {
            Err(error) => format!("{error:#}"),
            Ok(_) => panic!("an empty directory is no voice"),
        };
        let _ = std::fs::remove_dir_all(&empty);
        assert!(error.contains("no .onnx model"), "{error}");
    }
}
