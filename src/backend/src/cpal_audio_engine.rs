use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use anyhow::{Context, Result};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use tracing::{error, info, warn};

use crate::audio_engine::{AudioEngine, Playback};
use crate::audio_mixer::{AudioMixer, SourceId, CHANNELS, SURROUND_CHANNELS};
use crate::audio_source::ExternalPcmSource;

const FADE_MILLISECONDS: u32 = 250;
const SOURCE_BUFFER_FRAMES: usize = 44_100 * 2;
const SOURCE_START_TIMEOUT: Duration = Duration::from_secs(2);

enum MixerCommand {
    Add {
        consumer: ringbuf::HeapCons<f32>,
        reply: mpsc::SyncSender<Result<SourceId>>,
        cancelled: Arc<AtomicBool>,
    },
    SetLevels {
        source_id: SourceId,
        front: f32,
        rear: f32,
    },
    Remove {
        source_id: SourceId,
    },
}

/// The output stream, taken out and dropped once it failed (#59).
type StreamSlot = Arc<Mutex<Option<cpal::Stream>>>;

/// Remembers that the output stream failed.
///
/// After an xrun (e.g. the process was stopped, HDMI dropped out) cpal's ALSA
/// worker reports `POLLERR` to the error callback in a tight loop. Logging
/// each call filled 12-15 GB of log within the hour and kept a core busy,
/// and the stream never played again (#59). Only the first error is logged;
/// the stream is then dropped and the engine reports no output, so the
/// retrying engine opens a new one on the next start.
#[derive(Debug, Default)]
pub(crate) struct StreamFault {
    broken: AtomicBool,
    errors: AtomicU64,
}

impl StreamFault {
    /// Counts an error; true only for the first one.
    pub(crate) fn record(&self) -> bool {
        self.errors.fetch_add(1, Ordering::Relaxed);
        !self.broken.swap(true, Ordering::AcqRel)
    }

    pub(crate) fn is_broken(&self) -> bool {
        self.broken.load(Ordering::Acquire)
    }

    pub(crate) fn errors(&self) -> u64 {
        self.errors.load(Ordering::Relaxed)
    }
}

#[derive(Clone)]
pub struct CpalAudioEngine {
    command_sender: Sender<MixerCommand>,
    stream: StreamSlot,
    fault: Arc<StreamFault>,
    sample_rate: u32,
    rear_speakers: bool,
}

impl CpalAudioEngine {
    /// Opens the default output device with `channels`, or with its own
    /// default configuration when none is given.
    pub fn new(channels: Option<u16>, rear_level: f32) -> Result<Self> {
        let host = cpal::default_host();
        let device = host
            .default_output_device()
            .context("no default cpal output device")?;
        let supported = match channels {
            None => device
                .default_output_config()
                .context("failed to read cpal output configuration")?,
            Some(wanted) => output_config_with_channels(&device, wanted)?,
        };
        let sample_rate = supported.sample_rate().0;
        let channels = supported.channels() as usize;
        let (command_sender, command_receiver) = mpsc::channel();
        let mixer = AudioMixer::new(sample_rate, FADE_MILLISECONDS);
        let slot: StreamSlot = Arc::new(Mutex::new(None));
        let fault = Arc::new(StreamFault::default());
        let stream = build_stream(
            &device,
            &supported.config(),
            supported.sample_format(),
            OutputLayout {
                channels,
                rear_level: rear_level.clamp(0.0, 1.0),
            },
            mixer,
            command_receiver,
            stream_error_handler(Arc::clone(&fault), Arc::clone(&slot)),
        )?;
        stream
            .play()
            .context("failed to start cpal output stream")?;
        info!(
            sample_rate,
            channels,
            sample_format = ?supported.sample_format(),
            "cpal audio output stream started"
        );
        *slot.lock().unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(stream);
        Ok(Self {
            command_sender,
            stream: slot,
            fault,
            sample_rate,
            rear_speakers: channels >= SURROUND_CHANNELS,
        })
    }
}

