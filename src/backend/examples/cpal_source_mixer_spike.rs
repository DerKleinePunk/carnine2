use std::env;
use std::sync::mpsc::{self, Receiver};
use std::thread;
use std::time::Duration;

use anyhow::{Context, Result};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};

#[path = "../src/audio_mixer.rs"]
mod audio_mixer;
#[path = "../src/audio_source.rs"]
mod audio_source;

use audio_mixer::{AudioMixer, CHANNELS};
use audio_source::ExternalPcmSource;

const SAMPLE_RATE: u32 = 44_100;
const TEST_SECONDS: u64 = 20;

#[derive(Debug)]
enum MixerCommand {
    SetGain(audio_mixer::SourceId, f32),
    Remove(audio_mixer::SourceId),
}

fn main() -> Result<()> {
    let music_path = env::args()
        .nth(1)
        .context("usage: cpal_source_mixer_spike <music-file>")?;
    let host = cpal::default_host();
    let device = host
        .default_output_device()
        .context("no default output device")?;
    let supported = device
        .default_output_config()
        .context("failed to read default output configuration")?;
    let (source, consumer) =
        ExternalPcmSource::start(music_path, SAMPLE_RATE, SAMPLE_RATE as usize * 2)?;
    let mut mixer = AudioMixer::new(SAMPLE_RATE, 250);
    let source_id = mixer.add_stream_source(consumer, 1.0)?;
    let (commands, command_receiver) = mpsc::channel();
    let stream = match supported.sample_format() {
        cpal::SampleFormat::F32 => {
            build_stream::<f32>(&device, &supported.config(), mixer, command_receiver)?
        }
        cpal::SampleFormat::I16 => {
            build_stream::<i16>(&device, &supported.config(), mixer, command_receiver)?
        }
        cpal::SampleFormat::U16 => {
            build_stream::<u16>(&device, &supported.config(), mixer, command_receiver)?
        }
        format => anyhow::bail!("unsupported output sample format: {format:?}"),
    };
    stream
        .play()
        .context("failed to start cpal source mixer stream")?;
    println!(
        "cpal source mixer stream started: {} Hz, {} channels, {:?}",
        supported.sample_rate().0,
        supported.channels(),
        supported.sample_format()
    );
    thread::sleep(Duration::from_secs(5));
    commands.send(MixerCommand::SetGain(source_id, 0.0))?;
    println!("music fade-out requested");
    thread::sleep(Duration::from_secs(1));
    commands.send(MixerCommand::SetGain(source_id, 1.0))?;
    println!("music fade-in requested");
    thread::sleep(Duration::from_secs(TEST_SECONDS - 7));
    commands.send(MixerCommand::Remove(source_id))?;
    println!("music source removal requested");
    thread::sleep(Duration::from_secs(1));
    let decoded_samples = source.stop()?;
    drop(stream);
    println!("decoded {decoded_samples} stereo samples through AudioMixer");
    Ok(())
}

fn build_stream<T>(
    device: &cpal::Device,
    config: &cpal::StreamConfig,
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
                    MixerCommand::SetGain(source_id, gain) => {
                        let _ = mixer.set_gain(source_id, gain);
                    }
                    MixerCommand::Remove(source_id) => {
                        let _ = mixer.remove_source(source_id);
                    }
                }
            }
            let mut mixed_frame = [0.0_f32; CHANNELS];
            for frame in output.chunks_mut(CHANNELS) {
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
