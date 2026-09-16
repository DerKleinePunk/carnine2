use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Mutex;

use anyhow::{bail, Context, Result};
use tracing::{info, warn};

const MIXER_CARD: &str = "0";
const MIXER_CONTROL: &str = "PCM";
const PACTL_SINK: &str = "@DEFAULT_SINK@";

/// Which tool actually controls the audible volume, decided once at startup
/// and fixed for the process's lifetime (see `AudioVolume::new`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum VolumeBackend {
    /// A real ALSA hardware mixer, e.g. the Raspberry Pi target.
    Amixer,
    /// A PulseAudio sink, e.g. the WSLg bridge in local WSL development.
    Pactl,
    /// Neither tool could reach a working mixer/sink.
    Unavailable,
}

fn select_backend(amixer_ok: bool, pactl_ok: bool) -> VolumeBackend {
    if amixer_ok {
        VolumeBackend::Amixer
    } else if pactl_ok {
        VolumeBackend::Pactl
    } else {
        VolumeBackend::Unavailable
    }
}

pub struct AudioVolume {
    state_path: PathBuf,
    backend: VolumeBackend,
    percent: Mutex<u8>,
}

impl AudioVolume {
    pub fn new(state_path: PathBuf) -> Self {
        let amixer_probe = read_amixer_percent();
        let pactl_probe = read_pactl_percent();
        let backend = select_backend(amixer_probe.is_ok(), pactl_probe.is_ok());
        match backend {
            VolumeBackend::Amixer => info!("audio volume backend: amixer (ALSA hardware mixer)"),
            VolumeBackend::Pactl => {
                info!("audio volume backend: pactl (PulseAudio sink, e.g. WSLg)")
            }
            VolumeBackend::Unavailable => warn!(
                "no usable audio volume backend detected (neither amixer nor pactl); volume changes will be ignored"
            ),
        }

        let probed_percent = match backend {
            VolumeBackend::Amixer => amixer_probe.ok(),
            VolumeBackend::Pactl => pactl_probe.ok(),
            VolumeBackend::Unavailable => None,
        };
        let percent = read_state(&state_path).or(probed_percent).unwrap_or(100);
        Self {
            state_path,
            backend,
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
        match self.backend {
            VolumeBackend::Amixer => apply_amixer(percent),
            VolumeBackend::Pactl => apply_pactl(percent),
            VolumeBackend::Unavailable => {
                bail!("no usable audio volume backend (neither amixer nor pactl)")
            }
        }
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

fn apply_amixer(percent: u8) -> Result<()> {
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

fn read_amixer_percent() -> Result<u8> {
    let output = Command::new("amixer")
        .args(["-c", MIXER_CARD, "get", MIXER_CONTROL])
        .output()
        .context("failed to read ALSA volume with amixer")?;
    if !output.status.success() {
        bail!("amixer exited with {}", output.status);
    }
    parse_first_percent(&String::from_utf8_lossy(&output.stdout))
        .context("amixer output did not contain a valid PCM volume")
}

fn apply_pactl(percent: u8) -> Result<()> {
    let status = Command::new("pactl")
        .args(["set-sink-volume", PACTL_SINK, &format!("{percent}%")])
        .status()
        .context("failed to start pactl")?;
    if !status.success() {
        bail!("pactl exited with {status}");
    }
    Ok(())
}

fn read_pactl_percent() -> Result<u8> {
    let output = Command::new("pactl")
        .args(["get-sink-volume", PACTL_SINK])
        .output()
        .context("failed to read PulseAudio sink volume with pactl")?;
    if !output.status.success() {
        bail!("pactl exited with {}", output.status);
    }
    parse_first_percent(&String::from_utf8_lossy(&output.stdout))
        .context("pactl output did not contain a valid sink volume")
}

/// Finds the first `NN%` token in mixer/sink tool output and returns `NN`,
/// e.g. `78` from amixer's `"... 200 [78%] [-4.50dB] [on]"` or `100` from
/// pactl's `"Volume: front-left: 65536 / 100% / 0.00 dB, ..."`.
fn parse_first_percent(text: &str) -> Option<u8> {
    for (index, _) in text.match_indices('%') {
        let digits_start = text[..index]
            .rfind(|c: char| !c.is_ascii_digit())
            .map_or(0, |pos| pos + 1);
        if digits_start == index {
            continue;
        }
        if let Ok(value) = text[digits_start..index].parse::<u8>() {
            if value <= 100 {
                return Some(value);
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::{parse_first_percent, select_backend, VolumeBackend};

    #[test]
    fn selects_amixer_when_a_real_alsa_mixer_is_present() {
        assert_eq!(select_backend(true, true), VolumeBackend::Amixer);
        assert_eq!(select_backend(true, false), VolumeBackend::Amixer);
    }

    #[test]
    fn falls_back_to_pactl_when_no_alsa_mixer_is_present() {
        assert_eq!(select_backend(false, true), VolumeBackend::Pactl);
    }

    #[test]
    fn is_unavailable_when_neither_tool_works() {
        assert_eq!(select_backend(false, false), VolumeBackend::Unavailable);
    }

    #[test]
    fn parses_percent_from_amixer_output() {
        let output = "Simple mixer control 'PCM',0\n  \
            Front Left: Playback 200 [78%] [-4.50dB] [on]\n  \
            Front Right: Playback 200 [78%] [-4.50dB] [on]\n";
        assert_eq!(parse_first_percent(output), Some(78));
    }

    #[test]
    fn parses_percent_from_pactl_output() {
        let output = "Volume: front-left: 65536 / 100% / 0.00 dB, \
            front-right: 65536 / 100% / 0.00 dB\n        balance 0.00\n";
        assert_eq!(parse_first_percent(output), Some(100));
    }

    #[test]
    fn ignores_percent_values_above_the_valid_range() {
        assert_eq!(parse_first_percent("weirdly 150% loud"), None);
    }

    #[test]
    fn returns_none_without_any_percent_token() {
        assert_eq!(parse_first_percent("no volume information here"), None);
    }
}
