# Verhalten über Neustarts und ohne Backend

[← Inhalt](README.md)

## Was nach einem Neustart erhalten bleibt

| Zustand | Bleibt erhalten? |
|---|---|
| zuletzt gewählte Seite (außer Optionen) | ja |
| Lautstärke | ja; ohne gespeicherten Wert 50 % (#47) |
| Wiederholung und Zufall | ja |
| laufende Playlist, Titel und Stelle im Titel | ja |
| Stelle jeder anderen Playlist | ja – jede Playlist merkt sich ihre eigene Stelle (#68) |
| einzeln aus der Bibliothek gestarteter Titel | ja, mit seiner Stelle (#68); ist die Datei weg, wird er übersprungen |
| Sprache | ja (#30) |
| Route, Zoom, Suchtexte, eingeklappte Warteschlange, Unterseite von Medien und Optionen | nein |

Nach einem Neustart des Backends (oder des ganzen Geräts) wird die Playlist
oder der einzelne Titel, der zuletzt lief,
standardmäßig **pausiert an der gespeicherten Stelle** geladen und muss mit
**Wiedergabe** fortgesetzt werden. Das steuert `resume_mode` in der
Backend-Konfiguration:

| `resume_mode` | Verhalten |
|---|---|
| `restore_paused` (Standard) | pausiert an der gespeicherten Stelle |
| `start-last-title` | letzter Titel, von vorn |
| `auto-play` | spielt sofort weiter |

Der Neustart der Oberfläche allein (Optionen → System → **Neustart**) lässt
die Wiedergabe unberührt. **Beenden** ist der Wartungsmodus: Die Oberfläche
bleibt aus, bis sie jemand von Hand startet (siehe [Optionen](optionen.md#system)).

Frisch geflasht ist die Datenbank leer: Wiederholung steht dann auf aus.

Spielt zwischendurch ein einzelner Titel (zum Beispiel aus der Suche), geht
die Stelle der Playlist davor nicht verloren: Startet man sie wieder, macht
sie dort weiter, wo sie war. Bei einem Hörbuch also im richtigen Kapitel, nicht
wieder bei Kapitel eins (#68).

## Wenn das Backend nicht erreichbar ist

![Medien mit Banner „Die Verbindung zum Backend wurde unterbrochen. Es wird automatisch erneut verbunden.“ und ERNEUT VERSUCHEN](bilder/ohne-backend.png)

- **Medien:** Banner mit roter Wolke „Die Verbindung zum Backend wurde unterbrochen …“,
  Listen zeigen **Erneut versuchen**. Die Oberfläche verbindet sich von selbst
  wieder (alle 0,5 bis 5 s), danach ist alles wie vorher.
- **Karten:** rote Meldung „Navigation nicht erreichbar“, auch in der
  Zielsuche. Die Karte selbst bleibt bedienbar; die Position kommt nach der
  Wiederverbindung von selbst zurück.
- Schlägt ein einzelner Befehl fehl (z. B. **Weiter**), zeigt die Medienseite
  4 s lang den Streifen „Befehl fehlgeschlagen“ (#32, siehe
  [Banner](medien.md#banner)).
- Hängt das Backend, ohne abzustürzen, merkt die Oberfläche das nach
  spätestens etwa 8 s: Sie fragt alle 5 s nach, ob das Backend antwortet, und
  wartet höchstens 3 s auf die Antwort. Dann erscheint das Verbindungsbanner wie
  oben, und sie verbindet sich neu, sobald das Backend wieder antwortet (#58).

## Ohne Audio-Gerät

![Medien mit der roten Zeile „Kein Audio-Ausgang – bitte den Tonausgang prüfen (HDMI oder Klinke)“ unter der Kopfleiste](bilder/hinweis-kein-audio.png)

Findet das Backend kein Audio-Ausgabegerät, etwa weil HDMI keinen
Ton hat (das Display meldet in seinem EDID keinen Audioteil), läuft es
trotzdem: Karte, Navigation, Netzteil-Anzeige und Optionen funktionieren, nur
Musik nicht (#55). Solange kein Ausgang da ist, steht **auf jeder Seite** unter
der Kopfleiste die rote Zeile mit durchgestrichenem Lautsprecher „Kein
Audio-Ausgang – bitte den Tonausgang prüfen (HDMI oder Klinke)“ (#56). Sie hat
keinen Knopf und verschwindet von selbst, sobald wieder ein Ausgang da ist.
**Wiedergabe** zeigt dann „Befehl fehlgeschlagen“. Bei jedem neuen Start einer
Wiedergabe versucht das Backend das Gerät noch einmal; ein Ton über HDMI, der
erst später da ist, wird so ohne Neustart genutzt. Welcher Ausgang Karte 0 ist,
steht in [Ton über die Klinke](ton-klinke.md).

Reißt die Audioausgabe **während der Wiedergabe** ab, pausiert der Player an
der aktuellen Stelle, und die rote Zeile erscheint. **▶** spielt an derselben
Stelle weiter und öffnet die Ausgabe dabei neu (#59).

## Wenn das Gerät zu heiß wird

![Warnung „Gerät überhitzt“ mit Temperatur und dem Knopf „Verstanden“ über der Seite Medien](bilder/hinweis-ueberhitzt.png)

*Ein echter Test am Gerät: Für das Bild wurde die Warnschwelle auf 30 °C
gesenkt. Die angezeigten 39,9 °C sind echt gemessen, deshalb steht die Warnung
bei einer Temperatur da, die im Betrieb keine auslöst. Im Betrieb warnt
CarNine erst ab 75 °C.*

Wird die CPU **75 °C** heiß, legt sich über jede Seite die Warnung **„Gerät
überhitzt“**: „Die CPU hat … °C. Bitte das Gerät abkühlen lassen und die
Lüftung prüfen.“ (#70). Die Seite darunter ist abgedunkelt und gesperrt, bis
jemand **Verstanden** tippt.

- Danach kommt die Warnung nicht wieder, solange die CPU heiß bleibt, auch
  nicht, wenn sich die Oberfläche neu mit dem Backend verbindet. Startet die
  Oberfläche selbst neu, während die CPU noch heiß ist, kommt sie sofort wieder.
- Erst wenn die Temperatur unter **70 °C** gefallen und danach wieder auf 75 °C
  gestiegen ist, kommt sie erneut.
- Die beiden Schwellen stehen in der Backend-Konfiguration,
  `[system] cpu_temperature_warn_celsius` und `cpu_temperature_clear_celsius`.
  Ab 70 °C misst das Backend alle 5 s statt alle 30 s.
- Ist ein Gehäuselüfter mit `boost_on_overheat = true` eingerichtet
  (Backend-Konfiguration, `[[controls]]`), läuft er während der Warnung mit voller
  Drehzahl. Auf der Seite Technik steht sein Regler dann auf 100 %. Unter
  70 °C geht er auf den eingestellten Wert zurück. Wer den Regler während der
  Warnung verstellt, legt damit den Wert für danach fest.

## Noch nicht verfügbar

Sichtbar, aber ohne Funktion:

- **NOTFALL** im Seitenmenü (#34)
- Symbole Mobilfunk, Akku, Sonne in der Kopfleiste (#34)
- Seite **Start** (nur Entwickler-Test)
- Springen in der Zeitleiste des Players (dafür −30 s / +30 s)
- **Nach Updates suchen** (#20)
- **Karteneinstellungen** und der Reiter **Darstellung** in den Optionen
- **Audio-Ausgang**, **Handy-App** und **Netzteil** auf der Seite Geräte (nur
  eine Vorschau, nicht antippbar)
- Herunterfahren, wenn das Netzteil abschaltet: Die Kopfleiste kündigt es nur
  an (#36, siehe [Kopfleiste](README.md#kopfleiste-oben-rechts))

## Dauertest einrichten

Für einen Dauertest mit Karte und Musik auf dem Test-Pi:

1. **Medien → SAMMLUNGEN** → bei „Alle Lieder (Dauertest)“ auf **▶**.
2. Zurück zum Player, **Wiederholung** einmal antippen, bis 🔁 leuchtet
   (Playlist). Ohne das hört die Musik nach dem letzten Titel auf.
3. Seitenmenü → **Karten**. Im Replay fährt die Tour von selbst.

Der Watch-Dienst `freeze-watch` auf dem Pi schreibt dazu jede Minute eine
Zeile nach `~/freeze/watch.log` (Bildwiederholungen, Temperatur, Takt,
Drosselung, Last, CPU und Speicher der Oberfläche und des Backends).
