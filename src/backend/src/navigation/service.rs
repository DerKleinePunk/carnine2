//! gRPC surface of navigation (ADR-021).

use std::collections::HashMap;
use std::path::PathBuf;
use std::pin::Pin;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Duration;

use futures_util::StreamExt;
use tokio_stream::wrappers::WatchStream;
use tonic::{Request, Response, Status};
use tracing::{info, warn};

use super::location_name;
use super::places::{self, PlaceRecord};
use super::position::{Fix, PositionHub, PositionState, SourceKind};
use super::track::TrackRecorder;
use super::valhalla::{RouteData, RoutingError, Valhalla};
use crate::carnine::navigation_service_server::NavigationService;
use crate::carnine::{
    ComputeRouteRequest, Empty, FixState, GetLocationNameRequest, GetReplayRouteRequest, LatLon,
    LocationName, Maneuver, NavigationStatus, Place, PlaceType, PositionFix, PositionSourceKind,
    Route, SearchPlacesRequest, SearchPlacesResponse, ServiceVersion, SetTrackRecordingRequest,
};

/// How long the router probe may take before it counts as unavailable. The
/// frontend asks for the status when the map page opens, so this bounds how
/// long that call can hang.
const ROUTER_PROBE_TIMEOUT: Duration = Duration::from_millis(300);

/// Instruction language when the request names none.
const DEFAULT_LANGUAGE: &str = "de-DE";

#[derive(Debug, Clone)]
pub struct NavigationServiceImpl {
    positions: PositionHub,
    valhalla_url: String,
    map_region: String,
    names_database: Option<PathBuf>,
    valhalla: Valhalla,
    /// Valid, deduplicated points of the running replay; `None` without one.
    replay_points: Option<Arc<Vec<(f64, f64)>>>,
    /// Map-matching the whole tour takes seconds, and its answer never
    /// changes; one route per instruction language is kept.
    replay_routes: Arc<tokio::sync::Mutex<HashMap<String, Route>>>,
    next_route_id: Arc<AtomicU64>,
    tracks: TrackRecorder,
    /// Media database that keeps the recording switch; `None` in tests.
    database: Option<PathBuf>,
}

impl NavigationServiceImpl {
    pub fn new(positions: PositionHub, valhalla_url: String, map_region: String) -> Self {
        Self {
            valhalla: Valhalla::new(&valhalla_url),
            positions,
            valhalla_url,
            map_region,
            names_database: None,
            replay_points: None,
            replay_routes: Arc::default(),
            next_route_id: Arc::new(AtomicU64::new(1)),
            tracks: TrackRecorder::new(None, false),
            database: None,
        }
    }

    pub fn with_tracks(mut self, tracks: TrackRecorder, database: PathBuf) -> Self {
        self.tracks = tracks;
        self.database = Some(database);
        self
    }

    async fn status(&self) -> NavigationStatus {
        let state = self.positions.current();
        let tracks = self.tracks.status();
        NavigationStatus {
            routing_available: self.router_reachable().await,
            position_source: source_kind(state.source) as i32,
            fix_state: fix_state(state.fix.as_ref()) as i32,
            map_region: self.map_region.clone(),
            track_recording_available: tracks.available,
            track_recording_enabled: tracks.enabled,
            track_file: tracks
                .file
                .map(|path| path.display().to_string())
                .unwrap_or_default(),
        }
    }

    pub fn with_replay_points(mut self, points: Option<Vec<(f64, f64)>>) -> Self {
        self.replay_points = points.map(Arc::new);
        self
    }

    fn route_message(&self, data: RouteData) -> Route {
        let id = self.next_route_id.fetch_add(1, Ordering::Relaxed);
        Route {
            route_id: format!("route-{id}"),
            geometry: data
                .geometry
                .into_iter()
                .map(|(latitude, longitude)| LatLon {
                    latitude,
                    longitude,
                })
                .collect(),
            distance_meters: data.distance_meters,
            duration_seconds: data.duration_seconds,
            maneuvers: data
                .maneuvers
                .into_iter()
                .map(|maneuver| Maneuver {
                    instruction: maneuver.instruction,
                    length_meters: maneuver.length_meters,
                    time_seconds: maneuver.time_seconds,
                    r#type: maneuver.kind,
                    begin_shape_index: maneuver.begin_shape_index,
                    street_names: maneuver.street_names,
                })
                .collect(),
        }
    }

