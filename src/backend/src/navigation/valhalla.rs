//! Routing against the local Valhalla service: `/route` between two points and
//! `/trace_route` to map-match a recorded tour. Both answer with the same trip
//! format, parsed here into [`RouteData`].

use std::time::Duration;

use bytes::Bytes;
use http_body_util::{BodyExt, Full};
use hyper::header::CONTENT_TYPE;
use hyper::{Request, StatusCode};
use hyper_util::client::legacy::connect::HttpConnector;
use hyper_util::client::legacy::Client;
use hyper_util::rt::TokioExecutor;
use serde_json::{json, Value};

/// Upper bound for one routing call. A cross-Hessen route takes Valhalla well
/// under a second on the Pi 4; map-matching a 50-minute tour takes longer.
const REQUEST_TIMEOUT: Duration = Duration::from_secs(30);
/// Valhalla runs on this machine; a connect that takes longer means it is not
/// there, and the caller should hear that at once rather than after
/// [`REQUEST_TIMEOUT`].
const CONNECT_TIMEOUT: Duration = Duration::from_secs(2);

/// Valhalla's shapes are encoded polylines with six decimal places.
const POLYLINE_PRECISION: f64 = 1e6;

/// A replay tour is split where it comes closer than this to its own earlier
/// way ...
const OVERLAP_RADIUS_METERS: f64 = 25.0;
/// ... that lies more than this far back along the tour. A bend or a stop at
/// the lights stays in one piece; the turning point of an out-and-back drive
/// does not.
const OVERLAP_MIN_PATH_GAP_METERS: f64 = 300.0;

/// Valhalla maneuver types for "you have arrived" (straight, right, left).
const ARRIVAL_TYPES: [u32; 3] = [4, 5, 6];

/// Valhalla error codes that mean "these points cannot be connected", as
/// opposed to a malformed request: 171 no suitable edges near a location,
/// 442 no path found, 443 exact route match failed, 444 map-match failed.
const NO_ROUTE_ERROR_CODES: [i64; 4] = [171, 442, 443, 444];

#[derive(Debug, Clone, PartialEq)]
pub struct ManeuverData {
    pub instruction: String,
    pub length_meters: f64,
    pub time_seconds: f64,
    pub kind: u32,
    pub begin_shape_index: u32,
    pub street_names: Vec<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct RouteData {
    pub geometry: Vec<(f64, f64)>,
    pub distance_meters: f64,
    pub duration_seconds: f64,
    pub maneuvers: Vec<ManeuverData>,
}

/// Why a routing call failed, mapped 1:1 onto the service's status codes.
#[derive(Debug, Clone, PartialEq)]
pub enum RoutingError {
    /// Router down or not answering.
    Unavailable(String),
    /// Valid request, but no route between the points.
    NoRoute(String),
    /// Valhalla rejected the request itself.
    Invalid(String),
    /// Anything else: an answer we cannot read.
    Internal(String),
}

#[derive(Debug, Clone)]
pub struct Valhalla {
    base_url: String,
    client: Client<HttpConnector, Full<Bytes>>,
}

impl Valhalla {
    pub fn new(base_url: &str) -> Self {
        Self {
            base_url: base_url.trim_end_matches('/').to_string(),
            client: {
                let mut connector = HttpConnector::new();
                connector.set_connect_timeout(Some(CONNECT_TIMEOUT));
                Client::builder(TokioExecutor::new()).build(connector)
            },
        }
    }

    pub async fn route(
        &self,
        origin: (f64, f64),
        destination: (f64, f64),
        language: &str,
    ) -> Result<RouteData, RoutingError> {
        let body = json!({
            "locations": [
                {"lat": origin.0, "lon": origin.1},
                {"lat": destination.0, "lon": destination.1},
            ],
            "costing": "auto",
            "directions_options": {"units": "kilometers", "language": language},
        });
        self.trip("route", body).await
    }

