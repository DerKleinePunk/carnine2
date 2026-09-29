# Medien

[← Inhalt](README.md)

Die Seite **Medien** hat vier Ansichten: den **Player** (Standard),
**Bibliothek**, **Sammlungen** (Playlists) und **Playlist erstellen**. Über
dem Inhalt können Hinweisbanner erscheinen, siehe [Banner](#banner).

## Player

Links Cover, Titelangaben, Zeitleiste, Tasten und Lautstärke; rechts die
Warteschlange.

![Player: Cover, Titel „Amazing“, Titel 1 von 5, Zeitleiste, Tasten mit Wiederholung an, Lautstärke 61 %, rechts NÄCHSTE TITEL und die Kacheln BIBLIOTHEK und SAMMLUNGEN](bilder/medien-player.png)

- **Cover:** ohne Cover ein Equalizer-Symbol.
- **Titelangaben:** Titel, Interpret, darunter „TITEL 3 VON 19“,
  „EINZELTITEL“ oder „KEINE WIEDERGABE“. Lange Titel werden kleiner
  geschrieben statt abgeschnitten.
- **Zeitleiste:** Position und Dauer (mm:ss, „--:--“ wenn unbekannt).
  Springen durch Antippen oder Ziehen geht noch nicht, dafür gibt es −30 s und
  +30 s.

### Tasten (von links nach rechts)

| Taste | Wirkung | Hinweise |
|---|---|---|
| **Zufall** (⤮) | Zufallswiedergabe an/aus | an = leuchtet, mit Punkt darunter |
| **Zurück** (⏮) | ab 3 s Spielzeit: Titel von vorn; sonst vorheriger Titel | auf dem ersten Titel der Warteschlange und bei Einzeltiteln gesperrt (#33) |
| **−30 s** | 30 Sekunden zurück | am Titelanfang bleibt es bei 0:00 |
| **Wiedergabe/Pause** | pausieren bzw. fortsetzen | grau, wenn kein Titel geladen ist |
| **+30 s** | 30 Sekunden vor | nicht über das Titelende hinaus |
| **Weiter** (⏭) | nächster Titel | am Ende der Warteschlange gesperrt, außer Wiederholung ist an |
| **Wiederholung** (🔁) | jedes Antippen schaltet weiter: **aus → Playlist → aktueller Titel → aus** | aus = grau; Playlist = 🔁 leuchtet; aktueller Titel = 🔂 leuchtet |

Ohne geladenen Titel sind −30 s und +30 s grau. Solange ein Befehl noch beim
Backend in Arbeit ist, sind Zurück, −30 s, Wiedergabe/Pause, +30 s und Weiter
kurz gesperrt. Einen Stopp-Knopf gibt es nicht, und keine
Taste reagiert auf langes Drücken.

Zufall und Wiederholung merkt sich das Backend, auch über einen Neustart.

### Lautstärke

- **Lautsprecher-Symbol:** stumm schalten; noch einmal antippen stellt den
  vorherigen Wert wieder her.
- **Schieberegler** 0–100 mit Prozentanzeige. Bis das Backend den echten Wert
  meldet, steht dort 100 %.
- Nach einem Neustart stellt das Backend den zuletzt gespeicherten Wert
  wieder her, auch 0. Gibt es keinen gespeicherten Wert, beginnt es bei 50 %
  (#47).

### Warteschlange

- Die schmale Leiste mit dem Pfeil klappt die Warteschlange ein und aus.
  Alternativ: auf dem Player **nach links wischen** öffnet, **nach rechts
  wischen** schließt. Eingeklappt wird der Player etwas größer.

  ![Player mit eingeklappter Warteschlange, rechts am Rand nur der Pfeil](bilder/medien-warteschlange.png)
- **NÄCHSTE TITEL** listet die Warteschlange; der laufende Titel ist
  eingerahmt. **Antippen eines Eintrags springt zu diesem Titel.**
- Unten zwei Kacheln: **BIBLIOTHEK** und **SAMMLUNGEN**.

## Bibliothek

Erreichbar über die Kachel **BIBLIOTHEK** unter der Warteschlange; der Pfeil
oben links führt zurück zum Player.

![Bibliothek mit „Aerosmith“ im Suchfeld, Titel mit Interpret und Dauer, rechts oben RESCAN](bilder/medien-bibliothek.png)

- **Suchfeld** „Titel oder Interpret suchen“: öffnet die
  [Bildschirmtastatur](tastatur.md), sucht 300 ms nach dem letzten
  Tastendruck. Gefunden wird auch über den Dateipfad (z. B. Albumordner). Das
  × leert das Feld.
- **RESCAN** (↻ neben dem Suchfeld): liest den Musikordner neu ein;
  während eines Scans grau. Eine Statuszeile zeigt „Scan läuft...“ bzw.
  „x verarbeitet, y importiert“ oder „Scan fehlgeschlagen“.
  Ein Scan liest nur neue und geänderte Dateien (erkannt an Größe und
  Änderungszeit). Der erste Scan nach dem Update auf 0.9.0 liest einmal alles
  und dauert entsprechend lange. Wird das Backend während eines Scans
  beendet, bleiben alle Titel verfügbar, und der nächste Scan macht mit dem
  Rest weiter (#43).
- **Antippen eines Titels spielt ihn als Einzeltitel** (das ▶ am Zeilenende
  zeigt das nur an, es ist kein eigener Knopf). Die Bibliothek bleibt dabei
  offen, es geht nicht automatisch zum Player.
- Nicht abspielbare Dateien sind rot markiert („NICHT VERFÜGBAR“) und
  gesperrt.

### Tipp: eigene Sammlung mit Covern versorgen

Die Bibliothek zeigt ein Cover, wenn das Backend beim Einlesen eines findet:
zuerst das in die Datei eingebettete Bild, sonst ein Bild im selben Ordner
(`cover.jpg`, `cover.png`, `folder.jpg`, `folder.png` oder `AlbumArt…jpg/png`
wie vom Windows Media Player). Ohne Cover steht das Equalizer-Symbol da.
Eingelesen werden in der Standard-Konfiguration nur MP3, FLAC und Ogg
(`supported_formats`), WMA-Dateien erscheinen nicht.

Fehlen bei MP3-Dateien die Cover, hilft
[FindMediaInfo](https://github.com/DerKleinePunk/FindMediaInfo) (Python, am PC):
Es sucht die Dateien ohne eingebettetes Cover, holt passende Bilder über die
Deezer-API, zeigt unsichere Treffer in einer HTML-Seite zur Prüfung und bettet
die bestätigten Cover in die Dateien ein.

```
python -m mp3cover scan <musikordner>        # MP3s ohne Cover finden
python -m mp3cover fetch missing_covers.json # Cover suchen, review.html prüfen
python -m mp3cover embed missing_covers.json # bestätigte Cover einbetten
```

Danach die Dateien in den Musikordner kopieren (oder per
[USB-Stick](#banner)) und in der Bibliothek **RESCAN** antippen. Beim Einlesen
werden die Cover auch bei schon bekannten Titeln neu übernommen.

## Sammlungen (Playlists)

Erreichbar über die Kachel **SAMMLUNGEN**.

![Sammlungen: vier Playlists mit ▶ am Zeilenende, rechts oben ＋](bilder/medien-playlists.png)

- **＋** oben rechts: neue Playlist anlegen (siehe unten).
- **Zeile antippen:** Playlist öffnen (Detailansicht).
- **▶ am Zeilenende:** Playlist sofort starten; die Liste bleibt offen.

### Playlist-Detail

![Playlist „Roadtrip“ mit Cover neben dem Namen, fünf Titeln, PLAYLIST STARTEN und Titel hinzufügen](bilder/medien-playlist-detail.png)

- Neben dem Namen steht das Cover des ersten Titels der Playlist, der eines hat.
- **PLAYLIST STARTEN** oben rechts startet die Playlist und wechselt zum
  Player. Gesperrt, wenn die Playlist leer ist.
- Die Einträge zeigen Titel, Interpret, Dauer; der gerade laufende ist
  eingerahmt. **Einträge sind nicht antippbar** – zu einem Titel springen geht
  über die Warteschlange im Player.
- Titel, die nicht mehr in der Bibliothek sind, stehen rot da („Titel nicht
  mehr in der Bibliothek“).
- **Titel hinzufügen** unten öffnet die Auswahl.

### Titel hinzufügen

Dieselbe Liste wie die Bibliothek (mit Suche und RESCAN), aber
**Antippen fügt den Titel der Playlist hinzu**. Das Symbol rechts zeigt:
Hinzufügen-Symbol (Liste mit ＋) = noch nicht drin, Kreisel = wird
hinzugefügt, ✓ = drin. Ist ein Titel schon enthalten, erscheint kurz „Titel
ist bereits in der Playlist“.

![Titel hinzufügen: Titel mit ✓ sind schon in der Playlist, einer mit dem Hinzufügen-Symbol noch nicht](bilder/medien-titel-hinzufuegen.png)

Umbenennen, Löschen und Titel entfernen gibt es noch nicht (#14).

### Playlist erstellen

![Playlist erstellen: „Roadtrip“ im Feld, Zähler 8/40, darunter die Tastatur](bilder/medien-playlist-erstellen.png)

- Das Feld „Name der Playlist“ (höchstens 40 Zeichen) hat sofort den Fokus.
- **Angelegt wird mit „Fertig“ auf der Bildschirmtastatur** – einen eigenen
  Knopf dafür gibt es noch nicht (#31).
- Fehlermeldungen: „Bitte einen Namen eingeben“, „Eine Playlist mit diesem
  Namen existiert bereits“.
- Danach geht es direkt zu **Titel hinzufügen** für die neue Playlist.
- Der Pfeil oben links führt hier zum **Player**, nicht zu den Sammlungen.

## Banner

Erscheinen oben auf der Medienseite.

| Banner | Wann | Bedienung |
|---|---|---|
| **Verbindung unterbrochen** (rote Wolke) | Backend nicht erreichbar | **ERNEUT VERSUCHEN** verbindet sofort; sonst automatisch alle 0,5–5 s. Verdeckt die anderen Banner. |
| **ffmpeg fehlt** (rotes Warndreieck) | Das Backend kann ffprobe/ffmpeg nicht starten. Titel werden dann ohne Interpret, Dauer und Cover eingelesen. | **RESCAN** startet einen neuen Scan, das Banner verschwindet dabei. Fehlt ffmpeg weiter, kommt es zurück. Es lässt sich nicht schließen. |
| **USB-Stick „…“ gefunden – n Titel übernehmen?** | Stick mit dem Volume-Label **MUSIK** und passenden Dateien steckt | **ÜBERNEHMEN** kopiert die Titel und liest danach neu ein (Fortschritt in der Bibliothek); **SCHLIESSEN** verwirft den Hinweis. Verschwindet von selbst nur, wenn der Stick abgezogen wird; steckt man ihn wieder ein, kommt der Hinweis erneut. |
| **Audiofehler aufgetreten** / **Audioausgabegerät gewechselt** | Meldung vom Backend, z. B. [ohne Audio-Gerät](verhalten.md#ohne-audio-gerät) oder wenn der Ton während der Wiedergabe abreißt; der Player pausiert dann (#59) | **SCHLIESSEN**, sonst nach 4 s weg |
| **Befehl fehlgeschlagen** / **Kein weiterer Titel in der Warteschlange** (Fehlersymbol) | Eine Taste des Players ging nicht durch, z. B. **Weiter** ohne Antwort vom Backend; der zweite Text bei **Weiter**/**Zurück** am Ende der Warteschlange (#32) | **SCHLIESSEN**, sonst nach 4 s weg |

![Banner „ffmpeg fehlt: Titel werden ohne Interpret, Dauer und Cover eingelesen …“ mit RESCAN über dem Player](bilder/medien-ffmpeg-fehlt.png)

Das Bild von „Verbindung unterbrochen“ steht unter
[Wenn das Backend nicht erreichbar ist](verhalten.md#wenn-das-backend-nicht-erreichbar-ist).

## Wohin führt „Zurück“?

| Ansicht | Pfeil oben links führt zu |
|---|---|
| Bibliothek, Sammlungen, Playlist erstellen | Player |
| Playlist-Detail | Sammlungen |
| Titel hinzufügen | vorherige Ansicht (Detail oder Sammlungen) |
