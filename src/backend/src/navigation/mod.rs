//! Navigation: own position, routing and place search for the map page
//! (ADR-021).

pub mod nmea;
pub mod position;
pub mod service;

use crate::config::{NavigationConfig, PositionSourceSetting};
use position::{PositionHub, SourceKind};
use service::NavigationServiceImpl;
use tracing::info;

/// Starts the configured position source and returns the service around it.
/// Must run inside the Tokio runtime (the replay is a task).
pub fn start(config: &NavigationConfig) -> NavigationServiceImpl {
    let source = match config.position_source {
        PositionSourceSetting::None => SourceKind::None,
        PositionSourceSetting::Serial => SourceKind::Serial,
        PositionSourceSetting::Replay => SourceKind::Replay,
    };
    let hub = PositionHub::new(source);
    info!(source = ?source, "navigation position source configured");
    match (source, &config.serial_device, &config.replay_file) {
        (SourceKind::Serial, Some(device), _) => {
            position::spawn_serial(hub.clone(), device.clone())
        }
        (SourceKind::Replay, _, Some(file)) => {
            tokio::spawn(position::run_replay(
                hub.clone(),
                file.clone(),
                config.replay_loop,
            ));
        }
        // Config::validate rejects a source without its path; nothing to start.
        _ => {}
    }
    NavigationServiceImpl::new(hub, config.valhalla_url.clone(), config.map_region.clone())
}