/// A configuration of `device` with exactly `channels`; see
/// [`choose_output_config`].
fn output_config_with_channels(
    device: &cpal::Device,
    channels: u16,
) -> Result<cpal::SupportedStreamConfig> {
    let preferred_rate = device
        .default_output_config()
        .map(|config| config.sample_rate().0)
        .unwrap_or(48_000);
    let ranges: Vec<_> = device
        .supported_output_configs()
        .context("failed to list cpal output configurations")?
        .collect();
    choose_output_config(&ranges, channels, preferred_rate)
}

/// Picks from `ranges` one with exactly `channels` in a sample format the
/// stream can write (f32, then i16, then u16 - ALSA's plug offers I8 and
/// more first), at `preferred_rate` (the device's default) when the range
/// holds it, else at 48 kHz (what an AC-3 encoder takes) or its highest rate.
fn choose_output_config(
    ranges: &[cpal::SupportedStreamConfigRange],
    channels: u16,
    preferred_rate: u32,
) -> Result<cpal::SupportedStreamConfig> {
    let holds = |range: &cpal::SupportedStreamConfigRange, rate: u32| {
        (range.min_sample_rate().0..=range.max_sample_rate().0).contains(&rate)
    };
    for format in [
        cpal::SampleFormat::F32,
        cpal::SampleFormat::I16,
        cpal::SampleFormat::U16,
    ] {
        let usable: Vec<_> = ranges
            .iter()
            .filter(|range| range.channels() == channels && range.sample_format() == format)
            .collect();
        for rate in [preferred_rate, 48_000] {
            if let Some(range) = usable.iter().find(|range| holds(range, rate)) {
                return Ok(range.with_sample_rate(cpal::SampleRate(rate)));
            }
        }
        if let Some(range) = usable.first() {
            return Ok(range.with_max_sample_rate());
        }
    }
    anyhow::bail!("the output device offers no usable configuration with {channels} channels")
}

/// The cpal error callback: logs the first error, then drops the stream on
/// a thread of its own - dropping it joins cpal's worker, which is the
/// thread running this callback - so the error loop stops.
fn stream_error_handler(
    fault: Arc<StreamFault>,
    slot: StreamSlot,
) -> impl FnMut(cpal::StreamError) + Send + 'static {
    move |stream_error| {
        if !fault.record() {
            return;
        }
        error!(
            error = %stream_error,
            "cpal audio output stream failed; dropping it, the next start opens a new one"
        );
        let slot = Arc::clone(&slot);
        let fault = Arc::clone(&fault);
        let _ = thread::Builder::new()
            .name("cpal-stream-drop".to_string())
            .spawn(move || {
                let stream = slot
                    .lock()
                    .unwrap_or_else(|poisoned| poisoned.into_inner())
                    .take();
                drop(stream);
                warn!(errors = fault.errors(), "cpal audio output stream dropped");
            });
    }
}

impl AudioEngine for CpalAudioEngine {
    fn start(&self, input_path: &str) -> Result<Box<dyn Playback>> {
        self.start_at(input_path, 0)
    }

    fn start_at(&self, input_path: &str, position_ms: i64) -> Result<Box<dyn Playback>> {
        if self.fault.is_broken() {
            anyhow::bail!("cpal audio output stream failed and was dropped");
        }
        let (source, consumer) = ExternalPcmSource::start_at(
            input_path,
            self.sample_rate,
            SOURCE_BUFFER_FRAMES,
            position_ms,
        )?;
        let (reply_sender, reply_receiver) = mpsc::sync_channel(1);
        let cancelled = Arc::new(AtomicBool::new(false));
        self.command_sender
            .send(MixerCommand::Add {
                consumer,
                reply: reply_sender,
                cancelled: Arc::clone(&cancelled),
            })
            .map_err(|_| anyhow::anyhow!("cpal mixer thread is not available"))?;
        let source_id = match reply_receiver.recv_timeout(SOURCE_START_TIMEOUT) {
            Ok(Ok(source_id)) => source_id,
            Ok(Err(error)) => {
                let _ = source.stop();
                return Err(error);
            }
            Err(error) => {
                cancelled.store(true, Ordering::Release);
                let _ = source.stop();
                return Err(anyhow::anyhow!(
                    "timed out waiting for cpal mixer to accept audio source: {error}"
                ));
            }
        };
        info!(source_id = ?source_id, input_path, position_ms, "cpal audio source started");
        Ok(Box::new(CpalPlayback {
            command_sender: self.command_sender.clone(),
            source_id,
            source: Some(source),
        }))
    }

