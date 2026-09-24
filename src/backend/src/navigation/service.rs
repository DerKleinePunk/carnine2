//! gRPC surface of navigation (ADR-021).

use std::pin::Pin;
use std::time::Duration;

use futures_util::StreamExt;
use tokio_stream::wrappers::WatchStream;
use tonic::{Request, Response, Status};
use tracing::info;

use super::position::{Fix, PositionHub, PositionState, SourceKind};
use crate::carnine::navigation_service_server::NavigationService;
use crate::carnine::{
    ComputeRouteRequest, Empty, FixState, GetReplayRouteRequest, LatLon, NavigationStatus,
    PositionFix, PositionSourceKind, Route, SearchPlacesRequest, SearchPlacesResponse,
    ServiceVersion,
};

/// How long the router probe may take before it counts as unavailable. The
/// frontend asks for the status when the map page opens, so this bounds how
/// long that call can hang.
const ROUTER_PROBE_TIMEOUT: Duration = Duration::from_millis(300);

#[derive(Debug, Clone)]
pub struct NavigationServiceImpl {
    positions: PositionHub,
    valhalla_url: String,
    map_region: String,
}

impl NavigationServiceImpl {
    pub fn new(positions: PositionHub, valhalla_url: String, map_region: String) -> Self {
        Self {
            positions,
            valhalla_url,
            map_region,
        }
    }

    /// Whether something accepts connections at the router's address. A full
    /// `/status` request follows once the backend has an HTTP client for the
    /// routing calls themselves.
    async fn router_reachable(&self) -> bool {
        let Some(address) = host_port(&self.valhalla_url) else {
            return false;
        };
        matches!(
            tokio::time::timeout(
                ROUTER_PROBE_TIMEOUT,
                tokio::net::TcpStream::connect(address)
            )
            .await,
            Ok(Ok(_))
        )
    }
}

/// `host:port` of a plain `http://` URL; port 80 when none is given.
fn host_port(url: &str) -> Option<String> {
    let authority = url.strip_prefix("http://")?.split('/').next()?;
    if authority.is_empty() {
        return None;
    }
    Some(if authority.contains(':') {
        authority.to_string()
    } else {
        format!("{authority}:80")
    })
}

fn source_kind(kind: SourceKind) -> PositionSourceKind {
    match kind {
        SourceKind::None => PositionSourceKind::PositionSourceNone,
        SourceKind::Serial => PositionSourceKind::PositionSourceSerial,
        SourceKind::Replay => PositionSourceKind::PositionSourceReplay,
    }
}

fn fix_state(fix: Option<&Fix>) -> FixState {
    match fix {
        Some(fix) if fix.valid => FixState::Fix,
        _ => FixState::NoFix,
    }
}

/// The wire form of a hub state, or `None` before the first sentence.
fn position_fix(state: &PositionState) -> Option<PositionFix> {
    let fix = state.fix.as_ref()?;
    let valid = fix.valid;
    Some(PositionFix {
        fix_state: fix_state(Some(fix)) as i32,
        // Without a fix the coordinates are stale; the contract leaves them unset.
        location: valid.then_some(LatLon {
            latitude: fix.latitude,
            longitude: fix.longitude,
        }),
        heading_degrees: fix.heading_degrees.filter(|_| valid),
        speed_mps: fix.speed_mps.filter(|_| valid),
        accuracy_meters: fix.accuracy_meters.filter(|_| valid),
        timestamp_utc_ms: fix.timestamp_utc_ms,
        source: source_kind(state.source) as i32,
    })
}

#[tonic::async_trait]
impl NavigationService for NavigationServiceImpl {
    type StreamPositionsStream =
        Pin<Box<dyn tokio_stream::Stream<Item = Result<PositionFix, Status>> + Send + 'static>>;

