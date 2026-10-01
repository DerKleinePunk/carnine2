# Nach der Installation: Passwort und Gerätename

[← Übersicht](README.md)

Ein frisch geschriebenes Image hat ein **bekanntes Standardpasswort** und
einen Namen, den das Gerät sich beim ersten Start selbst gibt. Beides sollte
man gleich nach dem ersten Start anpassen, spätestens bevor das Gerät in ein
fremdes Netz oder ins Auto kommt.

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

Anders als Raspberry Pi OS **warnt das Image nicht**, wenn das
Standardpasswort noch gilt. Man muss selbst daran denken.

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
Konsole und `sudo`.

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
sudo hostnamectl set-hostname jeep-carpc
sudo sed -i 's/^127\.0\.1\.1[[:space:]].*/127.0.1.1\tjeep-carpc/' /etc/hosts
sudo reboot
```

- `hostnamectl` schreibt `/etc/hostname`. Die Zeile `127.0.1.1` in
  `/etc/hosts` ändert es nicht mit, deshalb der `sed`. Ohne sie meldet `sudo`
  „unable to resolve host“.
- Nach dem Neustart meldet sich das Gerät mit dem neuen Namen beim DHCP-Server
  und per mDNS: `ssh pi@jeep-carpc.local`. Ein bekannter Host-Schlüssel unter
  dem alten Namen stört nicht, er gehört nur zum alten Namen.
- Der Name bleibt. Den Namen mit der Seriennummer vergibt das Image nur
  **einmal**, beim allerersten Start (`carnine-hostname.service`, gemerkt in
  `/var/lib/carnine/hostname-set`). Danach fasst es ihn nicht mehr an.

### Fester Name im Router

Hängt im Router eine feste Adresse am **Namen** (z. B. `carnine-pc`), passt
ein neues Image mit `carnine-pc-xxxx` nicht mehr dazu und bekommt eine andere
Adresse. Dann entweder den Eintrag im Router auf den neuen Namen ändern oder
dem Gerät wie oben wieder den alten Namen geben. Ein Eintrag über die
**MAC-Adresse** ist davon nicht betroffen.

Steckt man die SD-Karte in einen anderen Pi um, wandert der Name mit, auch der
mit der alten Seriennummer. Er wird nicht neu vergeben.
