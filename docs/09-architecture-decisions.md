# 09 Architecture Decisions

Record important decisions made during the design process, including alternatives and rationale.

## ADR-001: Technology Stack - Flutter Frontend + Rust Backend

**Status:** Accepted

**Context:**
The CarPC project requires a modern UI with hot-reload capability for rapid development, combined with high-performance backend processing for vehicle telemetry, CAN-bus communication, and media handling. The system runs on resource-constrained hardware (Raspberry Pi 4) and must handle real-time data streams.

**Decision:**
Use Flutter (Dart) for the frontend UI and Rust for the backend business logic. Communication between them via gRPC.

**Rationale:**
- **Flutter**: Hot-reload enables faster iteration; cross-platform widget library; strong type safety in Dart; can easily port to mobile later
- **Rust**: Memory safety without garbage collection; excellent performance for real-time tasks; strong ecosystem for systems programming (CAN, async I/O)
- **Separation of concerns**: Clear boundary between UI and business logic enables independent testing and deployment

**Alternatives considered:**
- Qt/C++ for both frontend and backend – would require more boilerplate; less rapid development cycle
- Python backend – insufficient performance for real-time CAN processing and concurrent connections
- Web-based frontend (React/Vue) – adds unnecessary complexity on embedded Linux; Flutter provides better control

**Consequences:**
- Requires learning both Dart and Rust; increased initial development time
- Need to maintain IPC layer (gRPC) between processes
- Better long-term maintainability and testability

---

## ADR-002: Inter-Process Communication - gRPC over Unix Domain Socket

**Status:** Accepted

**Context:**
Frontend (Flutter) and backend (Rust) run as separate processes. Need a reliable, strongly-typed communication mechanism with good performance and minimal latency.

**Decision:**
Use gRPC with Protocol Buffers for IPC, primarily over Unix domain sockets (fallback to TCP loopback).

**Rationale:**
- **Strong typing**: Proto definitions auto-generate client/server stubs in both languages; compile-time checking
- **Performance**: Binary serialization (Protocol Buffers) is faster than JSON
- **Streaming support**: gRPC streaming enables real-time data flows (e.g., vehicle telemetry updates)
- **Unix domain sockets**: Lower latency than TCP; no network stack overhead; filesystem-based security
- **Maturity**: Proven in production; libraries available for both Dart (gRPC Dart) and Rust (tonic)

**Alternatives considered:**
- REST over HTTP – less efficient; no built-in streaming; loosely typed
- Message queues (RabbitMQ, ZeroMQ) – overkill for local IPC; adds operational complexity
- Shared memory – unsafe without careful synchronization; harder to debug

**Consequences:**
- Need to define and maintain `.proto` files; code generation step in build process
- Slightly steeper learning curve than REST
- Excellent debugging and monitoring capabilities via gRPC tools

---

## ADR-003: Backend Language - Rust with Tokio Async Runtime

**Status:** Accepted

**Context:**
The backend must handle multiple concurrent tasks: CAN-bus polling, network requests, gRPC server, media processing. Resource constraints (Raspberry Pi 4) demand efficient concurrency without runtime overhead.

**Decision:**
Implement backend in Rust using Tokio for async I/O and task spawning.

**Rationale:**
- **Memory safety**: No garbage collector; predictable performance; no null pointer exceptions
- **Concurrency**: Async/await with Tokio enables handling hundreds of concurrent connections with minimal overhead
- **Type system**: Strong compile-time guarantees reduce runtime errors
- **Performance**: Zero-cost abstractions; codegen optimization at compile time
- **Error handling**: Rust's `Result` type with `anyhow::Result` and `?` operator ensures errors are not silently ignored

**Alternatives considered:**
- Go – good concurrency model but less control over memory; simpler but less safe
- C++ – full control but higher safety risks; more development time

**Consequences:**
- Steeper learning curve; longer initial development time
- Excellent runtime reliability and performance
- Compilation times are longer but provide strong guarantees

---

## ADR-004: Data Persistence - SQLite for Offline Data

**Status:** Accepted

**Context:**
System must work offline with cached data (maps, preferences, vehicle history). Needs a lightweight, self-contained database suitable for embedded systems.

**Decision:**
Use SQLite for local data storage, with synchronization logic for online reconciliation.

**Rationale:**
- **Lightweight**: Single file database; no server process required; perfect for Raspberry Pi
- **Offline support**: Data available even without network connectivity
- **Query capability**: Better than flat file storage for complex data access patterns
- **Reliability**: ACID transactions ensure data integrity during power loss scenarios
- **Embedded-friendly**: Widely used in automotive and embedded systems

