use std::collections::{HashMap, HashSet};
use std::ffi::OsStr;
use std::os::unix::ffi::OsStrExt;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use anyhow::Result;
use futures_util::{Stream, StreamExt};
use tracing::{debug, error, info, warn};
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
    let messages = MessageStream::for_match_rule(rule, &connection, Some(32)).await?;
    let mut changes = Box::pin(messages.filter(|message| {
        let relevant = message.as_ref().map_or(true, is_volume_change);
        async move { relevant }
    }));
    let mut volumes = KnownVolumes::default();
    inspect_and_report(&connection, &media_service, &mut volumes).await;
    // Plugging a stick in sends a cascade of signals over several seconds -
    // mounting it sends more. Each burst ends in one inspection.
    while let Some(signals) = settle(&mut changes, QUIET_TIME, MAX_SETTLE_TIME).await {
        if let Some(error) = signals.error {
            return Err(error.into());
        }
        info!(
            signals = signals.count,
            "udisks2 storage events settled; inspecting music volumes"
        );
        inspect_and_report(&connection, &media_service, &mut volumes).await;
    }

    Ok(())
}

/// How long UDisks2 has to stay silent before the volumes are looked at.
const QUIET_TIME: Duration = Duration::from_millis(500);
/// A burst that never goes quiet is still looked at after this long.
const MAX_SETTLE_TIME: Duration = Duration::from_secs(5);

fn is_volume_change(message: &zbus::Message) -> bool {
    let header = message.header();
    header.primary().msg_type() == Type::Signal
        && header.member().is_some_and(|member| {
            matches!(
                member.as_str(),
                "InterfacesAdded" | "InterfacesRemoved" | "PropertiesChanged"
            )
        })
}

/// One burst of items from a stream.
#[derive(Debug)]
struct Burst<E> {
    count: usize,
    /// The stream failed; the burst ends there.
    error: Option<E>,
}

/// Waits for the next item, then keeps taking items until none arrives for
/// `quiet` or `max` has passed since the first. `None` once the stream ends
/// with nothing pending.
async fn settle<S, T, E>(stream: &mut S, quiet: Duration, max: Duration) -> Option<Burst<E>>
where
    S: Stream<Item = std::result::Result<T, E>> + Unpin,
{
    let mut burst = Burst {
        count: 0,
        error: None,
    };
    match stream.next().await? {
        Ok(_) => burst.count = 1,
        Err(error) => {
            burst.error = Some(error);
            return Some(burst);
        }
    }
    let deadline = tokio::time::Instant::now() + max;
    loop {
        let wait = quiet.min(deadline.saturating_duration_since(tokio::time::Instant::now()));
        match tokio::time::timeout(wait, stream.next()).await {
            Ok(Some(Ok(_))) => burst.count += 1,
            Ok(Some(Err(error))) => {
                burst.error = Some(error);
                return Some(burst);
            }
            // Quiet, out of time, or the stream ended: the burst is complete.
            Ok(None) | Err(_) => return Some(burst),
        }
    }
}

/// The MUSIK volumes seen mounted at the last inspection, by mount path.
#[derive(Debug, Default)]
struct KnownVolumes {
    mounted: HashSet<PathBuf>,
}

/// What changed between two inspections.
#[derive(Debug, Default, PartialEq, Eq)]
struct VolumeChanges {
    /// Newly mounted, with their label: to be scanned.
    added: Vec<(String, PathBuf)>,
    /// Gone since the last inspection.
    removed: Vec<PathBuf>,
}

impl KnownVolumes {
    /// A volume that stays mounted is not scanned again: pulling a stick and
    /// putting it back within one burst leaves it where it was, and the offer
    /// the UI already shows stands.
    fn update(&mut self, present: Vec<(String, PathBuf)>) -> VolumeChanges {
        let now: HashSet<PathBuf> = present.iter().map(|(_, path)| path.clone()).collect();
        let mut removed: Vec<PathBuf> = self.mounted.difference(&now).cloned().collect();
        removed.sort();
        let added = present
            .into_iter()
            .filter(|(_, path)| !self.mounted.contains(path))
            .collect();
        self.mounted = now;
        VolumeChanges { added, removed }
    }
}

async fn inspect_and_report(
    connection: &Connection,
    media_service: &MediaServiceImpl,
    volumes: &mut KnownVolumes,
) {
    let present = match mounted_music_volumes(connection).await {
        Ok(present) => present,
        Err(error) => {
            error!(%error, "music volume inspection failed");
            return;
        }
    };
    let changes = volumes.update(present);
    if changes.added.is_empty() && changes.removed.is_empty() {
        debug!("music volumes unchanged");
    }
    for path in changes.removed {
        media_service.music_volume_gone(&path);
    }
    for (label, path) in changes.added {
        if let Err(error) = media_service.discover_music_volume(label, path.clone()) {
            error!(%error, path = %path.display(), "music volume scan failed");
        }
    }
}

