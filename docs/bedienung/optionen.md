# Optionen

[← Inhalt](README.md)

Vier Kacheln; der Pfeil oben links in jeder Unterseite führt zurück zur
Übersicht.

![Optionen: vier Kacheln Karteneinstellungen, Darstellung & Sprache, Geräte, System](bilder/optionen.png)

| Kachel | Inhalt |
|---|---|
| **Karteneinstellungen** | noch leer („… vorbereitet“) |
| **Darstellung & Sprache** | zwei Reiter: **Darstellung** (noch leer) und **Sprache** (Anzeigesprache wählen) |
| **Geräte** | **Kamera** einstellen; Audio-Ausgang, Handy-App und Netzteil als Vorschau |
| **System** | Logs, Neustart, Beenden, Updates |

## Darstellung & Sprache

Oben zwei Reiter: **Darstellung** und **Sprache**. Die Seite öffnet auf
**Sprache**, dem Teil, der heute funktioniert. Der Reiter **Darstellung** ist noch
leer („Darstellung vorbereitet“); dort kommen später Farben und Schrift hin.
Wer die Seite verlässt und wieder öffnet, landet wieder auf **Sprache**.

### Sprache

![Darstellung & Sprache: Reiter Darstellung und Sprache, oben die aktive Sprache, darunter die Sprachen als Kacheln mit Flagge](bilder/optionen-sprache.png)

- Oben die aktive Sprache mit Flagge, darunter alle 15 Sprachen (Chinesisch,
  Dänisch, Deutsch, Englisch, Französisch, Italienisch, Japanisch,
  Niederländisch, Polnisch, Portugiesisch, Schwedisch, Spanisch, Tschechisch,
  Türkisch, Ungarisch).