**Alternatives considered:**
- PostgreSQL – overkill for single-device system; requires running server
- Firebase – tight coupling to cloud; problematic offline behavior
- Custom binary format – difficult to query; higher maintenance burden

**Consequences:**
- Need to manage database schema migrations
- Must implement offline-first sync logic for network data
- Excellent local performance and data integrity

---

## ADR-005: Real-time Data Streaming - gRPC Streaming for Vehicle Telemetry

**Status:** Accepted

**Context:**
Vehicle telemetry (speed, RPM, temperatures) must update the UI in real-time (<50ms latency). Traditional request-reply patterns introduce unnecessary latency.

**Decision:**
Use server-side gRPC streaming to push vehicle data updates from backend to frontend.

**Rationale:**
- **Low latency**: Server pushes data immediately; no polling overhead
- **Efficient**: Only transmits when data changes (with configurable update intervals)
- **Backpressure handling**: gRPC manages flow control automatically
- **Natural fit**: Rust Tokio streams map directly to gRPC streaming

**Alternatives considered:**
- Polling – excessive CPU usage on Raspberry Pi for frequent updates
- WebSockets – adds HTTP layer; less strongly typed
- Message queue – introduces latency; overkill for local IPC

**Consequences:**
- Requires implementing streaming handlers on backend
- Frontend must manage stream subscriptions and lifecycle
- Excellent real-time responsiveness

---

## ADR-006: CAN-Bus Integration - Direct RS232 via Custom Driver

**Status:** Accepted

**Context:**
Vehicle provides diagnostic and telemetry data over CAN-bus interface. System needs low-latency access to this data with minimal dependencies.

**Decision:**
Implement custom CAN-bus handler in Rust backend with direct RS232 communication to CAN interface hardware.

**Rationale:**
- **Control**: Custom driver allows optimization for specific hardware
- **Minimal dependencies**: Avoid heavy embedded libraries
- **Async-friendly**: Can be integrated into Tokio event loop
- **Performance**: Direct communication without middleware layers

**Alternatives considered:**
- SocketCAN (Linux kernel layer) – good but less portable; may not be available on all embedded Linux variants
- High-level CAN libraries – often include unnecessary features; harder to debug

**Consequences:**
- Increased complexity of backend implementation
- Deep knowledge of CAN protocol and RS232 communication required
- Complete control over data flow and timing

---

## ADR-007: Configuration Management - TOML Files with Typed gRPC Service

**Status:** Accepted

**Context:**
System needs configuration for hardware, media, audio, logging, and deployment-specific parameters. The configuration must be readable, validated, persistable, and changeable through the frontend without allowing the UI to write system files directly.

**Decision:**
Use TOML files for configuration storage. The versioned template is located at `resources/config/carnine.toml`; the installed system uses `/etc/carnine/config.toml`. The Rust backend loads the configuration at startup and exposes it through the typed gRPC `ConfigService`, which owns validated updates and atomic persistence.

**Rationale:**
- **Human-readable**: TOML is easy to inspect and edit for deployment and hardware settings
- **Type-safe**: Rust deserialization and validation reject invalid configuration at startup or update time
- **Controlled writes**: The backend owns persistence, preventing direct UI access to the system configuration file
- **Atomic updates**: Accepted changes are written to a temporary file and renamed into place
- **Thread-safe service state**: `ConfigServiceImpl` protects the active configuration with a mutex

**Alternatives considered:**
- Environment variables – fine for simple settings; difficult for nested configs
- JSON – less readable; more verbose
- Global `LazyLock` state – unsuitable for the mutable configuration exposed by the update service
- Direct UI file access – unsafe and couples the frontend to filesystem permissions and paths

**Consequences:**
- Config must be valid TOML and pass backend validation; errors halt startup or reject an update
- The current update service persists changes atomically and reports that a restart is required
- The frontend remains independent of the file format and filesystem path
- Secrets are not stored in the versioned configuration template

---

## ADR-008: Error Handling - `anyhow::Result` with Context

**Status:** Accepted

**Context:**
Rust provides multiple error handling approaches. Need a strategy that provides good error context for debugging while remaining concise in code.

**Decision:**
Use `anyhow::Result<T>` for fallible operations, with `.context()` for adding contextual information at each level.

**Rationale:**
- **Context preservation**: Each layer can add context; final error includes full chain
- **Concise syntax**: `?` operator works naturally; avoids verbose error handling
- **Debugging**: Stack traces and context messages aid troubleshooting
- **Consistency**: Single error handling pattern across codebase

**Alternatives considered:**
- Custom error enums – more boilerplate; better type safety but harder to use
- Simple `Option<T>` – loses all error context
- `thiserror` crate – more structured but more verbose

