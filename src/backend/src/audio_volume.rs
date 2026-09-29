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

/// Marks a state file written since amixer runs with `-M` (#65).
const MAPPED_MARKER: &str = "mapped";

/// How a saved percentage has to be read. amixer used to map percent
/// linearly onto the control's raw range, which made the same number sound
/// very different on HDMI (softvol, -51..0 dB) and on the jack
/// (-102.39..+4 dB). With `-M` percent follows the dB curve instead (#65),
/// so an old number would suddenly be several dB louder.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SavedVolume {
    /// Written before #65: percent of the raw range (`amixer` without `-M`).
    Raw(u8),
    /// Percent as the backend sets it now (`amixer -M`, or pactl).
    Mapped(u8),
}

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
    /// A pre-#65 value still to be converted by `start`.
    migrate_raw: Mutex<Option<u8>>,
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
        let saved = read_state(&state_path);
        if saved.is_none() {
            warn!(
                path = %state_path.display(),
                probed = ?probed_percent,
                "no saved audio volume, starting at {FALLBACK_PERCENT} %"
            );
        }
        let percent = initial_percent(saved);
        Self {
            state_path,
            backend,
            percent: Mutex::new(percent),
            migrate_raw: Mutex::new(match saved {
                Some(SavedVolume::Raw(raw)) => Some(raw),
                _ => None,
            }),
        }
    }

    pub fn start(&self) {
        if let Some(raw) = self
            .migrate_raw
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .take()
        {
            self.migrate(raw);
        }
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

    /// Turns a value saved before #65 into the mapped scale without changing
    /// what is heard: set it the old way, read the mapped percent back and
    /// keep that. If that fails the old number stays in the file, so the
    /// next start tries again.
    fn migrate(&self, raw: u8) {
        let result = match self.backend {
            VolumeBackend::Amixer => {
                convert_raw_to_mapped(raw, apply_amixer_raw, read_amixer_percent)
            }
            // PulseAudio percent never followed the raw range.
            VolumeBackend::Pactl => Ok(raw),
            VolumeBackend::Unavailable => return,
        };
        match result {
            Ok(mapped) => {
                *self
                    .percent
                    .lock()
                    .unwrap_or_else(|poisoned| poisoned.into_inner()) = mapped;
                match write_state(&self.state_path, mapped) {
                    Ok(()) => info!(raw, mapped, "audio volume converted to the mapped scale"),
                    Err(error) => {
                        warn!(%error, raw, mapped, "failed to save converted audio volume")
                    }
                }
            }
            Err(error) => warn!(%error, raw, "failed to convert saved audio volume"),
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
/// A raw value only stands until `start` has converted it.
fn initial_percent(saved: Option<SavedVolume>) -> u8 {
    match saved {
        Some(SavedVolume::Raw(percent) | SavedVolume::Mapped(percent)) => percent,
        None => FALLBACK_PERCENT,
    }
}

fn read_state(path: &Path) -> Option<SavedVolume> {
    parse_state(&fs::read_to_string(path).ok()?)
}

/// `42 mapped` since #65, a bare `65` before.
fn parse_state(text: &str) -> Option<SavedVolume> {
    let mut words = text.split_whitespace();
    let percent = words.next()?.parse::<u8>().ok().filter(|p| *p <= 100)?;
    match (words.next(), words.next()) {
        (None, _) => Some(SavedVolume::Raw(percent)),
        (Some(MAPPED_MARKER), None) => Some(SavedVolume::Mapped(percent)),
        _ => None,
    }
}

fn format_state(percent: u8) -> String {
    format!("{percent} {MAPPED_MARKER}\n")
}

fn write_state(path: &Path, percent: u8) -> Result<()> {
    fs::write(path, format_state(percent))
        .with_context(|| format!("failed to write audio volume state {}", path.display()))
}

fn convert_raw_to_mapped(
    raw: u8,
    set_raw: impl Fn(u8) -> Result<()>,
    read_mapped: impl Fn() -> Result<u8>,
) -> Result<u8> {
    set_raw(raw)?;
    read_mapped()
}

/// `-M` maps percent onto the dB curve (alsa-lib volume_mapping.c), so the
/// same number sounds alike on HDMI and on the jack (#65).
fn amixer_args(mapped: bool, command: &str, value: Option<u8>) -> Vec<String> {
    let mut args = Vec::new();
    if mapped {
        args.push("-M".to_string());
    }
    args.extend(["-c", MIXER_CARD, command, MIXER_CONTROL].map(String::from));
    if let Some(percent) = value {
        args.push(format!("{percent}%"));
    }
    args
}

fn amixer_set_args(percent: u8) -> Vec<String> {
    amixer_args(true, "set", Some(percent))
}

/// Only for converting a value saved before #65.
fn amixer_raw_set_args(percent: u8) -> Vec<String> {
    amixer_args(false, "set", Some(percent))
}

fn amixer_get_args() -> Vec<String> {
    amixer_args(true, "get", None)
}

fn run_amixer_set(args: Vec<String>) -> Result<()> {
    let output = Command::new("amixer")
        .args(args)
        .output()
        .context("failed to start amixer")?;
    check_tool("amixer", &output)
}

fn apply_amixer(percent: u8) -> Result<()> {
    run_amixer_set(amixer_set_args(percent))
}

fn apply_amixer_raw(percent: u8) -> Result<()> {
    run_amixer_set(amixer_raw_set_args(percent))
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
        .args(amixer_get_args())
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
    use std::cell::RefCell;

    use super::{
        amixer_get_args, amixer_raw_set_args, amixer_set_args, check_tool, convert_raw_to_mapped,
        format_state, initial_percent, parse_first_percent, parse_state, select_backend,
        SavedVolume, VolumeBackend,
    };

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
        assert_eq!(initial_percent(Some(SavedVolume::Mapped(61))), 61);
        assert_eq!(initial_percent(Some(SavedVolume::Mapped(0))), 0);
        assert_eq!(initial_percent(Some(SavedVolume::Raw(65))), 65);
    }

    #[test]
    fn a_bare_number_is_a_value_saved_before_the_mapped_scale() {
        assert_eq!(parse_state("65\n"), Some(SavedVolume::Raw(65)));
        assert_eq!(parse_state("0"), Some(SavedVolume::Raw(0)));
    }

    #[test]
    fn a_marked_number_is_on_the_mapped_scale() {
        assert_eq!(parse_state("42 mapped\n"), Some(SavedVolume::Mapped(42)));
    }

    #[test]
    fn a_written_state_reads_back_as_mapped() {
        assert_eq!(format_state(42), "42 mapped\n");
        assert_eq!(
            parse_state(&format_state(100)),
            Some(SavedVolume::Mapped(100))
        );
    }

    #[test]
    fn a_broken_state_counts_as_no_saved_value() {
        for text in ["", "loud", "150", "42 raw", "42 mapped extra", "-3"] {
            assert_eq!(parse_state(text), None, "{text:?}");
        }
    }

    #[test]
    fn amixer_sets_and_reads_on_the_mapped_scale() {
        assert_eq!(amixer_set_args(50), ["-M", "-c", "0", "set", "PCM", "50%"]);
        assert_eq!(amixer_get_args(), ["-M", "-c", "0", "get", "PCM"]);
    }

    #[test]
    fn the_conversion_sets_the_old_value_without_mapping() {
        assert_eq!(amixer_raw_set_args(65), ["-c", "0", "set", "PCM", "65%"]);
    }

    /// On carnine-pc (HDMI) the saved 65 read back as 42 with -M: the level
    /// stays -17.80 dB, only the number changes.
    #[test]
    fn converting_sets_the_raw_value_first_and_keeps_what_reads_back_mapped() {
        let calls = RefCell::new(Vec::new());
        let mapped = convert_raw_to_mapped(
            65,
            |raw| {
                calls.borrow_mut().push(format!("set raw {raw}"));
                Ok(())
            },
            || {
                calls.borrow_mut().push("read mapped".to_string());
                Ok(42)
            },
        )
        .expect("conversion should succeed");

        assert_eq!(mapped, 42);
        assert_eq!(*calls.borrow(), ["set raw 65", "read mapped"]);
    }

    #[test]
    fn a_failed_raw_set_stops_the_conversion() {
        let read = RefCell::new(false);
        let result = convert_raw_to_mapped(
            65,
            |_| anyhow::bail!("amixer: Invalid command!"),
            || {
                *read.borrow_mut() = true;
                Ok(42)
            },
        );

        assert!(result.is_err());
        assert!(!*read.borrow(), "must not read back after a failed set");
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
