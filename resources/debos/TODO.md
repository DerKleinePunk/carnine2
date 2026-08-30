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

Noch offen: Bluetooth-Firmware für Raspberry Pi 4

Beim Booten meldet der Bluetooth-Treiber, dass die Patch-Firmware für `BCM4345C0` nicht gefunden wurde. Geprüfte Pfade sind unter anderem:

- `brcm/BCM4345C0.raspberrypi,4-model-b.hcd`
- `brcm/BCM4345C0.hcd`
- `brcm/BCM.raspberrypi,4-model-b.hcd`
- `brcm/BCM.hcd`

Prüfen, ob die passende `.hcd`-Datei im Image fehlt, als separates Firmware-Paket installiert werden muss oder aus den Raspberry-Pi-Firmwarequellen übernommen werden sollte. Anschließend den Fehler `Opcode 0x1003 failed: -38` auf einem Raspberry Pi 4 verifizieren.
