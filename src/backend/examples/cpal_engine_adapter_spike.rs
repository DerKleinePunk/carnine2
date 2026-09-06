use std::env;
use std::thread;
use std::time::Duration;

use anyhow::{Context, Result};

#[path = "../src/audio_engine.rs"]
mod audio_engine;
#[path = "../src/audio_mixer.rs"]
mod audio_mixer;
#[path = "../src/audio_source.rs"]
mod audio_source;
#[path = "../src/config.rs"]
mod config;
#[path = "../src/cpal_audio_engine.rs"]
mod cpal_audio_engine;

use audio_engine::AudioEngine;
use cpal_audio_engine::CpalAudioEngine;

fn main() -> Result<()> {
    let input_path = env::args()
        .nth(1)
        .context("usage: cpal_engine_adapter_spike <music-file>")?;
    let engine = CpalAudioEngine::new()?;
    let playback = engine.start(&input_path)?;
    println!("cpal AudioEngine playback started");
    thread::sleep(Duration::from_secs(5));
    playback.pause()?;
    println!("cpal AudioEngine pause requested");
    thread::sleep(Duration::from_secs(1));
    playback.resume()?;
    println!("cpal AudioEngine resume requested");
    thread::sleep(Duration::from_secs(5));
    playback.stop()?;
    println!("cpal AudioEngine stop completed");
    Ok(())
}
