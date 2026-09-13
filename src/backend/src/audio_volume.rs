use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Mutex;

use anyhow::{bail, Context, Result};
use tracing::{info, warn};

const MIXER_CARD: &str = "0";
const MIXER_CONTROL: &str = "PCM";

pub struct AudioVolume {
    state_path: PathBuf,
    percent: Mutex<u8>,
}

impl AudioVolume {
    pub fn new(state_path: PathBuf) -> Self {
        let percent = read_state(&state_path)
            .or_else(|| read_mixer_percent().ok())
            .unwrap_or(100);
        Self {
            state_path,
            percent: Mutex::new(percent),
        }
    }

    pub fn start(&self) {
        let percent = self.current();
        if let Err(error) = self.apply(percent) {
            warn!(%error, percent, "failed to restore audio volume");
        } else {
            info!(percent, "audio volume restored");
        }
    }

    pub fn current(&self) -> u8 {
        *self
            .percent
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    pub fn set(&self, percent: u8) -> Result<u8> {
        if percent > 100 {
            bail!("audio volume must be between 0 and 100 percent");
        }
        self.apply(percent)?;
        *self
            .percent
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = percent;
        write_state(&self.state_path, percent)?;
        info!(percent, "audio volume changed");
        Ok(percent)
    }

    pub fn shutdown(&self) {
        let percent = self.current();
        if let Err(error) = write_state(&self.state_path, percent) {
            warn!(%error, percent, "failed to save audio volume");
        }
        if let Err(error) = self.apply(0) {
            warn!(%error, "failed to mute audio volume during shutdown");
        } else {
            info!(percent, "audio volume muted for shutdown");
        }
    }

    fn apply(&self, percent: u8) -> Result<()> {
        let status = Command::new("amixer")
            .args([
                "-c",
                MIXER_CARD,
                "set",
                MIXER_CONTROL,
                &format!("{percent}%"),
            ])
            .status()
            .context("failed to start amixer")?;
        if !status.success() {
            bail!("amixer exited with {status}");
        }
        Ok(())
    }
}

fn read_state(path: &Path) -> Option<u8> {
    fs::read_to_string(path)
        .ok()
        .and_then(|value| value.trim().parse::<u8>().ok())
        .filter(|percent| *percent <= 100)
}

fn write_state(path: &Path, percent: u8) -> Result<()> {
    fs::write(path, format!("{percent}\n"))
        .with_context(|| format!("failed to write audio volume state {}", path.display()))
}

fn read_mixer_percent() -> Result<u8> {
    let output = Command::new("amixer")
        .args(["-c", MIXER_CARD, "get", MIXER_CONTROL])
        .output()
        .context("failed to read ALSA volume with amixer")?;
    if !output.status.success() {
        bail!("amixer exited with {}", output.status);
    }
    String::from_utf8_lossy(&output.stdout)
        .split(['[', '%'])
        .find_map(|part| part.trim().parse::<u8>().ok())
        .filter(|percent| *percent <= 100)
        .context("amixer output did not contain a valid PCM volume")
}