    pub fn with_names_database(mut self, names_database: Option<PathBuf>) -> Self {
        self.names_database = names_database;
        self
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

fn routing_status(error: RoutingError) -> Status {
    match error {
        RoutingError::Unavailable(message) => Status::unavailable(message),
        RoutingError::NoRoute(message) => Status::not_found(message),
        RoutingError::Invalid(message) => Status::invalid_argument(message),
        RoutingError::Internal(message) => Status::internal(message),
    }
}

/// A usable (lat, lon), or INVALID_ARGUMENT naming the field.
fn coordinate(point: Option<LatLon>, field: &str) -> Result<(f64, f64), Status> {
    let point = point.ok_or_else(|| Status::invalid_argument(format!("{field} is required")))?;
    let valid = point.latitude.is_finite()
        && point.longitude.is_finite()
        && (-90.0..=90.0).contains(&point.latitude)
        && (-180.0..=180.0).contains(&point.longitude);
    if valid {
        Ok((point.latitude, point.longitude))
    } else {
        Err(Status::invalid_argument(format!(
            "{field} is not a WGS84 coordinate: {}, {}",
            point.latitude, point.longitude
        )))
    }
}

/// The BCP-47 tag for Valhalla, defaulting to German. Only the shape is
/// checked (letters, digits, hyphens); Valhalla falls back to English for a
/// language it does not know.
fn language(requested: Option<String>) -> Result<String, Status> {
    let Some(tag) = requested.filter(|tag| !tag.trim().is_empty()) else {
        return Ok(DEFAULT_LANGUAGE.to_string());
    };
    let tag = tag.trim();
    let well_formed = tag.len() <= 35
        && tag.split('-').all(|part| {
            !part.is_empty() && part.len() <= 8 && part.chars().all(|c| c.is_ascii_alphanumeric())
        });
    if well_formed {
        Ok(tag.to_string())
    } else {
        Err(Status::invalid_argument(format!(
            "language is not a BCP-47 tag: {tag}"
        )))
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

fn place_type(kind: &str) -> PlaceType {
    match kind {
        "place" => PlaceType::Place,
        "poi" => PlaceType::Poi,
        "mountain_peak" => PlaceType::MountainPeak,
        "water_name" => PlaceType::WaterName,
        "transportation_name" => PlaceType::TransportationName,
        _ => PlaceType::Unspecified,
    }
}

fn place(record: PlaceRecord) -> Place {
    Place {
        location: Some(LatLon {
            latitude: record.latitude,
            longitude: record.longitude,
        }),
        zoom: record.zoom,
        r#type: place_type(&record.kind) as i32,
        detail: record.detail.filter(|detail| !detail.is_empty()),
        area: record.area.filter(|area| !area.is_empty()),
        name: record.name,
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
        Ok(Response::new(self.status().await))
    }

    async fn set_track_recording(
        &self,
        request: Request<SetTrackRecordingRequest>,
    ) -> Result<Response<NavigationStatus>, Status> {
        let enabled = request.into_inner().enabled;
        self.tracks
            .set_enabled(enabled)
            .map_err(|err| Status::failed_precondition(err.to_string()))?;
        info!(enabled, "track recording switched");
        if let Some(database) = &self.database {
            // Live already; a failed save only means the next start forgets it.
            if let Err(err) = crate::database::Database::open(database)
                .and_then(|database| database.save_track_recording(enabled))
            {
                warn!(error = %format!("{err:#}"), "track recording switch not saved");
            }
        }
        Ok(Response::new(self.status().await))
    }

    async fn search_places(
        &self,
        request: Request<SearchPlacesRequest>,
    ) -> Result<Response<SearchPlacesResponse>, Status> {
        let request = request.into_inner();
        let Some(database) = self.names_database.clone() else {
            return Err(Status::unavailable("no names database configured"));
        };
        let near = request
            .near
            .map(|near| (near.latitude, near.longitude))
            .filter(|(lat, lon)| lat.is_finite() && lon.is_finite());
        let query = request.query;
        let limit = usize::try_from(request.limit).unwrap_or(places::DEFAULT_LIMIT);
        let hits =
            tokio::task::spawn_blocking(move || places::search(&database, &query, limit, near))
                .await
                .map_err(|err| Status::internal(format!("place search panicked: {err}")))?
                .map_err(|err| {
                    warn!(error = %format!("{err:#}"), "place search failed");
                    Status::unavailable(format!("place search failed: {err:#}"))
                })?;
        Ok(Response::new(SearchPlacesResponse {
            places: hits.into_iter().map(place).collect(),
        }))
    }

    async fn get_location_name(
        &self,
        request: Request<GetLocationNameRequest>,
    ) -> Result<Response<LocationName>, Status> {
        let Some(database) = self.names_database.clone() else {
            return Err(Status::unavailable("no names database configured"));
        };
        let (lat, lon) = match request.into_inner().position {
            Some(position) => coordinate(Some(position), "position")?,
            None => match self.positions.current().fix {
                Some(fix) if fix.valid => (fix.latitude, fix.longitude),
                _ => {
                    return Err(Status::failed_precondition(
                        "no position given and no GPS fix",
                    ))
                }
            },
        };
        let name = tokio::task::spawn_blocking(move || location_name::name_at(&database, lat, lon))
            .await
            .map_err(|err| Status::internal(format!("location lookup panicked: {err}")))?
            .map_err(|err| {
                warn!(error = %format!("{err:#}"), "location lookup failed");
                Status::unavailable(format!("location lookup failed: {err:#}"))
            })?
            .unwrap_or_default();
        Ok(Response::new(LocationName {
            street: name.street,
            locality: name.locality,
            district: name.district,
        }))
    }

    async fn compute_route(
        &self,
        request: Request<ComputeRouteRequest>,
    ) -> Result<Response<Route>, Status> {
        let request = request.into_inner();
        let destination = coordinate(request.destination, "destination")?;
        let origin = match request.origin {
            Some(origin) => coordinate(Some(origin), "origin")?,
            None => match self.positions.current().fix {
                Some(fix) if fix.valid => (fix.latitude, fix.longitude),
                _ => {
                    return Err(Status::failed_precondition(
                        "no origin given and no GPS fix to start from",
                    ))
                }
            },
        };
        let language = language(request.language)?;
        info!(?origin, ?destination, %language, "route requested");
        let data = self
            .valhalla
            .route(origin, destination, &language)
            .await
            .map_err(|err| {
                warn!(error = ?err, "route failed");
                routing_status(err)
            })?;
        let route = self.route_message(data);
        info!(
            route_id = %route.route_id,
            distance_meters = route.distance_meters,
            maneuvers = route.maneuvers.len(),
            "route computed"
        );
        Ok(Response::new(route))
    }

    async fn get_replay_route(
        &self,
        request: Request<GetReplayRouteRequest>,
    ) -> Result<Response<Route>, Status> {
        let Some(points) = self.replay_points.clone() else {
            return Err(Status::not_found("the position source is not a replay"));
        };
        let language = language(request.into_inner().language)?;
        // Held across the Valhalla call, so a second caller waits for the
        // first result instead of starting another multi-second match.
        let mut cache = self.replay_routes.lock().await;
        if let Some(route) = cache.get(&language) {
            return Ok(Response::new(route.clone()));
        }
        info!(points = points.len(), %language, "map-matching the replay tour");
        let data = self
            .valhalla
            .route_along_trace(&points, &language)
            .await
            .map_err(|err| {
                warn!(error = ?err, "replay route failed");
                routing_status(err)
            })?;
        let route = self.route_message(data);
        info!(
            route_id = %route.route_id,
            distance_meters = route.distance_meters,
            maneuvers = route.maneuvers.len(),
            "replay route computed"
        );
        cache.insert(language, route.clone());
        Ok(Response::new(route))
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

    fn service(hub: PositionHub) -> NavigationServiceImpl {
        NavigationServiceImpl::new(hub, "http://127.0.0.1:9".to_string(), String::new())
    }

    #[tokio::test]
    async fn route_without_origin_needs_a_fix() {
        let status = service(PositionHub::new(SourceKind::Serial))
            .compute_route(Request::new(ComputeRouteRequest {
                origin: None,
                destination: Some(LatLon {
                    latitude: 50.75,
                    longitude: 9.27,
                }),
                language: None,
            }))
            .await
            .expect_err("no fix yet");
        assert_eq!(status.code(), tonic::Code::FailedPrecondition);
    }

    #[tokio::test]
    async fn route_checks_coordinates_and_language_before_asking_valhalla() {
        let service = service(PositionHub::new(SourceKind::None));
        let request = |destination: Option<LatLon>, language: Option<&str>| ComputeRouteRequest {
            origin: Some(LatLon {
                latitude: 50.41,
                longitude: 9.36,
            }),
            destination,
            language: language.map(str::to_string),
        };
        for bad in [
            request(None, None),
            request(
                Some(LatLon {
                    latitude: 95.0,
                    longitude: 9.0,
                }),
                None,
            ),
            request(
                Some(LatLon {
                    latitude: 50.0,
                    longitude: f64::NAN,
                }),
                None,
            ),
            request(
                Some(LatLon {
                    latitude: 50.0,
                    longitude: 9.0,
                }),
                Some("de_DE; drop"),
            ),
        ] {
            let status = service
                .compute_route(Request::new(bad))
                .await
                .expect_err("rejected up front");
            assert_eq!(status.code(), tonic::Code::InvalidArgument);
        }
    }

    #[tokio::test]
    async fn route_with_the_router_down_is_unavailable() {
        let status = service(PositionHub::new(SourceKind::None))
            .compute_route(Request::new(ComputeRouteRequest {
                origin: Some(LatLon {
                    latitude: 50.41,
                    longitude: 9.36,
                }),
                destination: Some(LatLon {
                    latitude: 50.75,
                    longitude: 9.27,
                }),
                language: Some("en-US".to_string()),
            }))
            .await
            .expect_err("nothing listens on port 9");
        assert_eq!(status.code(), tonic::Code::Unavailable);
    }

    #[tokio::test]
    async fn replay_route_needs_a_replay() {
        let status = service(PositionHub::new(SourceKind::Serial))
            .get_replay_route(Request::new(GetReplayRouteRequest { language: None }))
            .await
            .expect_err("no replay running");
        assert_eq!(status.code(), tonic::Code::NotFound);
    }

    #[test]
    fn language_defaults_to_german_and_accepts_tags() {
        assert_eq!(language(None).unwrap(), "de-DE");
        assert_eq!(language(Some("  ".to_string())).unwrap(), "de-DE");
        assert_eq!(
            language(Some("zh-Hans-CN".to_string())).unwrap(),
            "zh-Hans-CN"
        );
        assert!(language(Some("de--DE".to_string())).is_err());
    }

    #[tokio::test]
    async fn search_without_a_names_database_is_unavailable() {
        let service = NavigationServiceImpl::new(
            PositionHub::new(SourceKind::None),
            "http://127.0.0.1:9".to_string(),
            String::new(),
        );
        let status = service
            .search_places(Request::new(SearchPlacesRequest {
                query: "Alsfeld".to_string(),
                limit: 0,
                near: None,
            }))
            .await
            .expect_err("no database configured");
        assert_eq!(status.code(), tonic::Code::Unavailable);
    }

    #[test]
    fn records_map_to_places_with_their_type() {
        let wire = place(PlaceRecord {
            name: "Alsfeld".to_string(),
            latitude: 50.75,
            longitude: 9.27,
            zoom: 12,
            kind: "place".to_string(),
            detail: Some(String::new()),
            area: Some("Vogelsbergkreis".to_string()),
        });
        assert_eq!(wire.r#type, PlaceType::Place as i32);
        assert_eq!(wire.detail, None, "an empty detail is left out");
        assert_eq!(wire.zoom, 12);
        assert_eq!(wire.area.as_deref(), Some("Vogelsbergkreis"));
    }

    #[tokio::test]
    async fn location_name_needs_a_database_and_a_position() {
        let service = NavigationServiceImpl::new(
            PositionHub::new(SourceKind::None),
            "http://127.0.0.1:9".to_string(),
            String::new(),
        );
        let status = service
            .get_location_name(Request::new(GetLocationNameRequest { position: None }))
            .await
            .expect_err("no database configured");
        assert_eq!(status.code(), tonic::Code::Unavailable);

        let db = super::places::tests::TempDb::new();
        rusqlite::Connection::open(&db.path)
            .expect("create db")
            .execute_batch("CREATE TABLE names_meta (id INTEGER PRIMARY KEY)")
            .expect("schema");
        let service = service.with_names_database(Some(db.path.clone()));
        let status = service
            .get_location_name(Request::new(GetLocationNameRequest { position: None }))
            .await
            .expect_err("no fix");
        assert_eq!(status.code(), tonic::Code::FailedPrecondition);
        let name = service
            .get_location_name(Request::new(GetLocationNameRequest {
                position: Some(LatLon {
                    latitude: 50.75,
                    longitude: 9.27,
                }),
            }))
            .await
            .expect("an old database answers with nothing")
            .into_inner();
        assert_eq!(name, LocationName::default());
    }

    #[tokio::test]
    async fn track_recording_needs_a_directory_and_is_kept_in_the_database() {
        let service = NavigationServiceImpl::new(
            PositionHub::new(SourceKind::Serial),
            "http://127.0.0.1:9".to_string(),
            String::new(),
        );
        let status = service
            .set_track_recording(Request::new(SetTrackRecordingRequest { enabled: true }))
            .await
            .expect_err("no track directory configured");
        assert_eq!(status.code(), tonic::Code::FailedPrecondition);

        let base = std::env::temp_dir().join(format!("carnine-track-rpc-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&base);
        std::fs::create_dir_all(&base).unwrap();
        let database = base.join("media.sqlite3");
        let service = service.with_tracks(
            TrackRecorder::new(Some(base.join("tracks")), false),
            database.clone(),
        );
        let status = service
            .set_track_recording(Request::new(SetTrackRecordingRequest { enabled: true }))
            .await
            .expect("recording switches on")
            .into_inner();
        assert!(status.track_recording_available);
        assert!(status.track_recording_enabled);
        assert_eq!(
            status.track_file, "",
            "nothing written before the first line"
        );
        assert!(crate::database::Database::open(&database)
            .unwrap()
            .load_track_recording()
            .unwrap());
        std::fs::remove_dir_all(base).unwrap();
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
