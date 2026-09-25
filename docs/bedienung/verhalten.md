# Verhalten über Neustarts und ohne Backend

[← Inhalt](README.md)

## Was nach einem Neustart erhalten bleibt

| Zustand | Bleibt erhalten? |
|---|---|
| zuletzt gewählte Seite (außer Optionen) | ja |
| Lautstärke | ja |
| Wiederholung und Zufall | ja |
| laufende Playlist, Titel und Stelle im Titel | ja |
| einzeln aus der Bibliothek gestarteter Titel | nein |
| Sprache | nein – immer Deutsch |
| Route, Zoom, Suchtexte, eingeklappte Warteschlange, Unterseite von Medien und Optionen | nein |

Nach einem Neustart des Backends (oder des ganzen Geräts) wird die Playlist
standardmäßig **pausiert an der gespeicherten Stelle** geladen und muss mit
**Wiedergabe** fortgesetzt werden. Das steuert `resume_mode` in der
Backend-Konfiguration:

| `resume_mode` | Verhalten |
|---|---|
| `restore_paused` (Standard) | pausiert an der gespeicherten Stelle |
| `start-last-title` | letzter Titel, von vorn |
| `auto-play` | spielt sofort weiter |

Der Neustart der Oberfläche allein (Optionen → System → **Neustart**) lässt
die Wiedergabe unberührt.

Frisch geflasht ist die Datenbank leer: Wiederholung steht dann auf aus.

## Wenn das Backend nicht erreichbar ist

- **Medien:** rotes Banner „Die Verbindung zum Backend wurde unterbrochen …“,
  Listen zeigen **Erneut versuchen**. Die Oberfläche verbindet sich von selbst
  wieder (alle 0,5 bis 5 s), danach ist alles wie vorher.
- **Karten:** rote Meldung „Navigation nicht erreichbar“, auch in der
  Zielsuche. Die Karte selbst bleibt bedienbar; die Position kommt nach der
  Wiederverbindung von selbst zurück.
- Schlägt ein einzelner Befehl fehl (z. B. Weiter), gibt es **keine sichtbare
  Rückmeldung** – nur einen Eintrag im Log (Optionen → System).

## Noch nicht verfügbar

Sichtbar, aber ohne Funktion:

- **NOTFALL** im Seitenmenü
- Symbole Mobilfunk, Akku, Sonne in der Kopfleiste
- Seiten **Start**, **Klima**, **Technik** (nur Entwickler-Test)
- **−30 s / +30 s** im Player (#8), Springen in der Zeitleiste
- **Nach Updates suchen** (#20)
- **Karteneinstellungen** und **Darstellung** in den Optionen
- Playlists umbenennen, löschen, Titel entfernen (#14)

## Dauertest einrichten

Für einen Dauertest mit Karte und Musik auf dem Test-Pi:

1. **Medien → SAMMLUNGEN** → bei „Alle Lieder (Dauertest)“ auf **▶**.
2. Zurück zum Player, **Wiederholung** einmal antippen, bis 🔁 leuchtet
   (Playlist). Ohne das hört die Musik nach dem letzten Titel auf.
3. Seitenmenü → **Karten**. Im Replay fährt die Tour von selbst.

Der Watch-Dienst `freeze-watch` auf dem Pi schreibt dazu jede Minute eine
Zeile nach `~/freeze/watch.log` (Bildwiederholungen, Temperatur, Takt,
Drosselung, Last, CPU und Speicher der Oberfläche und des Backends).
