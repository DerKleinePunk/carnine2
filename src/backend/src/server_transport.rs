use std::io;
use std::net::SocketAddr;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;
use std::pin::Pin;
use std::task::{Context, Poll};

use anyhow::{Context as _, Result};
use futures_util::stream::{select_all, BoxStream};
use tokio::io::{AsyncRead, AsyncWrite, ReadBuf};
use tokio::net::{TcpListener, TcpStream, UnixListener, UnixStream};
use tokio_stream::wrappers::{TcpListenerStream, UnixListenerStream};
use tokio_stream::{Stream, StreamExt};
use tonic::transport::server::Connected;

/// A gRPC connection accepted from either transport this server exposes.
///
/// Unix domain sockets are the primary transport (ADR-002): frontend and
/// backend run as the same user on the same machine in production, so a
/// socket file with owner-only permissions is sufficient without a separate
/// auth layer. The TCP loopback listener is an explicit, optional
/// development fallback for setups where client and server do not share a
/// kernel/socket namespace - e.g. a Windows-hosted Flutter debug build
/// talking to a backend running inside WSL2.
pub enum ServerStream {
    Unix(UnixStream),
    Tcp(TcpStream),
}

impl AsyncRead for ServerStream {
    fn poll_read(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &mut ReadBuf<'_>,
    ) -> Poll<io::Result<()>> {
        match self.get_mut() {
            ServerStream::Unix(stream) => Pin::new(stream).poll_read(cx, buf),
            ServerStream::Tcp(stream) => Pin::new(stream).poll_read(cx, buf),
        }
    }
}

impl AsyncWrite for ServerStream {
    fn poll_write(
        self: Pin<&mut Self>,
        cx: &mut Context<'_>,
        buf: &[u8],
    ) -> Poll<io::Result<usize>> {
        match self.get_mut() {
            ServerStream::Unix(stream) => Pin::new(stream).poll_write(cx, buf),
            ServerStream::Tcp(stream) => Pin::new(stream).poll_write(cx, buf),
        }
    }

    fn poll_flush(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<io::Result<()>> {
        match self.get_mut() {
            ServerStream::Unix(stream) => Pin::new(stream).poll_flush(cx),
            ServerStream::Tcp(stream) => Pin::new(stream).poll_flush(cx),
        }
    }

    fn poll_shutdown(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<io::Result<()>> {
        match self.get_mut() {
            ServerStream::Unix(stream) => Pin::new(stream).poll_shutdown(cx),
            ServerStream::Tcp(stream) => Pin::new(stream).poll_shutdown(cx),
        }
    }
}

impl Connected for ServerStream {
    type ConnectInfo = ();

    fn connect_info(&self) -> Self::ConnectInfo {}
}

/// Binds the primary Unix domain socket and, if `tcp_fallback` is set, an
/// additional TCP loopback listener, merging both into a single incoming
/// connection stream for `Server::serve_with_incoming_shutdown`.
pub async fn bind(
    socket_path: &Path,
    tcp_fallback: Option<SocketAddr>,
) -> Result<impl Stream<Item = io::Result<ServerStream>>> {
    let mut incoming: Vec<BoxStream<'static, io::Result<ServerStream>>> =
        vec![bind_unix_socket(socket_path)?];

    if let Some(addr) = tcp_fallback {
        let listener = TcpListener::bind(addr)
            .await
            .with_context(|| format!("cannot bind tcp fallback address {addr}"))?;
        incoming.push(Box::pin(
            TcpListenerStream::new(listener).map(|result| result.map(ServerStream::Tcp)),
        ));
    }

    Ok(select_all(incoming))
}

fn bind_unix_socket(socket_path: &Path) -> Result<BoxStream<'static, io::Result<ServerStream>>> {
    if let Some(parent) = socket_path.parent() {
        std::fs::create_dir_all(parent).with_context(|| {
            format!(
                "cannot create socket directory {}; for development set CARNINE_SOCKET_PATH to a writable location",
                parent.display()
            )
        })?;
    }
    if socket_path.exists() {
        std::fs::remove_file(socket_path)
            .with_context(|| format!("cannot remove stale socket {}", socket_path.display()))?;
    }
    let listener = UnixListener::bind(socket_path)
        .with_context(|| format!("cannot bind unix socket {}", socket_path.display()))?;
    std::fs::set_permissions(socket_path, std::fs::Permissions::from_mode(0o600))
        .with_context(|| format!("cannot set permissions on socket {}", socket_path.display()))?;

    Ok(Box::pin(
        UnixListenerStream::new(listener).map(|result| result.map(ServerStream::Unix)),
    ))
}
