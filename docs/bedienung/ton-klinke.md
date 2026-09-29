# Ton über die Klinke des Pi

[← Inhalt](README.md)

Für Displays **ohne Lautsprecher**, zum Beispiel das **Waveshare 7C** (das 7H
hat Lautsprecher, das 7C nicht). carnine2 schickt den Ton im
Auslieferungszustand über HDMI zum Display. Ohne Lautsprecher im Display ist
dann **nichts zu hören, aber auch kein Fehler zu sehen**. Mit den Schritten
unten kommt der Ton aus der **3,5-mm-Klinke am Raspberry Pi**. An der Software
ändert sich nichts. Die technischen Hintergründe stehen in
[07 – Deployment, „Audio output“](../07-deployment.md#audio-output).

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
      carnine2 auf **etwa 75–85 %** stellen.
   3. Erst dann den Knopf an den Boxen hochdrehen, bis es passt.

   So ist die Klinke gut ausgesteuert und rauscht weniger, als wenn carnine2
   leise und die Boxen voll aufgedreht sind. An der Klinke sind 50 % sehr
   leise. Das ist kein Fehler, die Klinke rechnet die Prozente anders als
   HDMI. Die gespeicherte Lautstärke gilt für beide Ausgänge: Nach dem
   Umstellen beginnt carnine2 mit demselben Prozentwert wie vorher, beim
   ersten Start eines frischen Images mit 50 %.

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

Das Image ist auf das Waveshare **7H** eingestellt: Der Pi liest die Kennung
(EDID) des Displays nicht, sondern nimmt eine gespeicherte des 7H, auch wenn
ein 7C dranhängt. Für den Ton über die Klinke spielt das keine Rolle. Für ein
sauberes Bild und künftige Images brauchen wir aber die Kennung weiterer
Displays. Wie man sie ausliest, mit Sicherung und Rückweg (auch wenn das Bild
schwarz bleibt), steht in
[22 – Waveshare Display, „Reading a panel's own EDID“](../22-waveshare-display-1024x600.md#reading-a-panels-own-edid).
Die Datei bitte an Michael schicken.

Den Ausgang in der Oberfläche wählen zu können, ist geplant (#48).

*Geprüft:* Das Umstellen auf die Klinke lief auf carnine-pc, damals einem
Pi 4. Pi 3 und Waveshare 7C sind noch nicht geprüft.
