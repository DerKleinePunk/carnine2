//! Writes the GPS receiver's raw NMEA to a file per drive, so a real drive
//! becomes a replay tour and a problem seen on the road can be replayed at
//! the desk. Switched live over gRPC; the switch itself is kept in the media
//! database by the caller.

use std::fs::File;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use anyhow::{Context, Result};
use chrono::NaiveDateTime;
use tracing::{info, warn};

/// What the navigation status reports about recording.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrackStatus {
    pub available: bool,
    pub enabled: bool,
    /// File being written; `None` while nothing is written.
    pub file: Option<PathBuf>,
}

#[derive(Debug)]
struct Inner {
    directory: Option<PathBuf>,
    enabled: bool,
    current: Option<(PathBuf, File)>,
    /// Set after a write error, so a full card logs once, not every second.
    /// Cleared by the next switch or segment.
    failed: bool,
}

/// Shared between the gRPC service (switch, status) and the serial reader
/// (lines). Cheap to clone.
#[derive(Debug, Clone)]
pub struct TrackRecorder {
    inner: Arc<Mutex<Inner>>,
}

impl TrackRecorder {
    /// `directory` unset means recording is not available at all.
    pub fn new(directory: Option<PathBuf>, enabled: bool) -> Self {
        let directory = directory.filter(|path| !path.as_os_str().is_empty());
        Self {
            inner: Arc::new(Mutex::new(Inner {
                enabled: enabled && directory.is_some(),
                directory,
                current: None,
                failed: false,
            })),
        }
    }

    fn lock(&self) -> std::sync::MutexGuard<'_, Inner> {
        self.inner
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    pub fn status(&self) -> TrackStatus {
        let inner = self.lock();
        TrackStatus {
            available: inner.directory.is_some(),
            enabled: inner.enabled,
            file: inner.current.as_ref().map(|(path, _)| path.clone()),
        }
    }

    /// Switches recording. Off closes the file; on starts a new one with the
    /// next sentence. Fails without a track directory.
    pub fn set_enabled(&self, enabled: bool) -> Result<()> {
        let mut inner = self.lock();
        if inner.directory.is_none() {
            anyhow::bail!("navigation.track_directory is not configured");
        }
        if !enabled {
            if let Some((path, _)) = inner.current.take() {
                info!(file = %path.display(), "track recording stopped");
            }
        }
        inner.enabled = enabled;
        inner.failed = false;
        Ok(())
    }

    /// Ends the current file; the next sentence starts a new one. Called when
    /// the receiver was reopened, so every connection is its own tour.
    pub fn new_segment(&self) {
        let mut inner = self.lock();
        if let Some((path, _)) = inner.current.take() {
            info!(file = %path.display(), "track file closed");
        }
        inner.failed = false;
    }

    /// Appends one received line. `gps_time` (rollover-corrected, when the
    /// sentence has one) names a new file, so the name is right even while
    /// the system clock is not.
    pub fn record_line(&self, line: &str, gps_time: Option<NaiveDateTime>) {
        let mut inner = self.lock();
        if !inner.enabled || inner.failed {
            return;
        }
        let Some(directory) = inner.directory.clone() else {
            return;
        };
        if inner.current.is_none() {
            let started = gps_time.unwrap_or_else(|| chrono::Utc::now().naive_utc());
            match open_track_file(&directory, started) {
                Ok((path, file)) => {
                    info!(file = %path.display(), "track recording started");
                    inner.current = Some((path, file));
                }
                Err(err) => {
                    inner.failed = true;
                    warn!(error = %format!("{err:#}"), "track recording not possible");
                    return;
                }
            }
        }
        let line = line.trim_end_matches(['\r', '\n']);
        let written = inner
            .current
            .as_mut()
            .map(|(_, file)| writeln!(file, "{line}"));
        if let Some(Err(err)) = written {
            let path = inner.current.take().map(|(path, _)| path);
            inner.failed = true;
            warn!(
                error = %err,
                file = %path.as_deref().unwrap_or(Path::new("")).display(),
                "writing the track file failed, recording paused until switched again"
            );
        }
    }
}

