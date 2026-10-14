# freeze-watch

Schreibt auf einem Carnine-Gerät (carnine-pc, jeep-pi) einmal pro Minute eine Zeile nach
`/var/log/carnine-freeze-watch.log`: ob sich das Bild auf dem Panel seit der letzten Minute geändert hat,
Temperatur, ARM-Takt, Drosselung, Last, RAM von Frontend (`homescreen`) und Backend, `MemAvailable`.

**Einfrieren:** Die Uhr in der Kopfleiste ändert sich jede Minute. Zwei Bilder vom Scanout im Abstand von
mindestens 60 s sind deshalb verschieden, solange das Frontend zeichnet. Gleiches Bild bei laufendem Frontend
→ `picture=same … FROZEN`. Der Vorgänger (`~/freeze/watch.sh`, 25.09.) zählte `LayerScene commit` im Journal;
das Release-Frontend schreibt das nicht mehr, darum war er seit dem 28.09. blind.

Läuft als root (DRM-Handles des Scanouts, `vcgencmd`). Prozesse findet es über `/proc`, es braucht also keine
bestimmten systemd-Units (geht auch, wenn Carnine per `~/start_carnine.sh` läuft).

## Einrichten (auf dem Gerät)

```sh
sudo install -D -m 0755 freeze_watch.py /usr/local/lib/carnine-freeze-watch/freeze_watch.py
sudo install -m 0644 carnine-freeze-watch.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now carnine-freeze-watch     # aus: disable --now
```

Einmal zum Ausprobieren: `sudo python3 freeze_watch.py --once` (eine Zeile, ohne Vergleich: `picture=new`).

## Eine Zeile

```
2026-10-14 06:59:33 picture=changed temp=29.7'C arm=1800MHz throttled=0x0 load=1.45 ui_rss=284MB be_rss=161MB avail=3180MB state=active pid=747 be_pid=695
```

`picture`: `new` (erste Probe), `changed`, `same`, `none` (kein Scanout gefunden). Zusätze am Ende:
`FROZEN` (gleiches Bild, Frontend lief in beiden Proben), `THROTTLED` (`get_throttled` ≠ 0x0).

Tests: `python3 -m unittest -v test_freeze_watch.py` (auch in der CI).
