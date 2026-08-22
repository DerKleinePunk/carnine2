use std::env;
use std::fs::File;
use std::io::Write;
use std::time::Instant;

use anyhow::{bail, Context, Result};
use ffmpeg_next as ffmpeg;

const SAMPLE_RATE: u32 = 44_100;
const CHANNELS: i32 = 2;
const OUTPUT_BYTES_PER_SAMPLE: u64 = 2;

fn main() -> Result<()> {
    let input_path = env::args()
        .nth(1)
        .context("usage: cargo run --example direct_ffmpeg_library_spike -- <audio-file>")?;
    let output_path = env::args()
        .nth(2)
        .unwrap_or_else(|| "/tmp/carnine-library-output.pcm".to_string());
    let started_at = Instant::now();

    ffmpeg::init().context("failed to initialize FFmpeg")?;
    let mut input = ffmpeg::format::input(&input_path)
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
    let mut output =
        File::create(&output_path).with_context(|| format!("failed to create {output_path}"))?;
    let mut pcm_bytes = 0_u64;
    let mut decoded = ffmpeg::frame::Audio::empty();

    for (stream, packet) in input.packets() {
        if stream.index() != stream_index {
            continue;
        }
        decoder.send_packet(&packet)?;
        while decoder.receive_frame(&mut decoded).is_ok() {
            pcm_bytes += write_resampled(&mut resampler, &decoded, &mut output)?;
        }
    }

    decoder.send_eof()?;
    while decoder.receive_frame(&mut decoded).is_ok() {
        pcm_bytes += write_resampled(&mut resampler, &decoded, &mut output)?;
    }
    output.flush()?;

    let bytes_per_second = SAMPLE_RATE as u64 * CHANNELS as u64 * OUTPUT_BYTES_PER_SAMPLE;
    let decoded_duration = pcm_bytes as f64 / bytes_per_second as f64;
    if pcm_bytes == 0 {
        bail!("FFmpeg decoded no PCM data");
    }
    println!(
        "direct FFmpeg library decoding completed in {:.2}s; PCM: {} bytes ({:.2}s); output: {}",
        started_at.elapsed().as_secs_f64(),
        pcm_bytes,
        decoded_duration,
        output_path,
    );
    Ok(())
}

fn write_resampled(
    resampler: &mut ffmpeg::software::resampling::Context,
    decoded: &ffmpeg::frame::Audio,
    output: &mut File,
) -> Result<u64> {
    let mut resampled = ffmpeg::frame::Audio::empty();
    resampler.run(decoded, &mut resampled)?;
    let data = resampled.data(0);
    output.write_all(data)?;
    Ok(data.len() as u64)
}
