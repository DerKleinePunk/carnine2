use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use anyhow::{Context, Result};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};

const MUSIC_GAIN: u32 = 1_000_000;
const NAVIGATION_GAIN: u32 = 350_000;
const TEST_SECONDS: u64 = 8;

fn main() -> Result<()> {
    let host = cpal::default_host();
    let device = host
        .default_output_device()
        .context("no default audio output device")?;
    let supported = device
        .default_output_config()
        .context("failed to read default output configuration")?;
    let sample_rate = supported.sample_rate().0 as f32;
    let channels = supported.channels() as usize;
    let stream_config = supported.config();
    let music_gain = Arc::new(AtomicU32::new(MUSIC_GAIN));
    let navigation_gain = Arc::new(AtomicU32::new(0));
    let stream = match supported.sample_format() {
        cpal::SampleFormat::F32 => build_stream::<f32>(
            &device,
            &stream_config,
            sample_rate,
            channels,
            Arc::clone(&music_gain),
            Arc::clone(&navigation_gain),
        )?,
        cpal::SampleFormat::I16 => build_stream::<i16>(
            &device,
            &stream_config,
            sample_rate,
            channels,
            Arc::clone(&music_gain),
            Arc::clone(&navigation_gain),
        )?,
        cpal::SampleFormat::U16 => build_stream::<u16>(
            &device,
            &stream_config,
            sample_rate,
            channels,
            Arc::clone(&music_gain),
            Arc::clone(&navigation_gain),
        )?,
        sample_format => anyhow::bail!("unsupported output sample format: {sample_format:?}"),
    };

    stream
        .play()
        .context("failed to start cpal output stream")?;
    println!(
        "cpal stream started: {} Hz, {} channels, {:?}",
        sample_rate,
        channels,
        supported.sample_format()
    );

    thread::sleep(Duration::from_secs(2));
    fade_to(&navigation_gain, NAVIGATION_GAIN);
    thread::sleep(Duration::from_secs(2));
    fade_to(&navigation_gain, 0);
    thread::sleep(Duration::from_secs(TEST_SECONDS - 4));
    fade_to(&music_gain, 0);
    thread::sleep(Duration::from_millis(300));
    println!("cpal stream stopped after fade-out");
    Ok(())
}

fn build_stream<T>(
    device: &cpal::Device,
    config: &cpal::StreamConfig,
    sample_rate: f32,
    channels: usize,
    music_gain: Arc<AtomicU32>,
    navigation_gain: Arc<AtomicU32>,
) -> Result<cpal::Stream>
where
    T: cpal::SizedSample + cpal::FromSample<f32>,
{
    let mut frame_index = 0_u64;
    let error_callback = |error| eprintln!("cpal stream error: {error}");
    let stream = device.build_output_stream(
        config,
        move |output: &mut [T], _info| {
            let music = music_gain.load(Ordering::Relaxed) as f32 / MUSIC_GAIN as f32;
            let navigation = navigation_gain.load(Ordering::Relaxed) as f32 / MUSIC_GAIN as f32;
            for frame in output.chunks_mut(channels) {
                let time = frame_index as f32 / sample_rate;
                let music_sample = (time * 220.0 * std::f32::consts::TAU).sin() * music;
                let navigation_sample = (time * 880.0 * std::f32::consts::TAU).sin() * navigation;
                let sample = music_sample + navigation_sample;
                for channel in frame {
                    *channel = T::from_sample(sample.clamp(-1.0, 1.0));
                }
                frame_index = frame_index.wrapping_add(1);
            }
        },
        error_callback,
        None,
    )?;
    Ok(stream)
}

fn fade_to(gain: &AtomicU32, target: u32) {
    gain.store(target, Ordering::Release);
    println!("source gain changed to {target}");
}
