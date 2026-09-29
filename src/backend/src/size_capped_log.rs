use std::fs::{self, File, OpenOptions};
use std::io::{self, Write};
use std::path::{Path, PathBuf};

/// Largest the log file grows before it is moved to `<name>.1`, so at most
/// twice this much log lies on the card.
pub const MAX_LOG_BYTES: u64 = 50 * 1024 * 1024;

/// An append-only log file with a size limit.
///
/// A burst of errors once filled 12-15 GB within the hour (#59); the old
/// `rolling::never` appender had no limit. Past `max_bytes` the file is
/// renamed to `<name>.1`, replacing an older one, and a new file is begun.
pub struct SizeCappedFile {
    path: PathBuf,
    max_bytes: u64,
    file: File,
    written: u64,
}

impl SizeCappedFile {
    pub fn open(path: impl AsRef<Path>, max_bytes: u64) -> io::Result<Self> {
        let path = path.as_ref().to_path_buf();
        let file = open_append(&path)?;
        let written = file.metadata()?.len();
        Ok(Self {
            path,
            max_bytes,
            file,
            written,
        })
    }

    fn rotate(&mut self) -> io::Result<()> {
        self.file.flush()?;
        let mut rotated = self.path.clone().into_os_string();
        rotated.push(".1");
        fs::rename(&self.path, rotated)?;
        self.file = open_append(&self.path)?;
        self.written = 0;
        Ok(())
    }
}

fn open_append(path: &Path) -> io::Result<File> {
    OpenOptions::new().create(true).append(true).open(path)
}

impl Write for SizeCappedFile {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        if self.written > 0 && self.written + buf.len() as u64 > self.max_bytes {
            self.rotate()?;
        }
        let written = self.file.write(buf)?;
        self.written += written as u64;
        Ok(written)
    }

    fn flush(&mut self) -> io::Result<()> {
        self.file.flush()
    }
}

#[cfg(test)]
mod tests {
    use std::io::Write;

    use super::SizeCappedFile;

    fn folder(name: &str) -> std::path::PathBuf {
        let folder = std::env::temp_dir().join(format!("carnine-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&folder);
        std::fs::create_dir_all(&folder).expect("log folder should be created");
        folder
    }

    #[test]
    fn stays_below_the_limit_and_keeps_one_old_file() {
        let folder = folder("log-cap");
        let path = folder.join("backend.log");
        let mut log = SizeCappedFile::open(&path, 100).expect("log should open");

        for line in 0..20 {
            writeln!(log, "line {line:02} with some padding text").expect("write should work");
        }
        log.flush().expect("flush should work");

        let current = std::fs::metadata(&path).expect("log exists").len();
        let old = std::fs::metadata(folder.join("backend.log.1"))
            .expect("rotated log exists")
            .len();
        assert!(current <= 100, "current {current}");
        assert!(old <= 100, "old {old}");
        assert!(std::fs::read_to_string(&path)
            .expect("log is text")
            .ends_with("line 19 with some padding text\n"));
        let _ = std::fs::remove_dir_all(folder);
    }

    #[test]
    fn an_existing_oversized_log_is_rotated_on_the_first_write() {
        let folder = folder("log-cap-existing");
        let path = folder.join("backend.log");
        std::fs::write(&path, vec![b'x'; 500]).expect("old log should be written");

        let mut log = SizeCappedFile::open(&path, 100).expect("log should open");
        writeln!(log, "first line after the update").expect("write should work");
        log.flush().expect("flush should work");

        assert_eq!(
            std::fs::read_to_string(&path).expect("log is text"),
            "first line after the update\n"
        );
        assert_eq!(
            std::fs::metadata(folder.join("backend.log.1"))
                .expect("old log was kept")
                .len(),
            500
        );
        let _ = std::fs::remove_dir_all(folder);
    }
}
