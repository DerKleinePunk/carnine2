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

Carnine (CarPC) ist ein selbstgebautes In-Vehicle-Infotainment-System auf einem Raspberry Pi 4. Das Flutter-Frontend läuft als Linux-Fenster auf einem Touchscreen im Fahrzeug und ist **reine Präsentationsschicht**: UI-Widgets (Navigation, Media Player, Telemetrie, Einstellungen, Rückfahrkamera) + State Management + gRPC-Client. Sämtliche Business-Logik, Datenhaltung und CAN-Bus-Kommunikation liegt im Rust-Backend, nicht im Frontend (`docs/05-building-block.md`, ADR-013 in `docs/09-architecture-decisions.md`). Kommunikation läuft ausschließlich über gRPC via lokalen Unix-Domain-Socket.

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

## Verhältnis zu AGENTS.md

`src/frontend/AGENTS.md` enthält die verbindlichen Code-Konventionen (Naming, Ordnerstruktur, GoRouter, JSON-Serialisierung, Testing-Tools, State-Management-Vorgaben). Diese Datei ergänzt das um den architektonischen Kontext aus `docs/` sowie um die Nachfrage-Pflicht für die Zusammenarbeit. Bei Widersprüchen: `AGENTS.md` gilt für Code-Konventionen, diese Datei gilt für die Zusammenarbeitsregeln.
