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

### gRPC-Testclient

Der generierte gRPC-Testclient `media_grpc_client` prueft den laufenden
Backend-Service ohne Flutter. Der Endpoint wird als erstes Argument uebergeben;
der Standard-Endpoint im Client ist `http://[::1]:50051`.

Allgemeines Format:

```bash
cargo run --example media_grpc_client -- <endpoint> <command> [argument]
```

#### Einzelbefehle

| Befehl | Argument | Zweck |
| --- | --- | --- |
| `version` | - | Liest die Version des `MediaService`. |
| `state` | - | Gibt Status, aktuellen Pfad, Position, Dauer und `playlist_id` aus. |
| `play` | `<media-path>` | Startet eine lokale Audiodatei als temporaere Ein-Titel-Queue. |
| `pause` | - | Pausiert die aktuelle Wiedergabe. |
| `resume` | - | Setzt die aktuelle Wiedergabe fort. |
| `stop` | - | Stoppt die Wiedergabe und setzt den aktuellen Titel zurueck. |
| `playlist` | `<playlist-id>` | Laedt eine gespeicherte Playlist mit dem konfigurierten Resume-Modus. |
| `queue-entry` | `<index>` | Startet einen Eintrag der aktuellen Queue; der Index beginnt bei `0`. |
| `rescan` | - | Startet einen vollstaendigen Medienscan und gibt dessen Events aus. |

Beispiele:

```bash
cargo run --example media_grpc_client -- http://[::1]:50051 version
cargo run --example media_grpc_client -- http://[::1]:50051 state
cargo run --example media_grpc_client -- http://[::1]:50051 play /path/to/audio.mp3
cargo run --example media_grpc_client -- http://[::1]:50051 pause
cargo run --example media_grpc_client -- http://[::1]:50051 resume
cargo run --example media_grpc_client -- http://[::1]:50051 stop
cargo run --example media_grpc_client -- http://[::1]:50051 playlist 1
cargo run --example media_grpc_client -- http://[::1]:50051 queue-entry 2
cargo run --example media_grpc_client -- http://[::1]:50051 rescan
```

`queue-entry` setzt voraus, dass zuvor eine Playlist geladen oder ein Titel
gestartet wurde. Bei einem ungueltigen Index oder ohne aktive Wiedergabe
antwortet das Backend mit einem Fehler.

#### Event-Streams

| Befehl | Argument | Zweck |
| --- | --- | --- |
| `player-events` | `[count]` | Liest Player-Snapshots und Live-Events. |
| `library-events` | `[count]` | Liest Rescan- und Library-Events. |
| `audio-events` | `[count]` | Liest Audio-Manager-Events. |

Ohne `[count]` wird genau ein Event gelesen. Mit einer Zahl werden mehrere
Events gelesen. `player-events` liefert beim Verbinden zuerst einen Snapshot;
waehrend laufender Wiedergabe folgt ungefaehr einmal pro Sekunde ein
`position_changed`-Event.

Beispiele:

```bash
cargo run --example media_grpc_client -- http://[::1]:50051 player-events [count]
cargo run --example media_grpc_client -- http://[::1]:50051 library-events [count]
cargo run --example media_grpc_client -- http://[::1]:50051 audio-events [count]
cargo run --example media_grpc_client -- http://[::1]:50051 player-events 5
```

#### Smoke-Tests

| Befehl | Argument | Ablauf |
| --- | --- | --- |
| `smoke` | `<media-path>` | Startet einen Titel, pausiert nach drei Sekunden, setzt fort und stoppt. |
| `event-smoke` | `<media-path>` | Oeffnet den Player-Stream, startet einen Titel und liest Snapshot sowie Start-Event. |
| `library-smoke` | - | Oeffnet den dauerhaften Library-Stream und startet parallel einen Rescan. |

Beispiele:

```bash
cargo run --example media_grpc_client -- http://[::1]:50051 smoke /path/to/audio.mp3
cargo run --example media_grpc_client -- http://[::1]:50051 event-smoke /path/to/audio.mp3
cargo run --example media_grpc_client -- http://[::1]:50051 library-smoke
```

Die Pfade muessen fuer den Backend-Prozess erreichbar sein. Der `play`-Befehl
setzt eine temporaere Queue; `playlist` ersetzt die Queue durch die gespeicherte
Playlist. Ein `queue-entry`-Aufruf bezieht sich immer auf die aktuell aktive
Queue und verwendet eine nullbasierte Position.

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
