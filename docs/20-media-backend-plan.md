# Media Backend Plan

## Zweck

Dieses Dokument ist die gemeinsame Arbeitsgrundlage fuer die erste Backend-
Unterstuetzung des Audio-Mediaplayers. Es fasst die bestaetigten fachlichen
Entscheidungen und die geplante Reihenfolge zusammen. Es ersetzt weder die
Architekturentscheidungen in `09-architecture-decisions.md` noch die Aufgaben-
liste in `17-ideas-roadmap.md`.

Vor der Umsetzung gilt: Wenn eine neue Anforderung diesem Dokument
widerspricht, muss zuerst die Dokumentation und gegebenenfalls der passende ADR
aktualisiert werden. Danach darf der Proto-Vertrag oder Backend-Code geaendert
werden.

## Ziel der ersten Version

Das Rust-Backend besitzt einen eigenstaendigen Audio-Player fuer lokale
Audiodateien. Das Flutter-Frontend steuert ihn ueber gRPC und zeigt seinen
Zustand an. Der Player muss auch ohne Flutter laufen koennen.

Die erste Version konzentriert sich auf:

- lokale Dateien auf der internen Festplatte
- mehrere konfigurierbare Medienordner
- MP3, FLAC und OGG, soweit der ausgewaehlte Debian-Audio-Stack sie unterstuetzt
- Media-Datenbank in SQLite
- explizit angeforderten vollstaendigen Rescan
- Metadatenimport aus den Audiodateien
- Suche im Backend nach Titel und Interpret
- gespeicherte Playlists
- temporaere Queue
- Play, Pause, Stop, Next und Previous
- Repeat: aus, Queue und einzelner Titel
- Player-, Bibliotheks- und Audio-Ereignisstreams

## Nicht Teil der ersten Version

Diese Punkte bleiben bewusst auf der Todo-Liste:

- automatische USB-Erkennung und USB-Medium-Plugin beziehungsweise Service
- Einstellungen fuer Medienordner und Resume-Modus
- Queue bearbeiten, umsortieren und einzelne Eintraege entfernen
- direkte Titelauswahl und Seek-RPC
- Shuffle-Bedienung
- M3U-Import und -Export
- Party-Modus
- Gapless Playback und Cross-Fading
- Equalizer und SoundCurve
- Video
- getrennte Lautstaerkegruppen
- vollstaendige Audio-System-Policy
- mehrere konkurrierende Steuerclients
- Wiedererkennung verschobener Dateien ueber Hashes

## Service-Grenzen

Alle Services bleiben in der einen Datei `src/proto/carnine.proto`:

### CarnineService

Bestehende Schnittstelle fuer CAN-Daten waehrend der aktuellen Aufbauphase.
Generische Command-RPCs gehoeren nicht zum Vertrag. Eine spaetere fachliche
Schnittstelle fuer Fahrzeugdaten und eine getrennte Schnittstelle fuer die
Fahrzeug-Ansteuerung werden separat definiert.

### MediaService

Zustaendig fuer:

- Service-Version
- Medienbibliothek und Quellen
- vollstaendigen Rescan
- Backend-Suche
- Playlists
- Queue
- Player-Steuerung
- Player-Zustand
- Player-Ereignisse
- Bibliotheks-Ereignisse

### AudioService

Zustaendig fuer den zentralen Audio-Manager und seine Ereignisse. Er
transportiert keine Audiodaten. Er soll spaeter unter anderem Musik,
Systemklaenge und Navigationsansagen koordinieren.

Jeder Service bekommt eine dreiteilige Version mit `major`, `minor` und
`patch`. Faehigkeiten und unterstuetzte Formate werden dokumentiert, aber in
der ersten Version nicht programmatisch abgefragt.

## Konfiguration

Die versionierte Laufzeit-Konfigurationsvorlage liegt in
`resources/config/carnine.yaml`. Im installierten System wird sie als
`/etc/carnine/config.yaml` verwendet. Das Debos-Rezept
`resources/debos/raspbian.yaml` bleibt ausschliesslich fuer Image-Aufbau und
Pakete zustaendig.

Die Konfiguration enthaelt mindestens:

- gRPC-Adresse
- Medienordner und SQLite-Datenbankpfad
- unterstuetzte Audioformate und Rescan-Verhalten
- Audio-Backend, ALSA-Geraet, Sample-Rate und Kanalzahl
- Verhalten bei Navigationsansagen
- Log-Verzeichnis und Log-Level

