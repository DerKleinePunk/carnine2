# Ton über vier Boxen (vorne und hinten)

[← Inhalt](README.md)

Für ein Auto mit Boxen **vorne und hinten**. carnine2 schickt den Ton dann als
**Dolby Digital (AC-3)** über HDMI an einen **5.1-Decoder**, der zwischen Pi
und Display sitzt, z. B. einen HDMI-Splitter mit Analog-Ausgängen. Der
Decoder gibt die vier Kanäle an die Verstärker weiter, das Bild geht weiter
zum Display.

| | vorne | hinten |
|---|---|---|
| Musik | ja, während einer Ansage leiser | ja, immer gleich laut |
| Ansagen | ja | nein |
| Pause | still | still |

Wie leise die Musik vorne unter einer Ansage wird, ist derselbe Wert wie bei
Stereo (Vorgabe 30 %, siehe
[Karten, Sprachansagen](karte.md#sprachansagen)). Die technischen
Hintergründe stehen in
[07 – Deployment, „Four speakers over AC-3“](../07-deployment.md#four-speakers-over-ac-3-hdmi-ac3).

**Nur mit so einem Decoder.** Ein Display oder Fernseher, der den Ton selbst
abspielt, versteht den AC-3-Strom nicht und bleibt **stumm**. Darum gibt es
dafür keinen Schalter in der Oberfläche, umgestellt wird wie unten
beschrieben.

**Wer das Image selbst baut**, nimmt `-t audio_output:hdmi-ac3`, dann ist
alles schon eingestellt
([resources/debos/README.md](../../resources/debos/README.md)). Die Schritte
unten sind für ein Gerät, das schon läuft.

## Was man braucht

- einen **5.1-Decoder mit HDMI-Eingang**, der **Dolby Digital (AC-3)** kann,
  z. B. einen HDMI-Splitter mit Analog-Ausgängen. Am Gerät auf **5.1**
  stellen, falls es einen Schalter hat. Mehrkanal-PCM reicht nicht.
- an den Ausgängen vorne links/rechts (FL/FR) und hinten links/rechts
  (SL/SR oder RL/RR) je einen Verstärker mit Boxen. Mitte (C) und Subwoofer
  (LFE) bleiben still.
- Zugang zum Pi mit Tastatur oder SSH und `sudo`.

## Einschalten

Alles, was gebraucht wird, ist schon im Image (`ffmpeg`), Internet ist nicht
nötig.

1. **Den Zwischenspeicher für den Ton laden** (ALSA-Loopback), jetzt und bei
   jedem Start:
   ```bash
   echo 'options snd-aloop id=Loopback pcm_substreams=1' | sudo tee /etc/modprobe.d/carnine-ac3.conf
   echo 'snd-aloop' | sudo tee /etc/modules-load.d/carnine-ac3.conf
   sudo modprobe snd-aloop
   grep Loopback /proc/asound/cards
   ```
   Die letzte Zeile muss eine Karte „Loopback“ zeigen.
2. **Die Tonkette einrichten.** Gibt es schon eine `/etc/asound.conf`, vorher
   sichern (`sudo cp /etc/asound.conf /root/asound.conf.bak`). Dann:
   ```bash
   sudo tee /etc/asound.conf > /dev/null << 'EOF'
   pcm.!default {
       type plug
       slave.pcm "carnine_volume"
   }
   pcm.carnine_volume {
       type softvol
       slave.pcm "carnine_loop"
       control {
           name "PCM Playback Volume"
           card 0
       }
   }
   pcm.carnine_loop {
       type plug
       slave {
           pcm "hw:CARD=Loopback,DEV=0"
           format S16_LE
           rate 48000
           channels 4
       }
   }
   ctl.!default {
       type hw
       card 0
   }
   EOF
   ```
   Der Name `PCM Playback Volume` muss genau so bleiben, sonst lässt sich die
   Lautstärke nicht mehr regeln.
3. **Den Kodierer als Dienst einrichten.** Er liest die vier Kanäle aus dem
   Zwischenspeicher, macht daraus Dolby Digital und schickt es auf HDMI:
   ```bash
   sudo tee /usr/local/sbin/carnine-ac3-encoder > /dev/null << 'EOF'
   #!/bin/sh
   set -eu
   input=${CARNINE_AC3_INPUT:-hw:CARD=Loopback,DEV=1}
   output=${CARNINE_AC3_OUTPUT:-hdmi:CARD=vc4hdmi0,AES0=0x06}
   ffmpeg -nostdin -hide_banner -loglevel warning \
       -f alsa -channels 4 -sample_rate 48000 -i "$input" \
       -af channelmap=channel_layout=quad \
       -c:a ac3 -b:a 448k -f spdif - |
       aplay -q -D "$output" -t raw -f S16_LE -c 2 -r 48000 \
           --buffer-time=200000 --period-time=50000
   EOF
   sudo chmod 0755 /usr/local/sbin/carnine-ac3-encoder
   sudo tee /etc/systemd/system/carnine-ac3.service > /dev/null << 'EOF'
   [Unit]
   Description=Carnine AC-3 encoder (ALSA loopback to HDMI0)
   After=sound.target alsa-restore.service

   [Service]
   User=carnine
   Group=carnine
   SupplementaryGroups=audio
   ExecStart=/usr/local/sbin/carnine-ac3-encoder
   Restart=always
   RestartSec=2

   [Install]
   WantedBy=multi-user.target
   EOF
   sudo systemctl daemon-reload
   sudo systemctl enable --now carnine-ac3
   ```
   Läuft carnine2 auf dem Gerät unter einem anderen Benutzer als `carnine`
   (`systemctl show -p User carnine-backend`), `User=` und `Group=` im Dienst
   genauso setzen.
4. **carnine2 auf vier Kanäle stellen:**
   ```bash
   sudo mkdir -p /etc/carnine/config.d
   printf '[audio]\nchannels = 4\n' | sudo tee /etc/carnine/config.d/20-audio-ac3.toml
   ```
5. **Vorher leise drehen**, dann das Backend neu starten:
   ```bash
   sudo systemctl restart carnine-backend
   ```
   Die Verstärker zuerst ganz leise drehen und in carnine2 mit kleiner
   Lautstärke anfangen. Ein Verstärker hinten mit viel Leistung ist sonst
   sofort sehr laut.
6. **Prüfen:** Das Backend schreibt beim Start ins Log, mit wie vielen Kanälen
   es spielt:
   ```bash
   journalctl -u carnine-backend -b | grep "stream started"
   systemctl is-active carnine-ac3
   ```
   Dort muss `channels=4` und `active` stehen. Unter [Medien](medien.md)
   einen Titel abspielen: Er muss aus allen vier Boxen kommen. Eine Ansage
   kommt nur vorne.

Ein Neustart des Pi ist nicht nötig. Nach einem Neustart läuft alles von
selbst wieder.

## Hinten zu laut?

Sind die Verstärker hinten viel stärker als vorne, übertönt die Musik hinten
die Ansagen vorne, auch wenn der Verstärker hinten schon ganz leise steht.
Dann die Musik hinten in carnine2 absenken, in Prozent von vorne (50 ≈ −6 dB,
30 ≈ −10 dB, 10 = −20 dB):

```bash
printf '[audio]\nrear_percent = 30\n' | sudo tee /etc/carnine/config.d/30-audio-rear.toml
sudo systemctl restart carnine-backend
```

Den Wert nach Gehör wählen und nach jeder Änderung das Backend neu starten. Am
Test-Pi (160 W hinten, 20 W vorne) passt 30. Ohne den Eintrag gilt 100,
hinten so laut wie vorne.

## Ausschalten (zurück auf Stereo)

```bash
sudo systemctl disable --now carnine-ac3
sudo rm /etc/systemd/system/carnine-ac3.service /usr/local/sbin/carnine-ac3-encoder
sudo rm /etc/modprobe.d/carnine-ac3.conf /etc/modules-load.d/carnine-ac3.conf
sudo rm /etc/asound.conf /etc/carnine/config.d/20-audio-ac3.toml
sudo rm -f /etc/carnine/config.d/30-audio-rear.toml
sudo systemctl daemon-reload
sudo systemctl restart carnine-backend
```

Danach spielt carnine2 wieder in Stereo über HDMI, genau wie vorher. Lag vor
Schritt 2 schon eine eigene `/etc/asound.conf`, die Sicherung zurückkopieren.
**Alles entfernen:** Bleibt ein Teil stehen, passen Tonkette und carnine2
nicht mehr zusammen. Der Zwischenspeicher (Loopback) bleibt bis zum nächsten
Neustart geladen, das stört nicht.

## Gut zu wissen

- **Kein Plopp.** Am Splitter ploppt es beim Anhalten nicht: Der Ton läuft als
  durchgehender Strom, eine Pause ist darin nur Stille.
- **Wenig Rechenzeit.** Der Strom läuft immer, auch bei Pause. Der Kodierer
  braucht dafür am Test-Pi etwa 7 % eines Kerns, sonst kostet es nicht mehr
  als Stereo.
- **Lautstärke.** Der Lautstärkeregler in carnine2 regelt alle vier Boxen gleich, den
  Abstand zwischen vorne und hinten bestimmen die Verstärker und
  `rear_percent`.

*Geprüft:* am 13.10.2026 auf dem Test-Pi jeep-pi (Pi 4, HDMI-Splitter mit
5.1-Ausgängen, 20 W vorne, 160 W hinten), Musik auf allen vier Boxen,
Ansagen nur vorne, `rear_percent = 30`, fast zehn Stunden Dauerlauf mit
Musik und 1381 Ansagen ohne hörbaren Aussetzer. Die Schritte von Hand auf dieser
Seite entsprechen dem, was die Image-Variante `hdmi-ac3` schreibt.
