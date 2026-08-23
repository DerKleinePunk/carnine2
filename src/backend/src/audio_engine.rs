use std::env;
use std::io::{Read, Write};
use std::process::{Child, Command, Stdio};
use std::thread::{self, JoinHandle};

use anyhow::{bail, Context, Result};

const SAMPLE_RATE: &str = "44100";
const CHANNELS: &str = "2";
const SAMPLE_FORMAT: &str = "s16le";

pub trait AudioEngine: Send + Sync {
    fn start(&self, input_path: &str) -> Result<Box<dyn Playback>>;
}

pub trait Playback: Send {
    fn pause(&self) -> Result<()>;
    fn resume(&self) -> Result<()>;
    fn stop(self: Box<Self>) -> Result<()>;
}

#[derive(Debug, Default)]
pub struct ExternalProcessAudioEngine;

impl AudioEngine for ExternalProcessAudioEngine {
    fn start(&self, input_path: &str) -> Result<Box<dyn Playback>> {
        Ok(Box::new(ProcessPlayback::start(input_path)?))
    }
}

#[derive(Debug)]
struct ProcessPlayback {
    decoder: Child,
    audio_output: Child,
    copy_thread: Option<JoinHandle<Result<u64>>>,
}

impl ProcessPlayback {
    fn start(input_path: &str) -> Result<Self> {
        let mut audio_output = start_audio_output()?;
        let mut decoder = Command::new("ffmpeg")
            .args([
                "-hide_banner", "-loglevel", "error", "-nostdin", "-i", input_path,
                "-vn", "-f", SAMPLE_FORMAT, "-ar", SAMPLE_RATE, "-ac", CHANNELS, "pipe:1",
            ])
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .with_context(|| format!("failed to start ffmpeg for {input_path}"))?;

        let mut decoded_pcm = decoder.stdout.take().context("ffmpeg stdout was not piped")?;
        let mut playback_input = audio_output.stdin.take().context("audio input was not piped")?;
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

        Ok(Self { decoder, audio_output, copy_thread: Some(copy_thread) })
    }

    fn signal(&self, signal: &str) -> Result<()> {
        for (name, process_id) in [("decoder", self.decoder.id()), ("audio output", self.audio_output.id())] {
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
    fn pause(&self) -> Result<()> { self.signal("STOP") }
    fn resume(&self) -> Result<()> { self.signal("CONT") }

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
    fn drop(&mut self) { let _ = self.signal("TERM"); }
}

fn start_audio_output() -> Result<Child> {
    let backend = env::var("CARNINE_AUDIO_BACKEND").unwrap_or_else(|_| "pulse".to_string());
    let mut command = if backend == "alsa" {
        let device = env::var("CARNINE_ALSA_DEVICE").unwrap_or_else(|_| "default".to_string());
        let mut command = Command::new("aplay");
        command.args(["-q", "-D", &device, "-f", "S16_LE", "-r", SAMPLE_RATE, "-c", CHANNELS]);
        command
    } else {
        let mut command = Command::new("paplay");
        command.args([
            "--client-name=carnine-backend", "--stream-name=carnine-media", "--raw",
            &format!("--rate={SAMPLE_RATE}"), &format!("--channels={CHANNELS}"),
            &format!("--format={SAMPLE_FORMAT}"),
        ]);
        command
    };
    command.stdin(Stdio::piped()).spawn().with_context(|| format!("failed to start audio backend: {backend}"))
}
