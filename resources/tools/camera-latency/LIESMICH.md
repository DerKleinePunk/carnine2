# camera-latency

Messen, wie spät das Bild der Rückfahrkamera ankommt, ohne Menschen: Der Pi schaltet einen Auslöser und sieht selbst nach,
wann der Wechsel im Kamerabild ankommt. Die Werkzeuge laufen auf dem Pi selbst. Ergebnisse und Verfahren:
[docs/10, „Rear camera latency“](../../../docs/10-quality-requirements.md).

| Datei | Wozu | Braucht |
|---|---|---|
| `latency_panel.py` | Analoger Grabber: Panel schwarz/weiß über `/dev/fb0`, die Kamera schaut aufs Panel. `somagic` oder `v4l2` (STK1160) | root, python3-numpy, v4l-utils; carnine-frontend gestoppt |
| `latency_led.py` | USB-Kamera: grüne ACT-LED des Pi, die Kamera schaut darauf. `raw` (Kamera allein) oder `display` (Bild, das carnine auf dem Ausgang hat) | root, python3-numpy, v4l-utils bzw. libdrm; bei `raw` carnine-frontend gestoppt, bei `display` carnine auf der Seite Kamera |
| `latency.py` | gemeinsame Auswertung (Schwelle, Median/10 %/90 %, CSV) | – |

Den Ordner als Ganzes auf den Pi kopieren (`scp -r resources/tools/camera-latency pi@<pi>:`).

```bash
sudo python3 latency_panel.py v4l2 --dev /dev/video0 --out stk1160-a
sudo python3 latency_panel.py somagic --somagic-capture ~/somagic/src/somagic-capture --out somagic-a
sudo python3 latency_led.py raw --out led-raw-a
sudo python3 latency_led.py display --out led-display-a
```

Ein Lauf dauert 60 s (`--secs`). Die Kamera sendet bei uns NTSC (Vorgabe, sonst `--norm pal`). `--out PREFIX` schreibt
`PREFIX.txt` (Ergebnis), `PREFIX.csv` (Verzögerung je Wechsel) und `PREFIX-raw.csv` (jedes Bild und jeder Wechsel).

Gemessen wird bis zur Ankunft im Pi bzw. bis zum Bildschirm-Ausgang; der Weg vom HDMI-Ausgang bis zum Licht des Panels
(bei 60 Hz bis zu 16 ms) ist nicht enthalten.

Tests: `python3 -m unittest discover -v` (auch in der CI; ohne numpy werden 2 übersprungen).