/// `<directory>/<UTC start>.nmea`, a new name even when two drives start in
/// the same second.
fn open_track_file(directory: &Path, started: NaiveDateTime) -> Result<(PathBuf, File)> {
    std::fs::create_dir_all(directory)
        .with_context(|| format!("creating {}", directory.display()))?;
    let stem = started.format("%Y-%m-%dT%H-%M-%SZ").to_string();
    for attempt in 0..100 {
        let name = if attempt == 0 {
            format!("{stem}.nmea")
        } else {
            format!("{stem}-{attempt}.nmea")
        };
        let path = directory.join(name);
        match std::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&path)
        {
            Ok(file) => return Ok((path, file)),
            Err(err) if err.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(err) => return Err(err).with_context(|| format!("creating {}", path.display())),
        }
    }
    anyhow::bail!(
        "no free track file name for {stem} in {}",
        directory.display()
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::NaiveDate;

    fn directory(name: &str) -> PathBuf {
        let path =
            std::env::temp_dir().join(format!("carnine-tracks-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&path);
        path
    }

    fn at(hour: u32, minute: u32) -> NaiveDateTime {
        NaiveDate::from_ymd_opt(2026, 9, 25)
            .unwrap()
            .and_hms_opt(hour, minute, 0)
            .unwrap()
    }

    #[test]
    fn without_a_directory_recording_is_unavailable() {
        let recorder = TrackRecorder::new(None, true);
        assert_eq!(
            recorder.status(),
            TrackStatus {
                available: false,
                enabled: false,
                file: None
            }
        );
        assert!(recorder.set_enabled(true).is_err());
        recorder.record_line("$GPRMC", None);
        assert_eq!(recorder.status().file, None);
    }

    #[test]
    fn writes_lines_to_a_file_named_after_the_gps_time() {
        let dir = directory("write");
        let recorder = TrackRecorder::new(Some(dir.clone()), true);
        recorder.record_line("$GPGGA,1*00\r\n", Some(at(14, 57)));
        recorder.record_line("$GPRMC,2*00\n", Some(at(14, 57)));
        let file = recorder.status().file.expect("recording writes a file");
        assert_eq!(file, dir.join("2026-09-25T14-57-00Z.nmea"));
        assert_eq!(
            std::fs::read_to_string(&file).unwrap(),
            "$GPGGA,1*00\n$GPRMC,2*00\n"
        );
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn switching_off_closes_and_on_again_starts_a_new_file() {
        let dir = directory("switch");
        let recorder = TrackRecorder::new(Some(dir.clone()), false);
        recorder.record_line("$GPRMC,0*00", Some(at(14, 0)));
        assert_eq!(recorder.status().file, None, "off writes nothing");

        recorder.set_enabled(true).unwrap();
        recorder.record_line("$GPRMC,1*00", Some(at(15, 0)));
        let first = recorder.status().file.unwrap();
        recorder.set_enabled(false).unwrap();
        assert_eq!(recorder.status().file, None);
        assert!(!recorder.status().enabled);

        recorder.set_enabled(true).unwrap();
        recorder.record_line("$GPRMC,2*00", Some(at(15, 0)));
        let second = recorder.status().file.unwrap();
        assert_ne!(first, second, "same second, still a new file");
        assert_eq!(second, dir.join("2026-09-25T15-00-00Z-1.nmea"));
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn a_new_segment_starts_a_new_file() {
        let dir = directory("segment");
        let recorder = TrackRecorder::new(Some(dir.clone()), true);
        recorder.record_line("$GPRMC,1*00", Some(at(16, 0)));
        recorder.new_segment();
        assert_eq!(recorder.status().file, None);
        recorder.record_line("$GPRMC,2*00", Some(at(16, 5)));
        assert_eq!(
            recorder.status().file,
            Some(dir.join("2026-09-25T16-05-00Z.nmea"))
        );
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[test]
    fn an_unwritable_directory_pauses_recording_without_panicking() {
        // A path below a regular file can never be created.
        let blocker = directory("blocked");
        std::fs::write(&blocker, "not a directory").unwrap();
        let recorder = TrackRecorder::new(Some(blocker.join("tracks")), true);
        recorder.record_line("$GPRMC,1*00", Some(at(17, 0)));
        recorder.record_line("$GPRMC,2*00", Some(at(17, 0)));
        let status = recorder.status();
        assert!(status.enabled);
        assert_eq!(status.file, None);
        std::fs::remove_file(blocker).unwrap();
    }
}
