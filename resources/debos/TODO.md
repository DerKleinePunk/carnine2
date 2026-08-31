Die Reduzierung der Boot-I/O ist teilweise umgesetzt:

- `systemd-journald` verwendet `Storage=volatile` und schreibt Logs nur ins RAM.
- `dpkg-db-backup` ist maskiert.
- `e2scrub_all` und `e2scrub_reap` sind maskiert.

Noch zurückgestellt und später separat betrachten:

- Automount von `/boot/firmware` deaktivieren. Die Partition bleibt vorerst automatisch eingehängt, damit Kernel- und Firmware-Updates weiterhin wie gewohnt funktionieren.
- Dateisystemprüfungen (`fsck`) deaktivieren oder reduzieren. Diese bleiben vorerst aktiv, weil sie vor beschädigten Dateisystemen nach Stromverlust schützen.

Hintergrund: Auf einer langsamen SD-Karte können viele kleine Lese- und Schreibzugriffe während des Boots deutlich bremsen. Die Änderungen oben reduzieren unnötige dauerhafte Schreibzugriffe, ohne die Dateisystemprüfung oder die Firmware-Wartbarkeit anzutasten.

Noch offen: Zeitquelle beim Boot

Der Raspberry Pi hat ohne angeschlossene RTC keine batteriegepufferte Echtzeituhr. Nach dem Einschalten ist die Systemzeit daher zunächst unzuverlässig. Später prüfen:

- Reicht die Zeitsynchronisation über `systemd-timesyncd`, sobald eine Netzwerkverbindung besteht?
- Brauchen wir für den Fahrzeugbetrieb eine externe Hardware-RTC?
- Wie sollen Logs und zeitabhängige Funktionen während der Zeit vor der Synchronisation behandelt werden?

Bluetooth-Firmware für Raspberry Pi 4 ist über das Paket `bluez-firmware` im Image enthalten. Das Paket installiert `BCM4345C0.hcd` und den Raspberry-Pi-4-Symlink `BCM4345C0.raspberrypi,4-model-b.hcd`.

Noch offen: Image-Profile für Entwicklungs-Hardware

Der Debos-Build soll optionale Profile für den Entwicklungs-Pi unterstützen:

- Displaymodus für das Waveshare-Panel (`1024x600`) per Template-Parameter aktivieren, ohne die automatische HDMI-Erkennung des Standard-Images zu verändern.
- Einen SSH-Public-Key ausschließlich beim Build übergeben und für den Benutzer `pi` installieren, damit der Entwicklungs-Pi ohne Passwort erreichbar ist.
- Private Schlüssel und sonstige Zugangsdaten dürfen weder im Repository noch im Image-Rezept hinterlegt werden. Das Standardprofil bleibt ohne zusätzlichen SSH-Key.
