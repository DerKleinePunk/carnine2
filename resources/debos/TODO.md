Die Reduzierung der Boot-I/O ist teilweise umgesetzt:

- `systemd-journald` verwendet `Storage=volatile` und schreibt Logs nur ins RAM.
- `dpkg-db-backup` ist maskiert.
- `e2scrub_all` und `e2scrub_reap` sind maskiert.

Noch zurückgestellt und später separat betrachten:

- Automount von `/boot/firmware` deaktivieren. Die Partition bleibt vorerst automatisch eingehängt, damit Kernel- und Firmware-Updates weiterhin wie gewohnt funktionieren.
- Dateisystemprüfungen (`fsck`) deaktivieren oder reduzieren. Diese bleiben vorerst aktiv, weil sie vor beschädigten Dateisystemen nach Stromverlust schützen.

Hintergrund: Auf einer langsamen SD-Karte können viele kleine Lese- und Schreibzugriffe während des Boots deutlich bremsen. Die Änderungen oben reduzieren unnötige dauerhafte Schreibzugriffe, ohne die Dateisystemprüfung oder die Firmware-Wartbarkeit anzutasten.