    fn shutdown(&self) -> Result<()> {
        let stream = self
            .stream
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        let Some(stream) = stream.as_ref() else {
            return Ok(());
        };
        stream
            .pause()
            .context("failed to pause cpal output stream")?;
        info!("cpal audio output stream paused for shutdown");
        Ok(())
    }

    fn output_available(&self) -> bool {
        !self.fault.is_broken()
    }

    fn has_rear_speakers(&self) -> bool {
        self.rear_speakers
    }
}

#[derive(Debug)]
struct CpalPlayback {
    command_sender: Sender<MixerCommand>,
    source_id: SourceId,
    source: Option<ExternalPcmSource>,
}

impl Playback for CpalPlayback {
    fn pause(&self) -> Result<()> {
        info!(source_id = ?self.source_id, "cpal audio source pause requested");
        self.command_sender
            .send(MixerCommand::SetLevels {
                source_id: self.source_id,
                front: 0.0,
                rear: 0.0,
            })
            .map_err(|_| anyhow::anyhow!("cpal mixer thread is not available"))?;
        Ok(())
    }

    fn resume(&self) -> Result<()> {
        info!(source_id = ?self.source_id, "cpal audio source resume requested");
        self.command_sender
            .send(MixerCommand::SetLevels {
                source_id: self.source_id,
                front: 1.0,
                rear: 1.0,
            })
            .map_err(|_| anyhow::anyhow!("cpal mixer thread is not available"))?;
        Ok(())
    }

    fn set_gain(&self, gain: f32) -> Result<()> {
        self.set_levels(gain, gain)
    }

    fn set_levels(&self, front: f32, rear: f32) -> Result<()> {
        self.command_sender
            .send(MixerCommand::SetLevels {
                source_id: self.source_id,
                front: front.clamp(0.0, 1.0),
                rear: rear.clamp(0.0, 1.0),
            })
            .map_err(|_| anyhow::anyhow!("cpal mixer thread is not available"))?;
        Ok(())
    }

    fn stop(mut self: Box<Self>) -> Result<()> {
        info!(source_id = ?self.source_id, "cpal audio source stop requested");
        // Without a mixer - the stream failed and was dropped (#59) - there
        // is nothing to fade or remove, but the decoder must still stop, or
        // every later start would fail on stopping this playback first.
        let mixer_alive = self
            .command_sender
            .send(MixerCommand::SetLevels {
                source_id: self.source_id,
                front: 0.0,
                rear: 0.0,
            })
            .is_ok();
        if mixer_alive {
            thread::sleep(Duration::from_millis(FADE_MILLISECONDS as u64));
            let _ = self.command_sender.send(MixerCommand::Remove {
                source_id: self.source_id,
            });
        } else {
            warn!(source_id = ?self.source_id, "cpal mixer is gone, stopping the decoder only");
        }
        if let Some(source) = self.source.take() {
            let decoded_samples = source.stop()?;
            info!(
                source_id = ?self.source_id,
                decoded_samples,
                "cpal audio decoder stopped"
            );
        }
        info!(source_id = ?self.source_id, "cpal audio source removed");
        Ok(())
    }

    fn is_finished(&self) -> bool {
        self.source
            .as_ref()
            .map(|source| source.is_finished())
            .unwrap_or(false)
    }
}

/// How the mixed frames go out: the device's channel count, and the level of
/// the rear speakers relative to the front (`[audio] rear_percent`).
#[derive(Debug, Clone, Copy)]
struct OutputLayout {
    channels: usize,
    rear_level: f32,
}