Hardware- und deployment-spezifische Werte wie das ALSA-Geraet duerfen fuer
den Zielrechner angepasst werden. Fuer den aktuell getesteten Pi ist HDMI 0
als `plughw:1,0` eingetragen. Geheimnisse gehoeren nicht in diese Datei.

Die UI aendert diese Datei nicht direkt. Ein spaeterer typisierter
`ConfigService` liest und schreibt die Konfiguration ueber das Backend. Das
Backend validiert die Werte, speichert sie atomar und meldet zurueck, ob eine
Aenderung sofort uebernommen wurde oder einen Neustart benoetigt. Audio-
Ausgang, Medienordner, Resume-Modus und Log-Level sind als Laufzeit-
Konfiguration vorgesehen; die gRPC-Bind-Adresse bleibt eine
Startkonfiguration.

## Medienquellen und Rescan

- Es gibt mehrere Medienquellen beziehungsweise Ordner.
- Der Hauptordner wird spaeter ueber Einstellungen festgelegt.
- USB-Datentraeger werden spaeter automatisch erkannt.
- Ein vollstaendiger Rescan wird explizit angefordert.
- Der Rescan aktualisiert die SQLite-Media-Datenbank.
- Ein Rescan laeuft nicht waehrend der Wiedergabe.
- Der Rescan meldet Fortschritt in einem eigenen Bibliotheksstream.
- Gueltige Dateien werden importiert oder aktualisiert.
- Nicht lesbare Dateien werden nicht in die Media-Datenbank aufgenommen.
- Nicht lesbare Dateien erzeugen einen Fehler im Bibliotheksstream.
- Eine geloeschte Datei auf einer erreichbaren Quelle wird als `MISSING`
  markiert.
- Eine nicht angeschlossene Quelle wird als `OFFLINE` behandelt.
- Eine Playlist darf auch bei einer offline Quelle wiederhergestellt werden.
- Ein einzelner fehlerhafter Eintrag macht den gesamten Rescan nicht ungueltig.

## Medienmodell

Pflichtdaten eines Media-Eintrags:

- stabile interne Medien-ID, sofern ohne unverhaeltnismaessigen Aufwand
  moeglich
- Titel
- Interpret
- Dateipfad oder URI

Zusaetzlich benoetigt der Player mindestens:

- Dauer in Millisekunden
- Quelle beziehungsweise Source-ID
- Medienstatus

Weitere Metadaten wie Album, Genre, Jahr, Tracknummer, Discnummer und Cover
koennen spaeter ergaenzt werden.

Der initiale Medienstatus unterscheidet:

- `AVAILABLE`: Quelle und Datei sind erreichbar.
- `OFFLINE`: Die Quelle, zum Beispiel ein USB-Datentraeger, ist nicht
  angeschlossen.
- `MISSING`: Die Quelle ist erreichbar, aber die Datei ist nicht mehr da.

Dateien werden beim ersten Import anhand ihrer Quelle und ihres Pfads
wiedererkannt. Eine robuste Erkennung verschobener Dateien ueber Hashes ist
nicht Teil der ersten Version.

## Playlist und Queue

Eine Playlist ist eine dauerhaft unter einem Namen gespeicherte, geordnete
Liste von Playlist-Eintraegen. Ein Titel darf mehrfach in derselben Playlist
vorkommen. Deshalb verweist jeder Playlist-Eintrag separat auf eine Media-ID
und besitzt eine eigene Eintrags-ID.

Es gibt zwei getrennte Konzepte:

- Die gespeicherte Playlist wird in SQLite dauerhaft gehalten.
- Die temporaere Queue existiert fuer die laufende Sitzung.

Eine Queue ohne aktive Playlist ist nach einem Neustart leer. Wird ein einzelner
Titel gestartet, erstellt das Backend daraus eine temporaere Queue mit diesem
Titel.

Beim Laden einer Playlist gilt exakt diese Reihenfolge:

1. aktuelle Wiedergabe stoppen
2. aktuelle Queue loeschen
3. Playlist in die Queue uebernehmen
4. aktive Playlist setzen
5. gespeicherten Titel beziehungsweise Playlist-Eintrag auswaehlen
6. gespeicherte Position auswaehlen
7. Wiedergabe pausiert lassen

Die Queue wird durch `Stop` nicht veraendert.

## Wiedergabe und Persistenz

Erste Steuerbefehle:

- `Play`
- `Pause`
- `Stop`
- `Next`
- `Previous`

