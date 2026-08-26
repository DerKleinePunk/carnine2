# Ideas & Roadmap

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
- [x] Implement initial player snapshot and library rescan event stream
- [ ] Implement live player and audio event streams
- [x] Package the selected audio dependencies in the Debos image and backend Debian package

### Media: Deferred
- [ ] USB medium plugin/service and automatic mount or insertion detection
- [x] Define and document systemd/D-Bus storage-event integration (selected `udisks2` API) before implementation
- [x] Implement the systemd-managed storage event listener for block-device add/remove and mount-state changes, then notify the media service
- [ ] Validate UDisks2 add/remove and mount events with a real USB device on the Raspberry Pi
- [ ] Settings UI for media folders and playlist resume mode
- [ ] Queue editing, direct track selection, seek RPC, shuffle, and advanced queue operations
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
- [ ] Add the systemd unit to the Debos image, service recovery on power cycles, and graceful `SIGTERM` shutdown of audio playback
- [ ] Install the backend Debian package and its systemd unit as part of the Debos image build

### Long-term Vision
- [ ] Companion app operating only inside trusted LAN/VPN boundary
- [ ] OTA update hardening with staged rollout and rollback validation
- [ ] Field diagnostics package (logs, metrics snapshot, health report export)

## Enhancement Suggestions

### Frontend (Flutter)
- [ ] Standardize error-state widgets and recovery CTAs
- [ ] Add performance instrumentation for frame pacing on Raspberry Pi 4
- [ ] Define responsive layout constraints for 1024x600 and fallback sizes
- [ ] Create a Debian package for the Flutter frontend, matching the backend package

### Backend (Rust)
- [ ] Finalize UDS-based gRPC transport behavior and reconnect policy
- [ ] Add structured error taxonomy and context propagation
- [x] Add configuration layering (defaults, file, env overrides)
- [x] Implement validated, atomic TOML configuration updates through `ConfigService`

### Infrastructure / DevOps
- [ ] Establish GitHub Actions pipeline (lint, test, cross-build checks)
- [ ] Add deployment checklist and script templates for Pi provisioning
- [ ] Add firewall baseline enforcement test (LAN-only inbound policy)

## Notes
Roadmap items must reference one of: quality goals, ADRs, or risk entries.
Any feature that changes protocol boundaries requires ADR update before implementation.