impl OutputLayout {
    #[cfg(test)]
    fn stereo() -> Self {
        Self {
            channels: CHANNELS,
            rear_level: 1.0,
        }
    }
}

fn build_stream(
    device: &cpal::Device,
    config: &cpal::StreamConfig,
    sample_format: cpal::SampleFormat,
    layout: OutputLayout,
    mixer: AudioMixer,
    command_receiver: Receiver<MixerCommand>,
    on_error: impl FnMut(cpal::StreamError) + Send + 'static,
) -> Result<cpal::Stream> {
    match sample_format {
        cpal::SampleFormat::F32 => {
            build_typed_stream::<f32>(device, config, layout, mixer, command_receiver, on_error)
        }
        cpal::SampleFormat::I16 => {
            build_typed_stream::<i16>(device, config, layout, mixer, command_receiver, on_error)
        }
        cpal::SampleFormat::U16 => {
            build_typed_stream::<u16>(device, config, layout, mixer, command_receiver, on_error)
        }
        format => anyhow::bail!("unsupported output sample format: {format:?}"),
    }
}

fn build_typed_stream<T>(
    device: &cpal::Device,
    config: &cpal::StreamConfig,
    layout: OutputLayout,
    mut mixer: AudioMixer,
    command_receiver: Receiver<MixerCommand>,
    on_error: impl FnMut(cpal::StreamError) + Send + 'static,
) -> Result<cpal::Stream>
where
    T: cpal::SizedSample + cpal::FromSample<f32>,
{
    Ok(device.build_output_stream(
        config,
        move |output: &mut [T], _info| {
            fill_output(output, layout, &mut mixer, &command_receiver);
        },
        on_error,
        None,
    )?)
}

/// One output callback: applies the pending mixer commands, then renders
/// `output`. Kept apart from the device so the tests can drive the real
/// engine without a sound card (#2).
fn fill_output<T>(
    output: &mut [T],
    layout: OutputLayout,
    mixer: &mut AudioMixer,
    command_receiver: &Receiver<MixerCommand>,
) where
    T: cpal::SizedSample + cpal::FromSample<f32>,
{
    for command in command_receiver.try_iter() {
        apply_command(mixer, command);
    }
    let channels = layout.channels;
    if channels >= SURROUND_CHANNELS {
        // ALSA's order: front left/right, rear left/right, then centre and
        // LFE for 5.1, which stay silent.
        let mut mixed_frame = [0.0_f32; SURROUND_CHANNELS];
        for frame in output.chunks_mut(channels) {
            let _ = mixer.render_surround(&mut mixed_frame);
            mixed_frame[2] *= layout.rear_level;
            mixed_frame[3] *= layout.rear_level;
            for (index, channel) in frame.iter_mut().enumerate() {
                *channel = T::from_sample(mixed_frame.get(index).copied().unwrap_or(0.0));
            }
        }
        return;
    }
    let mut mixed_frame = [0.0_f32; CHANNELS];
    for frame in output.chunks_mut(channels) {
        let _ = mixer.render(&mut mixed_frame);
        match frame {
            [] => {}
            [mono] => *mono = T::from_sample((mixed_frame[0] + mixed_frame[1]) * 0.5),
            [left, right, rest @ ..] => {
                *left = T::from_sample(mixed_frame[0]);
                *right = T::from_sample(mixed_frame[1]);
                for channel in rest {
                    *channel = T::from_sample(0.0);
                }
            }
        }
    }
}

fn apply_command(mixer: &mut AudioMixer, command: MixerCommand) {
    match command {
        MixerCommand::Add {
            consumer,
            reply,
            cancelled,
        } => {
            let result = if cancelled.load(Ordering::Acquire) {
                Err(anyhow::anyhow!("cpal audio source start was cancelled"))
            } else {
                mixer.add_stream_source(consumer, 1.0)
            };
            let _ = reply.send(result);
        }
        MixerCommand::SetLevels {
            source_id,
            front,
            rear,
        } => {
            let _ = mixer.set_levels(source_id, front, rear);
        }
        MixerCommand::Remove { source_id } => {
            let _ = mixer.remove_source(source_id);
        }
    }
}

