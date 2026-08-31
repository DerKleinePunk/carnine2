use std::io::{Read, Write};
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::Arc;
use std::thread::{self, JoinHandle};
use std::time::Duration;

use anyhow::{bail, Context, Result};
use tracing::info;

use crate::config::AudioConfig;

const SAMPLE_FORMAT: &str = "s16le";
const FADE_MILLISECONDS: u32 = 250;
const PCM_BUFFER_BYTES: usize = 4 * 1024;
const PULSE_LATENCY_MILLISECONDS: u32 = 20;
const PULSE_PROCESS_TIME_MILLISECONDS: u32 = 10;

pub trait AudioEngine: Send + Sync {
    fn start(&self, input_path: &str) -> Result<Box<dyn Playback>>;

    fn start_at(&self, input_path: &str, position_ms: i64) -> Result<Box<dyn Playback>> {
        let _ = position_ms;
        self.start(input_path)
    }
}

pub trait Playback: Send {
    fn pause(&self) -> Result<()>;
    fn resume(&self) -> Result<()>;
    fn stop(self: Box<Self>) -> Result<()>;
}

#[derive(Debug, Clone)]
pub struct ExternalProcessAudioEngine {
    backend: String,
    device: String,
    sample_rate: String,
    channels: String,
}

impl Default for ExternalProcessAudioEngine {
    fn default() -> Self {
        Self {
            backend: "pulse".to_string(),
            device: "default".to_string(),
            sample_rate: "44100".to_string(),
            channels: "2".to_string(),
        }
    }
}

impl ExternalProcessAudioEngine {
    pub fn from_config(config: &AudioConfig) -> Self {
        Self {
            backend: config.backend.clone(),
            device: config.device.clone(),
            sample_rate: config.sample_rate.to_string(),
            channels: config.channels.to_string(),
        }
    }
}

impl AudioEngine for ExternalProcessAudioEngine {
    fn start(&self, input_path: &str) -> Result<Box<dyn Playback>> {
        self.start_at(input_path, 0)
    }

    fn start_at(&self, input_path: &str, position_ms: i64) -> Result<Box<dyn Playback>> {
        Ok(Box::new(ProcessPlayback::start(
            input_path,
            self,
            position_ms,
        )?))
    }
}

#[derive(Debug)]
struct ProcessPlayback {
    decoder: Child,
    audio_output: Child,
    copy_thread: Option<JoinHandle<Result<u64>>>,
    target_gain: Arc<AtomicU32>,
    stop_requested: Arc<AtomicBool>,
}

impl ProcessPlayback {
    fn start(
        input_path: &str,
        engine: &ExternalProcessAudioEngine,
        position_ms: i64,
    ) -> Result<Self> {
        let mut audio_output = start_audio_output(engine)?;
        let mut decoder = Command::new("ffmpeg")
            .args([
                "-hide_banner",
                "-loglevel",
                "error",
                "-nostdin",
                "-ss",
                &format!("{:.3}", position_ms.max(0) as f64 / 1_000.0),
                "-i",
                input_path,
                "-vn",
                "-f",
                SAMPLE_FORMAT,
                "-ar",
                &engine.sample_rate,
                "-ac",
                &engine.channels,
                "pipe:1",
            ])
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .with_context(|| format!("failed to start ffmpeg for {input_path}"))?;

        let mut decoded_pcm = decoder
            .stdout
            .take()
            .context("ffmpeg stdout was not piped")?;
        let mut playback_input = audio_output
            .stdin
            .take()
            .context("audio input was not piped")?;
        let target_gain = Arc::new(AtomicU32::new(1_000_000));
        let stop_requested = Arc::new(AtomicBool::new(false));
        let target_gain_for_copy = Arc::clone(&target_gain);
        let stop_requested_for_copy = Arc::clone(&stop_requested);
        let sample_rate = engine.sample_rate.parse::<u32>()?;
        let channels = engine.channels.parse::<u16>()?;
        let copy_thread = thread::spawn(move || -> Result<u64> {
            let mut buffer = [0_u8; PCM_BUFFER_BYTES];
            let bytes_per_frame = channels as usize * 2;
            let mut pending_pcm = Vec::with_capacity(bytes_per_frame);
            let mut pcm_bytes = 0_u64;
            let mut current_gain = 1_000_000_u32;
            let fade_frames = (sample_rate * FADE_MILLISECONDS / 1_000).max(1);
            let zero_buffer = vec![0_u8; channels as usize * 2 * 1024];
            loop {
                if stop_requested_for_copy.load(Ordering::Acquire) {
                    break;
                }
                let target_gain = target_gain_for_copy.load(Ordering::Acquire);
                if target_gain == 0 && current_gain == 0 {
                    playback_input.write_all(&zero_buffer)?;
                    continue;
                }
                let bytes_read = decoded_pcm.read(&mut buffer)?;
                if bytes_read == 0 {
                    break;
                }
                pending_pcm.extend_from_slice(&buffer[..bytes_read]);
                let complete_bytes = pending_pcm.len() / bytes_per_frame * bytes_per_frame;
                if complete_bytes == 0 {
                    continue;
                }
                let mut pcm = pending_pcm.drain(..complete_bytes).collect::<Vec<_>>();
                let frames = complete_bytes / bytes_per_frame;
                apply_gain_fade(
                    &mut pcm,
                    &mut current_gain,
                    target_gain,
                    frames,
                    fade_frames,
                    channels,
                );
                playback_input.write_all(&pcm)?;
                pcm_bytes += complete_bytes as u64;
            }
            Ok(pcm_bytes)
        });

        info!(
            decoder_pid = decoder.id(),
            audio_output_pid = audio_output.id(),
            position_ms,
            "audio stream started"
        );

        Ok(Self {
            decoder,
            audio_output,
            copy_thread: Some(copy_thread),
            target_gain,
            stop_requested,
        })
    }

