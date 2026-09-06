use std::env;
use std::thread;
use std::time::Duration;

use anyhow::{Context, Result};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use ffmpeg_next as ffmpeg;
use ringbuf::{
    traits::{Consumer, Producer, Split},
    HeapRb,
};

const SAMPLE_RATE: u32 = 44_100;
const SOURCE_CHANNELS: usize = 2;
const BUFFER_FRAMES: usize = SAMPLE_RATE as usize * 2;
const TEST_SECONDS: u64 = 8;

fn main() -> Result<()> {
    let input_path = env::args().nth(1).context(
        "usage: cargo run --features direct-ffmpeg-library-spike --example cpal_decoder_spike -- <audio-file>",
    )?;
    ffmpeg::init().context("failed to initialize FFmpeg")?;

    let host = cpal::default_host();
    let device = host
        .default_output_device()
        .context("no default audio output device")?;
    let supported = device
        .default_output_config()
        .context("failed to read default output configuration")?;
    let channels = supported.channels() as usize;
    let stream_config = supported.config();
    let ring = HeapRb::<f32>::new(BUFFER_FRAMES * SOURCE_CHANNELS);
    let (mut producer, consumer) = ring.split();
    let decoder_thread =
        thread::spawn(move || decode_to_ring(&input_path, &mut producer, TEST_SECONDS));
    let stream = build_stream(
        &device,
        &stream_config,
        supported.sample_format(),
        channels,
        consumer,
    )?;

    stream
        .play()
        .context("failed to start cpal output stream")?;
    println!(
        "cpal decoder stream started: {} Hz, {} output channels, {:?}",
        supported.sample_rate().0,
        channels,
        supported.sample_format()
    );

    let decoded_samples = decoder_thread
        .join()
        .map_err(|_| anyhow::anyhow!("decoder thread panicked"))??;
    thread::sleep(Duration::from_secs(2));
    drop(stream);
    println!("decoded and played {decoded_samples} stereo samples");
    Ok(())
}

fn decode_to_ring(
    input_path: &str,
    producer: &mut ringbuf::HeapProd<f32>,
    duration_seconds: u64,
) -> Result<u64> {
    let mut input = ffmpeg::format::input(input_path)
        .with_context(|| format!("failed to open {input_path}"))?;
    let input_stream = input
        .streams()
        .best(ffmpeg::media::Type::Audio)
        .context("input has no audio stream")?;
    let stream_index = input_stream.index();
    let decoder_context =
        ffmpeg::codec::context::Context::from_parameters(input_stream.parameters())?;
    let mut decoder = decoder_context.decoder().audio()?;
    let mut resampler = ffmpeg::software::resampling::Context::get(
        decoder.format(),
        decoder.channel_layout(),
        decoder.rate(),
        ffmpeg::format::Sample::I16(ffmpeg::format::sample::Type::Packed),
        ffmpeg::channel_layout::ChannelLayout::STEREO,
        SAMPLE_RATE,
    )?;
    let mut decoded = ffmpeg::frame::Audio::empty();
    let mut samples = 0_u64;
    let max_samples = duration_seconds * SAMPLE_RATE as u64 * SOURCE_CHANNELS as u64;

    'packets: for (stream, packet) in input.packets() {
        if stream.index() != stream_index {
            continue;
        }
        decoder.send_packet(&packet)?;
        while decoder.receive_frame(&mut decoded).is_ok() {
            samples += push_resampled(&mut resampler, &decoded, producer)?;
            if samples >= max_samples {
                break 'packets;
            }
        }
    }
    if samples < max_samples {
        decoder.send_eof()?;
        while decoder.receive_frame(&mut decoded).is_ok() {
            samples += push_resampled(&mut resampler, &decoded, producer)?;
            if samples >= max_samples {
                break;
            }
        }
    }
    Ok(samples)
}

fn push_resampled(
    resampler: &mut ffmpeg::software::resampling::Context,
    decoded: &ffmpeg::frame::Audio,
    producer: &mut ringbuf::HeapProd<f32>,
) -> Result<u64> {
    let mut resampled = ffmpeg::frame::Audio::empty();
    resampler.run(decoded, &mut resampled)?;
    let data = resampled.data(0);
    for sample in data.chunks_exact(2) {
        let value = i16::from_le_bytes([sample[0], sample[1]]) as f32 / i16::MAX as f32;
        while producer.try_push(value).is_err() {
            thread::sleep(Duration::from_millis(1));
        }
    }
    Ok((data.len() / 2) as u64)
}

fn build_stream(
    device: &cpal::Device,
    config: &cpal::StreamConfig,
    sample_format: cpal::SampleFormat,
    channels: usize,
    consumer: ringbuf::HeapCons<f32>,
) -> Result<cpal::Stream> {
    let stream = match sample_format {
        cpal::SampleFormat::F32 => build_typed_stream::<f32>(device, config, channels, consumer)?,
        cpal::SampleFormat::I16 => build_typed_stream::<i16>(device, config, channels, consumer)?,
        cpal::SampleFormat::U16 => build_typed_stream::<u16>(device, config, channels, consumer)?,
        format => anyhow::bail!("unsupported output sample format: {format:?}"),
    };
    Ok(stream)
}

fn build_typed_stream<T>(
    device: &cpal::Device,
    config: &cpal::StreamConfig,
    channels: usize,
    mut consumer: ringbuf::HeapCons<f32>,
) -> Result<cpal::Stream>
where
    T: cpal::SizedSample + cpal::FromSample<f32>,
{
    let stream = device.build_output_stream(
        config,
        move |output: &mut [T], _info| {
            for frame in output.chunks_mut(channels) {
                let left = consumer.try_pop().unwrap_or(0.0);
                let right = consumer.try_pop().unwrap_or(left);
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
            }
        },
        |error| eprintln!("cpal stream error: {error}"),
        None,
    )?;
    Ok(stream)
}