/// The real engine - decoder, ring buffers, mixer and its commands - with an
/// output thread in place of the sound card (#2). The thread renders
/// `period_frames` at a time, sleeps `pace` in between, and hands each
/// rendered stereo block to `sink`, which is how a test hears what played.
/// It ends once the engine and all its playbacks are dropped.
#[cfg(test)]
pub(crate) fn engine_with_null_output(
    sample_rate: u32,
    period_frames: usize,
    pace: Duration,
    mut sink: impl FnMut(&[f32]) + Send + 'static,
) -> CpalAudioEngine {
    let (command_sender, command_receiver) = mpsc::channel();
    let mut mixer = AudioMixer::new(sample_rate, FADE_MILLISECONDS);
    thread::Builder::new()
        .name("null-audio-output".to_string())
        .spawn(move || {
            let mut output = vec![0.0_f32; period_frames * CHANNELS];
            loop {
                match command_receiver.try_recv() {
                    Ok(command) => apply_command(&mut mixer, command),
                    Err(mpsc::TryRecvError::Empty) => {}
                    Err(mpsc::TryRecvError::Disconnected) => return,
                }
                fill_output(
                    &mut output,
                    OutputLayout::stereo(),
                    &mut mixer,
                    &command_receiver,
                );
                sink(&output);
                thread::sleep(pace);
            }
        })
        .expect("null output thread should start");
    CpalAudioEngine {
        command_sender,
        stream: Arc::new(Mutex::new(None)),
        fault: Arc::new(StreamFault::default()),
        sample_rate,
        rear_speakers: false,
    }
}

#[cfg(test)]
mod tests {
    use std::sync::mpsc;
    use std::sync::{Arc, Mutex};

    use super::{
        fill_output, stream_error_handler, CpalPlayback, MixerCommand, OutputLayout, StreamFault,
    };
    use crate::audio_engine::Playback;
    use crate::audio_mixer::{AudioMixer, SourceId};

    /// One stereo frame (0.5, 0.25) of music at 0.3 in front and full at the
    /// back, plus one of an announcement (0.2, 0.2) only in front, put out
    /// with `channels`.
    fn fill_one_frame(channels: usize) -> Vec<f32> {
        fill_one_frame_with_rear(channels, 1.0)
    }

    fn fill_one_frame_with_rear(channels: usize, rear_level: f32) -> Vec<f32> {
        let mut mixer = AudioMixer::new(1, 1);
        let music = mixer.add_source(vec![0.5, 0.25], 1.0).unwrap();
        let announcement = mixer.add_source(vec![0.2, 0.2], 1.0).unwrap();
        mixer.set_levels(music, 0.3, 1.0).unwrap();
        mixer.set_levels(announcement, 1.0, 0.0).unwrap();
        let (_sender, receiver) = mpsc::channel::<MixerCommand>();
        let mut output = vec![9.0_f32; channels];
        fill_output(
            &mut output,
            OutputLayout {
                channels,
                rear_level,
            },
            &mut mixer,
            &receiver,
        );
        output
    }

    fn assert_close(actual: &[f32], expected: &[f32]) {
        assert_eq!(actual.len(), expected.len(), "{actual:?}");
        assert!(
            actual
                .iter()
                .zip(expected)
                .all(|(a, e)| (a - e).abs() < 0.0001),
            "{actual:?} != {expected:?}"
        );
    }

    fn range(
        channels: u16,
        min: u32,
        max: u32,
        format: cpal::SampleFormat,
    ) -> cpal::SupportedStreamConfigRange {
        cpal::SupportedStreamConfigRange::new(
            channels,
            cpal::SampleRate(min),
            cpal::SampleRate(max),
            cpal::SupportedBufferSize::Unknown,
            format,
        )
    }

