//! Serial lines to devices in the car (GPS mouse, power supply): raw mode at
//! a fixed speed, so the kernel neither edits nor echoes what they send.

use std::fs::File;
use std::os::fd::AsRawFd;

use anyhow::{Context, Result};

/// Puts a terminal into raw mode at `baud`, so the kernel neither edits nor
/// echoes the receiver's lines. Returns `false`, without error, for anything
/// that is not a terminal.
pub fn configure_line(file: &File, baud: u32) -> Result<bool> {
    let speed = baud_constant(baud).with_context(|| format!("unsupported line speed {baud}"))?;
    let fd = file.as_raw_fd();
    // SAFETY: termios is plain old data; tcgetattr fills it before any use.
    let mut settings: libc::termios = unsafe { std::mem::zeroed() };
    // SAFETY: fd stays open for the duration of the call, settings is valid.
    if unsafe { libc::tcgetattr(fd, &mut settings) } != 0 {
        let err = std::io::Error::last_os_error();
        if err.raw_os_error() == Some(libc::ENOTTY) {
            return Ok(false);
        }
        return Err(err).context("reading the line settings");
    }
    // SAFETY: settings came from tcgetattr; the calls only modify it.
    unsafe {
        libc::cfmakeraw(&mut settings);
        libc::cfsetispeed(&mut settings, speed);
        libc::cfsetospeed(&mut settings, speed);
    }
    settings.c_cflag |= libc::CLOCAL | libc::CREAD;
    settings.c_cc[libc::VMIN] = 1;
    settings.c_cc[libc::VTIME] = 0;
    // SAFETY: fd is open, settings is a valid termios.
    if unsafe { libc::tcsetattr(fd, libc::TCSANOW, &settings) } != 0 {
        return Err(std::io::Error::last_os_error()).context("applying the line settings");
    }
    // Whatever arrived at the wrong speed before is garbage.
    // SAFETY: fd is open.
    unsafe { libc::tcflush(fd, libc::TCIFLUSH) };
    Ok(true)
}

fn baud_constant(baud: u32) -> Option<libc::speed_t> {
    Some(match baud {
        4800 => libc::B4800,
        9600 => libc::B9600,
        19200 => libc::B19200,
        38400 => libc::B38400,
        57600 => libc::B57600,
        115200 => libc::B115200,
        _ => return None,
    })
}

pub fn set_blocking(file: &File) -> Result<()> {
    let fd = file.as_raw_fd();
    // SAFETY: fd is open; F_GETFL/F_SETFL only touch its status flags.
    let flags = unsafe { libc::fcntl(fd, libc::F_GETFL) };
    if flags < 0 || unsafe { libc::fcntl(fd, libc::F_SETFL, flags & !libc::O_NONBLOCK) } < 0 {
        return Err(std::io::Error::last_os_error()).context("switching to blocking reads");
    }
    Ok(())
}

/// A pseudo-terminal standing in for a serial adapter in tests: the master
/// end for the test, the path of the slave end for the code under test.
#[cfg(test)]
pub fn pseudo_terminal() -> (File, String) {
    use std::os::fd::FromRawFd;
    // SAFETY: plain libc calls on a descriptor this function owns until it
    // hands it over to the File.
    unsafe {
        let master = libc::posix_openpt(libc::O_RDWR | libc::O_NOCTTY);
        assert!(master >= 0, "posix_openpt");
        assert_eq!(libc::grantpt(master), 0);
        assert_eq!(libc::unlockpt(master), 0);
        let mut name = [0 as libc::c_char; 128];
        assert_eq!(libc::ptsname_r(master, name.as_mut_ptr(), name.len()), 0);
        let slave_path = std::ffi::CStr::from_ptr(name.as_ptr())
            .to_str()
            .unwrap()
            .to_string();
        (File::from_raw_fd(master), slave_path)
    }
}

#[cfg(test)]
mod tests {
    use std::os::unix::fs::OpenOptionsExt;

    use super::*;

    #[test]
    fn configure_line_sets_raw_mode_and_speed_on_a_terminal() {
        let (_master, slave_path) = pseudo_terminal();
        let slave = std::fs::OpenOptions::new()
            .read(true)
            .custom_flags(libc::O_NOCTTY)
            .open(&slave_path)
            .unwrap();

        assert!(configure_line(&slave, 4800).unwrap());
        // SAFETY: termios is plain old data, filled by tcgetattr.
        let mut settings: libc::termios = unsafe { std::mem::zeroed() };
        assert_eq!(
            unsafe { libc::tcgetattr(slave.as_raw_fd(), &mut settings) },
            0
        );
        assert_eq!(unsafe { libc::cfgetispeed(&settings) }, libc::B4800);
        assert_eq!(settings.c_lflag & (libc::ICANON | libc::ECHO), 0);
        assert!(configure_line(&slave, 4801).is_err());
    }
}