- Antippen stellt sofort um, ohne Neustart. Die Liste ist nach dem Namen in der
  aktuellen Sprache sortiert, ihre Reihenfolge ändert sich also beim Umschalten.
  Umlaute sortiert sie dabei noch falsch ein: „Deutsch“ steht vor „Dänisch“, so
  auch im Bild (#92).
- Die Wahl wird gespeichert und gilt auch nach einem Neustart, ebenso für die
  Fahranweisungen der Navigation (#30). Ist das Backend beim Start noch nicht
  bereit, holt die Oberfläche die Sprache nach; wer in der Zwischenzeit selbst
  eine Sprache wählt, behält seine Wahl.

## Geräte

![Geräte: Zeilen Kamera (mit Pfeil), Audio-Ausgang, Handy-App und Netzteil (ausgegraut)](bilder/optionen-geraete.png)

Die Seite zeigt vier Geräte-Bereiche. Jede Zeile hat ein Symbol, einen Namen
und eine Kurzbeschreibung. Nur **Kamera** hat eine Seite; sie hat einen Pfeil
und lässt sich antippen. Die anderen drei sind eine **Vorschau**: ausgegraut,
ohne Pfeil, **nicht antippbar**:

| Zeile | Inhalt |
|---|---|
| **Kamera** | Gerät, Videonorm, Eingang und Bildbreite (siehe unten) |
| **Audio-Ausgang** | später: HDMI, Klinke oder USB-Soundkarte wählen (#48) |
| **Handy-App** | später: Bluetooth-Kopplung mit Code am Handy (#72) |
| **Netzteil** | später: Zündung, Spannung und Service-Modus (#36) |

Den Ton-Ausgang stellt man bis dahin am Gerät um
([Ton über die Klinke](ton-klinke.md)). Ohne erreichbares Backend ist die Zeile
Kamera auch nur eine Vorschau.

### Kamera

![Kamera-Einstellungen: links die USB-Kamera „USB PHY 2.0: USB CAMERA“ (/dev/video0) ausgewählt, rechts Videonorm, Eingang und Bildbreite ausgegraut, unten Kamerabild ansehen](bilder/optionen-kamera.png)

Der Pfeil oben links führt zurück zu **Geräte**. Die Seite hat zwei Spalten:

- **Links: GERÄT.** Die Videogeräte, die das Backend sieht (Name und Pfad, z. B.
  „USB PHY 2.0: USB CAMERA“, `/dev/video1`). Das eingestellte hat einen
  gefüllten Kreis. Ein gespeichertes Gerät, das nicht angeschlossen ist, bleibt
  mit dem Hinweis „Kamera nicht angeschlossen“ in der Liste. Ein fester Name
  unter `/dev/v4l/by-id/` (siehe [Kamera](kamera.md)) steht ohne diesen Hinweis
  da: Die Liste kennt nur `/dev/video<n>`, die Seite kann also nicht sagen, ob
  die Kamera dran ist. Sieht das Backend
  kein Gerät, steht „Keine Kamera gefunden“, und das gespeicherte Gerät bleibt
  darunter sichtbar.
- **Rechts:** **VIDEONORM** (NTSC oder PAL), **EINGANG** (0, 1, 2, 3 oder
  S-Video; 0 bis 3 sind Composite, S-Video ist der Eingang 4) und
  **BILDBREITE** (360 oder 720). Ist über die Konfiguration ein anderer Eingang
  gespeichert, steht er als weiterer Knopf dabei.
- **Jede Auswahl wird sofort gespeichert**, es gibt keinen Speichern-Knopf.
  Schlägt es fehl, bleibt der alte Wert stehen und „Befehl fehlgeschlagen“
  erscheint kurz. Solange gespeichert wird, reagieren die Knöpfe nicht.
- **Bei einer USB-Kamera** sind Norm, Eingang und Bildbreite ausgegraut, mit dem
  Hinweis, dass sie nur für analoge Kameras am USB-Adapter gelten. Ausgegraut wird nur bei einem
  Gerät mit dem Treiber `uvcvideo`; ist der Treiber unbekannt, bleiben die Felder
  bedienbar.
- **Bildbreite 720** ist schärfer, liefert aber nur etwa 10 Bilder pro Sekunde
  (Hinweis unter der Auswahl).
- Unten links: „Gilt ab dem nächsten Öffnen der Seite Kamera.“ und der Knopf
  **Kamerabild ansehen**, der zur Seite [Kamera](kamera.md) springt, um die
  Änderung zu sehen.
- Ist das Backend nicht erreichbar, steht „Die Verbindung zum Backend wurde
  unterbrochen …“ mit **Erneut versuchen**.

## System

![System: Frontend-Logs, darunter Logansicht öffnen, Nach Updates suchen, Neustart, Beenden](bilder/optionen-system.png)

- **Aktuelle Frontend-Logs:** die letzten 30 Zeilen.
- **Logansicht öffnen:** alle gepufferten Zeilen (bis 200) in einem Dialog.
- **Nach Updates suchen:** zeigt nur „Noch nicht verfügbar“ (#20).
- **Neustart:** startet **nur die Oberfläche** neu, sofort und ohne Rückfrage.
  Auf dem Pi übernimmt systemd den Neustart; Backend und Musik laufen weiter.
- **Beenden** – der **Wartungsmodus**: fragt nach einem Passwort und beendet
  dann die Oberfläche. **Das Passwort ist ab Werk `4321`.** Ändern lässt es
  sich noch nicht, es steht vorläufig fest im Code
  (`exit_password_dialog.dart`, #51). **Bestätigen** oder **Fertig** auf der
  Tastatur prüft es, bei falscher Eingabe erscheint „Falsches Passwort“.
  **Abbrechen** oder Antippen außerhalb des Dialogs bricht ab.

  Die Oberfläche startet danach **absichtlich nicht** von selbst neu: Wer das
  Passwort kennt, soll am Gerät eine Konsole bekommen und dort arbeiten
  können. Etwa 5 Sekunden nach dem Beenden erscheint die Text-Anmeldung. Das
  Backend läuft weiter. Zurück zur Oberfläche mit
  `sudo systemctl start carnine-frontend` oder einem Neustart des Geräts.
  Stürzt die Oberfläche dagegen ab, startet systemd sie nach 3 Sekunden neu,
  ohne dass die Konsole dazwischen erscheint.

  ![Dialog „Passwort erforderlich“ mit leerem Feld, Abbrechen und Bestätigen, darunter die Tastatur](bilder/optionen-beenden.png)
