# Cam (Rückfahrkamera)

[← Übersicht](README.md)

Die Seite **Cam** zeigt das Bild einer Rückfahrkamera. Sie ersetzt ab 0.10.0
die frühere Platzhalter-Seite „Klima“. War vor dem Update „Klima“ die
zuletzt gewählte Seite, öffnet die Oberfläche danach **Cam**.

![Seite Cam mit dem Bild einer analogen Rückfahrkamera am Grabber, darin die farbigen Hilfslinien der Kamera](bilder/cam-grabber.png)

*Analoge Rückfahrkamera am Grabber, auf dem Test-Pi (Pi 4). Die Hilfslinien
kommen aus der Kamera selbst.*

- Das Bild füllt die Seite in der Höhe, links und rechts bleibt ein schwarzer
  Rand. Bedienelemente gibt es auf der Seite keine.
- Die Kamera läuft **nur, solange die Seite zu sehen ist**. Wechselt man auf
  eine andere Seite, gibt die Oberfläche die Kamera frei. Beim Zurückkommen
  öffnet sie sie neu, das dauert einen Moment.
- Auf das Bild umschalten, wenn der Rückwärtsgang eingelegt wird, kann die
  Oberfläche noch nicht. Dafür fehlt ein Signal vom Auto.

## Welche Kameras gehen

| Kamera | Anschluss | Bild |
|---|---|---|
| Analoge Rückfahrkamera (Composite oder S-Video) | über einen USB-Grabber mit **STK1160**-Chip | 360 Pixel breit (einstellbar auf 720), NTSC oder PAL |
| **USB-Kamera** (Webcam), die unkomprimiert liefert (YUYV) | direkt an USB | immer 640 × 480 |

Kameras, die **nur MJPEG** liefern, gehen nicht. Die Seite zeigt dann
„Kamera gestört“.

Grabber und USB-Kamera **direkt an den Pi** stecken, nicht an einen
USB-Hub, an dem auch die SSD hängt. Auf dem Test-Pi hat der Grabber dort
den USB-Controller zum Stehen gebracht.

![Seite Cam mit dem Bild einer USB-Kamera: ein Schreibtisch mit Kabeln und einem Raspberry Pi](bilder/cam-usb-kamera.png)

*USB-Kamera direkt am Test-Pi, 640 × 480.*

## Hinweise auf der Seite

Solange kein Bild läuft, steht ein Hinweis auf schwarzem Grund. Er erscheint
in der Sprache der Oberfläche.

| Hinweis | Bedeutung |
|---|---|
| **Verbinde mit der Kamera …** | Die Seite öffnet gerade die Kamera. |
| **Kein Kamerasignal** | Das Gerät ist da, liefert aber kein Bild, z. B. weil am gelben Stecker des Grabbers nichts hängt oder die Kamera keinen Strom hat. |
| **Kamera nicht angeschlossen** | Es gibt kein Gerät, z. B. weil Grabber oder Kamera abgezogen sind. Auf einem Gerät ganz ohne Kamera steht immer dieser Hinweis. |
| **Kamera gestört** | Öffnen oder Abspielen ist fehlgeschlagen, z. B. bei einer Kamera, die nur MJPEG kann. |

**Anstecken und Abziehen bei offener Seite** geht: Fehlt die Kamera, versucht
die Seite jede Sekunde, sie neu zu öffnen. Nach dem Anstecken steht kurz
„Verbinde mit der Kamera …“, dann kommt das Bild. Das kann einige Sekunden
dauern, weil der Pi das Gerät erst erkennen muss. Gesucht wird nur das
eingestellte Gerät (Vorgabe `/dev/video0`). Eine zweite Kamera bekommt eine
andere Nummer und erscheint erst, wenn man sie einstellt. Damit die Nummer
nicht wandert, kann man statt `/dev/video0` den festen Namen der Kamera unter
`/dev/v4l/by-id/` einstellen.

## Einstellungen

Eine Einstellungsseite in der Oberfläche gibt es noch nicht, sie kommt
später (#79). Bis dahin gelten die Vorgaben aus dem Abschnitt `[camera]` der
Konfiguration. Ohne Eintrag sind das diese Werte:

```toml
[camera]
device = "/dev/video0"   # oder ein fester Link unter /dev/v4l/
norm = "ntsc"            # oder "pal"
input = 0                # STK1160: 0–3 Composite, 4 S-Video
width = 360              # oder 720
```

- **Ändern:** am besten in einer eigenen Datei, z. B.
  `/etc/carnine/config.d/30-camera.toml`, nur mit den Zeilen, die anders sein
  sollen. Danach `sudo systemctl restart carnine-backend` und einmal die Seite
  Cam verlassen und wieder öffnen. Der Neustart des Backends unterbricht die
  Wiedergabe.
- **Norm, Eingang, Breite** gelten nur für den Grabber. Eine USB-Kamera
  liefert immer 640 × 480 und kennt sie nicht.
- **Breite 720** ist schärfer, aber der STK1160 kommt damit an die Grenze von
  USB 2: Es kommen nur etwa 10 statt 30 Bilder pro Sekunde, viele davon
  unvollständig. Für eine analoge Kamera ist 360 kaum unschärfer.
- Was die künftige Einstellungsseite speichert, liegt in der Datenbank und
  geht den Werten aus der Konfiguration vor. Das gilt schon heute für Werte,
  die jemand mit dem Test-Client gespeichert hat. Wirkt eine Änderung in der
  Konfiguration nicht, liegt das meist daran
  ([docs/07](../07-deployment.md#reversing-camera)).