    async fn get_service_version(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<ServiceVersion>, Status> {
        Ok(Response::new(crate::service_version()))
    }

    async fn get_navigation_status(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<NavigationStatus>, Status> {
        let state = self.positions.current();
        Ok(Response::new(NavigationStatus {
            routing_available: self.router_reachable().await,
            position_source: source_kind(state.source) as i32,
            fix_state: fix_state(state.fix.as_ref()) as i32,
            map_region: self.map_region.clone(),
        }))
    }

    async fn search_places(
        &self,
        _request: Request<SearchPlacesRequest>,
    ) -> Result<Response<SearchPlacesResponse>, Status> {
        Err(Status::unimplemented("SearchPlaces is not implemented yet"))
    }

    async fn compute_route(
        &self,
        _request: Request<ComputeRouteRequest>,
    ) -> Result<Response<Route>, Status> {
        Err(Status::unimplemented("ComputeRoute is not implemented yet"))
    }

    async fn get_replay_route(
        &self,
        _request: Request<GetReplayRouteRequest>,
    ) -> Result<Response<Route>, Status> {
        Err(Status::unimplemented(
            "GetReplayRoute is not implemented yet",
        ))
    }

    async fn stream_positions(
        &self,
        _request: Request<Empty>,
    ) -> Result<Response<Self::StreamPositionsStream>, Status> {
        info!("position stream opened");
        // WatchStream yields the current state first, so a client that opens
        // the map mid-drive gets the position at once instead of after a fix.
        let stream = WatchStream::new(self.positions.subscribe())
            .filter_map(|state| async move { position_fix(&state).map(Ok) });
        Ok(Response::new(Box::pin(stream)))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fix(valid: bool) -> Fix {
        Fix {
            valid,
            latitude: 50.41,
            longitude: 9.36,
            heading_degrees: Some(184.0),
            speed_mps: Some(11.5),
            accuracy_meters: Some(6.0),
            timestamp_utc_ms: Some(1_525_184_102_000),
        }
    }

    #[test]
    fn host_port_accepts_plain_http_only() {
        assert_eq!(
            host_port("http://127.0.0.1:8002"),
            Some("127.0.0.1:8002".to_string())
        );
        assert_eq!(
            host_port("http://localhost/route"),
            Some("localhost:80".to_string())
        );
        assert_eq!(host_port("https://127.0.0.1:8002"), None);
        assert_eq!(host_port("http://"), None);
    }

    #[test]
    fn a_valid_fix_goes_out_complete() {
        let state = PositionState {
            source: SourceKind::Replay,
            fix: Some(fix(true)),
        };
        let wire = position_fix(&state).expect("a fix is sent");
        assert_eq!(wire.fix_state, FixState::Fix as i32);
        assert_eq!(wire.source, PositionSourceKind::PositionSourceReplay as i32);
        let location = wire.location.expect("location is set");
        assert_eq!((location.latitude, location.longitude), (50.41, 9.36));
        assert_eq!(wire.heading_degrees, Some(184.0));
    }

    #[test]
    fn no_fix_leaves_location_and_motion_unset() {
        let state = PositionState {
            source: SourceKind::Serial,
            fix: Some(fix(false)),
        };
        let wire = position_fix(&state).expect("the no-fix state is still sent");
        assert_eq!(wire.fix_state, FixState::NoFix as i32);
        assert_eq!(wire.location, None);
        assert_eq!(wire.heading_degrees, None);
        assert_eq!(wire.speed_mps, None);
    }

    #[test]
    fn nothing_is_sent_before_the_first_sentence() {
        let state = PositionState {
            source: SourceKind::None,
            fix: None,
        };
        assert_eq!(position_fix(&state), None);
    }

    #[tokio::test]
    async fn status_reports_an_unreachable_router_and_the_source() {
        // Port 9 (discard) on loopback is closed on any sane test machine.
        let service = NavigationServiceImpl::new(
            PositionHub::new(SourceKind::Replay),
            "http://127.0.0.1:9".to_string(),
            "hessen".to_string(),
        );
        let status = service
            .get_navigation_status(Request::new(Empty {}))
            .await
            .expect("status always answers")
            .into_inner();
        assert!(!status.routing_available);
        assert_eq!(
            status.position_source,
            PositionSourceKind::PositionSourceReplay as i32
        );
        assert_eq!(status.fix_state, FixState::NoFix as i32);
        assert_eq!(status.map_region, "hessen");
    }

    #[tokio::test]
    async fn stream_starts_with_the_current_fix_and_follows_updates() {
        let hub = PositionHub::new(SourceKind::Replay);
        hub.publish(fix(false));
        let service = NavigationServiceImpl::new(
            hub.clone(),
            "http://127.0.0.1:9".to_string(),
            String::new(),
        );
        let mut stream = service
            .stream_positions(Request::new(Empty {}))
            .await
            .expect("stream opens")
            .into_inner();

        let first = stream.next().await.expect("current state").expect("ok");
        assert_eq!(first.fix_state, FixState::NoFix as i32);

        hub.publish(fix(true));
        let second = stream.next().await.expect("update").expect("ok");
        assert_eq!(second.fix_state, FixState::Fix as i32);
    }
}