    /// Map-matches `points` onto the road network and returns the driven way
    /// as a route. Consecutive duplicates (standstill) must be removed first.
    pub async fn trace_route(
        &self,
        points: &[(f64, f64)],
        language: &str,
    ) -> Result<RouteData, RoutingError> {
        let shape: Vec<Value> = points
            .iter()
            .map(|(lat, lon)| json!({"lat": lat, "lon": lon}))
            .collect();
        let body = json!({
            "shape": shape,
            "costing": "auto",
            "shape_match": "map_snap",
            "directions_options": {"units": "kilometers", "language": language},
        });
        self.trip("trace_route", body).await
    }

    /// Map-matches a whole recorded tour. `/trace_route` matches a trace that
    /// drives its own way again only in part (the 45 km out-and-back demo tour
    /// came back as 22.7 km), so the tour is split at such overlaps, each
    /// piece matched on its own and the pieces joined again. Same approach as
    /// `routeAlongTrace` in the map library.
    pub async fn route_along_trace(
        &self,
        points: &[(f64, f64)],
        language: &str,
    ) -> Result<RouteData, RoutingError> {
        let split = split_trace_at_overlaps(points);
        tracing::info!(
            pieces = split.len(),
            points = ?split.iter().map(|piece| piece.len()).collect::<Vec<_>>(),
            "tour split for map-matching"
        );
        let mut pieces = Vec::new();
        for piece in split {
            pieces.push(self.trace_route(piece, language).await?);
        }
        Ok(join_routes(pieces))
    }

