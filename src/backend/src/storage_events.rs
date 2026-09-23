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
            .and_then(|value| mount_paths_from_property(value))
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
        for mount_path in mount_points {
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

/// Turns the `MountPoints` property of `org.freedesktop.UDisks2.Filesystem`
/// into paths. The property is an `aay`: one NUL-terminated C string per mount
/// point. `None` means the value was not an array at all, which is different
/// from an array with no entries - the latter is an unmounted volume and the
/// caller mounts it.
fn mount_paths_from_property(value: &zbus::zvariant::Value<'_>) -> Option<Vec<PathBuf>> {
    let entries = value.downcast_ref::<zbus::zvariant::Array>().ok()?;
    Some(
        entries
            .iter()
            .filter_map(|entry| {
                let bytes: Vec<u8> = entry
                    .downcast_ref::<zbus::zvariant::Array>()
                    .ok()?
                    .iter()
                    .filter_map(|byte| byte.downcast_ref::<u8>().ok())
                    .collect();
                Some(mount_path_from_bytes(&bytes))
            })
            .collect(),
    )
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
    use super::{mount_path_from_bytes, mount_paths_from_property};
    use std::ffi::OsStr;
    use std::os::unix::ffi::OsStrExt;
    use std::path::Path;
    use zbus::zvariant::{Array, Value};

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

    /// The property as UDisks2 really hands it over: an `aay` whose single
    /// entry carries the terminator. This is the shape the original bug lived
    /// in - the byte-level helper alone would not have caught it, because the
    /// bug was in how the property was unpacked.
    #[test]
    fn the_udisks2_property_yields_a_path_that_exists_on_disk() {
        let directory = std::env::temp_dir().join("carnine-mount-points-test");
        std::fs::create_dir_all(&directory).expect("test directory should be creatable");
        let mut bytes = directory.as_os_str().as_bytes().to_vec();
        bytes.push(0);
        let property = Value::from(Array::from(vec![bytes]));

        let paths = mount_paths_from_property(&property).expect("an aay should parse");

        assert_eq!(paths, vec![directory.clone()]);
        assert!(
            paths[0].exists(),
            "a mount path taken from UDisks2 has to point at something real"
        );
        let _ = std::fs::remove_dir(&directory);
    }

    #[test]
    fn several_mount_points_all_come_back() {
        let property = Value::from(Array::from(vec![
            b"/media/carnine/MUSIK\0".to_vec(),
            b"/mnt/second\0".to_vec(),
        ]));

        assert_eq!(
            mount_paths_from_property(&property).expect("an aay should parse"),
            vec![Path::new("/media/carnine/MUSIK"), Path::new("/mnt/second")]
        );
    }

    #[test]
    fn an_unmounted_volume_is_an_empty_list_not_a_missing_one() {
        let property = Value::from(Array::from(Vec::<Vec<u8>>::new()));

        assert_eq!(
            mount_paths_from_property(&property),
            Some(Vec::new()),
            "an empty array means \"not mounted\"; the caller mounts it, so it must not look like a parse failure"
        );
    }

    #[test]
    fn a_property_that_is_not_an_array_is_rejected() {
        assert_eq!(mount_paths_from_property(&Value::from(42u32)), None);
    }
}