`Stop` beendet die Audioausgabe und setzt den aktuellen Titel an den Anfang.
`Previous` wechselt in der ersten Version immer zum vorherigen Queue-Eintrag.

Repeat unterstuetzt:

- aus
- gesamte Queue
- einzelner Titel

Gespeichert werden aktive Playlist, aktueller Playlist-Eintrag, Position und
Resume-Modus. Es gibt drei Resume-Modi:

- Playlist wiederherstellen und pausiert stehen bleiben
- Playlist wiederherstellen und automatisch abspielen
- Playlist wiederherstellen und am Anfang des letzten Titels starten

Die Queue ohne aktive Playlist wird nicht dauerhaft gespeichert.

Die Wiedergabeposition wird nur waehrend laufender Wiedergabe periodisch
persistiert. Alle zehn Sekunden wird der zuletzt bekannte Stand vor dem
aktuellen Intervall gespeichert. Ein expliziter Seek wird erst spaeter als
RPC eingefuehrt; dann soll sein Zeitpunkt sofort gespeichert werden. Beim
Beenden gilt fuer den periodischen Stand der naechste planmaessige
Speichervorgang.

## Ereignisstreams

Es gibt drei getrennte Streams:

### Player-Stream

Liefert beim Oeffnen zuerst einen vollstaendigen Snapshot und danach Updates zu:

- Player-Status
- aktuellem Media-Eintrag
- Playlist und Queue
- Position und Dauer
- Repeat und Shuffle
- Titelwechsel
- Play, Pause und Stop
- Wiedergabefehlern

### Bibliotheksstream

Liefert:

- Scan gestartet
- Fortschritt
- importierte und aktualisierte Dateien
- entfernte oder fehlende Dateien
- uebersprungene Dateien
- nicht lesbare Dateien mit Fehler
- Scan abgeschlossen oder fehlgeschlagen

### Audiostream

Dies ist kein Audio-Datenstrom. Er liefert Status- und Steuerereignisse des
zentralen Audio-Managers, spaeter zum Beispiel:

- Audioquelle gestartet oder beendet
- Navigationsansage gestartet oder beendet
- Ducking gestartet oder beendet
- Musik pausiert oder fortgesetzt
- Audiofehler

## Audio-Manager und Unterbrechungen

Der zentrale Audio-Manager sitzt im Backend. Media, Navigation und andere
Backend-Komponenten sprechen ihn an. Das Verhalten bei Navigationsansagen soll
konfigurierbar sein, mindestens zwischen:

- Musik pausieren
- Musik leiser machen

Die Lautstaerke wird in der ersten Version nicht durch den MediaService
verwaltet. Getrennte Lautstaerkegruppen und die vollstaendige Audio-System-
Policy kommen spaeter.

## FFmpeg- und Audio-Entscheidung

FFmpeg ist die bevorzugte erste Decoder-Richtung. Die WSL2-Pruefung auf Ubuntu
24.04 war erfolgreich:

- WSLg stellt PulseAudio ueber `unix:/mnt/wslg/PulseServer` bereit.
- Der Default-Sink ist `RDPSink`.
- MP3, FLAC und OGG wurden mit FFmpeg dekodiert.
- Die Repository-MP3 wurde ueber FFmpeg und `paplay` hoerbar abgespielt.
- WSL bietet kein physisches ALSA-Zielgeraet; Raspberry-Pi-Ausgabe ist daher
  noch nicht validiert.

Die erste Implementierung soll einen externen FFmpeg-Prozess als austauschbaren
Decoder-Adapter pruefen. Der `PlaybackManager` soll die konkrete Decoder-
Technik nicht kennen. Eine direkte FFmpeg-Library-Integration bleibt als
zweite Variante moeglich.

Der isolierte Rust-Spike unterstuetzt inzwischen die Prozessbefehle `play`,
`pause` und `stop`. `pause` und `play` halten FFmpeg und `paplay` gemeinsam an
beziehungsweise setzen sie fort. `stop` beendet beide Prozesse kontrolliert.
Diese Signale sind nur ein Spike-Mechanismus; die produktive Media-API muss
spaeter einen eigenen Player-Zustand und eine belastbare Audio-Engine-
Abstraktion verwenden.

Verglichen werden:

- Startzeit bis zum ersten Ton
- CPU- und Speicherverbrauch
- Play, Pause, Stop und Prozessende
- Position und Titelwechsel
- Fehler bei fehlenden oder beschaedigten Dateien
- langfristige Stabilitaet
- Debian-Paketierung und ARM64-Portierbarkeit
- Erweiterbarkeit fuer Ducking und spaetere SoundCurve