    fn signal(&self, signal: &str) -> Result<()> {
        for (name, process_id) in [
            ("decoder", self.decoder.id()),
            ("audio output", self.audio_output.id()),
        ] {
            self.signal_process(signal, name, process_id)?;
        }
        Ok(())
    }

    fn signal_process(&self, signal: &str, name: &str, process_id: u32) -> Result<()> {
        let status = Command::new("kill")
            .args([format!("-{signal}"), process_id.to_string()])
            .status()
            .with_context(|| format!("failed to send SIG{signal} to {name}"))?;
        if !status.success() {
            bail!("kill -{signal} {name} exited with {status}");
        }
        Ok(())
    }
}

impl Playback for ProcessPlayback {
    fn pause(&self) -> Result<()> {
        self.target_gain.store(0, Ordering::Release);
        thread::sleep(Duration::from_millis(FADE_MILLISECONDS as u64));
        self.signal("STOP")?;
        info!("audio stream paused; decoder and output processes stopped");
        Ok(())
    }
    fn resume(&self) -> Result<()> {
        self.signal("CONT")?;
        self.target_gain.store(1_000_000, Ordering::Release);
        info!("audio stream resumed; decoder and output processes continued");
        Ok(())
    }

    fn stop(mut self: Box<Self>) -> Result<()> {
        self.target_gain.store(0, Ordering::Release);
        let _ = self.signal("CONT");
        thread::sleep(Duration::from_millis(FADE_MILLISECONDS as u64));
        self.stop_requested.store(true, Ordering::Release);
        // Closing the output first releases a copy thread blocked in write_all.
        // The decoder can then be terminated without waiting indefinitely for
        // its stdout pipe to drain.
        let _ = self.signal_process("TERM", "audio output", self.audio_output.id());
        let _ = self.audio_output.kill();
        let _ = self.signal_process("TERM", "decoder", self.decoder.id());
        let _ = self.decoder.kill();
        if let Some(copy_thread) = self.copy_thread.take() {
            let _ = copy_thread.join();
        }
        let _ = self.decoder.wait();
        let _ = self.audio_output.wait();
        info!("audio stream stopped; decoder and output processes exited");
        Ok(())
    }
}

impl Drop for ProcessPlayback {
    fn drop(&mut self) {
        let _ = self.signal("TERM");
    }
}

fn start_audio_output(engine: &ExternalProcessAudioEngine) -> Result<Child> {
    let backend = &engine.backend;
    let mut command = if backend == "alsa" {
        let device = &engine.device;
        let mut command = Command::new("aplay");
        command.args([
            "-q",
            "-D",
            &device,
            "-f",
            "S16_LE",
            "-r",
            &engine.sample_rate,
            "-c",
            &engine.channels,
        ]);
        command
    } else {
        let mut command = Command::new("paplay");
        command.args([
            "--client-name=carnine-backend",
            "--stream-name=carnine-media",
            "--raw",
            &format!("--latency-msec={PULSE_LATENCY_MILLISECONDS}"),
            &format!("--process-time-msec={PULSE_PROCESS_TIME_MILLISECONDS}"),
            &format!("--rate={}", engine.sample_rate),
            &format!("--channels={}", engine.channels),
            &format!("--format={SAMPLE_FORMAT}"),
        ]);
        command
    };
    command
        .stdin(Stdio::piped())
        .spawn()
        .with_context(|| format!("failed to start audio backend: {backend}"))
}

fn apply_gain_fade(
    pcm: &mut [u8],
    current_gain: &mut u32,
    target_gain: u32,
    frames: usize,
    fade_frames: u32,
    channels: u16,
) {
    if frames == 0 {
        return;
    }
    let gain_delta = target_gain.abs_diff(*current_gain);
    let fade_frames = fade_frames.max(1);
    let gain_step = gain_delta
        .saturating_add(fade_frames - 1)
        .checked_div(fade_frames)
        .unwrap_or(0)
        .max(1);
    for frame in 0..frames {
        if *current_gain < target_gain {
            *current_gain = (*current_gain + gain_step).min(target_gain);
        } else if *current_gain > target_gain {
            *current_gain = current_gain.saturating_sub(gain_step).max(target_gain);
        }
        let gain = *current_gain as i64;
        let offset = frame * channels as usize * 2;
        for channel in 0..channels as usize {
            let channel_offset = offset + channel * 2;
            let sample = i16::from_le_bytes([pcm[channel_offset], pcm[channel_offset + 1]]) as i64;
            let scaled = (sample * gain / 1_000_000) as i16;
            pcm[channel_offset..channel_offset + 2].copy_from_slice(&scaled.to_le_bytes());
        }
    }
}

#[cfg(test)]
mod tests {
    use super::apply_gain_fade;

    #[test]
    fn fade_to_zero_reaches_silence_within_fade_duration() {
        let mut pcm = vec![0xFF_u8; 22_050 * 2];
        let mut current_gain = 1_000_000;

        apply_gain_fade(&mut pcm, &mut current_gain, 0, 11_025, 11_025, 1);

        assert_eq!(current_gain, 0);
        assert_eq!(pcm[22_050 - 2..22_050], [0, 0]);
    }

    #[test]
    fn fade_to_full_gain_reaches_target_within_fade_duration() {
        let mut pcm = vec![0_u8; 22_050 * 2];
        let mut current_gain = 0;

        apply_gain_fade(&mut pcm, &mut current_gain, 1_000_000, 11_025, 11_025, 1);

        assert_eq!(current_gain, 1_000_000);
    }
}
