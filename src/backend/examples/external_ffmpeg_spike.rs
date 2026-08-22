use std::env;
use std::io::copy;
use std::io::{self, BufRead, Write};
use std::process::{Command, Stdio};
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc,
};
use std::thread;
use std::time::Instant;

use anyhow::{bail, Context, Result};

const SAMPLE_RATE: &str = "44100";
const CHANNELS: &str = "2";
const SAMPLE_FORMAT: &str = "s16le";

fn main() -> Result<()> {
    let input = env::args()
        .nth(1)
        .context("usage: cargo run --example external_ffmpeg_spike -- <audio-file>")?;
    let started_at = Instant::now();

    let mut audio_output = Command::new("paplay")
        .args([
            "--client-name=carnine-spike",
            "--stream-name=carnine-external-ffmpeg",
            "--raw",
            &format!("--rate={SAMPLE_RATE}"),
            &format!("--channels={CHANNELS}"),
            &format!("--format={SAMPLE_FORMAT}"),
        ])
        .stdin(Stdio::piped())
        .spawn()
        .context("failed to start paplay")?;
    let audio_pid = audio_output.id();

    let mut decoder = Command::new("ffmpeg")
        .args([
            "-hide_banner",
            "-loglevel",
            "error",
            "-nostdin",
            "-i",
            &input,
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
        .with_context(|| format!("failed to start ffmpeg for {input}"))?;
    let decoder_pid = decoder.id();

    let mut decoded_pcm = decoder
        .stdout
        .take()
        .context("ffmpeg stdout was not piped")?;
    let mut playback_input = audio_output
        .stdin
        .take()
        .context("paplay stdin was not piped")?;

    let stop_requested = Arc::new(AtomicBool::new(false));
    let stop_requested_for_copy = Arc::clone(&stop_requested);
    let copy_thread = thread::spawn(move || -> Result<()> {
        let copy_result = copy(&mut decoded_pcm, &mut playback_input);
        drop(playback_input);

        match copy_result {
            Ok(_) => Ok(()),
            Err(error)
                if error.kind() == io::ErrorKind::BrokenPipe
                    && stop_requested_for_copy.load(Ordering::Acquire) =>
            {
                Ok(())
            }
            Err(error) => Err(error).context("failed to pipe PCM to paplay"),
        }
    });

    println!("commands: play, pause, stop");
    print!("> ");
    io::stdout()
        .flush()
        .context("failed to flush command prompt")?;

    let stdin = io::stdin();
    let mut stopped = false;
    for line in stdin.lock().lines() {
        match line.context("failed to read playback command")?.trim() {
            "play" | "resume" => {
                send_signal(decoder_pid, "CONT")?;
                send_signal(audio_pid, "CONT")?;
                println!("playback resumed");
            }
            "pause" => {
                send_signal(decoder_pid, "STOP")?;
                send_signal(audio_pid, "STOP")?;
                println!("playback paused");
            }
            "stop" => {
                stop_requested.store(true, Ordering::Release);
                send_signal(decoder_pid, "TERM")?;
                send_signal(audio_pid, "TERM")?;
                stopped = true;
                println!("playback stopped");
                break;
            }
            "" => {}
            command => println!("unknown command: {command}"),
        }
        print!("> ");
        io::stdout()
            .flush()
            .context("failed to flush command prompt")?;
    }

    copy_thread
        .join()
        .map_err(|_| anyhow::anyhow!("PCM pipe thread panicked"))??;

    let decoder_status = decoder.wait().context("failed to wait for ffmpeg")?;
    let audio_status = audio_output.wait().context("failed to wait for paplay")?;

    if !stopped && !decoder_status.success() {
        bail!("ffmpeg exited with {decoder_status}");
    }
    if !stopped && !audio_status.success() {
        bail!("paplay exited with {audio_status}");
    }

    println!(
        "external FFmpeg playback completed in {:.2}s",
        started_at.elapsed().as_secs_f64()
    );
    Ok(())
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