/// Lists the mounted MUSIK volumes with their label, and asks UDisks2 to
/// mount the ones that are not; those show up at a later inspection.
async fn mounted_music_volumes(connection: &Connection) -> Result<Vec<(String, PathBuf)>> {
    let manager = ObjectManagerProxy::builder(connection)
        .destination("org.freedesktop.UDisks2")?
        .path("/org/freedesktop/UDisks2")?
        .build()
        .await?;
    let objects = manager.get_managed_objects().await?;
    let mut present_volumes = Vec::new();
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
        present_volumes.extend(
            mount_points
                .into_iter()
                .map(|mount_path| (label.clone(), mount_path)),
        );
    }
    Ok(present_volumes)
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
    use super::{
        mount_path_from_bytes, mount_paths_from_property, settle, KnownVolumes, VolumeChanges,
    };
    use std::ffi::OsStr;
    use std::os::unix::ffi::OsStrExt;
    use std::path::{Path, PathBuf};
    use std::time::Duration;
    use tokio::sync::mpsc;
    use tokio_stream::wrappers::UnboundedReceiverStream;
    use zbus::zvariant::{Array, Value};

    const QUIET: Duration = Duration::from_millis(500);
    const MAX: Duration = Duration::from_secs(5);

    /// A stream fed by a task that sends `Ok(())` after each delay in turn.
    fn signals_after(delays_ms: &[u64]) -> UnboundedReceiverStream<Result<(), &'static str>> {
        let (sender, receiver) = mpsc::unbounded_channel();
        let delays = delays_ms.to_vec();
        tokio::spawn(async move {
            for delay in delays {
                tokio::time::sleep(Duration::from_millis(delay)).await;
                if sender.send(Ok(())).is_err() {
                    return;
                }
            }
            // Keeps the stream open, the way the D-Bus stream stays open.
            tokio::time::sleep(Duration::from_secs(3600)).await;
        });
        UnboundedReceiverStream::new(receiver)
    }

    fn musik(path: &str) -> (String, PathBuf) {
        ("MUSIK".to_string(), PathBuf::from(path))
    }

    /// The cascade from issue #25: one pull and plug, eight signals within
    /// about seven seconds, the last after a longer pause for the mount.
    #[tokio::test(start_paused = true)]
    async fn a_cascade_of_signals_ends_in_one_burst() {
        let mut stream = signals_after(&[0, 14, 15, 30, 200, 100, 300]);
        let started = tokio::time::Instant::now();

        let burst = settle(&mut stream, QUIET, MAX).await.expect("a burst");

        assert_eq!(burst.count, 7);
        assert!(burst.error.is_none());
        // The last signal came at 659 ms, then 500 ms of quiet.
        assert_eq!(started.elapsed(), Duration::from_millis(1159));
    }

    #[tokio::test(start_paused = true)]
    async fn signals_apart_by_more_than_the_quiet_time_make_two_bursts() {
        let mut stream = signals_after(&[0, 100, 2000, 50]);

        assert_eq!(settle(&mut stream, QUIET, MAX).await.unwrap().count, 2);
        assert_eq!(settle(&mut stream, QUIET, MAX).await.unwrap().count, 2);
    }

    #[tokio::test(start_paused = true)]
    async fn a_burst_that_never_goes_quiet_ends_after_the_maximum() {
        let mut stream = signals_after(&[400; 40]);
        let started = tokio::time::Instant::now();

        let burst = settle(&mut stream, QUIET, MAX).await.unwrap();

        // First at 400 ms, then every 400 ms until 5 s after the first.
        assert_eq!(burst.count, 13);
        assert_eq!(started.elapsed(), Duration::from_millis(5400));
    }

    #[tokio::test(start_paused = true)]
    async fn a_failing_stream_ends_the_burst_with_its_error() {
        let (sender, receiver) = mpsc::unbounded_channel();
        sender.send(Ok(())).unwrap();
        sender.send(Err("connection lost")).unwrap();
        let mut stream = UnboundedReceiverStream::new(receiver);

        let burst = settle(&mut stream, QUIET, MAX).await.unwrap();

        assert_eq!(burst.count, 1);
        assert_eq!(burst.error, Some("connection lost"));
    }

    #[tokio::test(start_paused = true)]
    async fn an_ended_stream_gives_no_burst() {
        let (sender, receiver) = mpsc::unbounded_channel::<Result<(), ()>>();
        drop(sender);
        let mut stream = UnboundedReceiverStream::new(receiver);

        assert!(settle(&mut stream, QUIET, MAX).await.is_none());
    }

    #[test]
    fn a_new_volume_is_added_once() {
        let mut volumes = KnownVolumes::default();

        assert_eq!(
            volumes.update(vec![musik("/media/carnine/MUSIK")]),
            VolumeChanges {
                added: vec![musik("/media/carnine/MUSIK")],
                removed: Vec::new(),
            }
        );
        assert_eq!(
            volumes.update(vec![musik("/media/carnine/MUSIK")]),
            VolumeChanges::default(),
            "a volume that stays mounted is not scanned again"
        );
    }

    #[test]
    fn a_pulled_volume_is_removed_and_comes_back_as_new() {
        let mut volumes = KnownVolumes::default();
        volumes.update(vec![musik("/media/carnine/MUSIK")]);

        assert_eq!(
            volumes.update(Vec::new()),
            VolumeChanges {
                added: Vec::new(),
                removed: vec![PathBuf::from("/media/carnine/MUSIK")],
            }
        );
        assert_eq!(
            volumes.update(vec![musik("/media/carnine/MUSIK")]).added,
            vec![musik("/media/carnine/MUSIK")]
        );
    }

    #[test]
    fn one_volume_going_leaves_the_other_alone() {
        let mut volumes = KnownVolumes::default();
        volumes.update(vec![
            musik("/media/carnine/MUSIK"),
            musik("/media/carnine/MUSIK1"),
        ]);

        assert_eq!(
            volumes.update(vec![musik("/media/carnine/MUSIK1")]),
            VolumeChanges {
                added: Vec::new(),
                removed: vec![PathBuf::from("/media/carnine/MUSIK")],
            }
        );
    }

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