**Consequences:**
- Errors are strings with context; no type-based error discrimination possible
- Excellent for system services where all errors should be logged
- Simpler error handling paths in code

---

## ADR-009: Code Organization - Modular Structure with `mod.rs` Files

**Status:** Accepted

**Context:**
Backend will grow to handle CAN, networking, media, storage, and other concerns. Need a clear structure that scales.

**Decision:**
Organize backend as modules with `mod.rs` files declaring submodules; each major concern (e.g., `can_handler`, `media`, `storage`) gets its own module directory.

**Rationale:**
- **Scoping**: Modules control visibility; public APIs are explicit
- **Encapsulation**: Internal implementation details remain private
- **Scalability**: Works well as codebase grows
- **Testing**: Modular structure supports unit testing of individual modules

**Alternatives considered:**
- Single file (like simple Python scripts) – unmaintainable at scale
- Flat file structure – no encapsulation; namespace pollution

**Consequences:**
- Clear boundaries between subsystems
- Easier to test components in isolation
- Well-defined interfaces between modules

---

## ADR-010: Logging and Tracing - `tracing` Crate for Structured Logging

**Status:** Accepted

**Context:**
System needs observability for debugging and monitoring. Traditional printf-style logging is insufficient for troubleshooting async/concurrent code.

**Decision:**
Use the `tracing` crate for structured logging with `debug!`, `info!`, and `error!` macros. Output to stdout/logs with filters for different verbosity levels.

**Rationale:**
- **Structured logging**: Logs include metadata and context; easier to parse and analyze
- **Async-aware**: Designed for async Rust code; tracks spans across await points
- **Performance**: Macros optimize away disabled levels
- **Ecosystem**: Integrates well with Tokio and other async crates

**Alternatives considered:**
- `log` crate – simpler but less powerful; lacks async awareness
- `println!` debugging – fine for development; poor for production observability
- `slog` – more complex configuration

**Consequences:**
- Structured logs can be filtered and analyzed programmatically
- Better visibility into system behavior in production
- Slight performance overhead (negligible on Raspberry Pi 4)

---

## ADR-011: Testing Strategy - Unit Tests in Module, Integration via gRPC

**Status:** Accepted

**Context:**
Need to validate backend functionality without running the full graphical application. Must support testing of business logic and IPC independently.

**Decision:**
Write unit tests directly in Rust modules for business logic. Integration tests call backend via gRPC client. Prefer tests over manual verification.

**Rationale:**
- **Avoiding UI**: Graphical testing is slow and error-prone; prefer automated tests
- **Unit tests**: Fast feedback loop; test individual components in isolation
- **Integration tests**: Verify IPC contract and end-to-end behavior
- **Regression prevention**: Test suite catches regressions early

**Alternatives considered:**
- Only integration tests – slower; harder to isolate issues
- Manual testing – time-consuming; unreliable

**Consequences:**
- Higher initial development time
- Test-driven development becomes natural
- System reliability significantly improved

---

## ADR-012: Concurrency Model - Tokio Tasks with `tokio::sync` Primitives

**Status:** Accepted

**Context:**
Multiple subsystems (CAN polling, gRPC server, media playback, network I/O) must execute concurrently without blocking.

**Decision:**
Use Tokio tasks for concurrent work; synchronize via `tokio::sync` channels and mutexes (Mutex, RwLock). Avoid blocking operations in async code.

**Rationale:**
- **Scalability**: Thousands of tasks share few OS threads; minimal overhead
- **Type safety**: Rust's ownership system prevents data races
- **Composability**: Tokio integrates seamlessly with async/await syntax
- **Well-tested**: Tokio is battle-tested in production systems

**Alternatives considered:**
- OS threads – higher memory overhead per task; more complex synchronization
- Futures without Tokio – requires managing executor; less integrated

**Consequences:**
- Must understand async/await patterns and Tokio APIs
- Excellent runtime efficiency
- No data races possible (enforced by compiler)

---

## ADR-013: Backend Runtime Identity - Dedicated System User

**Status:** Accepted

**Context:**
The backend needs access to audio hardware, media data, logs, and its runtime
configuration. Running it as `root` would provide unnecessary privileges, while
using the interactive `pi` account would couple the service to a human login.

**Decision:**
Run the backend as the dedicated system user `carnine`, without an interactive
login. The user is a member of the `audio` group and owns the backend's media
and log directories. The configuration directory is owned by `root:carnine`
and is group-writable so the backend can persist validated updates atomically.

**Rationale:**
- **Least privilege**: The backend does not need a root shell or unrestricted filesystem access
- **Stable deployment**: Service permissions do not depend on the `pi` user's login
- **Hardware access**: Audio access is explicit through the `audio` group
- **Atomic configuration updates**: Group write access to `/etc/carnine` permits temporary-file replacement without making the file world-writable

