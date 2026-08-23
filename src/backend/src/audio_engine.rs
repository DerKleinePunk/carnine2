use std::io::{Read, Write};
use std::process::{Child, Command, Stdio};
use std::thread::{self, JoinHandle};

use anyhow::{bail, Context, Result};

use crate::config::AudioConfig;

const SAMPLE_FORMAT: &str = "s16le";

pub trait AudioEngine: Send + Sync {
    fn start(&self, input_path: &str) -> Result<Box<dyn Playback>>;
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
        Ok(Box::new(ProcessPlayback::start(input_path, self)?))
    }
}

#[derive(Debug)]
struct ProcessPlayback {
    decoder: Child,
    audio_output: Child,
    copy_thread: Option<JoinHandle<Result<u64>>>,
}

impl ProcessPlayback {
    fn start(input_path: &str, engine: &ExternalProcessAudioEngine) -> Result<Self> {
        let mut audio_output = start_audio_output(engine)?;
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
        let copy_thread = thread::spawn(move || -> Result<u64> {
            let mut buffer = [0_u8; 64 * 1024];
            let mut pcm_bytes = 0_u64;
            loop {
                let bytes_read = decoded_pcm.read(&mut buffer)?;
                if bytes_read == 0 {
                    break;
                }
                playback_input.write_all(&buffer[..bytes_read])?;
                pcm_bytes += bytes_read as u64;
            }
            Ok(pcm_bytes)
        });

        Ok(Self {
            decoder,
            audio_output,
            copy_thread: Some(copy_thread),
        })
    }

    fn signal(&self, signal: &str) -> Result<()> {
        for (name, process_id) in [
            ("decoder", self.decoder.id()),
            ("audio output", self.audio_output.id()),
        ] {
            let status = Command::new("kill")
                .args([format!("-{signal}"), process_id.to_string()])
                .status()
                .with_context(|| format!("failed to send SIG{signal} to {name}"))?;
            if !status.success() {
                bail!("kill -{signal} {name} exited with {status}");
            }
        }
        Ok(())
    }
}

impl Playback for ProcessPlayback {
    fn pause(&self) -> Result<()> {
        self.signal("STOP")
    }
    fn resume(&self) -> Result<()> {
        self.signal("CONT")
    }

    fn stop(mut self: Box<Self>) -> Result<()> {
        let _ = self.signal("TERM");
        let _ = self.decoder.wait();
        let _ = self.audio_output.wait();
        if let Some(copy_thread) = self.copy_thread.take() {
            let _ = copy_thread.join();
        }
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
