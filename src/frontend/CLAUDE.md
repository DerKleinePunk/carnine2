# CLAUDE.md – Frontend (src/frontend)

Diese Datei gilt **nur für das Flutter-Frontend** (`src/frontend/`). Für Backend- oder projektweite Konventionen siehe die jeweiligen `AGENTS.md`-Dateien (Root, Backend).

## Wichtigste Regel: Erst nachfragen, dann handeln

Bevor ich hier Code ändere, Dateien anlege oder eine Architektur-/Design-Entscheidung treffe: Wenn ich nicht zu **mindestens 99 % sicher** bin, **was** Jonas will und **wie** er es umgesetzt haben möchte, frage ich aktiv nach – ich rate nicht und nehme nichts "wahrscheinlich Gemeintes" an.

Das gilt besonders bei:
- UI/UX- und Design-Entscheidungen (das Design-System unten ist verbindlich, keine Freihand-Interpretation)
- Abweichungen von der vorgegebenen Architektur oder dem State-Management-Ansatz
- unklarem Umfang einer Änderung ("nur diese Komponente" vs. "überall")
- mehrdeutigen oder knappen Anweisungen

Lieber eine gezielte Rückfrage stellen, als eine falsche Annahme umzusetzen, die später wieder rückgängig gemacht werden muss.

## Projektkontext

Carnine (CarPC) ist ein selbstgebautes In-Vehicle-Infotainment-System auf einem Raspberry Pi 4. Das Flutter-Frontend läuft als Linux-Fenster auf einem Touchscreen im Fahrzeug und ist **reine Präsentationsschicht**: UI-Widgets (Navigation, Media Player, Telemetrie, Einstellungen, Rückfahrkamera) + State Management + gRPC-Client. Sämtliche Business-Logik, Datenhaltung und CAN-Bus-Kommunikation liegt im Rust-Backend, nicht im Frontend (`docs/05-building-block.md`, ADR-013 in `docs/09-architecture-decisions.md`). Kommunikation läuft in Produktion ausschließlich über gRPC via lokalen Unix-Domain-Socket (ADR-002); Transport-Wahl sitzt zentral in `lib/core/platform/grpc_endpoint.dart`. Für lokale Entwicklung, wenn Flutter und Backend nicht denselben Kernel-/Socket-Namespace teilen (z. B. Flutter als natives Windows-Debug-Target gegen ein Backend in WSL2), gibt es einen expliziten, per Env-Var aktivierten TCP-Loopback-Fallback (`docs/07-deployment.md` §7.4) – das ändert nichts am Sicherheitsmodell in Produktion.

## Arbeitsumfang

Gearbeitet wird **nur am Frontend** (`src/frontend/`). Am Backend (`src/backend/`, `src/proto/`) werden keine Änderungen gemacht. Die Bedienungsanleitung (`docs/bedienung/`) wird mitgepflegt, wenn sich die Bedienung ändert.

## Test-Pi (echtes Gerät)

Merker für die Arbeit am echten Raspberry Pi, Stand 2026-10-02:

| | |
|---|---|
| Gerät | Raspberry Pi 4 Model B, Debian 13 (trixie), per LAN im Heimnetz |
| Hostname | `carnine-pc-843d` (mDNS `carnine-pc-843d.local`, zuletzt 192.168.178.48) |
| Zugang | Benutzer `pi`, Passwort `raspberry` (Image-Standard, noch nicht geändert; bei Änderung hier nachtragen) |
| SSH | `ssh carnine-pi` ohne Passwort. Alias in `~/.ssh/config`, eigener Schlüssel `~/.ssh/id_ed25519_carnine_pi`, öffentlicher Teil auf dem Pi installiert |
| sudo | fragt nach dem Passwort: `echo raspberry \| sudo -S -p "" <befehl>` |
| Dienste | `carnine-backend`, `carnine-frontend` (systemd), Logs mit `sudo journalctl -u carnine-frontend -b` |
| Stand | Image 0.10.0 (`0.10.0+git20261001165750.562f528`), Ton über die Klinke (`/etc/modprobe.d/carnine-audio.conf`: `slots=snd_bcm2835,vc4,vc4`, seit 2026-10-02), kein EDID-Override, das Display meldet sein eigenes EDID (128 Byte, ohne Audio) |