Die gemeinsame Audioausgabe bleibt bei beiden Varianten gleich. Die
Entscheidung wird vor der Raspberry-Pi-Implementierung dokumentiert.

## Repository-Testmedium

Die Datei `resources/musik/1-Here We Go Now (Single Edit).mp3` ist als
Testmedium im Repository vorhanden. Laut bestaetigter Freigabe der Band darf
sie mit dem Repository verbreitet werden.

Bekannte Metadaten:

- Titel: `Here We Go Now (Single Edit)`
- Interpret: `Kensington Road`
- Album: `Here We Go Now`
- Format: MP3, 128 kbit/s, 44.1 kHz
- Dauer: ungefaehr 175 Sekunden

## Implementierungsreihenfolge

1. WSL-FFmpeg- und PulseAudio-Spike abschliessen.
2. Externen FFmpeg-Prozess in einem kleinen Rust-Testprogramm kapseln.
3. PCM-Ausgabe, Play, Pause, Stop, Prozessfehler und Titelende testen.
4. Direkte FFmpeg-Library-Variante als isolierten Vergleich pruefen.
5. Decoder-Entscheidung und Debian-Paketierung dokumentieren.
6. Proto-Vertrag in `src/proto/carnine.proto` entwerfen und bestaetigen.
7. Rust- und Dart-Stubs neu generieren.
8. AudioEngine-Abstraktion und austauschbaren Audioausgabe-Adapter implementieren.
9. MediaService mit Player-Steuerung und Player-Zustand implementieren.
10. AudioService mit Mock-Audio-Manager und Ereignisstream implementieren.
11. SQLite-Schema und Migrationen implementieren.
12. Media-Rescan, Suche, Playlist, Queue und Resume integrieren.
13. Debian-/Debos-Integration und anschliessend Raspberry-Pi-Test durchfuehren.

### Aktueller Arbeitsabschnitt

Der Backend-Fokus fuer den aktuellen Arbeitsabschnitt ist die MediaService-
Vertikalscheibe ohne Flutter:

- `AudioEngine` bleibt die technische Austauschgrenze.
- `MediaPlayer` kapselt Player-Befehle und Zustand.
- `MediaService` stellt Version, Play, Pause, Stop und Player-Zustand ueber
  typisierte gRPC-RPCs bereit.
- Tests verwenden zunaechst den Rust-Service und den Pi als Zielsystem.
- Flutter-Stubs und Flutter-UI werden erst nach Abschluss des Backend-Vertrags
  und der Backend-Tests angepasst.

## Aktueller Stand

Erledigt:

- fachliche Anforderungen fuer die erste Version abgestimmt
- ADR-016 erstellt
- Runtime-Ablauf dokumentiert
- Media-Todos und zurueckgestellte Funktionen dokumentiert
- WSLg-PulseAudio-Endpunkt bestaetigt
- MP3-, FLAC- und OGG-Dekodierung bestaetigt
- Repository-MP3 erfolgreich ueber FFmpeg abgespielt
- FFmpeg-Dekodierung ohne Audioausgabe isoliert bestaetigt
- dekodierte PCM-WAV ueber `paplay` isoliert bestaetigt
- FFmpeg direkt zum WSLg-PulseAudio-Sink isoliert bestaetigt
- ein 60-Sekunden-Test ohne Rust ueber FFmpeg direkt zu WSLg/PulseAudio zeigte
  ebenfalls deutlich hoerbare Aussetzer
- direkte `ffmpeg-next`-Library-Dekodierung als isoliertes Rust-Example
- direkte Library-PCM-Ausgabe unabhaengig mit FFmpeg validiert

Noch offen:

- vollstaendiger Vergleich externer Prozess gegen FFmpeg-Library fuer Live-
  Ausgabe, Pause/Resume und Langzeitverhalten; der reine Decoder-Vergleich ist
  abgeschlossen
- Rust-PCM-Pipe und Prozess-Signalsteuerung auf Audioaussetzer und
  Pause-Latenz untersuchen; Decoder und PulseAudio-Einzeltests sind unauffaellig
- WSLg/PulseAudio-Ausgabe fuer subjektive Audioqualitaet als bekannte
  Testeinschraenkung behandeln
- konkrete Audioausgabe und Paketierung fuer Debian/Debos
- Proto-Entwurf und Abnahme
- SQLite-Schema und Migrationen
- Backend-Implementierung
- Raspberry-Pi-Hardwaretest
