use std::env;
use std::io::Read;
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;

use anyhow::{Context, Result};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use ringbuf::{
    traits::{Consumer, Producer, Split},
    HeapRb,
};

const SAMPLE_RATE: u32 = 44_100;
const SOURCE_CHANNELS: usize = 2;
const BYTES_PER_SAMPLE: usize = 2;
const BUFFER_FRAMES: usize = SAMPLE_RATE as usize * 2;
const TEST_SECONDS: u64 = 20;
const NOTIFICATION_START_SECONDS: u64 = 10;

fn main() -> Result<()> {
    let input_path = env::args()
        .nth(1)
        .context("usage: cpal_external_decoder_spike <music-file> [notification-wav]")?;
    let notification_path = env::args()
        .nth(2)
        .unwrap_or_else(|| "resources/sounds/IncomingMessage.wav".to_string());
    let host = cpal::default_host();
    let requested_device = env::var("CARNINE_CPAL_DEVICE").ok();
    let device = select_output_device(&host, requested_device.as_deref())?;
    let supported = device
        .default_output_config()
        .context("failed to read default output configuration")?;
    let output_channels = supported.channels() as usize;
    let ring = HeapRb::<f32>::new(BUFFER_FRAMES * SOURCE_CHANNELS);
    let notification_ring = HeapRb::<f32>::new(BUFFER_FRAMES * SOURCE_CHANNELS);
    let (mut producer, music_consumer) = ring.split();
    let (mut notification_producer, notification_consumer) = notification_ring.split();
    let decoder_thread =
        thread::spawn(move || decode_to_ring(&input_path, &mut producer, TEST_SECONDS));
    let notification_thread =
        thread::spawn(move || decode_to_ring(&notification_path, &mut notification_producer, 30));
    let stream = build_stream(
        &device,
        &supported.config(),
        supported.sample_format(),
        output_channels,
        music_consumer,
        notification_consumer,
    )?;
    stream
        .play()
        .context("failed to start cpal output stream")?;
    println!(
        "cpal external decoder stream started: {} Hz, {} output channels, {:?}",
        supported.sample_rate().0,
        output_channels,
        supported.sample_format()
    );
    let decoded_samples = decoder_thread
        .join()
        .map_err(|_| anyhow::anyhow!("decoder thread panicked"))??;
    let notification_samples = notification_thread
        .join()
        .map_err(|_| anyhow::anyhow!("notification decoder thread panicked"))??;
    thread::sleep(Duration::from_secs(2));
    drop(stream);
    println!(
        "decoded and played {decoded_samples} music samples plus {notification_samples} notification samples"
    );
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

fn decode_to_ring(
    input_path: &str,
    producer: &mut ringbuf::HeapProd<f32>,
    duration_seconds: u64,
) -> Result<u64> {
    let mut decoder = Command::new("ffmpeg")
        .args([
            "-hide_banner",
            "-loglevel",
            "error",
            "-nostdin",
            "-i",
            input_path,
            "-vn",
            "-f",
            "s16le",
            "-ar",
            &SAMPLE_RATE.to_string(),
            "-ac",
            &SOURCE_CHANNELS.to_string(),
            "pipe:1",
        ])
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .with_context(|| format!("failed to start ffmpeg for {input_path}"))?;
    let max_bytes =
        duration_seconds * SAMPLE_RATE as u64 * SOURCE_CHANNELS as u64 * BYTES_PER_SAMPLE as u64;
    let mut pcm = Vec::new();
    decoder
        .stdout
        .take()
        .context("ffmpeg stdout was not piped")?
        .take(max_bytes)
        .read_to_end(&mut pcm)?;
    let _ = decoder.kill();
    let _ = decoder.wait();
    for frame in pcm.chunks_exact(SOURCE_CHANNELS * BYTES_PER_SAMPLE) {
        for sample in frame.chunks_exact(BYTES_PER_SAMPLE) {
            let value = i16::from_le_bytes([sample[0], sample[1]]) as f32 / i16::MAX as f32;
            while producer.try_push(value).is_err() {
                thread::sleep(Duration::from_millis(1));
            }
        }
    }
    Ok((pcm.len() / BYTES_PER_SAMPLE) as u64)
}

fn build_stream(
    device: &cpal::Device,
    config: &cpal::StreamConfig,
    sample_format: cpal::SampleFormat,
    channels: usize,
    music_consumer: ringbuf::HeapCons<f32>,
    notification_consumer: ringbuf::HeapCons<f32>,
) -> Result<cpal::Stream> {
    match sample_format {
        cpal::SampleFormat::F32 => build_typed_stream::<f32>(
            device,
            config,
            channels,
            music_consumer,
            notification_consumer,
        ),
        cpal::SampleFormat::I16 => build_typed_stream::<i16>(
            device,
            config,
            channels,
            music_consumer,
            notification_consumer,
        ),
        cpal::SampleFormat::U16 => build_typed_stream::<u16>(
            device,
            config,
            channels,
            music_consumer,
            notification_consumer,
        ),
        format => anyhow::bail!("unsupported output sample format: {format:?}"),
    }
}

fn build_typed_stream<T>(
    device: &cpal::Device,
    config: &cpal::StreamConfig,
    channels: usize,
    mut music_consumer: ringbuf::HeapCons<f32>,
    mut notification_consumer: ringbuf::HeapCons<f32>,
) -> Result<cpal::Stream>
where
    T: cpal::SizedSample + cpal::FromSample<f32>,
{
    let mut output_frame_index = 0_usize;
    Ok(device.build_output_stream(
        config,
        move |output: &mut [T], _info| {
            for frame in output.chunks_mut(channels) {
                let left = music_consumer.try_pop().unwrap_or(0.0);
                let right = music_consumer.try_pop().unwrap_or(left);
                let notification_active = output_frame_index
                    >= (NOTIFICATION_START_SECONDS * SAMPLE_RATE as u64) as usize;
                let notification_left = if notification_active {
                    notification_consumer.try_pop().unwrap_or(0.0)
                } else {
                    0.0
                };
                let notification_right = if notification_active {
                    notification_consumer.try_pop().unwrap_or(notification_left)
                } else {
                    0.0
                };
                let left = (left + notification_left).clamp(-1.0, 1.0);
                let right = (right + notification_right).clamp(-1.0, 1.0);
                match frame {
                    [] => {}
                    [mono] => *mono = T::from_sample((left + right) * 0.5),
                    [left_output, right_output, rest @ ..] => {
                        *left_output = T::from_sample(left);
                        *right_output = T::from_sample(right);
                        for channel in rest {
                            *channel = T::from_sample(0.0);
                        }
                    }
                }
                output_frame_index = output_frame_index.saturating_add(1);
            }
        },
        |error| eprintln!("cpal stream error: {error}"),
        None,
    )?)
}
