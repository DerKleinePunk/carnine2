//! The sd_notify protocol, so systemd knows when the backend is ready.
//!
//! With `Type=notify` systemd holds back units ordered after the backend (the
//! frontend) until it sends `READY=1`. The backend sends it once its gRPC
//! socket listens; before that the frontend's first calls failed with
//! UNAVAILABLE. Without `NOTIFY_SOCKET` (a start by hand, WSL, tests) nothing
//! is sent.

use std::ffi::OsStr;
use std::io;
use std::os::linux::net::SocketAddrExt;
use std::os::unix::ffi::OsStrExt;
use std::os::unix::net::{SocketAddr, UnixDatagram};

/// The service is up: its socket accepts connections.
pub const READY: &str = "READY=1";
/// The service is shutting down.
pub const STOPPING: &str = "STOPPING=1";

/// Sends `state` to the socket systemd passed in `NOTIFY_SOCKET`. Returns
/// whether anything was sent; no socket is not an error.
pub fn notify(state: &str) -> io::Result<bool> {
    match std::env::var_os("NOTIFY_SOCKET") {
        Some(socket) if !socket.is_empty() => notify_to(&socket, state).map(|()| true),
        _ => Ok(false),
    }
}

/// Sends `state` to `socket`: a path, or an abstract address written with a
/// leading `@` as systemd does.
fn notify_to(socket: &OsStr, state: &str) -> io::Result<()> {
    let bytes = socket.as_bytes();
    let address = match bytes.strip_prefix(b"@") {
        Some(name) => SocketAddr::from_abstract_name(name)?,
        None => SocketAddr::from_pathname(socket)?,
    };
    let sent = UnixDatagram::unbound()?.send_to_addr(state.as_bytes(), &address)?;
    if sent != state.len() {
        return Err(io::Error::new(
            io::ErrorKind::WriteZero,
            format!("sent {sent} of {} bytes to the notify socket", state.len()),
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::OsString;

    fn received(listener: &UnixDatagram) -> String {
        let mut buffer = [0u8; 64];
        let length = listener
            .recv(&mut buffer)
            .expect("a datagram should arrive");
        String::from_utf8_lossy(&buffer[..length]).into_owned()
    }

    #[test]
    fn sends_the_state_to_a_path_socket() {
        let directory =
            std::env::temp_dir().join(format!("carnine-notify-test-{}", std::process::id()));
        std::fs::create_dir_all(&directory).unwrap();
        let path = directory.join("notify.sock");
        let _ = std::fs::remove_file(&path);
        let listener = UnixDatagram::bind(&path).unwrap();

        notify_to(path.as_os_str(), READY).expect("notify should succeed");
        assert_eq!(received(&listener), "READY=1");
        notify_to(path.as_os_str(), STOPPING).expect("notify should succeed");
        assert_eq!(received(&listener), "STOPPING=1");

        std::fs::remove_dir_all(&directory).ok();
    }

    #[test]
    fn sends_the_state_to_an_abstract_socket() {
        let name = format!("carnine-notify-test-{}", std::process::id());
        let listener =
            UnixDatagram::bind_addr(&SocketAddr::from_abstract_name(name.as_bytes()).unwrap())
                .unwrap();

        notify_to(&OsString::from(format!("@{name}")), READY).expect("notify should succeed");
        assert_eq!(received(&listener), "READY=1");
    }

    #[test]
    fn a_missing_socket_is_an_error() {
        let path = std::env::temp_dir().join("carnine-notify-test-nobody-listens.sock");
        let _ = std::fs::remove_file(&path);
        assert!(notify_to(path.as_os_str(), READY).is_err());
    }
}
