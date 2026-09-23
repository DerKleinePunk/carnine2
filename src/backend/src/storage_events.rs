use std::collections::HashMap;
use std::ffi::OsStr;
use std::os::unix::ffi::OsStrExt;
use std::path::PathBuf;
use std::sync::Arc;

use anyhow::Result;
use futures_util::StreamExt;
use tracing::{error, info, warn};
use zbus::{fdo::ObjectManagerProxy, message::Type, Connection, MatchRule, MessageStream};

use crate::MediaServiceImpl;

#[zbus::proxy(
    interface = "org.freedesktop.UDisks2.Filesystem",
    default_service = "org.freedesktop.UDisks2"
)]
trait Filesystem {
    async fn mount(
        &self,
        options: HashMap<&str, zbus::zvariant::Value<'_>>,
    ) -> zbus::Result<String>;
}

pub fn spawn(media_service: Arc<MediaServiceImpl>) {
    tokio::spawn(async move {
        if let Err(error) = listen(media_service).await {
            warn!(%error, "storage event listener stopped");
        }
    });
}

async fn listen(media_service: Arc<MediaServiceImpl>) -> Result<()> {
    let connection = Connection::system().await?;
    let rule = MatchRule::builder()
        .msg_type(Type::Signal)
        .sender("org.freedesktop.UDisks2")?
        .path_namespace("/org/freedesktop/UDisks2")?
        .build();
    info!("udisks2 storage event listener started");
    let mut messages = MessageStream::for_match_rule(rule, &connection, Some(32)).await?;
    inspect_music_volumes(&connection, &media_service).await?;
    while let Some(message) = messages.next().await {
        let message = message?;
        let header = message.header();
        if header.primary().msg_type() != Type::Signal {
            continue;
        }
        let Some(member) = header.member() else {
            continue;
        };
        if !matches!(
            member.as_str(),
            "InterfacesAdded" | "InterfacesRemoved" | "PropertiesChanged"
        ) {
            continue;
        }

        info!(event = %member, "udisks2 storage event received; inspecting music volumes");
        if let Err(error) = inspect_music_volumes(&connection, &media_service).await {
            error!(%error, "automatic music volume inspection failed after storage event");
        }
    }

    Ok(())
}

async fn inspect_music_volumes(
    connection: &Connection,
    media_service: &MediaServiceImpl,
) -> Result<()> {
    let manager = ObjectManagerProxy::builder(connection)
        .destination("org.freedesktop.UDisks2")?
        .path("/org/freedesktop/UDisks2")?
        .build()
        .await?;
    let objects = manager.get_managed_objects().await?;
    for (object_path, interfaces) in objects {
        let Some(block_properties) = interfaces.get("org.freedesktop.UDisks2.Block") else {
            continue;
        };
        let Some(filesystem_properties) = interfaces.get("org.freedesktop.UDisks2.Filesystem")
        else {
            continue;
        };
        let label = block_properties
            .get("IdLabel")
            .and_then(|value| value.downcast_ref::<String>().ok())
            .unwrap_or_default();
        if !label.eq_ignore_ascii_case("MUSIK") {
            continue;
        }
        let Some(mount_points) = filesystem_properties
            .get("MountPoints")
            .and_then(|value| value.downcast_ref::<zbus::zvariant::Array>().ok())
        else {
            continue;
        };
        if mount_points.is_empty() {
            let filesystem = FilesystemProxy::builder(connection)
                .destination("org.freedesktop.UDisks2")?
                .path(object_path.as_str())?
                .build()
                .await?;
            match filesystem.mount(HashMap::new()).await {
                Ok(mount_path) => info!(label, path = %mount_path, "mounted MUSIK volume"),
                Err(error) => {
                    error!(%error, path = %object_path, "failed to mount MUSIK volume")
                }
            }
            continue;
        }
        for mount_point in mount_points.iter() {
            let Ok(mount_point) = mount_point.downcast_ref::<zbus::zvariant::Array>() else {
                continue;
            };
            let mount_point: Vec<u8> = mount_point
                .iter()
                .filter_map(|value| value.downcast_ref::<u8>().ok())
                .collect();
            let mount_path = mount_path_from_bytes(&mount_point);
            if let Err(error) =
                media_service.discover_music_volume(label.to_string(), mount_path.clone())
            {
                error!(%error, path = %mount_path.display(), "music volume scan failed");
            }
        }
        info!(path = %object_path, label, "inspected MUSIK volume");
    }
    Ok(())
}

/// UDisks2 reports `MountPoints` as NUL-terminated C strings inside an `aay`.
/// The terminator has to go before the bytes become a path: it is valid UTF-8,
/// so nothing rejects it, it is invisible in logs, and `Path::exists` then
/// answers false for a directory that is plainly there.
///
/// The bytes are taken as they are otherwise. A mount path is not required to
/// be UTF-8 on Linux, and a stick whose label decides the path is exactly the
/// place where that shows up.
fn mount_path_from_bytes(bytes: &[u8]) -> PathBuf {
    let bytes = bytes.split(|byte| *byte == 0).next().unwrap_or_default();
    PathBuf::from(OsStr::from_bytes(bytes))
}

#[cfg(test)]
mod tests {
    use super::mount_path_from_bytes;
    use std::ffi::OsStr;
    use std::os::unix::ffi::OsStrExt;
    use std::path::Path;

    /// The exact bytes UDisks2 returned for the test stick on the Pi:
    /// 20 characters of path plus the terminator.
    const UDISKS2_REPLY: &[u8] = b"/media/carnine/MUSIK\0";

    #[test]
    fn the_nul_terminator_never_reaches_the_path() {
        assert_eq!(UDISKS2_REPLY.len(), 21);
        assert_eq!(
            mount_path_from_bytes(UDISKS2_REPLY),
            Path::new("/media/carnine/MUSIK")
        );
    }

    #[test]
    fn a_path_without_a_terminator_is_left_alone() {
        assert_eq!(
            mount_path_from_bytes(b"/media/carnine/MUSIK"),
            Path::new("/media/carnine/MUSIK")
        );
    }

    #[test]
    fn a_path_that_is_not_utf8_survives() {
        let bytes = b"/media/carnine/M\xffSIK\0";
        assert_eq!(
            mount_path_from_bytes(bytes),
            Path::new(OsStr::from_bytes(b"/media/carnine/M\xffSIK"))
        );
    }

    #[test]
    fn an_empty_reply_yields_an_empty_path() {
        assert_eq!(mount_path_from_bytes(b""), Path::new(""));
        assert_eq!(mount_path_from_bytes(b"\0"), Path::new(""));
    }
}
