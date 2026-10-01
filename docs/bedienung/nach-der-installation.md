# Nach der Installation: Passwort, Gerätename, Kartendaten

[← Übersicht](README.md)

Ein frisch geschriebenes Image hat ein **bekanntes Standardpasswort**, einen
Namen, den das Gerät sich beim ersten Start selbst gibt, und **keine
Kartendaten**. Passwort und Namen sollte man gleich nach dem ersten Start
anpassen, spätestens bevor das Gerät in ein fremdes Netz oder ins Auto kommt.
Die Kartendaten holt sich das Gerät mit einem Befehl selbst.

## Was das Image mitbringt

| | Wert nach dem ersten Start |
|---|---|
| Benutzer | `pi` (darf `sudo`, fragt dabei nach dem Passwort) |
| Passwort | `raspberry`, außer das Image wurde mit `-t rootpassword:<passwort>` gebaut |
| SSH | an, mit Passwort; Images für das Waveshare-Panel zusätzlich mit dem Schlüssel aus dem Bau |
| Gerätename | `carnine-pc-` und die letzten vier Stellen der Seriennummer, z. B. `carnine-pc-a869` (#62) |
| Im Netz | über DHCP, per mDNS als `<name>.local` erreichbar |

`root` hat kein Passwort und kann sich nicht anmelden. Das Passwort für
**Optionen → Beenden** in der Oberfläche ist ein anderes, es steht fest im
Code und lässt sich am Gerät nicht ändern (#51).

Solange `pi` noch das Standardpasswort hat, erscheint bei **jeder
Anmeldung**, an der Konsole wie per SSH, diese Warnung:

```text
WARNUNG: Der Benutzer 'pi' hat noch das Standardpasswort.
Jeder im selben Netz kann sich damit per SSH anmelden.
Bitte jetzt mit 'passwd' ein eigenes Passwort setzen.
```

Darunter steht derselbe Text auf Englisch. Befehle per SSH ohne Terminal
(z. B. `deploy_pi.sh`) bleiben still. Die Warnung gibt es in Images ab der
Version nach 0.9.5. **Bis 0.9.5 warnt nichts**, man muss selbst daran
denken.

## Anmelden

- **Über das Netz:** `ssh pi@carnine-pc-a869.local` (den eigenen Namen
  einsetzen). Wer den Namen nicht kennt, findet ihn im Router unter den
  DHCP-Geräten oder mit `avahi-browse -at` auf einem Linux-Rechner.
- **Am Gerät:** **Optionen → Beenden** in der Oberfläche, danach erscheint
  die Text-Anmeldung ([Optionen](optionen.md#system)). Dafür braucht es eine
  USB-Tastatur. Zusätzlich läuft auf der zweiten Konsole (`tty2`) immer eine
  Anmeldung. Ob man mit **Strg + Alt + F2** dorthin kommt, während die
  Oberfläche läuft, ist noch nicht geprüft.

## Passwort ändern

Angemeldet als `pi`:

```sh
passwd
```

Erst das alte Passwort, dann zweimal das neue. Es gilt sofort für SSH, die
Konsole und `sudo`. Die Warnung ist danach ohne Neustart weg, bei der
nächsten Anmeldung erscheint sie nicht mehr. Dafür prüft
`carnine-password-check` beim Start und bei jeder Änderung von `/etc/shadow`,
ob noch das Standardpasswort gilt.

Wurde das Image mit einem eigenen `-t rootpassword:…` gebaut, ist das alte
Passwort dieses und nicht `raspberry`.

### Anmelden mit Passwort über SSH abschalten (wahlweise)

Nur, wenn die Anmeldung mit dem **eigenen SSH-Schlüssel** schon klappt, sonst
sperrt man sich aus. Am Gerät bleibt die Anmeldung mit Passwort möglich.

```sh
echo 'PasswordAuthentication no' | sudo tee /etc/ssh/sshd_config.d/10-nur-schluessel.conf
sudo systemctl reload ssh
```

In einem **zweiten** Fenster prüfen, dass `ssh pi@<name>.local` noch geht,
bevor man das erste schließt. Rückgängig: die Datei löschen und `ssh` neu
laden.

## Gerätenamen ändern

Den aktuellen Namen zeigt `hostname`. Ein neuer Name besteht aus
Kleinbuchstaben, Ziffern und Bindestrichen, ohne Bindestrich am Anfang oder
Ende, höchstens 63 Zeichen. Beispiel `jeep-carpc`:

```sh
sudo carnine-rename jeep-carpc
sudo reboot
```

`carnine-rename` meldet „Name geändert: carnine-pc-a869 → jeep-carpc“. Einen
Namen, der nicht geht (Großbuchstaben, Leerzeichen, Umlaute), lehnt es mit
einer Fehlermeldung ab und ändert nichts.

- Es schreibt `/etc/hostname`, die Zeile `127.0.1.1` in `/etc/hosts` und den
  laufenden Namen in einem Schritt.
- Nach dem Neustart meldet sich das Gerät mit dem neuen Namen beim DHCP-Server
  und per mDNS: `ssh pi@jeep-carpc.local`. Ein bekannter Host-Schlüssel unter
  dem alten Namen stört nicht, er gehört nur zum alten Namen.
- Der Name bleibt. Den Namen mit der Seriennummer vergibt das Image nur
  **einmal**, beim allerersten Start (`carnine-hostname.service`, gemerkt in
  `/var/lib/carnine/hostname-set`). Danach fasst es ihn nicht mehr an.

### Ohne `carnine-rename` (bis 0.9.5)

Den Befehl gibt es in Images ab der Version nach 0.9.5. Davor geht es von
Hand:

```sh
sudo hostnamectl set-hostname jeep-carpc
sudo sed -i 's/^127\.0\.1\.1[[:space:]].*/127.0.1.1\tjeep-carpc/' /etc/hosts
sudo reboot
```

`hostnamectl` schreibt `/etc/hostname`, die Zeile `127.0.1.1` in `/etc/hosts`
ändert es nicht mit, deshalb der `sed`. Ohne sie meldet `sudo` „unable to
resolve host“.

### Fester Name im Router

Hängt im Router eine feste Adresse am **Namen** (z. B. `carnine-pc`), passt
ein neues Image mit `carnine-pc-xxxx` nicht mehr dazu und bekommt eine andere
Adresse. Dann entweder den Eintrag im Router auf den neuen Namen ändern oder
dem Gerät wie oben wieder den alten Namen geben. Ein Eintrag über die
**MAC-Adresse** ist davon nicht betroffen.

Steckt man die SD-Karte in einen anderen Pi um, wandert der Name mit, auch der
mit der alten Seriennummer. Er wird nicht neu vergeben.

## Kartendaten installieren

Kacheln, Namensdatenbank, Routing-Kacheln und Demo-Tour sind **nicht im
Image**, dafür sind sie zu groß. Bis sie da sind, zeigt die Kartenseite
„Keine Kartendaten installiert“ ([Karten](karte.md)). Wer ein Kartenpaket
weitergibt, gibt auch einen **Freigabe-Link** dazu heraus (MagentaCloud oder
eine andere Nextcloud). Der Link steht nicht im Image.

Das Gerät braucht dafür ein **Netzwerkkabel** (WLAN ist im Image nicht
eingerichtet) und eine Karte mit mindestens 16 GB, besser 32 GB. Das Paket
für Hessen lädt etwa 3,8 GB und belegt entpackt etwa 7,6 GB.

```sh
sudo carnine-install-maps
```

Der Befehl fragt nach dem Link, z. B. `https://magentacloud.de/s/…`. Mit
`--link <link>` kann man ihn gleich mitgeben. Danach:

1. Er prüft, ob genug Platz frei ist, und bricht sonst vorher ab.
2. Er lädt das Paket. **Bricht das ab** (Netz weg, Strom weg), einfach
   denselben Befehl noch einmal aufrufen. Er macht dort weiter.
3. Er prüft die Prüfsummen. Bei einem Fehler löscht er die Datei und bittet
   um einen neuen Aufruf.
4. Erst dann stoppt er Oberfläche, Backend und Valhalla. Der Bildschirm ist
   dabei kurz ohne Oberfläche. Er entpackt die Dateien, prüft sie noch einmal
   und startet die Dienste wieder, auch wenn etwas schiefgeht.
5. Am Ende steht „Fertig. Die Karte ist nach dem Neustart der Dienste in etwa
   einer Minute da.“

Dateien, die schon installiert sind, überspringt er. Ein zweiter Aufruf mit
demselben Paket meldet „Die Kartendaten sind schon installiert, nichts zu
tun.“

### Vom USB-Stick

Ohne Netz geht es mit dem Paketordner auf einem USB-Stick, z. B. so (das
Gerät des Sticks zeigt `lsblk`):

```sh
sudo mount /dev/sda1 /mnt
sudo carnine-install-maps --dir /mnt/karten-hessen
sudo umount /mnt
```

`--dir` nennt den Paketordner selbst, also den Ordner mit `INHALT`,
`SHA256SUMS` und den `.zst`-Dateien. Wie man so ein Paket baut, steht in
`resources/debos/README.md` (`pack_maps.sh`).

Wie lange das auf dem Pi dauert, hängt vom Netz ab und ist noch nicht
gemessen.
