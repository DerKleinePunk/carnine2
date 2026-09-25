# Medien

[← Inhalt](README.md)

Die Seite **Medien** hat vier Ansichten: den **Player** (Standard),
**Bibliothek**, **Sammlungen** (Playlists) und **Playlist erstellen**. Über
dem Inhalt können Hinweisbanner erscheinen, siehe [Banner](#banner).

## Player

Links Cover, Titelangaben, Zeitleiste, Tasten und Lautstärke; rechts die
Warteschlange.

- **Cover:** ohne Cover ein Equalizer-Symbol.
- **Titelangaben:** Titel, Interpret, darunter „TITEL 3 VON 19“,
  „EINZELTITEL“ oder „KEINE WIEDERGABE“. Lange Titel werden kleiner
  geschrieben statt abgeschnitten.
- **Zeitleiste:** Position und Dauer (mm:ss, „--:--“ wenn unbekannt).
  Springen durch Antippen oder Ziehen geht noch nicht.

### Tasten (von links nach rechts)

| Taste | Wirkung | Hinweise |
|---|---|---|
| **Zufall** (⤮) | Zufallswiedergabe an/aus | an = leuchtet, mit Punkt darunter |
| **Zurück** (⏮) | ab 3 s Spielzeit: Titel von vorn; sonst vorheriger Titel | auf dem ersten Titel der Warteschlange gesperrt |
| **−30 s** | – | noch nicht verfügbar, immer grau |
| **Wiedergabe/Pause** | pausieren bzw. fortsetzen | grau, wenn kein Titel geladen ist |
| **+30 s** | – | noch nicht verfügbar, immer grau |
| **Weiter** (⏭) | nächster Titel | am Ende der Warteschlange gesperrt, außer Wiederholung ist an |
| **Wiederholung** (🔁) | jedes Antippen schaltet weiter: **aus → Playlist → aktueller Titel → aus** | aus = grau; Playlist = 🔁 leuchtet; aktueller Titel = 🔂 leuchtet |

Solange ein Befehl noch beim Backend in Arbeit ist, sind Zurück, Weiter und
Wiedergabe/Pause kurz gesperrt. Einen Stopp-Knopf gibt es nicht, und keine
Taste reagiert auf langes Drücken.

Zufall und Wiederholung merkt sich das Backend, auch über einen Neustart.

### Lautstärke

- **Lautsprecher-Symbol:** stumm schalten; noch einmal antippen stellt den
  vorherigen Wert wieder her.
- **Schieberegler** 0–100 mit Prozentanzeige. Bis das Backend den echten Wert
  meldet, steht dort 100 %.

### Warteschlange

- Die schmale Leiste mit dem Pfeil klappt die Warteschlange ein und aus.
  Alternativ: auf dem Player **nach links wischen** öffnet, **nach rechts
  wischen** schließt. Eingeklappt wird der Player etwas größer.
- **NÄCHSTE TITEL** listet die Warteschlange; der laufende Titel ist
  eingerahmt. **Antippen eines Eintrags springt zu diesem Titel.**
- Unten zwei Kacheln: **BIBLIOTHEK** und **SAMMLUNGEN**.

## Bibliothek

Erreichbar über die Kachel **BIBLIOTHEK** unter der Warteschlange; der Pfeil
oben links führt zurück zum Player.

- **Suchfeld** „Titel oder Interpret suchen“: öffnet die
  [Bildschirmtastatur](tastatur.md), sucht 300 ms nach dem letzten
  Tastendruck. Gefunden wird auch über den Dateipfad (z. B. Albumordner). Das
  × leert das Feld.
- **Neu einlesen** (↻ neben dem Suchfeld): liest den Musikordner neu ein;
  während eines Scans grau. Eine Statuszeile zeigt „Scan läuft...“ bzw.
  „x verarbeitet, y importiert“ oder „Scan fehlgeschlagen“.
- **Antippen eines Titels spielt ihn als Einzeltitel.** Die Bibliothek bleibt
  dabei offen, es geht nicht automatisch zum Player.
- Nicht abspielbare Dateien sind rot markiert („NICHT VERFÜGBAR“) und
  gesperrt.

## Sammlungen (Playlists)

Erreichbar über die Kachel **SAMMLUNGEN**.

- **＋** oben rechts: neue Playlist anlegen (siehe unten).
- **Zeile antippen:** Playlist öffnen (Detailansicht).
- **▶ am Zeilenende:** Playlist sofort starten; die Liste bleibt offen.

### Playlist-Detail

- **PLAYLIST STARTEN** oben rechts startet die Playlist und wechselt zum
  Player. Gesperrt, wenn die Playlist leer ist.
- Die Einträge zeigen Titel, Interpret, Dauer; der gerade laufende ist
  eingerahmt. **Einträge sind nicht antippbar** – zu einem Titel springen geht
  über die Warteschlange im Player.
- Titel, die nicht mehr in der Bibliothek sind, stehen rot da („Titel nicht
  mehr in der Bibliothek“).
- **Titel hinzufügen** unten öffnet die Auswahl.

### Titel hinzufügen

Dieselbe Liste wie die Bibliothek (mit Suche und Neu einlesen), aber
**Antippen fügt den Titel der Playlist hinzu**. Das Symbol rechts zeigt:
＋ = noch nicht drin, Kreisel = wird hinzugefügt, ✓ = drin. Ist ein Titel schon
enthalten, erscheint kurz „Titel ist bereits in der Playlist“.

Umbenennen, Löschen und Titel entfernen gibt es noch nicht (#14).

### Playlist erstellen

- Das Feld „Name der Playlist“ (höchstens 40 Zeichen) hat sofort den Fokus.
- **Angelegt wird mit „Fertig“ auf der Bildschirmtastatur** – einen eigenen
  Knopf dafür gibt es nicht.
- Fehlermeldungen: „Bitte einen Namen eingeben“, „Eine Playlist mit diesem
  Namen existiert bereits“.
- Danach geht es direkt zu **Titel hinzufügen** für die neue Playlist.
- Der Pfeil oben links führt hier zum **Player**, nicht zu den Sammlungen.

## Banner

Erscheinen oben auf der Medienseite.

| Banner | Wann | Bedienung |
|---|---|---|
| **Verbindung unterbrochen** (rote Wolke) | Backend nicht erreichbar | **ERNEUT VERSUCHEN** verbindet sofort; sonst automatisch alle 0,5–5 s. Verdeckt die anderen Banner. |
| **USB-Stick „…“ gefunden – n Titel übernehmen?** | Stick mit dem Volume-Label **MUSIK** und passenden Dateien steckt | **ÜBERNEHMEN** kopiert die Titel und liest danach neu ein (Fortschritt in der Bibliothek); **SCHLIESSEN** verwirft den Hinweis. Verschwindet nicht von selbst. |
| **Audiofehler aufgetreten** / **Audioausgabegerät gewechselt** | Meldung vom Backend | **SCHLIESSEN**, sonst nach 4 s weg |

## Wohin führt „Zurück“?

| Ansicht | Pfeil oben links führt zu |
|---|---|
| Bibliothek, Sammlungen, Playlist erstellen | Player |
| Playlist-Detail | Sammlungen |
| Titel hinzufügen | vorherige Ansicht (Detail oder Sammlungen) |