- Das EDID des Displays liegt als Datei unter `E:\Studio-Projekte\CarNine2\edid\edid-panel-carnine-pc-843d.bin` (nicht im Repo).
- Frontend auf den Pi bringen: `build_pi.sh` und `deploy_pi.sh pi@carnine-pc-843d` laufen in WSL (Debian, Benutzer `Daoniyella`). Die Toolchain ist dort seit 2026-10-02 eingerichtet: apt-Pakete, Rust-Ziel `aarch64-unknown-linux-gnu`, `cargo-deb`, Dart-SDK (`~/dart-sdk`), `emb` 0.3.6, `protoc-gen-dart`, emb-Workspace `~/develop/emb-workspace` (Flutter 3.47.5, ivi-homescreen `92c2353a`, Arm-Toolchain und Sysroot geholt), ALSA-Sysroot unter `build/sysroots/carnine-pi-arm64`. Umgebung laden: `. ~/.carnine-env.sh`. Aufruf aus WSL: `cd /mnt/e/Studio-Projekte/CarNine2/carnine2 && . ~/.carnine-env.sh && ./build_pi.sh`.
- **Offen (Stand 2026-10-02): der Frontend-Build läuft noch nicht durch.** (1) Der gepinnte Commit `3114ff6…` von `video_grabber` existiert im Upstream nicht mehr (Historie dort am 2026-10-02 umgeschrieben), `pub get` scheitert. Ein Test mit Pin auf `6e2768c` kam weiter, der Pin wurde wieder zurückgenommen. (2) `emb` 0.3.6 bricht mit „bundle lib/: unexpected file libsqlite3.so“ ab; das Bundle auf dem Pi enthält die Datei aber. Beides mit Michael klären, bevor `pubspec.*` oder emb angefasst werden.
- Das Backend-Paket baut in WSL durch (`resources/debos/carnine-backend.deb`). `deploy_pi.sh` installiert Frontend **und** Backend-Paket und schreibt `config.toml` (die Repo-Config ist identisch mit der auf dem Pi).
- Vor dem ersten Ausprobieren von Frontend-Änderungen auf dem Pi nach dem Weg fragen, nicht raten.

## Relevante Rahmenbedingungen aus docs/ (arc42)

### Hardware & Umgebung (`docs/02-constraints.md`)
- Zielhardware Raspberry Pi 4 – begrenzter RAM/CPU. Keine unnötig schweren Widgets, Effekte oder Animationen.
- Fahrzeugstromnetz kann instabil sein (plötzliche Abschaltungen möglich) – UI darf dadurch keinen inkonsistenten Zustand erzeugen.
- Internet ist nicht garantiert verfügbar – das Frontend zeigt nur an/cached nicht selbst; Offline-Verhalten kommt vom Backend.
- Keine Features, die den Fahrer ablenken – Verkehrssicherheit hat Vorrang vor Spielereien.

### Qualitätsziele mit Frontend-Bezug (`docs/10-quality-requirements.md`)
- Verbindungsverlust zum Backend muss innerhalb von **≤500 ms** erkannt und mit Fehler-Banner angezeigt werden – kein stilles Hängen der UI.
- Startet die UI, bevor das Backend bereit ist: sichtbarer Wartezustand mit Retry, keine eingefrorene Oberfläche.
- Bei 10+ Hz Updates (z. B. Telemetrie-Stream) muss die UI ruckelfrei bleiben – Ziel **≥60 FPS**.
- App-Start **<3 s**, Input-Latenz **<50 ms**, Gesamt-RAM-Budget der App **<200 MB**.

