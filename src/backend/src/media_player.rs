use std::io::Read;
use std::path::Path;
use std::process::{Child, Command, Stdio};
use std::sync::Mutex;
use std::thread::{self, JoinHandle};

use anyhow::{bail, Context, Result};

const SAMPLE_RATE: &str = "44100";
const CHANNELS: &str = "2";
const SAMPLE_FORMAT: &str = "s16le";

#[derive(Debug, Default)]
pub struct MediaPlayer {
    session: Mutex<Option<PlaybackSession>>,
}

impl MediaPlayer {
    pub fn execute(&self, command: &str, parameters: &str) -> Result<String> {
        match command.trim().to_ascii_lowercase().as_str() {
            "play" | "resume" => self.play(parameters),
            "pause" => self.signal("STOP", "paused"),
            "stop" => self.stop(),
            unknown => bail!("unknown media command: {unknown}"),
        }
    }

    fn play(&self, input_path: &str) -> Result<String> {
        let mut session = self.session.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        if let Some(active_session) = session.as_ref() {
            send_signal(active_session.decoder.id(), "CONT")?;
            send_signal(active_session.audio_output.id(), "CONT")?;
            return Ok("playback resumed".to_string());
        }

        if input_path.is_empty() {
            bail!("play requires an audio file path in parameters");
        }
        if !Path::new(input_path).is_file() {
            bail!("audio file does not exist: {input_path}");
        }

        *session = Some(PlaybackSession::start(input_path)?);
        Ok("playback started".to_string())
    }

    fn signal(&self, signal: &str, result: &str) -> Result<String> {
        let session = self.session.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        let active_session = session.as_ref().context("no active playback")?;
        send_signal(active_session.decoder.id(), signal)?;
        send_signal(active_session.audio_output.id(), signal)?;
        Ok(format!("playback {result}"))
    }

    fn stop(&self) -> Result<String> {
        let mut session = self.session.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        let Some(mut active_session) = session.take() else {
            return Ok("playback already stopped".to_string());
        };

        let _ = send_signal(active_session.decoder.id(), "TERM");
        let _ = send_signal(active_session.audio_output.id(), "TERM");
        let _ = active_session.decoder.wait();
        let _ = active_session.audio_output.wait();
        if let Some(copy_thread) = active_session.copy_thread.take() {
            let _ = copy_thread.join();
        }
        Ok("playback stopped".to_string())
    }
}

#[derive(Debug)]
struct PlaybackSession {
    decoder: Child,
    audio_output: Child,
    copy_thread: Option<JoinHandle<Result<u64>>>,
}

impl PlaybackSession {
    fn start(input_path: &str) -> Result<Self> {
        let mut audio_output = Command::new("paplay")
            .args([
                "--client-name=carnine-backend",
                "--stream-name=carnine-media",
                "--raw",
                &format!("--rate={SAMPLE_RATE}"),
                &format!("--channels={CHANNELS}"),
                &format!("--format={SAMPLE_FORMAT}"),
            ])
            .stdin(Stdio::piped())
            .spawn()
            .context("failed to start paplay")?;
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
                SAMPLE_RATE,
                "-ac",
                CHANNELS,
                "pipe:1",
            ])
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .with_context(|| format!("failed to start ffmpeg for {input_path}"))?;

        let mut decoded_pcm = decoder.stdout.take().context("ffmpeg stdout was not piped")?;
        let mut playback_input = audio_output.stdin.take().context("paplay stdin was not piped")?;
        let copy_thread = thread::spawn(move || -> Result<u64> {
            let mut buffer = [0_u8; 64 * 1024];
            let mut pcm_bytes = 0_u64;
            loop {
                let bytes_read = decoded_pcm.read(&mut buffer)?;
                if bytes_read == 0 {
                    break;
                }
                std::io::Write::write_all(&mut playback_input, &buffer[..bytes_read])?;
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
}

fn send_signal(process_id: u32, signal: &str) -> Result<()> {
    let status = Command::new("kill")
        .args([format!("-{signal}"), process_id.to_string()])
        .status()
        .with_context(|| format!("failed to send SIG{signal} to process {process_id}"))?;
    if !status.success() {
        bail!("kill -{signal} {process_id} exited with {status}");
    }
    Ok(())
}

impl Drop for PlaybackSession {
    fn drop(&mut self) {
        let _ = send_signal(self.decoder.id(), "TERM");
        let _ = send_signal(self.audio_output.id(), "TERM");
    }
}