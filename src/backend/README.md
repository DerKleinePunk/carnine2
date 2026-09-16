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

### Audio-Ausgang

Die Wiedergabe laeuft ausschliesslich ueber `cpal`: beim Start oeffnet das
Backend einen einzigen dauerhaften Ausgabestream auf dem vom Betriebssystem
gemeldeten Standard-Ausgabegeraet. Es gibt keinen Umschalter und keinen
Software-/Dummy-Fallback mehr — existiert kein Standardgeraet (z. B. WSL
ohne WSLg-Audio, Container, CI), scheitert der Start mit einer Fehlermeldung.

Der cpal-Pfad verwendet die ALSA-Laufzeitbibliothek. Das Image installiert
`libasound2t64` explizit; `alsa-utils` bleibt fuer Diagnose, Hardwaretests
und die Lautstaerkeregelung (`amixer`) enthalten.

Die Lautstaerkeregelung (`AudioService.GetVolume`/`SetVolume`, `audio_volume.rs`)
erkennt beim Start des Backends einmalig, welches Werkzeug tatsächlich einen
Mixer/Sink erreicht, und legt das für die gesamte Laufzeit des Prozesses fest
(keine Neupruefung pro Aufruf, kein Config-Schalter):

1. `amixer -c 0 get PCM` gegen eine echte ALSA-Hardwarekarte (Raspberry Pi).
2. Falls das fehlschlaegt, `pactl get-sink-volume @DEFAULT_SINK@` gegen einen
   PulseAudio-Sink (z. B. WSLg).
3. Ist auch das nicht erreichbar, bleibt die Lautstaerkeregelung wirkungslos
   (kein Prozessaufruf mehr pro `SetVolume`, nur eine einmalige Warnung beim Start).

Auf der Pi-Hardware faellt die Wahl weiterhin unveraendert auf `amixer`. In WSL2
gibt es dagegen kein ALSA-Kartensystem (`/proc/asound` existiert nicht) — WSLg
stellt Audio nur ueber die PulseAudio-Bridge auf Userspace-Ebene bereit
(`PULSE_SERVER=unix:/mnt/wslg/PulseServer`). Dort greift automatisch der
`pactl`-Pfad, sodass Regler-Verschieben und Stummschalten im Frontend auch in der
lokalen WSL-Entwicklung hoerbar wirken. Die Pakete `libasound2-dev`,
`libavcodec-dev`, `libavformat-dev`, `libavutil-dev`, `libavdevice-dev`,
`libavfilter-dev`, `libswscale-dev`, `libswresample-dev` und
`libpostproc-dev` sind nur fuer lokale beziehungsweise CI-Cross-Builds
erforderlich und gehoeren nicht ins Runtime-Image.

Der lokale ARM64-Sysroot fuer Cross-Builds liegt persistent unter
`build/sysroots/carnine-pi-arm64/`. Dieser Ordner ist absichtlich ignoriert
und wird nicht committed. Die Cross-Build-Variablen verwenden ihn so:

```bash
SYSROOT="$PWD/../../build/sysroots/carnine-pi-arm64"
PKG_CONFIG_ALLOW_CROSS=1 \
PKG_CONFIG_SYSROOT_DIR="$SYSROOT" \
PKG_CONFIG_PATH="$SYSROOT/usr/lib/aarch64-linux-gnu/pkgconfig" \
CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc \
cargo build --release --target aarch64-unknown-linux-gnu
```

Nach einem neuen Pi-Image oder Paketupdate muss der Sysroot erneut vom Pi
synchronisiert werden. Fuer CI ist ein reproduzierbarer ARM64-Container oder
Runner vorgesehen; der lokale Sysroot ist nur ein Entwickler-Cache.

Der Audio-Lifecycle wird ueber `journalctl -u carnine-backend` beobachtet. Die
relevanten Ereignisse sind `cpal audio output stream started`, `cpal audio
source started`, `pause requested`, `resume requested`, `decoder stopped` und
`source removed`.

