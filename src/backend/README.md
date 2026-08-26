# Backend (Rust)

Minimal bootstrap service for Carnine.

## Build Dependencies

To build the gRPC code, you need to install Protocol Buffers compiler:

```bash
sudo apt install protobuf-compiler
```

The protobuf schema is shared across frontend and backend at `../proto/carnine.proto`.

## Commands

- `cargo check`
- `cargo run`
- `cargo test`
- `cargo deb`

### Developer start

The repository configuration contains the installed-system paths
`/var/lib/carnine` and `/var/log/carnine`. These directories are normally not
writable by an unprivileged developer account. Start the backend locally with
writable temporary paths:

```bash
CARNINE_LOG_DIRECTORY=/tmp/carnine-log \\
CARNINE_DATABASE_PATH=/tmp/carnine-media.sqlite3 \\
CARNINE_AUDIO_BACKEND=pulse \\
CARNINE_AUDIO_DEVICE=default \\
cargo run
```

On WSL, the repository configuration's ALSA device `plughw:1,0` is not
available. PulseAudio is provided by WSLg, so use the overrides above for
local playback. The installed Raspberry Pi service keeps its ALSA
configuration.

If startup still fails, the error names the exact path and explains whether a
log directory or the database path needs to be changed. Do not solve local
development errors by running the backend with `sudo`; the installed service
uses `/etc/carnine/config.toml`, `/var/lib/carnine`, and `/var/log/carnine`.

The generated-stub gRPC smoke client can be used without Flutter:

```bash
cargo run --example media_grpc_client -- http://[::1]:50051 version
cargo run --example media_grpc_client -- http://[::1]:50051 state
cargo run --example media_grpc_client -- http://[::1]:50051 smoke /path/to/audio.mp3
cargo run --example media_grpc_client -- http://[::1]:50051 playlist 1
cargo run --example media_grpc_client -- http://[::1]:50051 player-events [count]
cargo run --example media_grpc_client -- http://[::1]:50051 library-events [count]
cargo run --example media_grpc_client -- http://[::1]:50051 library-smoke
cargo run --example media_grpc_client -- http://[::1]:50051 audio-events [count]
cargo run --example media_grpc_client -- http://[::1]:50051 rescan
cargo run --example media_grpc_client -- http://[::1]:50051 event-smoke /path/to/audio.mp3
```

`player-events`, `library-events` und `audio-events` lesen standardmaessig ein
Ereignis. Mit `[count]` kann ein Entwickler mehrere Nachrichten beobachten.
Waehren der Player laeuft, erzeugt `player-events` einmal pro Sekunde ein
`position_changed`-Ereignis mit der aktuellen Wiedergabeposition. Der erste
Ticker-Impuls erfolgt direkt nach dem Verbinden.
`library-smoke` oeffnet zuerst den dauerhaften Library-Stream und startet dann
mit einem zweiten Client einen Rescan. `event-smoke` prueft entsprechend den
Player-Snapshot und das Live-Event nach dem Start eines Titels. `playlist <id>`
verwendet den konfigurierten Resume-Modus des Backends.

For manual, dynamic gRPC exploration, `granc` is a suitable external tool.
It needs a protobuf `FileDescriptorSet` when server reflection is not enabled.
The project client remains the regression-test tool because it uses generated
Tonic stubs and therefore fails at compile time when the contract changes.

`cargo deb` erzeugt ein optimiertes Debian-Paket unter `target/debian/`.
Installieren lässt es sich beispielsweise mit:

```bash
sudo apt install target/debian/carnine-backend_0.1.0-1_amd64.deb
```

## Current State

This is an initial executable skeleton. gRPC services and domain modules will be added incrementally.