    async fn trip(&self, action: &str, body: Value) -> Result<RouteData, RoutingError> {
        let request = Request::post(format!("{}/{action}", self.base_url))
            .header(CONTENT_TYPE, "application/json")
            .body(Full::new(Bytes::from(body.to_string())))
            .map_err(|err| RoutingError::Internal(format!("building request: {err}")))?;
        let response = tokio::time::timeout(REQUEST_TIMEOUT, self.client.request(request))
            .await
            .map_err(|_| RoutingError::Unavailable(format!("Valhalla /{action} timed out")))?
            .map_err(|err| RoutingError::Unavailable(format!("Valhalla unreachable: {err}")))?;
        let status = response.status();
        let bytes = response
            .into_body()
            .collect()
            .await
            .map_err(|err| RoutingError::Unavailable(format!("reading Valhalla answer: {err}")))?
            .to_bytes();
        let answer: Value = serde_json::from_slice(&bytes).map_err(|err| {
            RoutingError::Internal(format!("Valhalla answered {status} with no JSON: {err}"))
        })?;
        if status != StatusCode::OK {
            return Err(error_from_answer(status, &answer));
        }
        parse_trip(&answer)
    }
}

fn error_from_answer(status: StatusCode, answer: &Value) -> RoutingError {
    let code = answer["error_code"].as_i64().unwrap_or_default();
    let message = format!(
        "Valhalla {status}: {} (error_code {code})",
        answer["error"].as_str().unwrap_or("no message")
    );
    if NO_ROUTE_ERROR_CODES.contains(&code) {
        RoutingError::NoRoute(message)
    } else if status.is_client_error() {
        RoutingError::Invalid(message)
    } else {
        RoutingError::Unavailable(message)
    }
}

/// Reads `trip` from a `/route` or `/trace_route` answer. Legs are joined into
/// one geometry; each leg repeats the previous leg's last point, which is
/// dropped, and maneuver indices are shifted so they stay valid across legs.
pub fn parse_trip(answer: &Value) -> Result<RouteData, RoutingError> {
    let trip = &answer["trip"];
    let legs = trip["legs"]
        .as_array()
        .filter(|legs| !legs.is_empty())
        .ok_or_else(|| RoutingError::Internal("Valhalla trip has no legs".to_string()))?;
    let mut geometry: Vec<(f64, f64)> = Vec::new();
    let mut maneuvers = Vec::new();
    for leg in legs {
        let shape = leg["shape"]
            .as_str()
            .ok_or_else(|| RoutingError::Internal("Valhalla leg has no shape".to_string()))?;
        let points = decode_polyline(shape, POLYLINE_PRECISION).ok_or_else(|| {
            RoutingError::Internal("Valhalla shape is not a polyline".to_string())
        })?;
        let (offset, skip) = if geometry.is_empty() {
            (0, 0)
        } else {
            (geometry.len() - 1, 1)
        };
        geometry.extend(points.into_iter().skip(skip));
        for maneuver in leg["maneuvers"].as_array().into_iter().flatten() {
            let index = maneuver["begin_shape_index"].as_u64().unwrap_or_default() as usize;
            maneuvers.push(ManeuverData {
                instruction: maneuver["instruction"]
                    .as_str()
                    .unwrap_or_default()
                    .to_string(),
                length_meters: maneuver["length"].as_f64().unwrap_or_default() * 1000.0,
                time_seconds: maneuver["time"].as_f64().unwrap_or_default(),
                kind: maneuver["type"].as_u64().unwrap_or_default() as u32,
                begin_shape_index: u32::try_from(index + offset).unwrap_or(u32::MAX),
                street_names: maneuver["street_names"]
                    .as_array()
                    .into_iter()
                    .flatten()
                    .filter_map(|name| name.as_str().map(str::to_string))
                    .collect(),
            });
        }
    }
    Ok(RouteData {
        geometry,
        // Requested in kilometres; the contract is SI.
        distance_meters: trip["summary"]["length"].as_f64().unwrap_or_default() * 1000.0,
        duration_seconds: trip["summary"]["time"].as_f64().unwrap_or_default(),
        maneuvers,
    })
}

/// Splits `trace` where it drives its own earlier way again: as soon as a
/// point lies closer than [`OVERLAP_RADIUS_METERS`] to a point of the same
/// piece more than [`OVERLAP_MIN_PATH_GAP_METERS`] back along the way.
/// Neighbouring pieces share one point.
pub fn split_trace_at_overlaps(trace: &[(f64, f64)]) -> Vec<&[(f64, f64)]> {
    if trace.len() < 3 {
        return vec![trace];
    }
    let mut path = vec![0.0; trace.len()];
    for i in 1..trace.len() {
        path[i] = path[i - 1] + flat_meters(trace[i - 1], trace[i]);
    }
    let mut pieces = Vec::new();
    let mut start = 0;
    for i in 1..trace.len() {
        for j in start..i {
            // Path distance only shrinks from here on.
            if path[i] - path[j] <= OVERLAP_MIN_PATH_GAP_METERS {
                break;
            }
            if flat_meters(trace[i], trace[j]) < OVERLAP_RADIUS_METERS {
                pieces.push(&trace[start..i]);
                start = i - 1;
                break;
            }
        }
    }
    pieces.push(&trace[start..]);
    pieces
}

/// Equirectangular distance: exact enough for points a few kilometres apart
/// and much cheaper than haversine, which would run millions of times here.
fn flat_meters(a: (f64, f64), b: (f64, f64)) -> f64 {
    const METERS_PER_DEGREE: f64 = 111_319.49;
    let dx = (b.1 - a.1) * a.0.to_radians().cos() * METERS_PER_DEGREE;
    let dy = (b.0 - a.0) * METERS_PER_DEGREE;
    (dx * dx + dy * dy).sqrt()
}

/// Joins routes driven one after the other: geometry appended, maneuver
/// indices shifted, the arrival at the end of every piece but the last
/// dropped.
pub fn join_routes(pieces: Vec<RouteData>) -> RouteData {
    let count = pieces.len();
    let mut joined = RouteData {
        geometry: Vec::new(),
        distance_meters: 0.0,
        duration_seconds: 0.0,
        maneuvers: Vec::new(),
    };
    for (i, piece) in pieces.into_iter().enumerate() {
        let offset = u32::try_from(joined.geometry.len()).unwrap_or(u32::MAX);
        let is_last = i + 1 == count;
        joined.geometry.extend(piece.geometry);
        joined.distance_meters += piece.distance_meters;
        joined.duration_seconds += piece.duration_seconds;
        joined.maneuvers.extend(
            piece
                .maneuvers
                .into_iter()
                .filter(|m| is_last || !ARRIVAL_TYPES.contains(&m.kind))
                .map(|m| ManeuverData {
                    begin_shape_index: m.begin_shape_index.saturating_add(offset),
                    ..m
                }),
        );
    }
    joined
}

/// Decodes a Google-style encoded polyline into (lat, lon) pairs.
pub fn decode_polyline(encoded: &str, precision: f64) -> Option<Vec<(f64, f64)>> {
    let bytes = encoded.as_bytes();
    let mut index = 0;
    let (mut lat, mut lon) = (0i64, 0i64);
    let mut points = Vec::new();
    while index < bytes.len() {
        lat += next_value(bytes, &mut index)?;
        lon += next_value(bytes, &mut index)?;
        points.push((lat as f64 / precision, lon as f64 / precision));
    }
    Some(points)
}

fn next_value(bytes: &[u8], index: &mut usize) -> Option<i64> {
    let mut result: i64 = 0;
    let mut shift = 0;
    loop {
        let byte = i64::from(*bytes.get(*index)?) - 63;
        *index += 1;
        if !(0..64).contains(&byte) || shift > 60 {
            return None;
        }
        result |= (byte & 0x1f) << shift;
        shift += 5;
        if byte < 0x20 {
            break;
        }
    }
    Some(if result & 1 != 0 {
        !(result >> 1)
    } else {
        result >> 1
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decodes_the_reference_polyline() {
        // Google's documented example, precision 5.
        let points = decode_polyline("_p~iF~ps|U_ulLnnqC_mqNvxq`@", 1e5).expect("valid polyline");
        let expected = [(38.5, -120.2), (40.7, -120.95), (43.252, -126.453)];
        assert_eq!(points.len(), expected.len());
        for ((lat, lon), (want_lat, want_lon)) in points.iter().zip(expected) {
            assert!((lat - want_lat).abs() < 1e-9 && (lon - want_lon).abs() < 1e-9);
        }
    }

    #[test]
    fn rejects_a_truncated_polyline() {
        assert_eq!(decode_polyline("_p~iF~ps|U_", 1e5), None);
    }

    /// The same example as precision 6 is what Valhalla sends; two legs share
    /// the middle point.
    fn two_leg_answer() -> Value {
        json!({
            "trip": {
                "summary": {"length": 12.5, "time": 900.0},
                "legs": [
                    {
                        "shape": "_p~iF~ps|U_ulLnnqC",
                        "maneuvers": [
                            {"instruction": "Fahren Sie Richtung Norden.", "length": 1.2, "time": 60.0,
                             "type": 1, "begin_shape_index": 0, "street_names": ["Hauptstraße"]},
                            {"instruction": "Biegen Sie rechts ab.", "length": 0.0, "time": 0.0,
                             "type": 10, "begin_shape_index": 1}
                        ]
                    },
                    {
                        "shape": "_c`|@nnqC_mqNvxq`@",
                        "maneuvers": [
                            {"instruction": "Sie haben Ihr Ziel erreicht.", "length": 0.0, "time": 0.0,
                             "type": 4, "begin_shape_index": 1}
                        ]
                    }
                ]
            }
        })
    }

    #[test]
    fn joins_legs_and_keeps_maneuver_indices_valid() {
        let route = parse_trip(&two_leg_answer()).expect("parses");
        assert_eq!(route.geometry.len(), 3, "shared point appears once");
        assert_eq!(route.distance_meters, 12_500.0);
        assert_eq!(route.duration_seconds, 900.0);
        let indices: Vec<u32> = route
            .maneuvers
            .iter()
            .map(|m| m.begin_shape_index)
            .collect();
        assert_eq!(indices, [0, 1, 2]);
        assert_eq!(route.maneuvers[0].length_meters, 1200.0);
        assert_eq!(route.maneuvers[0].street_names, ["Hauptstraße"]);
        assert_eq!(route.maneuvers[1].kind, 10);
        assert!(route.maneuvers[1].street_names.is_empty());
    }

    #[test]
    fn a_trip_without_legs_is_an_internal_error() {
        assert!(matches!(
            parse_trip(&json!({"trip": {"legs": []}})),
            Err(RoutingError::Internal(_))
        ));
    }

    #[test]
    fn valhalla_errors_map_to_the_contract() {
        let no_path = json!({"error_code": 442, "error": "No path could be found for input"});
        assert!(matches!(
            error_from_answer(StatusCode::BAD_REQUEST, &no_path),
            RoutingError::NoRoute(_)
        ));
        let bad = json!({"error_code": 106, "error": "Try any of: /route /trace_route"});
        assert!(matches!(
            error_from_answer(StatusCode::BAD_REQUEST, &bad),
            RoutingError::Invalid(_)
        ));
        assert!(matches!(
            error_from_answer(StatusCode::INTERNAL_SERVER_ERROR, &json!({})),
            RoutingError::Unavailable(_)
        ));
    }

    /// Straight line north from Alsfeld, one point every ~11 m.
    fn line(from: usize, to: usize) -> Vec<(f64, f64)> {
        (from..to)
            .map(|i| (50.75 + i as f64 * 0.0001, 9.27))
            .collect()
    }

    #[test]
    fn a_tour_that_drives_back_is_split_at_the_turn() {
        // 2.2 km north, then back south on the other lane, 14 m to the east.
        let mut tour = line(0, 200);
        let turn = tour.len();
        tour.extend(
            line(0, 200)
                .into_iter()
                .rev()
                .map(|(lat, lon)| (lat, lon + 0.0002)),
        );
        let pieces = split_trace_at_overlaps(&tour);
        assert_eq!(
            pieces.len(),
            2,
            "{:?}",
            pieces.iter().map(|p| p.len()).collect::<Vec<_>>()
        );
        assert_eq!(pieces[0].last(), pieces[1].first(), "pieces share the seam");
        assert!(
            pieces[0].len() > turn,
            "the first piece reaches past the turn"
        );
        assert_eq!(pieces[0].len() + pieces[1].len() - 1, tour.len());
    }

    #[test]
    fn a_tour_without_overlap_stays_whole() {
        let tour = line(0, 300);
        assert_eq!(split_trace_at_overlaps(&tour), vec![tour.as_slice()]);
        assert_eq!(split_trace_at_overlaps(&tour[..2]).len(), 1);
    }

    fn maneuver(kind: u32, begin_shape_index: u32) -> ManeuverData {
        ManeuverData {
            instruction: String::new(),
            length_meters: 100.0,
            time_seconds: 10.0,
            kind,
            begin_shape_index,
            street_names: Vec::new(),
        }
    }

    #[test]
    fn joined_routes_keep_one_arrival_and_valid_indices() {
        let piece = |kinds: &[(u32, u32)]| RouteData {
            geometry: vec![(50.0, 9.0), (50.1, 9.0), (50.2, 9.0)],
            distance_meters: 1000.0,
            duration_seconds: 60.0,
            maneuvers: kinds.iter().map(|&(k, i)| maneuver(k, i)).collect(),
        };
        let joined = join_routes(vec![
            piece(&[(1, 0), (10, 1), (4, 2)]),
            piece(&[(1, 0), (5, 2)]),
        ]);
        assert_eq!(joined.geometry.len(), 6);
        assert_eq!(joined.distance_meters, 2000.0);
        assert_eq!(joined.duration_seconds, 120.0);
        let got: Vec<(u32, u32)> = joined
            .maneuvers
            .iter()
            .map(|m| (m.kind, m.begin_shape_index))
            .collect();
        assert_eq!(got, [(1, 0), (10, 1), (1, 3), (5, 5)]);
    }

    #[tokio::test]
    async fn an_unreachable_router_is_unavailable() {
        let valhalla = Valhalla::new("http://127.0.0.1:9");
        let result = valhalla.route((50.0, 9.0), (50.1, 9.1), "de-DE").await;
        assert!(
            matches!(result, Err(RoutingError::Unavailable(_))),
            "{result:?}"
        );
    }
}
