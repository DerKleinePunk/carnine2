# Technik (Schalter und Regler)

[← Übersicht](README.md)

Die Seite **Technik** schaltet Geräte im Auto: Licht, Lüfter und was sonst am
Schaltmodul hängt. Was sie zeigt, steht nicht in der Oberfläche, sondern in
der Konfiguration des Backends ([Einrichten](#einrichten)).

![Seite Technik mit acht Schaltern: Arbeitslicht, Innenlicht, Scheinwerfer, Rundumleuchte, Kühlbox, Steckdose 12 V, Standheizung, Reserve, alle AUS](bilder/technik.png)

*Die acht Relais des Testaufbaus, eingerichtet wie unter [Einrichten](#einrichten) beschrieben.*

- **Schalter:** Die ganze Karte antippen. Sie leuchtet in der Primärfarbe, wenn
  der Schalter **AN** ist, und zeigt **AUS**, wenn nicht.
- **Regler:** Den Griff ziehen. Die Karte ist so breit wie die Seite, niedriger
  als eine Schalterkarte und hat eine eigene Zeile: links der Name, in der
  Mitte der Schieber, rechts der Wert in Prozent.
- Die Schalter stehen in der Reihenfolge der Konfiguration, vier nebeneinander.
  Acht Schalter und ein Regler passen ohne Scrollen auf den Bildschirm. Sind
  es mehr, lässt sich die Seite nach oben und unten wischen.
- Die Namen stehen so da, wie man sie in der Konfiguration vergeben hat. Sie
  werden nicht übersetzt.

## Was die Karten anzeigen

| Anzeige | Bedeutung |
|---|---|
| Karte leuchtet, **AN** | Der Schalter ist eingeschaltet. |
| Karte dunkel, **AUS** | Der Schalter ist ausgeschaltet. |
| Karte ausgegraut, **NICHT ERREICHBAR** (beim Regler rechts statt des Werts) | Das Modul antwortet nicht, z. B. weil das Kabel fehlt. Die Karte reagiert nicht. Sobald das Modul wieder da ist, wird sie von selbst wieder bedienbar. |

Ändert jemand anderes einen Wert, z. B. über die Kommandozeile des Backends,
sieht man das auf der Seite sofort.

Beim Ziehen am Regler folgt die Anzeige dem Finger sofort. Gesendet wird etwa
alle 150 ms und beim Loslassen noch einmal, damit der Endwert sicher ankommt.

## Hinweise auf der Seite

| Hinweis | Bedeutung |
|---|---|
| **Keine Technik eingerichtet** | Das Backend kennt keinen Schalter und keinen Regler. Die Konfiguration fehlt oder ist leer. |
| **Wird geladen …** | Die Seite fragt das Backend gerade ab. |
| **Die Verbindung zum Backend wurde unterbrochen …** mit **Erneut versuchen** | Die Verbindung steht nicht. Die Seite versucht es von selbst weiter, erst nach einer halben Sekunde, dann in wachsenden Abständen bis alle 5 Sekunden. **Erneut versuchen** probiert es sofort. |
| roter Streifen **Befehl fehlgeschlagen** | Ein Schalten kam nicht an. Der Streifen geht nach 4 Sekunden von selbst weg, die Karte zeigt weiter den echten Zustand. |

## Einrichten

**Ab Werk ist nichts eingerichtet.** Ein frisch geschriebenes Image hat keinen
Schalter und keinen Regler, die Seite zeigt dann „Keine Technik eingerichtet“.
Was am Schaltmodul hängt, trägt man für jedes Gerät selbst ein.

Jeder Schalter und Regler ist ein Eintrag `[[controls]]` in der Konfiguration
des Backends, am besten in einer eigenen Datei, z. B.
`/etc/carnine/config.d/40-controls.toml`:

```toml
[[controls]]
id = "interior_light"
name = "Innenlicht"
type = "switch"          # oder "slider" (0–100)
chip = "mcp23017"        # oder "demo" zum Ausprobieren ohne Hardware
address = 0x20
pin = 0
```

Danach `sudo systemctl restart carnine-backend`. Die Oberfläche lädt die Liste
beim Öffnen der Seite neu, ein Neustart der Oberfläche ist nicht nötig. Alle
Optionen, auch `restore` und `reset_gpio` für das IO-Board, stehen als
Kommentar in `resources/config/carnine.toml`.

- Den Namen nach dem benennen, was am Ausgang hängt. Die Oberfläche zeigt ihn
  unverändert.
- Ein fehlerhafter Eintrag wird übersprungen und steht im Log des Backends.
- Ohne `restore = true` starten Schalter nach dem Einschalten **aus**, Regler
  mit ihrem letzten Wert.
