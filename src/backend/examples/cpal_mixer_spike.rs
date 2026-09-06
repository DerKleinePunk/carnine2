use std::env;
use std::thread;
use std::time::Duration;

use anyhow::{Context, Result};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};

#[path = "../src/audio_mixer.rs"]
mod audio_mixer;

use audio_mixer::{AudioMixer, CHANNELS};

const SAMPLE_RATE: u32 = 44_100;
const TEST_SECONDS: usize = 20;
const NOTIFICATION_START_SECONDS: usize = 10;

fn main() -> Result<()> {
    let host = cpal::default_host();
    let device = select_output_device(&host, env::var("CARNINE_CPAL_DEVICE").ok().as_deref())?;
    let supported = device
        .default_output_config()
        .context("failed to read default output configuration")?;
    let config = supported.config();
    let music = sine_source(220.0, 0.35, TEST_SECONDS * SAMPLE_RATE as usize);
    let notification = notification_source();
    let mut mixer = AudioMixer::new(SAMPLE_RATE, 250);
    mixer.add_source(music, 1.0)?;
    mixer.add_source(notification, 1.0)?;
    let stream = match supported.sample_format() {
        cpal::SampleFormat::F32 => build_stream::<f32>(&device, &config, mixer)?,
        cpal::SampleFormat::I16 => build_stream::<i16>(&device, &config, mixer)?,
        cpal::SampleFormat::U16 => build_stream::<u16>(&device, &config, mixer)?,
        format => anyhow::bail!("unsupported output sample format: {format:?}"),
    };
    stream.play().context("failed to start cpal mixer stream")?;
    println!(
        "cpal mixer stream started: {} Hz, {} channels, {:?}; notification at {}s",
        supported.sample_rate().0,
        supported.channels(),
        supported.sample_format(),
        NOTIFICATION_START_SECONDS
    );
    thread::sleep(Duration::from_secs(TEST_SECONDS as u64 + 1));
    drop(stream);
    println!("cpal mixer stream stopped");
    Ok(())
}

fn select_output_device(host: &cpal::Host, requested: Option<&str>) -> Result<cpal::Device> {
    let mut devices = host
        .output_devices()
        .context("failed to enumerate output devices")?;
    let mut first_device = None;
    while let Some(device) = devices.next() {
        let name = device.name().unwrap_or_else(|_| "<unnamed>".to_string());
        println!("cpal output device: {name}");
        if first_device.is_none() {
            first_device = Some(device.clone());
        }
        if requested.is_some_and(|requested| name.contains(requested)) {
            return Ok(device);
        }
    }
    requested.map_or_else(
        || first_device.context("no audio output device"),
        |requested| anyhow::bail!("requested cpal device not found: {requested}"),
    )
}

fn sine_source(frequency: f32, amplitude: f32, frames: usize) -> Vec<f32> {
    (0..frames * CHANNELS)
        .map(|sample| {
            let frame = sample / CHANNELS;
            (frame as f32 * frequency * std::f32::consts::TAU / SAMPLE_RATE as f32).sin()
                * amplitude
        })
        .collect()
}

fn notification_source() -> Vec<f32> {
    let mut source = vec![0.0; NOTIFICATION_START_SECONDS * SAMPLE_RATE as usize * CHANNELS];
    source.extend(sine_source(
        880.0,
        0.5,
        (TEST_SECONDS - NOTIFICATION_START_SECONDS) * SAMPLE_RATE as usize,
    ));
    source
}

fn build_stream<T>(
    device: &cpal::Device,
    config: &cpal::StreamConfig,
    mut mixer: AudioMixer,
) -> Result<cpal::Stream>
where
    T: cpal::SizedSample + cpal::FromSample<f32>,
{
    Ok(device.build_output_stream(
        config,
        move |output: &mut [T], _info| {
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
