# 08 Cross-cutting Concepts

This section describes architectural principles, patterns, and technologies that apply across multiple system components, ensuring consistency, maintainability, and reliability.

## 8.1 Logging and Monitoring

### Centralized Logging
- **Framework**: Rust backend uses `tracing` with compact text output, both to stdout (so systemd's journal gets it) and to `backend.log`
- **Flutter Frontend**: Uses `package:logging`; lines go to DevTools (`dart:developer`), to an in-memory buffer for the log viewer and to the file named by `CARNINE_LOG_PATH` (`/var/log/carnine/frontend.log` on the Pi). Forwarding to the backend is not implemented
- **Aggregation**: All logs collected in `/var/log/carnine/`. The backend caps its own `backend.log` at 50 MB and then moves it to `backend.log.1` (no `logrotate` needed, #59)
- **Levels**: ERROR, WARN, INFO, DEBUG, TRACE, set by `[logging] level` (default `info`, an `EnvFilter` expression); DEBUG/TRACE can be enabled in production for troubleshooting

### Health Monitoring
- **Backend Health Checks**: No gRPC health service. systemd restarts a failed service (`Restart=on-failure`), the frontend detects a lost or frozen backend through a heartbeat (`backend_heartbeat.dart`: every 5 s a `GetServiceVersion` call with a 3 s deadline) and shows a connection banner (#58); the long-lived gRPC channels run without HTTP/2 keepalive, and the UI reports its readiness with `SystemService.ReportUiReady`
- **System Metrics**: CPU temperature, load and disk usage, sampled inside the backend (`system_metrics.rs`, no Node/Prometheus) and served by `SystemService.GetSystemMetrics`/`StreamSystemMetrics`. RAM and CAN status are not collected yet
- **Alerting**: Critical errors are displayed on the UI and logged; user is notified directly rather than via external channels

## 8.2 Error Handling and Resilience

### Exception Handling
- **Rust Backend**: Result<T, E> pattern with custom error types; panics converted to controlled shutdowns
- **Flutter Frontend**: try-catch blocks with user-friendly error dialogs
- **Recovery Strategies**: Automatic restart on transient failures; graceful degradation for non-critical features

### Fault Tolerance
- **CAN Bus Failures**: Fallback to cached data; alert driver if communication lost >30s
- **Network Issues**: gRPC retries with exponential backoff; offline mode for navigation
- **Power Interruptions**: systemd service restart on boot; state persistence to avoid data loss

## 8.3 Security

### Authentication and Authorization
- **On-device IPC**: Frontend/backend over Unix domain socket; no user login flow on the device itself
- **Remote Control Scope**: Remote control is allowed only from the local network (LAN) and is not exposed to the public internet
- **Remote Access Control**: Any LAN-exposed control endpoint must require authentication (token or mTLS) and authorization checks
- **OTA Updates** (planned, not implemented): Signed packages with GPG verification
- **Network Security**: gRPC over local socket for IPC; firewall defaults deny WAN ingress; SSH access is LAN/VPN-restricted

### Data Protection
- **Sensitive Data** (planned): Vehicle telemetry encrypted at rest using AES-256. Today no telemetry is stored
- **Input Validation**: All gRPC messages validated against protobuf schemas
- **Secure Boot**: Evaluate hardware/boot-chain support; treat as a hardening goal, not as a guaranteed baseline

## 8.4 Performance and Resource Management

### Resource Constraints
- **Memory**: <200MB RAM usage target; no memory leaks (Rust guarantees)
- **CPU**: <20% average load; real-time CAN processing prioritized
- **Storage**: <1GB app data; compressed logs and media cache

### Optimization Patterns
- **Async Processing**: Tokio runtime for non-blocking I/O
- **Caching**: In-memory caches for map tiles; SQLite for the media library, playlists, resume state and UI/navigation state. Settings live in TOML (§8.6)
- **Lazy Loading**: UI components loaded on-demand to reduce startup time

## 8.5 Communication Protocols

### Inter-Process Communication
- **gRPC**: Primary IPC between frontend/backend; protobuf for type safety
- **Unix Domain Sockets**: Local communication for security and performance
- **CAN Bus** (planned): Vehicle data via socketcan. `CarnineService.GetCanData` exists in the contract but returns a fixed placeholder value; bitrate and adapter depend on the vehicle

### External Interfaces
- **Map tiles**: read locally from MBTiles, no network needed
- **Routing**: Valhalla, running locally on the device
- **HTTP/REST** (planned): OTA updates

## 8.6 Configuration Management

### Configuration Sources
- **Static Config**: Compiled-in defaults for hardware-specific settings
- **Runtime Config**: TOML file at `/etc/carnine/config.toml` for deployment and user preferences, followed by the drop-ins in `/etc/carnine/config.d/*.toml` in name order
- **Repository Template**: `resources/config/carnine.toml` and `resources/config/config.d/` are the versioned examples and image-install source
- **Environment Variables**: Only for deployment-specific overrides: `CARNINE_CONFIG`, `CARNINE_LOG_DIRECTORY`, `CARNINE_DATABASE_PATH`, `CARNINE_SOCKET_PATH`, `CARNINE_SOCKET_MODE`, `CARNINE_TCP_ADDRESS` (`carnine-backend --help` lists them)

### Hot Reloading (planned)
- **Settings**: Changes applied without restart via gRPC config endpoint. Today `UpdateConfiguration` saves the change and always reports that a restart is required
- **Feature Flags**: Runtime toggles for experimental features (none exist yet)

### UI Configuration Changes
- The Flutter UI never writes `/etc/carnine/config.toml` directly.
- A dedicated, typed `ConfigService` exposes read and update RPCs.
- The backend validates every update, rejects unsupported or unsafe values, and
	persists accepted changes atomically.
- Runtime changes are applied immediately when the affected subsystem supports
	reconfiguration; startup-only settings are reported as requiring a restart.
- Secrets are not stored in the repository configuration template.

## 8.7 Testing and Quality Assurance

### Unit Testing
- **Rust**: `cargo test`; hardware is replaced by fakes (for example a listening thread instead of the sound card in the queue tests). Coverage is not measured yet
- **Flutter**: Widget tests and unit tests with hand-written fakes (`test/fakes/`) and `fake_async`

### Integration Testing
- **End-to-End** (planned): Automated tests on target hardware. Today the checks on the Pi are done by hand and recorded in the pull request or issue
- **CAN Simulation** (planned): Virtual CAN interfaces for testing without real vehicle

### Continuous Integration
- **Build Pipeline**: GitHub Actions (`.github/workflows/ci.yml`): backend `cargo fmt --check`, `cargo clippy --all-targets -- -D warnings` and `cargo test`; frontend `flutter analyze` and `flutter test`; shellcheck and tests for the image scripts; the tests of the demo tools and of the ivi-homescreen SBOM script (Python); a native arm64 release build; an SBOM of our own dependencies (`Cargo.lock`, `pubspec.lock`) with syft, checked with grype, which fails only on a Critical finding that has a fix (#41, accepted findings in `.grype.yaml`)
- **Code Quality**: Clippy (Rust), Flutter analyze. No pre-commit hooks in the repository

## 8.8 Deployment and Updates

### Over-the-Air Updates (planned, not implemented)

Today updates are Debian packages installed by `deploy_pi.sh` or a new SD-card image (07-deployment.md).

- **Mechanism**: Delta updates via HTTP download; A/B partitions for rollback
- **Validation**: Checksum verification and signature validation
- **Scheduling**: Updates applied during ignition off; user notification required

### Rollback Strategy
- **Automatic**: Failed updates trigger rollback to previous version
- **Manual**: SSH access for emergency recovery

## 8.9 Internationalization (i18n)

### Language Support
- **Primary**: German (de) with English (en) fallback
- **Implementation**: The frontend has its own lookup in `lib/l10n/` with 15 languages (`lib/l10n/translations/`). The backend sends codes and event types, not display text
- **Date/Number Formats**: Locale-aware formatting for vehicle data display

## 8.10 UI/UX Design Workflow

### Design Template Source
- **Tool**: Stitch
- **Project**: https://stitch.withgoogle.com/projects/11236860998423822860
- **Rule**: Stitch project is the source of truth for screens, components, spacing, and visual hierarchy.

### Handoff to Flutter
- **Implementation**: Flutter UI implementation follows approved Stitch templates.
- **Change Process**: Significant UI changes are first updated in Stitch, then implemented in Flutter.

## 8.11 Map Style

The maps page draws the MBTiles vector tiles with
`src/frontend/assets/maps/style_carnine_dark.json`, rendered by
`vector_map_tiles` and `vector_tile_renderer` 6.1 through `local_map`. Since
0.9.5 (`local_map-v0.6.0`) both come from forks pinned to commits in the
`dependency_overrides` of `src/frontend/pubspec.yaml`: the tiles are rendered
for the map rotation rounded to 45° steps (`labelRotationStep: 45` in
`maps_content.dart`), so labels are never upside down when the map follows
the heading (flutter_local_map #1). Measured on the Pi 4 (jeep-pi,
2026-09-30): 0–5 instead of 0–1 frames over 100 ms per drive and about
30 MB more resident. If that hurts, the one line `labelRotationStep` in
`maps_content.dart` switches it off again.

### Field Names in the Tiles
- The Hessen tiles are built with tilemaker in the OpenMapTiles schema, and
  names are stored **only as `name:latin`**. There is no `name` field.
- A text field of `{name}` therefore draws nothing. Until 2026-09-25 this is
  why the map showed not a single place, street or water name (#28).
- Labels use `["coalesce", ["get", "name:latin"], ["get", "name"]]`, so tiles
  that do carry `name` also work.
- To see what a tile really contains, decode one tile from the MBTiles file.
  The `vector_layers` list in the metadata can be incomplete.

### Style ID, Version and the Tile Cache
`vector_map_tiles` caches two things in `/tmp/.vector_map`, and both outlive
the app:

| Cache | Files | Key |
|---|---|---|
| Tile data, filtered for a style (only the layers and fields it uses) | `*.pbf` | tile and style `id` |
| Rendered tiles | `*.png` | style `id` and `metadata.version`, e.g. `carnine-dark-2-v3-…` |

A changed style that keeps both gets old cached data or old images. It then
looks like the previous one, although the log reports the new layer count
("Style aktiv: N Ebenen"). This happened twice on 2026-09-25: first with the
names, then with a colour-only change that did not show up on the panel at
all.

- **Every change** to the style: raise `metadata.version` (currently `3`).
- **Changes to layers, filters or queried fields:** also raise the number
  in `id` (currently `carnine-dark-2`).
- Both apply on the Pi too; without them an update keeps showing the old
  cached tiles until they expire.

### Supported Style Features
`vector_tile_renderer` 6.1 understands `get`, `has`, `coalesce`, `match`,
`case`, `step`, `interpolate`, `zoom`, comparisons, `in`/`!in` and
`all`/`any`. `line-dasharray` is not supported.

### Colour Rules
- The map background is `AppColors.surfaceContainer` (`#191919`), set both
  in the style and as `MapLayerStyle.backgroundColor`. It is lighter than the
  app's `surface`, because the 7-inch Waveshare panel shows nothing darker
  than a mid dark grey: on 2026-09-25 areas that looked fine on a desktop
  monitor were nearly invisible on the panel. Judge colours on the panel,
  not on the monitor.
- Roads and areas are never cyan or magenta. `AppColors.primary` marks the
  route and the own position, and `AppColors.secondary` marks the
  destination; both must stay the brightest things on the map.

### Checking a Change
- Locally with `./run_wsl.sh` (07-deployment.md §3.4). WSLg renders in
  software, so this judges appearance only, not speed.
- Speed on the Pi with the map in navigation mode and music playing, logged
  by `~/freeze/watch.log`. Reference from 2026-09-25 with `carnine-dark-2`
  (32 layers), which matches the old 21-layer style:
  - about 3350 commits per minute
  - no lost page flips
  - homescreen at about 72 % of one core
  - load 1.6–1.8, 37–38 °C, no throttling
