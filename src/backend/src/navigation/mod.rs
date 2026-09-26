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
    match (source, &config.serial_device, &config.replay_file) {
        (SourceKind::Serial, Some(device), _) => position::spawn_serial(
            hub.clone(),
            device.clone(),
            config.serial_baud,
            clock::ClockSetter::new(config.set_system_clock),
            tracks.clone(),
        ),
        (SourceKind::Replay, _, Some(file)) => match position::load_replay(file) {
            Ok(steps) => {
                replay_points = Some(position::trace_points(&steps));
                tokio::spawn(position::run_replay(
                    hub.clone(),
                    steps,
                    file.display().to_string(),
                    config.replay_loop,
                ));
            }
            // The service still runs: status reports the replay source without
            // a fix, which is what the stand shows until the file is fixed.
            Err(err) => error!(error = %format!("{err:#}"), "position replay not started"),
        },
        // Config::validate rejects a source without its path; nothing to start.
        _ => {}
    }
    NavigationServiceImpl::new(hub, config.valhalla_url.clone(), config.map_region.clone())
        .with_names_database(config.names_database.clone())
        .with_replay_points(replay_points)
        .with_tracks(tracks, database.to_path_buf())
}