**Alternatives considered:**
- `root` – unnecessary privileges and greater impact of a backend vulnerability
- `pi` – interactive account and unclear service ownership
- World-writable configuration – insecure and not acceptable for a service that accepts remote configuration requests

**Consequences:**
- The system image must create the `carnine` user and required directories
- A future systemd unit must run with `User=carnine` and `Group=carnine`
- Changes to the backend's required device or filesystem access must be reflected in the image recipe and this decision

---

## ADR-014: Removable Media Detection - UDisks2 over D-Bus

**Status:** Accepted

**Context:**
The media library must react when removable storage is added, removed, or
mounted. Polling the filesystem is inefficient and cannot reliably distinguish
device and mount state changes on the Raspberry Pi.

**Decision:**
The Rust backend listens on the system D-Bus for signals from `udisks2`. The
listener reacts to `InterfacesAdded`, `InterfacesRemoved`, and
`PropertiesChanged` signals below `/org/freedesktop/UDisks2`, then starts a
media-library rescan. The `udisks2` package is part of the Raspberry Pi image.

**Rationale:**
- **Standard Linux integration**: UDisks2 provides the platform service for block devices and mount state
- **Event-driven behavior**: The backend does not need to poll for new media
- **Single process**: The listener remains inside the backend and avoids another IPC protocol
- **Graceful degradation**: A missing D-Bus or UDisks2 service disables automatic detection but does not stop the backend

**Alternatives considered:**
- Filesystem polling – wastes resources and has race conditions around mounts
- Direct udev monitoring – exposes device events but not the complete user-space mount state
- Separate storage-monitor process – adds process and IPC complexity for a feature owned by the media service

**Consequences:**
- The image must install and run `udisks2` with a system D-Bus
- A storage signal can trigger more than one rescan; debouncing and source-specific filtering remain follow-up work
- Automatic detection is limited to events visible through UDisks2

---

## ADR-013: Frontend Architecture - Widget-based with State Management

**Status:** Accepted

**Context:**
Flutter frontend must display multiple screens (navigation, media, settings, diagnostics). Need to manage shared state and navigate between screens efficiently.

**Decision:**
Use Flutter's widget composition model with a state management approach (Provider pattern or similar). Keep UI stateless where possible; manage shared state centrally.

**Rationale:**
- **Widget composition**: Declarative UI; changes naturally flow from state updates
- **Hot reload**: Enables rapid iteration during development
- **Separation**: Business logic remains in backend via gRPC; frontend focuses on presentation
- **Testability**: UI statelessness improves testability

**Alternatives considered:**
- Stateful widgets everywhere – difficult to manage complex state
- Custom state management – reinventing the wheel

**Consequences:**
- Clear data flow from state to UI makes debugging easier
- Hot reload shortens development cycle
- Lower coupling between UI components

---

## ADR-014: Offline-First Data Strategy - Cache with Sync

**Status:** Accepted

**Context:**
Connectivity is intermittent (vehicle may lose signal). Navigation maps, preferences, and vehicle history must remain available offline.

**Decision:**
Backend caches all necessary data locally (SQLite) and syncs with remote services when connectivity is available. UI always reads from cache; background sync keeps cache updated.

**Rationale:**
- **Reliability**: System works without network; critical for in-vehicle use
- **Performance**: Local cache is faster than network requests
- **Resilience**: Graceful degradation when offline; data converges when rejoined

**Alternatives considered:**
- Cloud-only – fails without network; unacceptable for vehicle environment
- No caching – forces network dependency; poor performance

**Consequences:**
- Need to implement sync logic and conflict resolution
- Data consistency complexity (what if offline changes conflict with server state?)
- Excellent user resilience and performance

---

## ADR-015: Communication Protocol Strategy - gRPC as Unified API, Cap'n Proto by Measured Need

**Status:** Accepted

**Context:**
The system uses Flutter (Dart) frontend and Rust backend on Raspberry Pi 4. Local IPC must be efficient, and a future companion mobile app should be able to remotely control backend features. A suggestion was made to use Cap'n Proto for local communication while keeping gRPC for remote control. This introduces a potential dual-protocol architecture.

**Decision:**
Use gRPC (protobuf) as the single communication contract for both local frontend-backend communication and future remote control APIs. Keep Cap'n Proto as a fallback optimization option only if measurements prove gRPC IPC is a critical bottleneck on target hardware.

