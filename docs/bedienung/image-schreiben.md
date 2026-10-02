# Image auf die SD-Karte schreiben

[← Inhalt](README.md)

carnine2 kommt als fertiges Image für den Raspberry Pi. Es wird einmal auf
eine SD-Karte geschrieben, die Karte kommt in den Pi, fertig. Diese Seite
beschreibt das Schreiben unter **Windows mit Rufus** und unter **Linux mit
`bmaptool`** (oder `dd`). Was nach dem ersten Start zu tun ist, steht unter
[Nach der Installation](nach-der-installation.md).

**Beim Schreiben wird alles gelöscht, was auf der Karte ist.** Vorher genau
prüfen, dass die richtige Karte gewählt ist und nicht ein USB-Stick oder eine
Festplatte.

## Was man braucht

- eine **SD-Karte mit mindestens 16 GB**, besser 32 GB. Das Image selbst
  braucht nur 3 GB, die Kartendaten für Hessen später aber knapp 8 GB, beim
  Auspacken kurz noch mehr
  ([Kartendaten installieren](nach-der-installation.md#kartendaten-installieren)).
- einen Kartenleser am PC
- einen **Raspberry Pi 4**. Getestet und freigegeben wird nur der Pi 4.
- die Dateien des Images, für jede Version drei:

| Datei | Inhalt |
|---|---|
| `carnine-v0.11.0-waveshare-hdmi.img.gz` | das Image, gepackt |
| `carnine-v0.11.0-waveshare-hdmi.img.bmap` | Blockkarte für `bmaptool` (unter Windows nicht nötig) |
| `carnine-v0.11.0-waveshare-hdmi.SHA256SUMS` | Prüfsummen der beiden Dateien oben |

### Welche Variante?

| Variante | Ton | für |
|---|---|---|
| `…-waveshare-hdmi` | über HDMI zum Display | Waveshare **7H** (hat Lautsprecher) |
| `…-waveshare-jack` | aus der 3,5-mm-Klinke des Pi | Waveshare **7H**, Ton lieber über eigene Boxen ([Ton über die Klinke](ton-klinke.md)) |
| `…-waveshare-7c` | aus der Klinke | Waveshare **7C** (ohne Lautsprecher), siehe [unten](#waveshare-7c) |

Im Zweifel `hdmi`. Umstellen geht später auch noch, siehe
[Ton über die Klinke](ton-klinke.md).

**Das `7c`-Image nicht an ein 7H.** Ohne die Vorgabe meldet sich das 7H mit
seiner geklonten Kennung, in der 1024 × 600 fehlt. Der Pi wählt dann
1920 × 1080, und das Bild passt nicht (geprüft am 7H, 02.10.2026).
Umgekehrt flackert das 7C mit `hdmi` und `jack`, siehe unten.

### Waveshare 7C

Die Images `hdmi` und `jack` sind auf das **7H** eingestellt: Sie geben dem
Display die Kennung (EDID) des 7H vor. Am 7C flackerte das Bild damit. Das 7C
braucht diese Vorgabe nicht und läuft mit seiner eigenen Kennung, der Ton kommt
aus der Klinke (geprüft an einem 7C, 02.10.2026). Dafür gibt es seit 0.11.0 das
Image **`…-waveshare-7c`**: ohne Vorgabe, Ton aus der Klinke. Es wird wie die
anderen geschrieben, mehr ist nicht zu tun.

**Mit einem älteren Image (bis 0.10.0)** gibt es kein 7C-Image. Dann:

1. Das `…-waveshare-jack`-Image wie unten beschrieben auf die Karte schreiben.
2. Die Karte noch einmal in den PC stecken. Die kleine Partition
   **FIRMWARE** lässt sich auch unter Windows öffnen. Die Frage nach dem
   Formatieren der anderen Partition: **Abbrechen**.
3. Dort `cmdline.txt` mit einem Texteditor öffnen. Die Datei ist **eine
   einzige Zeile**. Darin genau dieses Stück löschen, mit dem Leerzeichen davor:
   ```
    drm.edid_firmware=HDMI-A-1:edid/waveshare-7h-260929.bin
   ```
   Sonst nichts ändern, keinen Zeilenumbruch einfügen. Speichern, Karte
   auswerfen.

Die Hintergründe stehen in
[22 – Waveshare Display, „Waveshare 7C“](../22-waveshare-display-1024x600.md#waveshare-7c).

## Prüfsumme kontrollieren

Damit sicher ist, dass der Download vollständig ist. Alle Dateien liegen im
selben Ordner.

**Windows** (PowerShell, im Ordner mit den Dateien):

```powershell
Get-FileHash -Algorithm SHA256 .\carnine-v0.11.0-waveshare-hdmi.img.gz
```

Die ausgegebene Zahl muss mit der Zeile in `….SHA256SUMS` übereinstimmen
(PowerShell schreibt sie in Großbuchstaben, das ist egal).

**Linux:**

```bash
sha256sum -c carnine-v0.11.0-waveshare-hdmi.SHA256SUMS
```

Beide Dateien müssen `OK` melden.

## Windows: Rufus

[Rufus](https://rufus.ie) ist kostenlos und braucht keine Installation (die
„Portable“-Fassung reicht). Es schreibt das gepackte `.img.gz` direkt,
auspacken ist nicht nötig.

1. SD-Karte in den Kartenleser stecken, Rufus starten und die Frage nach
   Administratorrechten mit **Ja** beantworten.
2. Unter **Laufwerk** die SD-Karte wählen. An der Größe prüfen, dass es die
   Karte ist.
3. Unter **Startart** „Laufwerk oder ISO-Image“ lassen, rechts daneben auf
   **AUSWAHL** und die Datei `carnine-…img.gz` öffnen. Die übrigen Felder
   füllt Rufus selbst aus, sie bleiben so.
4. **START**. Rufus warnt, dass alle Daten auf dem Laufwerk gelöscht werden:
   mit **OK** bestätigen.
5. Warten, bis unten **BEREIT** steht, dann Rufus schließen und die Karte
   abziehen.

**Danach fragt Windows oft, ob die Karte formatiert werden soll:**
**Abbrechen.** Windows kann die Linux-Partition der Karte nicht lesen und hält
sie deshalb für leer. Formatieren würde das Image wieder löschen.

Aus der WSL heraus geht es nicht, dort ist die SD-Karte nicht zu sehen.

## Linux: bmaptool

`bmaptool` schreibt nur die belegten Blöcke (etwa 1,4 von 3 GB) und prüft sie
dabei gegen die Prüfsummen in der `.bmap`. Unter Debian und Ubuntu:

```bash
sudo apt install bmap-tools
```

**1. Die Karte finden.** Einmal ohne und einmal mit gesteckter Karte
aufrufen; die neue Zeile ist die Karte:

```bash
lsblk -d -o NAME,SIZE,MODEL,TRAN
```

Ein eingebauter Kartenleser heißt meist `mmcblk0`, ein Kartenleser am USB
`sda`, `sdb` … Im Folgenden steht `/dev/sdX` für die Karte: **genau den
gefundenen Namen einsetzen**, ohne Ziffer am Ende (`/dev/sdb`, nicht
`/dev/sdb1`; beim eingebauten Leser `/dev/mmcblk0`).

**2. Partitionen aushängen**, falls der Rechner die alte Karte eingehängt hat:

```bash
sudo umount /dev/sdX?*
```

(„not mounted“ ist in Ordnung. Beim eingebauten Leser `/dev/mmcblk0p*`.)

**3. Schreiben.** `bmaptool` findet die `.bmap` neben dem Image selbst:

```bash
sudo bmaptool copy carnine-v0.11.0-waveshare-hdmi.img.gz /dev/sdX
```

Fertig ist es, wenn `synchronizing '/dev/sdX'` und die Zeit erscheinen. Dann
kann die Karte heraus.

### Ohne bmaptool: dd

Geht überall, schreibt aber die vollen 3 GB und prüft nichts:

```bash
gunzip -c carnine-v0.11.0-waveshare-hdmi.img.gz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress
```

Bei `dd` ist ein falscher Gerätename besonders schnell fatal: Es fragt nicht
nach.

## Erster Start

Karte in den Pi stecken, Display anschließen, Strom an. Beim **ersten Start**
vergrößert der Pi die Partition auf die ganze Karte und **startet dabei einmal
von selbst neu**. Danach erscheint die Oberfläche.

Weiter geht es mit [Nach der Installation](nach-der-installation.md):
Standardpasswort ändern, Gerätename, WLAN und Kartendaten.

*Geprüft (02.10.2026, Image 0.10.0): Prüfsummen unter Linux und mit
PowerShell, `bmaptool copy` (3.6) und der `dd`-Weg, beide in eine Datei statt auf eine
Karte; sie schreiben bytegleich dasselbe. Auf jeep-pi wird seit 0.9.3 mit `dd` geschrieben.*
