# Ton über die Klinke des Pi

[← Inhalt](README.md)

Für Displays **ohne Lautsprecher**, zum Beispiel das **Waveshare 7C** (das 7H
hat Lautsprecher, das 7C nicht). carnine2 schickt den Ton im
Auslieferungszustand über HDMI zum Display. Ohne Lautsprecher im Display ist
dann **nichts zu hören, aber auch kein Fehler zu sehen**. Mit den Schritten
unten kommt der Ton aus der **3,5-mm-Klinke am Raspberry Pi**. An der Software
ändert sich nichts. Die technischen Hintergründe stehen in
[07 – Deployment, „Audio output“](../07-deployment.md#audio-output).

**Wer das Image selbst baut**, braucht die Schritte unten nicht: Mit
`-t audio_output:jack` beim Bauen ist die Klinke gleich die erste Soundkarte
(#64, siehe [resources/debos/README.md](../../resources/debos/README.md)).
Die Schritte unten sind für ein fertiges Image, das auf HDMI steht.

## Was man braucht

- einen **Raspberry Pi 4 oder Pi 3**. Der **Pi 5 hat keine Klinke**.
- an der Klinke etwas mit eigenem Verstärker: **PC-Aktivboxen**,
  Aktivlautsprecher, ein Verstärker oder der AUX-Eingang des Autoradios. Die
  Klinke des Pi ist nicht für passive Lautsprecher gedacht und rauscht etwas.
- Zugang zum Pi mit Tastatur oder SSH und `sudo`.

## Umstellen

1. **Klinke als erste Soundkarte einstellen.** Der Befehl ersetzt die eine
   Zeile in der Datei:
   ```bash
   echo 'options snd slots=snd_bcm2835,vc4,vc4' | sudo tee /etc/modprobe.d/carnine-audio.conf
   ```
2. **Die Initramfs neu bauen**, vorher eine Sicherung anlegen:
   ```bash
   sudo cp /boot/initrd.img-$(uname -r) /root/initrd.img-$(uname -r).bak
   sudo dracut --force /boot/initrd.img-$(uname -r) $(uname -r)
   ```
   `dracut` braucht auf dem Pi 3 gut 1–2 Minuten und zeigt dabei nichts an,
   einfach warten.

   Wer vor dem Neustart prüfen will (hilft bei der Fehlersuche): Dieser Befehl
   muss die **neue** Zeile zeigen. Steht dort noch die alte, hat dracut die
   Datei nicht übernommen, und nach dem Neustart bleibt HDMI die erste
   Soundkarte.
   ```bash
   sudo lsinitrd -f etc/modprobe.d/carnine-audio.conf /boot/initrd.img-$(uname -r)
   ```
   Dann neu starten:
   ```bash
   sudo systemctl reboot
   ```
3. **Prüfen:**
   ```bash
   cat /proc/asound/cards
   ```
   Ganz oben (Nummer **0**) muss **Headphones** stehen. Beim Pi 4 folgen
   darunter vc4hdmi0 und vc4hdmi1, beim Pi 3 nur vc4hdmi.
4. **Lautstärke einstellen**, in dieser Reihenfolge:
   1. Den Lautstärkeknopf an den Boxen (oder am Verstärker) **ganz leise**
      drehen. Aktivboxen brauchen ihren eigenen Strom (Netzteil oder USB).
   2. Unter [Medien](medien.md) einen Titel abspielen und den Regler in
      carnine2 auf eine **mittlere Lautstärke** stellen, etwa 50 %.
   3. Erst dann den Knopf an den Boxen hochdrehen, bis es passt.

   So ist die Klinke gut ausgesteuert und rauscht weniger, als wenn carnine2
   leise und die Boxen voll aufgedreht sind. Gleiche Prozente klingen an der
   Klinke und über HDMI etwa gleich laut (#65). Die gespeicherte Lautstärke
   gilt für beide Ausgänge: Nach dem Umstellen beginnt carnine2 mit demselben
   Prozentwert wie vorher, beim ersten Start eines frischen Images mit 50 %.

## Zurück auf HDMI

Dieselben Schritte mit der ursprünglichen Zeile:

```bash
echo 'options snd slots=vc4,vc4,snd_bcm2835' | sudo tee /etc/modprobe.d/carnine-audio.conf
sudo dracut --force /boot/initrd.img-$(uname -r) $(uname -r)
sudo systemctl reboot
```

Die Sicherung aus Schritt 2 ist nur ein Notnagel. Zurückkopieren allein reicht
nicht, weil sie dann nicht in die Datei gelangt, die der Pi beim Start lädt
(`/boot/firmware/initramfs8`).

## Das EDID des Displays

Je nach Image ist der Pi auf das Waveshare **7H** eingestellt: Er liest dann die
Kennung (EDID) des Displays nicht, sondern nimmt eine gespeicherte des 7H, auch
wenn ein 7C dranhängt. Für den Ton über die Klinke spielt das keine Rolle. Für
ein sauberes Bild und künftige Images brauchen wir aber die Kennung weiterer
Displays. So bekommt man sie als Datei auf den PC:

1. **Prüfen, ob eine gespeicherte Kennung eingestellt ist:**
   ```bash
   grep -o 'drm.edid_firmware=[^ ]*' /proc/cmdline
   ```
   - **Keine Ausgabe:** Der Pi liest das Display selbst, weiter mit Schritt 2.
   - **Eine Zeile erscheint:** Dann zeigt der Pi die gespeicherte Datei statt des
     Displays. Erst den Eintrag entfernen, wie in
     [22 – Waveshare Display, „Reading a panel's own EDID“](../22-waveshare-display-1024x600.md#reading-a-panels-own-edid)
     beschrieben (mit Sicherung und Rückweg, auch wenn das Bild schwarz
     bleibt), danach hier weitermachen.
2. **Die Kennung in eine Datei schreiben.** Das Display muss an **HDMI 0**
   hängen (beim Pi 4 der Anschluss neben USB-C):
   ```bash
   cat /sys/class/drm/card*-HDMI-A-1/edid > ~/edid-panel.bin
   ls -l ~/edid-panel.bin
   ```
   Die Datei ist 128 oder 256 Byte groß. Steht dort **0**, ist kein Display
   erkannt, dann Kabel und Anschluss prüfen. Zusätzlich, was der Kernel dazu
   meldet (`dmesg` braucht `sudo`):
   ```bash
   sudo dmesg | grep -iE "edid|not supported" > ~/edid-panel-dmesg.txt
   ```
3. **Die Datei auf den PC holen.** Am PC (Windows PowerShell, Git Bash oder
   Linux), den eigenen Gerätenamen einsetzen:
   ```bash
   scp pi@carnine-pc-843d.local:edid-panel.bin .
   scp pi@carnine-pc-843d.local:edid-panel-dmesg.txt .
   ```
   Ohne `scp` geht es auch mit WinSCP oder FileZilla (SFTP, Benutzer `pi`,
   Ordner `/home/pi`).
4. **Wiederherstellen**, falls in Schritt 1 etwas entfernt wurde (Anleitung
   in 22), und die Datei(en) bitte an Michael schicken.

Gemessen am Waveshare-Display von `carnine-pc-843d` (02.10.2026): Dort war kein
`drm.edid_firmware` eingestellt, der Pi las das Display selbst. Es lieferte
**128 Byte ohne Audioteil** (1024 × 600). Das erklärt, warum über HDMI kein Ton
kam: Das Display meldet keinen Ton, der Pi schickt ihn nicht dorthin.

Den Ausgang in der Oberfläche wählen zu können, ist geplant (#48).

*Geprüft:* genau nach dieser Seite auf einem **Pi 3** (carnine-pc, 29.09.):
danach 0 Headphones, 1 vc4hdmi, der Ton lief auf Karte 0, zurück auf HDMI ging
ebenso. Auf einem **Pi 4** (carnine-pc-843d, 02.10.2026, Image 0.10.0) ebenso:
vorher 0 vc4hdmi0, 1 vc4hdmi1, 2 Headphones, danach 0 Headphones, 1 vc4hdmi0,
2 vc4hdmi1. Das Backend öffnete den Ton auf Karte 0 und stellte die Lautstärke
über deren Regler `PCM` ein. `dracut` brauchte auf dem Pi 4 nur wenige
Sekunden. Gehört wurde der Ton an der Klinke noch nicht; am Waveshare 7C ist es
noch nicht geprüft.