### Cross-Cutting Concepts (`docs/08-crosscutting.md`)
- Logging ausschließlich über `dart:developer` `log()`, niemals `print` (Weiterleitung ans Backend via gRPC vorgesehen).
- Fehlerbehandlung: try-catch mit nutzerfreundlichen Error-Dialogen statt Abstürzen; graceful degradation bei nicht-kritischen Features.
- i18n: Deutsch ist Primärsprache, Englisch Fallback (Flutter `intl`). **Zusätzlich müssen alle aktuell implementierten Sprachen immer direkt mit unterstützt werden** – kein Verlassen auf den Englisch-Fallback bei neuen oder geänderten Texten. Maßgeblich ist die Liste in `lib/l10n/app_language_option.dart` (Stand bei Erstellung dieser Datei: de, en, fr, es, it, zh, ja, nl, pl, hu, tr, pt, cs, sv, da). Jeder neue `AppTextKey`/UI-Text wird für **alle** dort gelisteten Locales sofort mitübersetzt, nicht nur DE/EN.
- Testing: Widget- und Unit-Tests, `Mockito` zum Mocken des gRPC-Clients.
- Sicherheit: IPC läuft lokal über Unix-Domain-Socket, kein eigener Auth-Flow im Frontend nötig; keine sensiblen Daten hart codieren.

### Design-System ist verbindliche Quelle der Wahrheit (`docs/08-crosscutting.md` §8.10, `docs/stitch_car_pc/`)
Das Stitch-Projekt ist Source of Truth für Screens, Komponenten, Spacing und visuelle Hierarchie – Flutter-Implementierung folgt den freigegebenen Templates, keine freihändigen Design-Entscheidungen. Designsprache laut `docs/stitch_car_pc/aether_drive/DESIGN.md` ("Automotive Tactile Maximalism" / "Kinetic Cockpit"):
- Ultra-dunkle OLED-Flächen (`surface` #0e0e0e) + Neon-Akzente (`primary` #81ecff, `secondary` #ff51fa) statt flachem Mobile-Look.
- Keine Trennlinien/Borders zur Sektionierung – Struktur entsteht über Surface-Container-Ebenen (`surface` → `surface_container` → `surface_container_highest`).
- Typografie: **Space Grotesk** für Headlines/große Metriken (z. B. Geschwindigkeit), **Manrope** für Body-Text/Listen.
- Touch-Targets **mindestens 76–80dp** – im Fahrzeugkontext eine Sicherheitsanforderung, kein Stilmittel.
- Animationen **maximal 200 ms**.
- Kein reines Weiß (#ffffff) für Fließtext – stattdessen `on_surface_variant` (#ababab).
- Bei Unsicherheit, ob eine UI-Änderung vom Design-System abweicht: nachfragen (siehe Regel oben), nicht frei improvisieren.

### Flutter-Version-Updates
Auf dem Pi läuft das Frontend unter ivi-homescreen und wird mit `emb_cli` gebaut (ADR-020, `docs/07-deployment.md` §3.3). Maßgeblich ist die Flutter-Version im emb-Workspace (derzeit 3.47.5), nicht die im `PATH`. Ein Update der Flutter-Version nur zusammen mit dem emb-Workspace, und nur auf eine Version, für die emb eine vorgebaute arm64-Engine liefert. Danach auf dem Pi prüfen, nicht nur lokal. Die Karte (`local_map`) ist auf derselben Version gemessen; ein Versionswechsel wird mit der Karten-Sitzung abgestimmt.

## Verhältnis zu AGENTS.md

`src/frontend/AGENTS.md` enthält die verbindlichen Code-Konventionen (Naming, Ordnerstruktur, GoRouter, JSON-Serialisierung, Testing-Tools, State-Management-Vorgaben). Diese Datei ergänzt das um den architektonischen Kontext aus `docs/` sowie um die Nachfrage-Pflicht für die Zusammenarbeit. Bei Widersprüchen: `AGENTS.md` gilt für Code-Konventionen, diese Datei gilt für die Zusammenarbeitsregeln.
