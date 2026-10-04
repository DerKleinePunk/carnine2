# Befehle auf dem Gerät

[← Übersicht](README.md)

Das Image bringt vier Befehle mit, die man selbst aufruft. Man gibt sie am
Gerät ein (Konsole, z. B. nach [Optionen → Beenden](optionen.md#system)) oder
per SSH. Alles andere läuft von selbst.

## Zum Aufrufen

| Befehl | Wozu | Beschrieben unter |
|---|---|---|
| `passwd` | Passwort des Benutzers `pi` ändern. Die Warnung beim Anmelden verschwindet sofort | [Passwort ändern](nach-der-installation.md#passwort-ändern) |
| `sudo carnine-rename <name>` | Gerätenamen ändern | [Gerätenamen ändern](nach-der-installation.md#gerätenamen-ändern) |
| `sudo carnine-wlan` | WLAN einrichten | [WLAN einrichten](nach-der-installation.md#wlan-einrichten) |
| `sudo carnine-install-maps` | Kartendaten installieren, ab Werk die Karte von Hessen | [Kartendaten installieren](nach-der-installation.md#kartendaten-installieren) |

### `carnine-rename`

```sh
sudo carnine-rename <name>
```

Setzt den neuen Namen in einem Schritt: `/etc/hostname`, die Zeile
`127.0.1.1` in `/etc/hosts` und den laufenden Namen. Erlaubt sind 1 bis 63
Kleinbuchstaben, Ziffern und Bindestriche, ohne Bindestrich am Anfang oder
Ende. Den Namen, den das Gerät sich beim ersten Start gegeben hat, vergibt es
danach nicht wieder. Im Netz (DHCP, `<name>.local`) gilt der neue Name nach
einem Neustart.

### `carnine-wlan`

| Aufruf | Wirkung |
|---|---|
| `sudo carnine-wlan` | sucht die Netze in Reichweite, fragt nach Netz und Passwort |
| `sudo carnine-wlan --ssid <name>` | ein Netz nach Namen, auch ein verstecktes |
| `sudo carnine-wlan --country <XX>` | Land für die Funkkanäle (Vorgabe `DE`) |
| `sudo carnine-wlan --status` | zeigt Netz, Zustand und Adresse |
| `sudo carnine-wlan --off` | schaltet WLAN aus, auch über Neustarts |
| `sudo carnine-wlan --on` | schaltet es mit den gespeicherten Netzen wieder ein |

Gespeichert wird nur ein aus dem Passwort berechneter Schlüssel, nicht das
Passwort selbst.

### `carnine-install-maps`

| Aufruf | Wirkung |
|---|---|
| `sudo carnine-install-maps` | fragt nach dem Freigabe-Link und lädt die Kartendaten herunter |
| `sudo carnine-install-maps --link <link>` | dasselbe mit dem Link gleich im Aufruf |
| `sudo carnine-install-maps --dir <ordner>` | installiert aus einem Ordner, z. B. von einem [USB-Stick](nach-der-installation.md#vom-usb-stick) |
| `… --package <name>` | ein anderes Kartenpaket als `karten-hessen` |

Ein abgebrochener Download geht beim nächsten Aufruf weiter. Vorher prüft der
Befehl, ob genug Platz frei ist. Oberfläche, Backend und `valhalla` hält er
erst an, wenn alle Dateien da und geprüft sind, und startet sie danach wieder.

## Läuft von selbst

Diese Programme muss man nicht aufrufen. Sie stehen hier, damit man sie
erkennt, wenn man sie in `systemctl` oder im Log sieht.

| Programm | Wann | Was |
|---|---|---|
| `expand-rootfs` | beim ersten Start | vergrößert das Dateisystem auf die ganze SD-Karte |
| `carnine-ssh-hostkeys` | beim ersten Start | erzeugt die SSH-Schlüssel des Geräts, jedes Gerät bekommt eigene |
| `carnine-hostname` | beim ersten Start, einmal | gibt dem Gerät den Namen `carnine-pc-` und die letzten vier Stellen der Seriennummer |
| `carnine-password-check` | beim Start und bei jeder Änderung eines Passworts | merkt sich, ob `pi` noch das Standardpasswort hat |
| `carnine-password.sh` | bei jeder Anmeldung | zeigt die Warnung, solange `pi` das Standardpasswort hat |
| `carnine-backend` | als Dienst, immer | das Backend: Musik, Navigation, Kamera, Technik |
| `carnine-frontend` | als Dienst, immer | die Oberfläche |
| `valhalla` | als Dienst, immer | berechnet die Routen |

Die drei Dienste `carnine-backend`, `carnine-frontend` und `valhalla` lassen
sich mit `sudo systemctl status <dienst>` ansehen und mit
`sudo systemctl restart <dienst>` neu starten.
