use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Mutex;

use anyhow::{bail, Context, Result};
use tracing::{info, warn};

const MIXER_CARD: &str = "0";
const MIXER_CONTROL: &str = "PCM";
const PACTL_SINK: &str = "@DEFAULT_SINK@";
const RESTORE_RETRY_DELAY: std::time::Duration = std::time::Duration::from_secs(1);

/// Used whenever there is no saved value (#61). Deliberately moderate:
/// behind a car amplifier, 100 % is far too loud.
const FALLBACK_PERCENT: u8 = 50;

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
        let saved_percent = read_state(&state_path);
        if saved_percent.is_none() {
            warn!(
                path = %state_path.display(),
                probed = ?probed_percent,
                "no saved audio volume, starting at {FALLBACK_PERCENT} %"
            );
        }
        let percent = initial_percent(saved_percent);
        Self {
            state_path,
            backend,
            percent: Mutex::new(percent),
        }
    }

    pub fn start(&self) {
        let percent = self.current();
        // On a fresh image's first boot `amixer set` once failed while `get`
        // worked (#61); one retry covers a mixer that is not ready yet.
        let result = self.apply(percent).or_else(|error| {
            warn!(%error, percent, "failed to restore audio volume, retrying in 1 s");
            std::thread::sleep(RESTORE_RETRY_DELAY);
            self.apply(percent)
        });
        match result {
            Ok(()) => info!(percent, "audio volume restored"),
            Err(error) => warn!(%error, percent, "failed to restore audio volume"),
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

/// The saved value wins, even 0 (the user muted on purpose). Without one
/// the mixer says nothing about what the user wants: at 0 it is our own mute
/// from the last shutdown (#47), and on a fresh image it stands at the
/// factory 100 % (#61). Either way the volume starts at the fallback.
fn initial_percent(saved: Option<u8>) -> u8 {
    saved.unwrap_or(FALLBACK_PERCENT)
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
    let output = Command::new("amixer")
        .args([
            "-c",
            MIXER_CARD,
            "set",
            MIXER_CONTROL,
            &format!("{percent}%"),
        ])
        .output()
        .context("failed to start amixer")?;
    check_tool("amixer", &output)
}

/// Fails with the tool's own message: its stderr went only to the journal,
/// which lives in RAM and was gone when a first-boot failure was looked at
/// (#61).
fn check_tool(tool: &str, output: &std::process::Output) -> Result<()> {
    if output.status.success() {
        return Ok(());
    }
    let stderr = String::from_utf8_lossy(&output.stderr);
    let message = stderr.trim();
    if message.is_empty() {
        bail!("{tool} exited with {}", output.status);
    }
    bail!("{tool} exited with {}: {message}", output.status)
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
    let output = Command::new("pactl")
        .args(["set-sink-volume", PACTL_SINK, &format!("{percent}%")])
        .output()
        .context("failed to start pactl")?;
    check_tool("pactl", &output)
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
    use super::{check_tool, initial_percent, parse_first_percent, select_backend, VolumeBackend};

    fn run(script: &str) -> std::process::Output {
        std::process::Command::new("sh")
            .args(["-c", script])
            .output()
            .expect("sh should run")
    }

    #[test]
    fn a_failing_tool_reports_its_own_message() {
        let error = check_tool(
            "amixer",
            &run("echo \"amixer: Unable to find simple control 'PCM',0\" >&2; exit 1"),
        )
        .expect_err("exit 1 must fail");

        let message = format!("{error:#}");
        assert!(
            message.contains("Unable to find simple control 'PCM',0"),
            "{message}"
        );
        assert!(message.contains("exit status: 1"), "{message}");
    }

    #[test]
    fn a_silent_failure_still_names_the_exit_status() {
        let error = check_tool("pactl", &run("exit 3")).expect_err("exit 3 must fail");

        assert_eq!(format!("{error:#}"), "pactl exited with exit status: 3");
    }

    #[test]
    fn a_successful_tool_passes() {
        assert!(check_tool("amixer", &run("echo ok; exit 0")).is_ok());
    }

    #[test]
    fn the_saved_volume_wins_even_when_muted() {
        assert_eq!(initial_percent(Some(61)), 61);
        assert_eq!(initial_percent(Some(0)), 0);
    }

    /// Neither the shutdown mute (0 %, #47) nor the factory mixer (100 %,
    /// #61) may decide the volume; without a saved value it starts at 50 %.
    #[test]
    fn without_a_saved_value_the_volume_starts_at_the_fallback() {
        assert_eq!(initial_percent(None), 50);
    }

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