### Developer start

The repository configuration contains the installed-system paths
`/var/lib/carnine` and `/var/log/carnine`. These directories are normally not
writable by an unprivileged developer account. Start the backend locally with
writable temporary paths:

```bash
CARNINE_LOG_DIRECTORY=/tmp/carnine-log \\
CARNINE_DATABASE_PATH=/tmp/carnine-media.sqlite3 \\
cargo run
```

`cpal` opens the operating system's default output device at startup and
has no configurable backend/device override. On environments without a
usable default output device (e.g. WSL without WSLg audio, containers, CI),
the backend fails to start with an error naming the missing device — there
is no software or dummy fallback.

If startup still fails, the error names the exact path and explains whether a
log directory or the database path needs to be changed. Do not solve local
development errors by running the backend with `sudo`; the installed service
uses `/etc/carnine/config.toml`, `/var/lib/carnine`, and `/var/log/carnine`.

### gRPC-Testclient

Der generierte gRPC-Testclient `media_grpc_client` prueft den laufenden
Backend-Service ohne Flutter, aber nur ueber TCP. Der Backend-Standardtransport
ist inzwischen ein Unix-Domain-Socket (ADR-002); fuer diesen Testclient muss
der optionale TCP-Fallback lokal aktiviert werden:

```bash
CARNINE_SOCKET_PATH=/tmp/carnine-dev.sock \\
CARNINE_TCP_ADDRESS=127.0.0.1:50051 \\
cargo run
```

(`CARNINE_SOCKET_PATH` ist noetig, weil `/run/carnine` root-owned tmpfs ist
und ein normaler Dev-User es nicht selbst anlegen kann - siehe
docs/07-deployment.md §7.4.) Der Endpoint wird als erstes Argument uebergeben;
der im Client fest einkompilierte Default ist `http://[::1]:50051` - mit
obigem Setup stattdessen `http://127.0.0.1:50051` verwenden (siehe unten).

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
cargo run --example media_grpc_client -- http://127.0.0.1:50051 version
cargo run --example media_grpc_client -- http://127.0.0.1:50051 state
cargo run --example media_grpc_client -- http://127.0.0.1:50051 play /path/to/audio.mp3
cargo run --example media_grpc_client -- http://127.0.0.1:50051 pause
cargo run --example media_grpc_client -- http://127.0.0.1:50051 resume
cargo run --example media_grpc_client -- http://127.0.0.1:50051 stop
cargo run --example media_grpc_client -- http://127.0.0.1:50051 playlist 1
cargo run --example media_grpc_client -- http://127.0.0.1:50051 queue-entry 2
cargo run --example media_grpc_client -- http://127.0.0.1:50051 rescan
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
cargo run --example media_grpc_client -- http://127.0.0.1:50051 player-events [count]
cargo run --example media_grpc_client -- http://127.0.0.1:50051 library-events [count]
cargo run --example media_grpc_client -- http://127.0.0.1:50051 audio-events [count]
cargo run --example media_grpc_client -- http://127.0.0.1:50051 player-events 5
```

#### Smoke-Tests

| Befehl | Argument | Ablauf |
| --- | --- | --- |
| `smoke` | `<media-path>` | Startet einen Titel, pausiert nach drei Sekunden, setzt fort und stoppt. |
| `event-smoke` | `<media-path>` | Oeffnet den Player-Stream, startet einen Titel und liest Snapshot sowie Start-Event. |
| `library-smoke` | - | Oeffnet den dauerhaften Library-Stream und startet parallel einen Rescan. |

Beispiele:

```bash
cargo run --example media_grpc_client -- http://127.0.0.1:50051 smoke /path/to/audio.mp3
cargo run --example media_grpc_client -- http://127.0.0.1:50051 event-smoke /path/to/audio.mp3
cargo run --example media_grpc_client -- http://127.0.0.1:50051 library-smoke
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