    #[test]
    fn the_output_config_has_the_channels_in_a_format_the_stream_writes() {
        use cpal::SampleFormat::{F32, I16, I8, U16};
        // What ALSA's plug offers: every format, I8 first.
        let ranges = [
            range(2, 4_000, 192_000, I8),
            range(4, 4_000, 192_000, I8),
            range(2, 4_000, 192_000, I16),
            range(4, 4_000, 192_000, U16),
            range(4, 4_000, 192_000, I16),
        ];

        let chosen = super::choose_output_config(&ranges, 4, 44_100).unwrap();

        assert_eq!(chosen.channels(), 4);
        assert_eq!(chosen.sample_format(), I16, "i16 before u16, I8 never");
        assert_eq!(chosen.sample_rate().0, 44_100, "the device's default rate");

        let with_f32 = [range(4, 4_000, 192_000, I16), range(4, 4_000, 192_000, F32)];
        assert_eq!(
            super::choose_output_config(&with_f32, 4, 48_000)
                .unwrap()
                .sample_format(),
            F32
        );
    }

    #[test]
    fn the_output_config_falls_back_to_48_khz_then_the_highest_rate() {
        use cpal::SampleFormat::I16;
        let only_48k = [range(4, 48_000, 48_000, I16)];
        assert_eq!(
            super::choose_output_config(&only_48k, 4, 44_100)
                .unwrap()
                .sample_rate()
                .0,
            48_000
        );
        let only_96k = [range(4, 96_000, 96_000, I16)];
        assert_eq!(
            super::choose_output_config(&only_96k, 4, 44_100)
                .unwrap()
                .sample_rate()
                .0,
            96_000
        );
    }

    #[test]
    fn without_the_channels_in_a_usable_format_there_is_no_output_config() {
        use cpal::SampleFormat::{I16, I8};
        let ranges = [range(2, 4_000, 192_000, I16), range(4, 4_000, 192_000, I8)];
        assert!(super::choose_output_config(&ranges, 4, 48_000).is_err());
    }

    #[test]
    fn stereo_output_carries_the_front_mix() {
        assert_close(&fill_one_frame(2), &[0.15 + 0.2, 0.075 + 0.2]);
    }

    #[test]
    fn four_channels_carry_front_and_rear_in_alsa_order() {
        assert_close(&fill_one_frame(4), &[0.35, 0.275, 0.5, 0.25]);
    }

    #[test]
    fn the_rear_level_lowers_only_the_rear_speakers() {
        assert_close(
            &fill_one_frame_with_rear(4, 0.3),
            &[0.35, 0.275, 0.5 * 0.3, 0.25 * 0.3],
        );
        assert_close(&fill_one_frame_with_rear(2, 0.3), &[0.35, 0.275]);
    }

    #[test]
    fn five_one_leaves_centre_and_lfe_silent() {
        assert_close(&fill_one_frame(6), &[0.35, 0.275, 0.5, 0.25, 0.0, 0.0]);
    }

    #[test]
    fn only_the_first_stream_error_counts_as_new() {
        let fault = StreamFault::default();

        assert!(!fault.is_broken());
        assert!(fault.record());
        assert!(!fault.record());
        assert!(!fault.record());

        assert!(fault.is_broken());
        assert_eq!(fault.errors(), 3);
    }

    #[test]
    fn the_error_handler_marks_the_output_broken_on_a_burst_of_errors() {
        let fault = Arc::new(StreamFault::default());
        let mut handler = stream_error_handler(Arc::clone(&fault), Arc::new(Mutex::new(None)));

        for _ in 0..10_000 {
            handler(cpal::StreamError::DeviceNotAvailable);
        }

        assert!(fault.is_broken());
        assert_eq!(fault.errors(), 10_000);
    }

    #[test]
    fn a_playback_stops_even_when_the_mixer_is_gone() {
        let (command_sender, command_receiver) = mpsc::channel();
        drop(command_receiver);
        let playback = Box::new(CpalPlayback {
            command_sender,
            source_id: SourceId::for_test(0),
            source: None,
        });

        assert!(playback.stop().is_ok());
    }
}
