use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::{Arc, Mutex};

use anyhow::{Context, Result};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};

use crate::audio_engine::{AudioEngine, Playback};
use crate::audio_mixer::{AudioMixer, SourceId, CHANNELS};
use crate::audio_source::ExternalPcmSource;

const FADE_MILLISECONDS: u32 = 250;
const SOURCE_BUFFER_FRAMES: usize = 44_100 * 2;

enum MixerCommand {
    Add {
        consumer: ringbuf::HeapCons<f32>,
        reply: mpsc::SyncSender<Result<SourceId>>,
    },
    SetGain {
        source_id: SourceId,
        gain: f32,
    },
    Remove {
        source_id: SourceId,
    },
}

#[derive(Clone)]
pub struct CpalAudioEngine {
    command_sender: Sender<MixerCommand>,
    _stream: Arc<Mutex<cpal::Stream>>,
    sample_rate: u32,
}

impl CpalAudioEngine {
    pub fn new() -> Result<Self> {
        let host = cpal::default_host();
        let device = host
            .default_output_device()
            .context("no default cpal output device")?;
        let supported = device
            .default_output_config()
            .context("failed to read cpal output configuration")?;
        let sample_rate = supported.sample_rate().0;
        let channels = supported.channels() as usize;
        let (command_sender, command_receiver) = mpsc::channel();
        let mixer = AudioMixer::new(sample_rate, FADE_MILLISECONDS);
        let stream = build_stream(
            &device,
            &supported.config(),
            supported.sample_format(),
            channels,
            mixer,
            command_receiver,
        )?;
        stream
            .play()
            .context("failed to start cpal output stream")?;
        Ok(Self {
            command_sender,
            _stream: Arc::new(Mutex::new(stream)),
            sample_rate,
        })
    }
}

impl AudioEngine for CpalAudioEngine {
    fn start(&self, input_path: &str) -> Result<Box<dyn Playback>> {
        let (source, consumer) =
            ExternalPcmSource::start(input_path, self.sample_rate, SOURCE_BUFFER_FRAMES)?;
        let (reply_sender, reply_receiver) = mpsc::sync_channel(1);
        self.command_sender
            .send(MixerCommand::Add {
                consumer,
                reply: reply_sender,
            })
            .map_err(|_| anyhow::anyhow!("cpal mixer thread is not available"))?;
        let source_id = reply_receiver
            .recv()
            .context("cpal mixer did not accept audio source")??;
        Ok(Box::new(CpalPlayback {
            command_sender: self.command_sender.clone(),
            source_id,
            source: Some(source),
        }))
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
        self.command_sender
            .send(MixerCommand::SetGain {
                source_id: self.source_id,
                gain: 0.0,
            })
            .map_err(|_| anyhow::anyhow!("cpal mixer thread is not available"))?;
        Ok(())
    }

    fn resume(&self) -> Result<()> {
        self.command_sender
            .send(MixerCommand::SetGain {
                source_id: self.source_id,
                gain: 1.0,
            })
            .map_err(|_| anyhow::anyhow!("cpal mixer thread is not available"))?;
        Ok(())
    }

    fn stop(mut self: Box<Self>) -> Result<()> {
        self.command_sender
            .send(MixerCommand::Remove {
                source_id: self.source_id,
            })
            .map_err(|_| anyhow::anyhow!("cpal mixer thread is not available"))?;
        if let Some(source) = self.source.take() {
            source.stop()?;
        }
        Ok(())
    }
}

fn build_stream(
    device: &cpal::Device,
    config: &cpal::StreamConfig,
    sample_format: cpal::SampleFormat,
    channels: usize,
    mixer: AudioMixer,
    command_receiver: Receiver<MixerCommand>,
) -> Result<cpal::Stream> {
    match sample_format {
        cpal::SampleFormat::F32 => {
            build_typed_stream::<f32>(device, config, channels, mixer, command_receiver)
        }
        cpal::SampleFormat::I16 => {
            build_typed_stream::<i16>(device, config, channels, mixer, command_receiver)
        }
        cpal::SampleFormat::U16 => {
            build_typed_stream::<u16>(device, config, channels, mixer, command_receiver)
        }
        format => anyhow::bail!("unsupported output sample format: {format:?}"),
    }
}

fn build_typed_stream<T>(
    device: &cpal::Device,
    config: &cpal::StreamConfig,
    channels: usize,
    mut mixer: AudioMixer,
    command_receiver: Receiver<MixerCommand>,
) -> Result<cpal::Stream>
where
    T: cpal::SizedSample + cpal::FromSample<f32>,
{
    Ok(device.build_output_stream(
        config,
        move |output: &mut [T], _info| {
            for command in command_receiver.try_iter() {
                match command {
                    MixerCommand::Add { consumer, reply } => {
                        let result = mixer.add_stream_source(consumer, 1.0);
                        let _ = reply.send(result);
                    }
                    MixerCommand::SetGain { source_id, gain } => {
                        let _ = mixer.set_gain(source_id, gain);
                    }
                    MixerCommand::Remove { source_id } => {
                        let _ = mixer.remove_source(source_id);
                    }
                }
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
        },
        |error| eprintln!("cpal stream error: {error}"),
        None,
    )?)
}
