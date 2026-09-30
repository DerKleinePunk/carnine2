# 05 Building Block View

The Building Block View describes the static structure of the system by decomposing it into hierarchical building blocks. These building blocks represent modules, components, and their relationships. The view starts with a blackbox view of the entire system and refines into levels down to detailed components.

## Level 1: Overall System (Blackbox View)

The CarPC system runs as a standalone unit on the Raspberry Pi 4. It consists of two main building blocks:

- **Flutter Frontend**: Responsible for the user interface and interaction.
- **Rust Backend**: Handles business logic, data processing, and external interfaces.

Relationship: Communication via gRPC over local sockets.

## Level 2: Flutter Frontend (Whitebox View)

The Flutter Frontend is a Dart application running in a Linux window and utilizing the touchscreen.

- **UI Widgets** (`lib/features/`): dashboard, maps (map, routing), media player, settings.
- **State Management**: Manages application state and synchronizes with the backend.
- **gRPC Client**: Sends requests to the backend and receives responses.

Relationships: Widgets interact with state management; gRPC client connects to the backend.

## Level 2: Rust Backend (Whitebox View)

The Rust Backend is a headless service executing the core logic.

- **gRPC Server** (`main.rs`, `server_transport.rs`): Serves `MediaService`, `AudioService`, `ConfigService`, `SystemService`, `NavigationService` and `CarnineService` (src/proto/carnine.proto) on a Unix domain socket, with an optional TCP fallback.
- **Media Player** (`media_player.rs`): Queue, playlists, repeat and shuffle, seek, resume after restart; publishes `PlayerEvent`s.
- **Audio Engine** (`audio_engine.rs`, `cpal_audio_engine.rs`, `audio_source.rs`, `audio_mixer.rs`, `audio_volume.rs`): Decodes with FFmpeg into a ring buffer and plays through ALSA via cpal. `RetryingAudioEngine` keeps the backend running without an audio device. A track counts as finished only when the buffer has played out. Volume goes through the ALSA softvol control (`amixer -M`).
- **Media Library** (`database.rs`, `storage_events.rs`): Scans music folders and USB sticks (UDisks2 over D-Bus) into SQLite and reports progress as `LibraryEvent`s.
- **Data Storage** (`database.rs`): SQLite for the media library, playlists, resume state, UI state and navigation state.
- **Configuration** (`config.rs`): Loads `/etc/carnine/config.toml` and its `config.d` drop-ins, applies `CARNINE_*` overrides and serves `ConfigService`.
- **Navigation** (`navigation/`): GPS mouse over NMEA, clock from GPS, place search, route calculation with a local Valhalla, track recording.
- **Power Supply Link** (`power_supply.rs`, `serial_line.rs`): Talks to the car power supply AuPrV1_1 on `/dev/powersupply` (USB serial or UART), sends the sign of life and publishes its state (docs/23).
- **System Metrics Sampler** (`system_metrics.rs`): Reads CPU temperature, CPU utilisation and load average from `/sys` and `/proc` on a short cadence, and disk usage per filesystem on a slower one. Holds the latest snapshot for `SystemService.GetSystemMetrics` and pushes it to `StreamSystemMetrics` subscribers.
- **CAN-Bus Handler** (planned): `CarnineService.GetCanData` returns a fixed placeholder today. The adapter is a MCP2515 on SPI; its details depend on the vehicle.

Relationships: The gRPC server connects to the frontend and delegates to the other blocks. The audio engine, media library, navigation and power supply link access hardware (sound card, USB storage, GPS mouse, serial line). Relays on the power supply are switched by its own firmware, not by the backend.

## Level 3: Detailed Components (Examples)

- **Navigation Service** (`navigation/service.rs`): Serves `NavigationService`; calculates routes with Valhalla, searches places, streams positions.
- **Media Library** (`database.rs`, `media_player.rs`): Indexes local media and plays it.
- **Settings** (`config.rs`, `ConfigService`): Stores and loads settings; the UI changes them only through `UpdateConfiguration`.

This level can be further refined depending on implementation complexity.
