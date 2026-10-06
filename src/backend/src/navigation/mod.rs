//! Navigation: own position, routing and place search for the map page
//! (ADR-021).

pub mod clock;
pub mod location_name;
pub mod nmea;
pub mod places;
pub mod position;
pub mod service;
pub mod track;
pub mod valhalla;

use std::path::Path;

use crate::config::{NavigationConfig, PositionSourceSetting};
use crate::database::Database;
use position::{PositionHub, SourceKind};
use service::NavigationServiceImpl;
use tracing::{error, info, warn};
use track::TrackRecorder;

/// Starts the configured position source and returns the service around it.
/// Must run inside the Tokio runtime (the replay is a task). The media
/// database keeps the track recording switch.
pub fn start(config: &NavigationConfig, database: &Path) -> NavigationServiceImpl {
    let source = match config.position_source {
        PositionSourceSetting::None => SourceKind::None,
        PositionSourceSetting::Serial => SourceKind::Serial,
        PositionSourceSetting::Replay => SourceKind::Replay,
    };
    // A replay that cannot be read leaves no source running. Status says so
    // instead of promising a replay the map page keeps asking for (#100).
    let replay = match (source, &config.replay_file) {
        (SourceKind::Replay, Some(file)) => match position::load_replay(file) {
            Ok(steps) => Some((steps, file)),
            Err(err) => {
                error!(error = %format!("{err:#}"), "position replay not started");
                None
            }
        },
        _ => None,
    };
    let source = match (source, &replay) {
        (SourceKind::Replay, None) => SourceKind::None,
        _ => source,
    };
    let hub = PositionHub::new(source);
    info!(source = ?source, "navigation position source configured");
    let recording = Database::open(database)
        .and_then(|database| database.load_track_recording())
        .unwrap_or_else(|err| {
            warn!(error = %format!("{err:#}"), "track recording switch not readable, off");
            false
        });
    let tracks = TrackRecorder::new(config.track_directory.clone(), recording);
    let status = tracks.status();
    info!(
        available = status.available,
        enabled = status.enabled,
        "track recording configured"
    );
    let mut replay_points = None;
    if let Some((steps, file)) = replay {
        replay_points = Some(position::trace_points(&steps));
        tokio::spawn(position::run_replay(
            hub.clone(),
            steps,
            file.display().to_string(),
            config.replay_loop,
        ));
    } else if let (SourceKind::Serial, Some(device)) = (source, &config.serial_device) {
        position::spawn_serial(
            hub.clone(),
            device.clone(),
            config.serial_baud,
            clock::ClockSetter::new(config.set_system_clock),
            tracks.clone(),
        );
    }
    // Config::validate rejects a source without its path; nothing to start.
    NavigationServiceImpl::new(hub, config.valhalla_url.clone(), config.map_region.clone())
        .with_names_database(config.names_database.clone())
        .with_replay_points(replay_points)
        .with_tracks(tracks, database.to_path_buf())
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;

    use tonic::Request;

    use super::*;
    use crate::carnine::navigation_service_server::NavigationService;
    use crate::carnine::{Empty, GetReplayRouteRequest, PositionSourceKind};

    /// Scratch directory per test; the media database inside stays absent.
    fn scratch(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("carnine-nav-{name}-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn replay_config(file: PathBuf) -> NavigationConfig {
        NavigationConfig {
            position_source: PositionSourceSetting::Replay,
            replay_file: Some(file),
            // Port 9 (discard) on loopback is closed: no router answers.
            valhalla_url: "http://127.0.0.1:9".to_string(),
            ..NavigationConfig::default()
        }
    }

    async fn source_of(service: &NavigationServiceImpl) -> i32 {
        service
            .get_navigation_status(Request::new(Empty {}))
            .await
            .expect("status always answers")
            .into_inner()
            .position_source
    }

    #[tokio::test]
    async fn missing_replay_tour_reports_no_source() {
        let dir = scratch("no-tour");
        let service = start(
            &replay_config(dir.join("GPS-Adnan-Tour.txt")),
            &dir.join("media.sqlite3"),
        );
        assert_eq!(
            source_of(&service).await,
            PositionSourceKind::PositionSourceNone as i32
        );
        let status = service
            .get_replay_route(Request::new(GetReplayRouteRequest { language: None }))
            .await
            .expect_err("no tour loaded");
        assert_eq!(status.code(), tonic::Code::NotFound);
        assert!(
            status.message().contains("no replay tour"),
            "{}",
            status.message()
        );
        std::fs::remove_dir_all(dir).unwrap();
    }

    #[tokio::test]
    async fn loaded_replay_tour_reports_replay_and_offers_its_route() {
        let dir = scratch("tour");
        let tour = dir.join("tour.txt");
        std::fs::write(
            &tour,
            "$GPRMC,141502.000,A,5024.5968,N,00921.8742,E,22.35,184.27,010518,,,A*5C\n",
        )
        .unwrap();
        let service = start(&replay_config(tour), &dir.join("media.sqlite3"));
        assert_eq!(
            source_of(&service).await,
            PositionSourceKind::PositionSourceReplay as i32
        );
        // The tour is there; only the router is missing.
        let status = service
            .get_replay_route(Request::new(GetReplayRouteRequest { language: None }))
            .await
            .expect_err("nothing listens on port 9");
        assert_ne!(status.code(), tonic::Code::NotFound);
        std::fs::remove_dir_all(dir).unwrap();
    }
}
