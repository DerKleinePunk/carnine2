# Ideas & Roadmap

## Current Priorities

These are the next concrete work items after the current backend and image integration:

1. Validate UDisks2 add/remove and mount events with a real USB device on the Raspberry Pi.
2. Investigate audio pause latency, intermittent dropouts, and the residual stop click/pop.
3. Standardize frontend error states and recovery actions, then verify the 1024x600 layout on the Raspberry Pi.
4. Verify the complete image boot path after power cycles, including service recovery and graceful `SIGTERM` shutdown.
5. Establish a first CI pipeline for formatting, tests, and cross-build checks.

## Feature Ideas

### Short-term Ideas
- [ ] Define first stable `.proto` contract for core control and telemetry messages
- [ ] Implement minimal end-to-end vertical slice (frontend button -> backend RPC -> response)
- [ ] Add backend health endpoint and frontend connection banner handling
- [ ] Create reproducible local build scripts for backend and frontend

### Media: Before Implementation
- Detailed working plan: [20 – Media Backend Plan](20-media-backend-plan.md)
- [ ] Run a WSL FFmpeg spike before Raspberry Pi work
	- [x] Confirm WSLg PulseAudio endpoint and FFmpeg availability
	- [x] Confirm MP3, FLAC, and OGG decoding in WSL
	- [x] Play the repository MP3 through FFmpeg and WSLg PulseAudio
	- [x] Validate external FFmpeg process from an isolated Rust example
	- [x] Exercise process-level play, pause, and stop commands
	- [x] Validate direct ffmpeg-next library decoding and PCM output
	- [ ] Investigate pause latency and intermittent audio dropouts
	- [ ] Investigate residual click/pop at the end of `stop` and compare with a fully buffered audio implementation
	- [x] Verify Debian package availability and planned backend packaging
	- [ ] Compare external FFmpeg process with direct library integration
	- [x] Verify audible output and target audio device on Raspberry Pi
	- [x] Document the selected audio stack for the Debian image
- [x] Document and approve the first `MediaService` and `AudioService` protobuf contract
- [x] Define typed `ConfigService` RPCs for reading and updating runtime configuration
- [x] Define media, playlist-entry, queue-entry, source, scan, and service-version identifiers
- [x] Define SQLite schema and migration strategy for media, playlists, and resume state
- [x] Implement explicit complete media-library rescan with progress and error stream
- [x] Implement backend media search for title and artist
- [x] Implement persistent playlists and temporary queue semantics
- [x] Implement backend-owned playback state and play/pause/stop/next/previous
- [x] Add RestartCurrentTrack without losing the queue (#7)
- [x] Expose active playlist context in player snapshots and restore it in the frontend (#10)
- [x] Add direct queue-entry selection without changing queue order (#11)
- [x] Implement initial player snapshot and library rescan event stream
- [x] Implement live player and audio event streams
- [x] Package the selected audio dependencies in the Debos image and backend Debian package

### Media: Deferred
- [ ] USB medium plugin/service and automatic mount or insertion detection
- [x] Define and document systemd/D-Bus storage-event integration (selected `udisks2` API) before implementation
- [x] Implement the systemd-managed storage event listener for block-device add/remove and mount-state changes, then notify the media service
- [ ] Validate UDisks2 add/remove and mount events with a real USB device on the Raspberry Pi
- [ ] Settings UI for media folders and playlist resume mode
- [ ] Queue editing, seek RPC (#8), shuffle (#9), and advanced queue operations
- [ ] M3U import/export
- [ ] Party mode
- [ ] Gapless playback and cross-fading
- [ ] Equalizer/SoundCurve
- [ ] Video playback
- [ ] Separate volume groups and full audio-system policy
- [ ] Conflict handling for concurrent control clients
- [ ] Robust recognition of moved files using hashes or other content identity

### Medium-term Ideas
- [ ] Integrate CAN telemetry ingestion with bounded update rates and UI throttling
- [ ] Add offline cache synchronization strategy for navigation/media metadata
- [ ] Introduce authenticated LAN remote control endpoint (no WAN exposure)
- [ ] Add service recovery validation on power cycles and graceful `SIGTERM` shutdown of audio playback
- [x] Install the backend Debian package and its systemd unit as part of the Debos image build

### Long-term Vision
- [ ] Companion app operating only inside trusted LAN/VPN boundary
- [ ] OTA update hardening with staged rollout and rollback validation
- [ ] Field diagnostics package (logs, metrics snapshot, health report export)

## Enhancement Suggestions

### Frontend (Flutter)
- [ ] Standardize error-state widgets and recovery CTAs
- [ ] Add performance instrumentation for frame pacing on Raspberry Pi 4
- [ ] Define responsive layout constraints for 1024x600 and fallback sizes
- [x] Create a Debian package for the Flutter frontend, matching the backend package

### Backend (Rust)
- [ ] Finalize UDS-based gRPC transport behavior and reconnect policy
- [ ] Add structured error taxonomy and context propagation
- [x] Add configuration layering (defaults, file, env overrides)
- [x] Implement validated, atomic TOML configuration updates through `ConfigService`

### Infrastructure / DevOps
- [ ] Establish GitHub Actions pipeline (lint, test, cross-build checks)
- [ ] Evaluate aptly-based local Debian repository/cache for CI/CD and Debos image builds, so package updates and image rebuilds do not require downloading the same packages from the internet repeatedly
- [ ] Add deployment checklist and script templates for Pi provisioning
- [ ] Add firewall baseline enforcement test (LAN-only inbound policy)

## Notes
Roadmap items must reference one of: quality goals, ADRs, or risk entries.
Any feature that changes protocol boundaries requires ADR update before implementation.
