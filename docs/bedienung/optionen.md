# Optionen

[← Inhalt](README.md)

Vier Kacheln; der Pfeil oben links in jeder Unterseite führt zurück zur
Übersicht.

![Optionen: vier Kacheln Karteneinstellungen, Darstellung & Sprache, Geräte, System](bilder/optionen.png)

| Kachel | Inhalt |
|---|---|
| **Karteneinstellungen** | zwei Reiter: **Ansagen** (Sprachansagen der Navigation) und **Karte** (Zoom beim Folgen) |
| **Darstellung & Sprache** | zwei Reiter: **Darstellung** (noch leer) und **Sprache** (Anzeigesprache wählen) |
| **Geräte** | **Kamera** und **Display** (Helligkeit) einstellen; Audio-Ausgang, Handy-App und Netzteil als Vorschau |
| **System** | Logs, Updates, Passwort ändern, Neustart, Beenden, Version |

## Karteneinstellungen

Oben zwei Reiter: **Ansagen** und **Karte**. Die Seite öffnet auf **Ansagen**.

**Ansagen** stellt die gesprochenen Abbiegehinweise der Navigation ein
([Karten, Sprachansagen](karte.md#sprachansagen)). Jede Änderung gilt sofort und
bleibt über Neustarts erhalten, das Backend speichert sie.

- **Sprachansagen:** Die ganze Karte antippen schaltet die Ansagen an oder aus.
- **Lautstärke der Ansagen** (0 bis 100 %): Den Griff ziehen, gesendet wird beim
  Loslassen. Die Stufen sind 5 %.
- **Musik während einer Ansage** (0 bis 100 %): Wie laut die Musik bleibt,
  solange gesprochen wird. Bei **0 %** hält die Musik an und läuft danach an
  derselben Stelle weiter, bei **100 %** bleibt sie gleich laut. Ab Werk 30 %.
- **Ansage testen** spricht den Satz „In 300 Metern rechts abbiegen.“, damit man
  Lautstärke und Musik gleich hört. Der Satz ist immer deutsch, weil die Stimme
  deutsch ist. Beim ersten Mal braucht das Gerät ein paar Sekunden, um ihn zu
  sprechen. Ausgegraut bei ausgeschalteten Ansagen.
- **Keine Stimme installiert:** Fehlt das Sprachpaket `carnine-voice` (z. B. in
  WSL), steht das statt der Erklärung auf der Karte, und nichts auf der Seite
  lässt sich ändern.
- Ist das Backend nicht erreichbar, steht „Die Verbindung zum Backend wurde
  unterbrochen …“ mit **Erneut versuchen**. Schlägt eine Änderung fehl, erscheint
  kurz „Befehl fehlgeschlagen“, und der Regler springt auf den gespeicherten Wert.

Die Ansagen gibt es nur, wenn die Oberfläche auf Deutsch steht, die Einstellungen
selbst sind in jeder Sprache bedienbar.

**Karte** stellt ein, wie nah die Karte ist, wenn sie dem Auto folgt. Ein Regler
mit den Stufen **14 bis 17** (14 weit, 17 nah). Ab Werk gilt **16**. Die Karte
geht beim Loslassen sofort auf die neue Stufe, und das Backend merkt sie sich
über Neustarts hinweg. Schlägt das Speichern fehl, springt die Karte zurück und
kurz steht „Befehl fehlgeschlagen“. Mehr zum Folgen steht unter
[Karten, Zoom beim Folgen](karte.md#karte-bewegen).

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

Die Seite zeigt fünf Geräte-Bereiche. Jede Zeile hat ein Symbol, einen Namen
und eine Kurzbeschreibung. **Kamera** und **Display** haben eine Seite; sie
haben einen Pfeil und lassen sich antippen. Die anderen drei sind eine
**Vorschau**: ausgegraut, ohne Pfeil, **nicht antippbar**:

| Zeile | Inhalt |
|---|---|
| **Kamera** | Gerät, Videonorm, Eingang und Bildbreite (siehe unten) |
| **Display** | Helligkeit des Displays (siehe unten) |
| **Audio-Ausgang** | später: HDMI, Klinke oder USB-Soundkarte wählen (#48) |
| **Handy-App** | später: Bluetooth-Kopplung mit Code am Handy (#72) |
| **Netzteil** | später: Zündung, Spannung und Service-Modus (#36) |

Den Ton-Ausgang stellt man bis dahin am Gerät um
([Ton über die Klinke](ton-klinke.md)). Ohne erreichbares Backend sind die
Zeilen Kamera und Display auch nur eine Vorschau.

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

### Display

Die Helligkeit des Display-Hintergrunds, 0 bis 100 %. Die Zeile **Display**
lässt sich nur antippen, wenn das Display dafür **umgebaut** ist (Waveshare 7H:
ein Widerstand entfernt, das Pad an GPIO 19) und im Backend `[display.backlight]`
eingerichtet ist ([Konfiguration](../07-deployment.md)). Sonst ist die Zeile
ausgegraut und sagt „Dieses Display hat keine Helligkeitsregelung“.

- Ein Regler mit großem Griff, in Schritten von 5 %. Das Display folgt dem
  Griff **schon beim Ziehen** (etwa alle 150 ms) und noch einmal beim Loslassen.
  Der Wert steht groß daneben, darunter die Enden „dunkel“ und „hell“.
- **0 %** ist die dunkelste Stufe, die das Backend erlaubt (Vorgabe 10 %
  Tastgrad), nie schwarz. Das steht auch als Hinweis unter dem Regler. So kann
  man das Display nicht versehentlich unlesbar machen.
- Der Wert bleibt über Neustarts erhalten, das Backend speichert ihn. Ohne
  gespeicherten Wert ist es 100 %.
- Ist das Display umgebaut, aber der PWM-Kanal gerade nicht ansprechbar
  (Overlay oder Chip fehlen), ist der Regler ausgegraut und es steht „Die
  Helligkeit lässt sich gerade nicht ändern.“
- Schlägt eine Änderung fehl, springt der Regler auf den gespeicherten Wert
  zurück, und kurz steht „Befehl fehlgeschlagen“.

## System

![System: zwei Gruppen mit je drei Kacheln, Wartung (Logansicht, Updates, Passwort ändern) und Oberfläche (Neustart, Beenden, Version)](bilder/optionen-system.png)

Die Seite hat sechs große Kacheln in zwei Gruppen. Jede Kachel nennt in einer
Zeile, was sie tut.

**Wartung**

- **Logansicht öffnen:** alle gepufferten Zeilen der Oberfläche (bis 200) in
  einem Dialog.
- **Nach Updates suchen:** zeigt nur „Noch nicht verfügbar“ (#20).
- **Passwort ändern:** ändert das Passwort für **Beenden**, siehe
  [Beenden-Passwort](#beenden-passwort).

**Oberfläche**

- **Neustart:** startet **nur die Oberfläche** neu, sofort und ohne Rückfrage.
  Auf dem Pi übernimmt systemd den Neustart; Backend und Musik laufen weiter.
- **Beenden** (rot): der **Wartungsmodus**. Fragt nach dem
  [Beenden-Passwort](#beenden-passwort) und beendet dann die Oberfläche.
- **Version:** zeigt die Versionsnummer der Oberfläche und darunter das Datum
  des Builds (z. B. `0.18.0` und `2026-10-14`). Die Kachel ist nur eine
  Anzeige.

### Beenden

**Beenden** fragt nach dem Passwort. **Bestätigen** oder **Fertig** auf der
Tastatur schickt es zur Prüfung an das Backend; solange es prüft (etwa eine
Sekunde), steht unter dem Feld „Wird geprüft …“. Bei falscher Eingabe erscheint
„Falsches Passwort“ und das Feld ist wieder leer. **Abbrechen** oder Antippen
außerhalb des Dialogs bricht ab.

Das **Auge** im Feld zeigt die Eingabe, ein zweiter Tipp blendet sie wieder
aus. Das Passwort steht sonst nur als Punkte da.

Ist das Backend nicht erreichbar, beendet sich die Oberfläche **nicht**. Unter
dem Feld steht „Das Passwort kann gerade nicht geprüft werden. Bitte versuchen
Sie es gleich noch einmal.“, der Dialog bleibt offen, und ein erneutes
**Bestätigen** versucht es noch einmal.

Die Oberfläche startet danach **absichtlich nicht** von selbst neu: Wer das
Passwort kennt, soll am Gerät eine Konsole bekommen und dort arbeiten können.
Etwa 5 Sekunden nach dem Beenden erscheint die Text-Anmeldung. Das Backend
läuft weiter. Zurück zur Oberfläche mit `sudo systemctl start carnine-frontend`
oder einem Neustart des Geräts. Stürzt die Oberfläche dagegen ab, startet
systemd sie nach 3 Sekunden neu, ohne dass die Konsole dazwischen erscheint.

![Dialog „Passwort erforderlich“ mit leerem Feld und dem Auge, Abbrechen und Bestätigen, darunter die Tastatur](bilder/optionen-beenden.png)

### Beenden-Passwort

Das Passwort steht **nicht in dieser Anleitung**. Wer das Gerät eingerichtet
hat, kennt es. Das Backend hält es nur als Hash (Argon2id); die Oberfläche
speichert es nirgends. Ändern: **System → Passwort ändern**. Der
Dialog fragt Schritt für Schritt, mit je einem Feld:

1. **Das aktuelle Passwort.** Ist es falsch, steht „Falsches Passwort“ und es
   geht nicht weiter.
2. **Das neue Passwort**, 4 bis 64 Zeichen. Ist es kürzer oder länger, steht
   „Das neue Passwort muss 4 bis 64 Zeichen lang sein.“
3. **Das neue Passwort noch einmal.** Stimmen die beiden nicht überein, geht es
   zurück zu Schritt 2.

Danach steht „Das Passwort wurde erfolgreich geändert.“, **Fertig** schließt den
Dialog. Das neue Passwort gilt sofort, übersteht einen Neustart und eine
Neuinstallation der Pakete (`deploy_pi.sh`). Ist das Backend zwischendurch
nicht erreichbar, bleibt der Dialog auf dem Schritt und meldet es; dann noch
einmal **Weiter** bzw. **Bestätigen**.

Zurück auf das Passwort aus der Konfiguration (`config.toml`) geht es mit
`sudo rm /etc/carnine/config.d/30-exit-password.toml` und einem Neustart des
Backends (`sudo systemctl restart carnine-backend`).
