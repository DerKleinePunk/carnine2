# Kamera (Rückfahrkamera)

[← Übersicht](README.md)

Die Seite **Kamera** zeigt das Bild einer Rückfahrkamera.

![Seite Kamera mit dem Bild einer analogen Rückfahrkamera am Grabber, darin die farbigen Hilfslinien der Kamera](bilder/cam-grabber.png)

*Analoge Rückfahrkamera am Grabber, auf dem Test-Pi (Pi 4). Die Hilfslinien
kommen aus der Kamera selbst.*

- Das Bild füllt die Seite in der Höhe, links und rechts bleibt ein schwarzer
  Rand. Bedienelemente gibt es auf der Seite keine.
- Die Kamera läuft **nur, solange die Seite zu sehen ist**. Wechselt man auf
  eine andere Seite, gibt die Oberfläche die Kamera frei. Beim Zurückkommen
  öffnet sie sie neu, das dauert einen Moment.
- Ist das Signal des Rückwärtsgangs eingerichtet, kommt die Seite beim
  Einlegen von selbst, siehe [Rückwärtsgang](#rückwärtsgang).

## Rückwärtsgang

Liefert das Auto das Signal des Rückwärtsgangs (Eingang am Pi oder die
Demo-Quelle, Einrichtung in [docs/07](../07-deployment.md#reversing-camera)),
schaltet die Oberfläche selbst um (#191):

| Gang | Was passiert |
|---|---|
| **eingelegt** | Die Seite **Kamera** kommt, von jeder Seite aus. Offene Dialoge und die Bildschirmtastatur gehen dabei zu; was darin getippt war, ist weg. Musik, Route und Warteschlange bleiben. |
| **heraus** | Sofort zurück auf die Seite von vorher. Hat man während der Rückwärtsfahrt selbst eine andere Seite gewählt, bleibt diese. |
| **unbekannt** (Signal nicht lesbar) | Nichts wird umgeschaltet, auch nicht zurück. Auf der Seite Kamera steht oben „Rückwärtsgang: Signal fehlt“. |

- War die Kamera schon offen, bleibt sie es auch nach dem Herausnehmen.
- Die Kamera wird durch den Rückwärtsgang nicht als letzte Seite gemerkt:
  Nach dem nächsten Einschalten startet die Oberfläche nicht auf der Kamera.
  Ist der Gang beim Einschalten schon eingelegt, kommt die Kamera sofort.
- Im Messe-Modus springt die Oberfläche nicht zur Karte, solange der Gang
  eingelegt ist.
- Ohne eingerichtetes Signal passiert nichts, und es gibt keinen Hinweis.

## Welche Kameras gehen

| Kamera | Anschluss | Bild |
|---|---|---|
| Analoge Rückfahrkamera (Composite oder S-Video) | über einen USB-Grabber mit **STK1160**-Chip | 360 Pixel breit (einstellbar auf 720), NTSC oder PAL |
| **USB-Kamera** (Webcam), als MJPEG oder unkomprimiert (YUYV) | direkt an USB | immer 640 × 480 |

Kann eine Kamera beides, nimmt die Seite MJPEG, weil das Bild damit
deutlich schneller ankommt. MJPEG packt der Pi selbst aus. Zeigt eine
Kamera mit MJPEG Störungen, lässt sich auf das unkomprimierte Bild
umschalten ([docs/07](../07-deployment.md#reversing-camera)).

Das Bild kommt etwas zu spät auf den Bildschirm: mit einem analogen Grabber
etwa 0,08 Sekunden, mit einer USB-Kamera in MJPEG etwa 0,06 Sekunden, bei
wenig Licht etwa 0,1 Sekunden. carnine selbst braucht davon nur etwa 0,01
Sekunden.

**Ältere Webcams nicht benutzen**, z. B. die Microsoft LifeCam VX-3000. Sie
zeigen zwar ein Bild, aber nach etwa zwei Minuten bleibt der ganze Pi stehen
und lässt sich nur noch über den Strom neu starten. Ein kurzer Blick auf die
Seite zeigt das noch nicht. Für eine Rückfahrkamera eine neuere USB-Kamera
nehmen, die unter Linux ohne eigenen Treiber läuft („UVC“ im Datenblatt).

Grabber und USB-Kamera **direkt an den Pi** stecken, nicht an einen
USB-Hub, an dem auch die SSD hängt. Auf dem Test-Pi hat der Grabber dort
den USB-Controller zum Stehen gebracht.

Die Kamera **nur bei ausgeschaltetem Gerät** anstecken oder umstecken. Beim
Einstecken im laufenden Betrieb ist auf dem Test-Pi der ganze USB-Teil
hängen geblieben, samt Touch und SSD. Danach half nur, den Strom aus- und
wieder einzuschalten.

![Seite Kamera mit dem Bild einer USB-Kamera: Kabel, Klebeband und ein Display, auf dem die Seite Kamera noch einmal zu sehen ist](bilder/cam-usb-kamera.png)

*USB-Kamera direkt am Test-Pi, 640 × 480.*

## Hinweise auf der Seite

Solange kein Bild läuft, steht ein Hinweis auf schwarzem Grund. Er erscheint
in der Sprache der Oberfläche.

| Hinweis | Bedeutung |
|---|---|
| **Verbinde mit der Kamera …** | Die Seite öffnet gerade die Kamera. |
| **Kein Kamerasignal** | Das Gerät ist da, liefert aber kein Bild, z. B. weil am gelben Stecker des Grabbers nichts hängt oder die Kamera keinen Strom hat. |
| **Kamera nicht angeschlossen** | Es gibt kein Gerät, z. B. weil Grabber oder Kamera abgezogen sind. Auf einem Gerät ganz ohne Kamera steht immer dieser Hinweis. |
| **Kamera gestört** | Öffnen oder Abspielen ist fehlgeschlagen, z. B. bei einer Kamera, deren Bildformat die Seite nicht kennt. |

Unabhängig vom Bild steht oben eine kleine rote Zeile **Rückwärtsgang: Signal
fehlt**, solange das Signal des Rückwärtsgangs eingerichtet, aber nicht
lesbar ist. Dann kommt die Seite beim Einlegen nicht von selbst (siehe
[Rückwärtsgang](#rückwärtsgang)).

**Anstecken und Abziehen bei offener Seite** geht: Fehlt die Kamera, versucht
die Seite jede Sekunde, sie neu zu öffnen. Nach dem Anstecken steht kurz
„Verbinde mit der Kamera …“, dann kommt das Bild. Das kann einige Sekunden
dauern, weil der Pi das Gerät erst erkennen muss. Gesucht wird nur das
eingestellte Gerät (Vorgabe `/dev/video0`). Eine zweite Kamera bekommt eine
andere Nummer und erscheint erst, wenn man sie einstellt. Damit die Nummer
nicht wandert, kann man statt `/dev/video0` den festen Namen der Kamera unter
`/dev/v4l/by-id/` einstellen.

## Einstellungen

Gerät, Videonorm, Eingang und Bildbreite stellt man unter
[Optionen → Geräte → Kamera](optionen.md#kamera) ein. Ohne gespeicherte Werte
gelten die Vorgaben aus dem Abschnitt `[camera]` der Konfiguration. Ohne Eintrag
sind das diese Werte:

```toml
[camera]
device = "/dev/video0"   # oder ein fester Link unter /dev/v4l/
norm = "ntsc"            # oder "pal"
input = 0                # STK1160: 0–3 Composite, 4 S-Video
width = 360              # oder 720
```

- **Ändern in der Konfiguration** (nur für die Vorgabe, wenn in den Optionen
  noch nichts gespeichert ist): am besten in einer eigenen Datei, z. B.
  `/etc/carnine/config.d/30-camera.toml`, nur mit den Zeilen, die anders sein
  sollen. Danach `sudo systemctl restart carnine-backend` und einmal die Seite
  Kamera verlassen und wieder öffnen. Der Neustart des Backends unterbricht die
  Wiedergabe.
- **Norm, Eingang, Breite** gelten nur für den Grabber. Eine USB-Kamera
  liefert immer 640 × 480 und kennt sie nicht.
- **Breite 720** ist schärfer, aber der STK1160 kommt damit an die Grenze von
  USB 2: Es kommen nur etwa 10 statt 30 Bilder pro Sekunde, viele davon
  unvollständig. Für eine analoge Kamera ist 360 kaum unschärfer.
- Was die Einstellungsseite speichert, liegt in der Datenbank und geht den
  Werten aus der Konfiguration vor. Wirkt eine Änderung in der Konfiguration
  nicht, liegt das meist daran
  ([docs/07](../07-deployment.md#reversing-camera)).