**Rationale:**
- **Single source of truth**: One IDL (`.proto`) and one generated client/server contract across Rust and Dart
- **Lower complexity**: Avoid parallel schema maintenance, duplicate codegen pipelines, and protocol translation layers
- **Ecosystem maturity**: gRPC in Dart/Flutter and Rust is actively maintained and production-proven
- **Future readiness**: Remote access via mobile app can reuse existing service contracts instead of introducing a second API surface
- **Resource balance on RPi4**: gRPC over Unix domain sockets with streaming/channel reuse is typically sufficient for control/state traffic while keeping maintenance cost low

**Alternatives considered:**
- **Hybrid model (Cap'n Proto local + gRPC remote)**
	- **Pros**: Potentially lower local serialization overhead in selected high-throughput paths
	- **Cons**: Two protocol ecosystems, schema drift risk, more testing burden, higher long-term maintenance effort
- **Cap'n Proto-only end-to-end**
	- **Pros**: High performance serialization and rich RPC model
	- **Cons**: No mature official Dart path in current ecosystem strategy; higher adoption and tooling risk for Flutter frontend and mobile roadmap

**Consequences:**
- IPC and remote APIs share the same contract lifecycle and versioning process
- Performance tuning focuses first on transport and usage patterns (UDS, streaming, channel reuse, deadlines, backpressure)
- Team can move faster with fewer integration failure modes
- If performance issues occur, optimization is evidence-driven rather than speculative

**Revisit / Trigger Conditions (Cap'n Proto Re-evaluation):**
- Profiling on Raspberry Pi 4 shows sustained CPU or latency bottlenecks where gRPC serialization/transport is the dominant cost
- The bottleneck cannot be solved by gRPC-level tuning and message design improvements
- A production-viable Dart strategy for Cap'n Proto exists (maintenance, tooling, compatibility, security posture)
- Team accepts and plans explicit long-term ownership of a dual-protocol architecture

**Related decisions:**
- ADR-002 (gRPC over Unix domain socket)
- ADR-005 (gRPC streaming for telemetry)
- ADR-011 (integration testing via gRPC)

**Quality linkage:**
- See Chapter 10 (Quality Requirements), section "Communication Protocol Strategy (linked to ADR-015)" for weighted decision matrix, measurable thresholds, and protocol re-evaluation triggers.

---

## Decision Rationale Summary

---

## ADR-016: Media Architecture Baseline

**Status:** Accepted

**Context:**
The first media feature is an audio-only player for local files. The Flutter
media screen currently contains presentation state and mock data, while the
backend must own playback, media indexing, persistence, and recovery state.
The contract must support future USB media, navigation audio, and additional
media features without using untyped command strings.

**Decision:**
Keep the protobuf contract in the single shared `src/proto/carnine.proto`
file, but define separate fachliche gRPC services for `CarnineService`,
`MediaService`, and `AudioService`. `MediaService` owns the media library,
search, playlists, queue, playback commands, player state, and player events.
`AudioService` represents the central backend audio manager and its audio
events; it does not transport audio data.

The generic `SendCommand` RPC is not part of the contract. Future vehicle
data and vehicle-control APIs will use separate fachliche services instead of
an untyped command endpoint.

The first implementation targets multiple configured local folders, including
the internal disk and later USB-mounted media. A complete library rescan is an
explicit backend operation. It updates SQLite and reports progress and errors
on a dedicated library stream. Rescans do not run during playback.

Audio files are inspected for metadata when they are imported. Title, artist,
and source URI/path are required. Unreadable files are not inserted into the
media database; the error is reported on the library stream. A missing file on
an available source is represented as `MISSING`. A detached source is
represented as `OFFLINE` so playlists can be restored and shown.

Playlists have a persistent name and ordered entries. The same media item may
occur more than once. Loading a playlist stops playback, clears the current
queue, replaces it with the playlist, selects the saved entry and position,
and leaves playback paused. Starting one media item creates a temporary queue.
The temporary queue is empty after restart. The active playlist, current
entry, and resume position are persisted in SQLite.

The initial playback commands are play, pause, stop, next, and previous.
Stop ends audio output and resets the current track to its beginning without
changing the queue. Repeat supports off, queue, and track. Concurrent control
requests are not solved in the first version; there is one controlling client
and the effective behavior is last-wins without crashing the backend.

The player operates independently of Flutter. A player event stream sends an
initial complete state followed by updates. A separate library event stream
reports scan activity, and a separate audio event stream reports central
audio-manager events such as interruption and ducking. These are control and
state streams, not audio streams. Each service exposes a three-part interface
version (`major`, `minor`, `patch`). Supported capabilities remain documented,
not queried programmatically.

The initial decoder/output decision is deferred until a local WSL FFmpeg
spike. The spike must validate the Debian package path, MP3/FLAC/OGG support,
process or library integration options, and system audio output before any
Raspberry Pi implementation. Equalizer/SoundCurve, gapless playback,
cross-fading, party mode, video, and M3U remain future work.

The first WSL2 check on Ubuntu 24.04 succeeded with the WSLg-provided
PulseAudio server: FFmpeg decoded MP3, FLAC, and OGG test files, and a WAV
test file was accepted by the `RDPSink`. WSLg exposes the server through
`PULSE_SERVER=unix:/mnt/wslg/PulseServer`. The WSL instance did not expose a
physical ALSA device, so audible output, Raspberry Pi packaging, and target
audio hardware remain unverified. A separate Windows PulseAudio server is
therefore not required for the current WSLg setup and should only be treated
as a fallback for environments without WSLg.

The repository contains `resources/musik/1-Here We Go Now (Single Edit).mp3`
as a test medium. Its embedded metadata identifies the title as `Here We Go
Now (Single Edit)`, the artist as `Kensington Road`, and the album as `Here We
Go Now`; the file is an MP3 at 128 kbit/s and 44.1 kHz with a duration of about
175 seconds. The user confirmed that the band has granted permission for this
file to be distributed with the repository. The file was successfully
decoded with FFmpeg and played for five seconds through the WSLg PulseAudio
output. `paplay` should receive decoded PCM from FFmpeg for MP3 playback; a
direct MP3 handoff to `paplay` is not the supported test path.

The isolated Rust external-process spike was subsequently validated with this
track. It streamed FFmpeg PCM output into `paplay`, played the complete track,
and exited successfully after about 176 seconds. A missing input file produced
a controlled error and exit status 1; PulseAudio registered and removed the
playback stream normally. This validates the basic process-and-pipe approach,
including process-level pause/resume and stop control. Pause responsiveness
and occasional audio dropouts still need to be isolated between WSLg/
PulseAudio, process signalling, and the PCM pipe. Long-running resource
behavior and the direct FFmpeg-library alternative remain unverified.

The follow-up isolation tests decoded the same MP3 to a five-second PCM-WAV
without errors, played that WAV through `paplay`, and played the MP3 through
FFmpeg directly to the WSLg PulseAudio sink. These paths completed
successfully. The current audio-dropout investigation is therefore narrowed
to the Rust PCM pipe and process-level signal handling, especially the joint
pause/resume control; this is not yet proof that WSLg is uninvolved.

An additional 60-second test sent the MP3 directly from FFmpeg to the WSLg
PulseAudio sink without any Rust code. The user heard clear dropouts there as
well, while Windows audio output itself is otherwise good. WSLg/PulseAudio is
therefore a confirmed limitation of subjective playback tests in this WSL
environment. Further Rust comparisons should use decoder-only checks, PCM
byte-count and timing checks, or a captured file/null sink. Final audible
quality must be verified later on the Debian/Raspberry Pi audio stack.

The first direct-library comparison is complete at decoder level. An isolated
`ffmpeg-next` example decoded the repository MP3 directly in Rust to the same
packed `s16le`, stereo, 44.1 kHz PCM format. It processed about 174.85 seconds
of audio in about 0.22 seconds and produced 30,844,288 bytes. FFmpeg validated
the resulting raw PCM without errors. The normal backend build does not enable
this dependency; the experiment is behind the optional Cargo feature
`direct-ffmpeg-library-spike`. Live PulseAudio output, pause/resume, stop
semantics, and long-running behavior still need a like-for-like comparison
before selecting the production adapter.

**Rationale:**
- Typed media operations are safer and easier to evolve than generic command
	strings.
- Separate services preserve fachliche boundaries while one proto file keeps
	code generation manageable.
- SQLite provides durable playlist and resume state on an embedded system.
- Explicit source and media statuses distinguish an unavailable device from a
	file removed from an available device.
- A local FFmpeg spike reduces the risk of choosing an audio stack before
	validating Debian and Raspberry Pi packaging constraints.

**Consequences:**
- The proto contract must define three independent event streams and stable
	identifiers for media, playlist entries, and scans.
- The backend needs a media library, playback manager, central audio manager,
	SQLite persistence, and a decoder/output adapter.
- USB discovery, settings UI, and advanced queue editing are separate follow-up
	work and must not be smuggled into the first playback contract.

**Related decisions:**
- ADR-001 (Flutter frontend and Rust backend)
- ADR-002 (gRPC over Unix domain socket)
- ADR-004 (SQLite persistence)
- ADR-005 (gRPC streaming)
- ADR-009 (module organization)
- ADR-015 (single protobuf communication contract)

---

## ADR-017: Speech Recognition and Voice Control - sherpa-onnx for Offline ASR

**Status:** Accepted

**Context:**
Voice control is a natural interaction method for in-vehicle systems, allowing hands-free operation while driving. The system requires speech recognition that works offline (no cloud dependency), respects privacy (GDPR-compliant), runs efficiently on Raspberry Pi 4, and integrates with the existing audio architecture.

**Decision:**
Use [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) as the speech processing toolkit for offline Automatic Speech Recognition (ASR), Voice Activity Detection (VAD), and optional keyword spotting (wake-word detection). Integrate microphone input into the existing audio manager architecture.

**Rationale:**
- **Fully offline**: No cloud dependency; all processing on-device ensures privacy and eliminates network latency
- **GDPR-compliant**: No voice data leaves the device
- **ARM64/Raspberry Pi support**: Proven to run efficiently on embedded ARM processors
- **Comprehensive feature set**: Provides ASR, VAD, keyword spotting, speaker diarization, and TTS in one toolkit
- **ONNX Runtime**: Uses optimized neural models with low latency
- **Rust bindings available**: Can be integrated directly into the Rust backend
- **Active maintenance**: Regular updates and model releases via GitHub and Hugging Face
- **Multi-language**: Supports German and English models

**Alternatives considered:**
- **CMU Sphinx / Pocketsphinx** – older technology; less accurate; limited model updates
- **Vosk** – good offline option but heavier resource footprint; less modular than sherpa-onnx
- **Mozilla DeepSpeech** – no longer actively maintained (archived project)
- **Google Cloud Speech / AWS Transcribe** – requires network; privacy concerns; violates offline-first principle
- **Whisper (OpenAI)** – excellent accuracy but too resource-intensive for Raspberry Pi 4 real-time use

**Audio Architecture Integration:**
The existing audio manager (see ADR-016 and `docs/20-media-backend-plan.md`) must be extended to coordinate multiple audio sources:

**Audio sources with priorities:**
- **Critical (highest)**: Navigation announcements, system sounds
- **Interactive (medium)**: Speech recognition (microphone input + processing)
- **Background (lowest)**: Media player (music/audio)

**Ducking strategies** (configurable in `carnine.toml`):
- **Pause**: Lower-priority source is paused during higher-priority activity
- **Duck**: Lower-priority source volume reduced to configurable level (e.g., -20dB)
- **Mix**: Both sources play simultaneously (only for compatible combinations)

When speech recognition is active, the audio manager:
1. Signals the media player to duck or pause (via audio manager events)
2. Grants exclusive microphone access to the speech service
3. Processes audio through sherpa-onnx ASR pipeline
4. After speech ends (VAD-detected or manual stop), releases microphone
5. Signals media player to resume normal volume/playback

**Proto Contract:**
Introduce a new `SpeechService` in `carnine.proto` alongside `MediaService` and `AudioService`:

```protobuf
service SpeechService {
  rpc GetVersion(VersionRequest) returns (VersionResponse);
  rpc StartListening(StartListeningRequest) returns (StartListeningResponse);
  rpc StopListening(StopListeningRequest) returns (StopListeningResponse);
  rpc StreamSpeechEvents(StreamSpeechEventsRequest) returns (stream SpeechEvent);
  rpc SetLanguage(SetLanguageRequest) returns (SetLanguageResponse);
  rpc ExecuteCommand(ExecuteCommandRequest) returns (ExecuteCommandResponse);
}

message SpeechEvent {
  oneof event {
    TranscriptionUpdate transcription = 1;    // Live transcription during speech
    CommandRecognized command = 2;            // Recognized command with intent
    CommandExecuted executed = 3;             // Confirmation of execution
    SpeechError error = 4;                    // Error during recognition
  }
}

message CommandRecognized {
  string intent = 1;                          // e.g., "play_media", "navigate_to"
  map<string, string> entities = 2;           // e.g., {"artist": "Kensington Road"}
  float confidence = 3;                       // 0.0 - 1.0
}
```

Extend `AudioService` events:
```protobuf
message AudioEvent {
  oneof event {
    // ... existing events ...
    MicrophoneStarted microphone_started = 7;
    MicrophoneStopped microphone_stopped = 8;
    SpeechDetected speech_detected = 9;
    SpeechEnded speech_ended = 10;
  }
}
```

**Command routing:**
A `CommandRouter` component in the backend maps recognized intents to service actions:
- `"play_media"` + `{"artist": "X"}` → `MediaService.SearchMedia` + `PlayMedia`
- `"pause"` → `MediaService.Pause`
- `"navigate_to"` + `{"location": "Y"}` → `NavigationService.StartRoute` (future)
- `"volume_up"` → Audio system volume control (future)

**Configuration in `carnine.toml`:**
```toml
[audio]
backend = "alsa"         # or "pulse"
output_device = "plughw:1,0"
input_device = "plughw:2,0"  # Microphone ALSA device
ducking_behavior = "duck"    # or "pause", "mix"
ducking_level_db = -20       # Volume reduction during ducking

[speech]
enabled = true
language = "de-DE"           # or "en-US"
model_path = "/usr/share/carnine/speech-models"
push_to_talk = false         # true = manual, false = continuous VAD
vad_threshold = 0.5          # Voice Activity Detection sensitivity
wake_word = ""               # Optional wake word (e.g., "Hey Carnine")
```

**Implementation phases:**
1. **Phase 1 (MVP)**: Basic microphone integration, sherpa-onnx ASR, simple pattern-matching command parser
2. **Phase 2**: VAD-based automatic activation, audio manager ducking coordination
3. **Phase 3**: Wake-word detection, advanced NLU with ONNX intent models, TTS feedback

**Consequences:**
- Microphone hardware (USB or built-in) must be present and configured in ALSA/PulseAudio
- ONNX models for German/English must be packaged in Debian image (`resources/speech-models/`)
- Audio manager becomes more complex (coordinates output + input, multiple source priorities)
- Speech recognition adds CPU/memory load; must be profiled on Raspberry Pi 4
- Privacy-friendly: all voice data stays on-device; no cloud API keys needed
- Commands are processed in real-time without network latency
- Future TTS integration (sherpa-onnx also supports TTS) enables full voice assistant experience

**Related decisions:**
- ADR-016 (Media Architecture) – audio manager concept, event streams
- ADR-004 (SQLite) – potential for voice command history/preferences storage
- ADR-008 (Error handling) – speech errors propagate via `anyhow::Result`
- ADR-010 (Logging) – speech processing logged via `tracing`

**References:**
- [sherpa-onnx GitHub](https://github.com/k2-fsa/sherpa-onnx)
- [sherpa-onnx Rust bindings](https://github.com/k2-fsa/sherpa-onnx/tree/master/sherpa-onnx/rust)
- Issues: #15 (Microphone/Speech Backend), #16 (Audio Manager), #17 (Command Parser), #18 (Speech UI)

---

## ADR-017: UI Readiness and Plymouth Handoff

**Status:** Accepted

**Context:**
The DRM/KMS frontend must replace the Plymouth splash without briefly exposing
the `getty` login console. The frontend also needs a bounded failure path when
it cannot start.

**Decision:**
Expose `SystemService.ReportUiReady` over the existing gRPC channel. Flutter
calls it after its first frame has been rendered. After the backend acknowledges
the call, Flutter sends `READY=1` to systemd. The frontend unit uses
`Type=notify` with a 30-second startup timeout, and `plymouth-quit.service` is
ordered after it.

**Rationale:**
- The UI is the only component that can verify that a frame is visible.
- The backend receives an explicit lifecycle event without gaining root
  privileges.
- systemd remains responsible for service state, timeouts, restarts, and the
  privileged Plymouth operation.
- A failed or stalled UI cannot leave Plymouth visible forever.

**Consequences:**
- The shared protobuf schema and generated clients must be regenerated when the
  system service changes.
- The frontend package requires `/usr/bin/systemd-notify` at runtime.
- The 30-second timeout releases Plymouth to the usable virtual console when
  the UI does not become ready.
- Future power-management events can use the same `SystemService` boundary;
  shutdown execution should remain in a dedicated privileged systemd unit.

---

## ADR-018: Single Release Version Source

**Status:** Accepted

**Context:**
The release version was duplicated in Cargo, Flutter, Debian metadata, the
Plymouth theme, and backend service responses.

**Decision:**
The repository-root `VERSION` file is the single release-version source. The
Pi build passes it to Cargo, Flutter, Debian packaging, and Debos. Rust embeds
the same value for both existing `GetServiceVersion` RPCs. Plymouth replaces
its template token from the Debos `version` parameter.

**Consequences:**
- Release builds must pass `-t version:$(cat ../VERSION)` to Debos.
- Flutter's technical build number remains independent from the release
  version and can be added separately when needed.
- Build scripts can reject malformed versions before producing artifacts.

---

These decisions collectively create a system that is:
- **Safe**: Type-safe languages (Rust, Dart) prevent entire classes of bugs
- **Performant**: Async concurrency and optimized serialization minimize latency
- **Reliable**: Offline-first caching and error handling ensure robustness
- **Maintainable**: Clear module boundaries and strong typing aid long-term development
- **Testable**: Separated frontend/backend and gRPC allow component testing without UI
- **Privacy-focused**: Voice recognition runs entirely on-device with no cloud dependency
