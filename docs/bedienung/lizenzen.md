# Lizenzen

CarNine selbst steht unter der
[GPL-3.0](https://github.com/DerKleinePunk/carnine2/blob/main/LICENSE). Das
Image enthält außerdem viele fremde Bausteine. Die meisten stehen unter MIT,
BSD oder Apache-2.0. Unter GPL oder LGPL stehen der Linux-Kernel, viele
Debian-Pakete, FFmpeg und die Aussprachedaten von eSpeak NG.

## Lizenztexte auf dem Gerät

Jedes Paket im Image bringt seine Lizenztexte mit, unter
`/usr/share/doc/<paket>/copyright`. Bei den Paketen von CarNine liegt dort
noch mehr:

| Ordner | Inhalt |
|---|---|
| `/usr/share/doc/carnine-backend/` | `third-party-licenses.txt`: die Lizenzen aller Rust-Bausteine im Backend |
| `/usr/share/doc/carnine-frontend/` | `copyright` nennt die Teile der Oberfläche, `ivi-homescreen-licenses.txt` die Lizenzen von ivi-homescreen. Die Lizenzen von Flutter und allen Dart-Paketen stehen in `/opt/carnine/frontend/data/flutter_assets/NOTICES.Z` |
| `/usr/share/doc/carnine-voice/` | `copyright` für sherpa-onnx, ONNX Runtime, die Stimme „thorsten“ und die Aussprachedaten von eSpeak NG |
| `/usr/share/doc/carnine-valhalla/` | `copyright` für Valhalla, prime_server und die eingebauten Fremdteile |
| `/usr/share/doc/carnine/` | `SOURCE-OFFER.txt` (das Angebot unten) und `source-packages.txt` (alle Quellpakete des Images mit Version) |

Ansehen geht über SSH, zum Beispiel:

```bash
less /usr/share/doc/carnine/SOURCE-OFFER.txt
less /usr/share/doc/carnine-backend/third-party-licenses.txt
```

## Kartendaten und Sprachausgabe

- Die Kartendaten sind von [OpenStreetMap](https://www.openstreetmap.org/copyright)
  (© OpenStreetMap-Mitwirkende, Lizenz
  [ODbL](https://opendatacommons.org/licenses/odbl/)). Die Kacheln sind nach
  dem Schema von [OpenMapTiles](https://openmaptiles.org/) gebaut (CC-BY 4.0).
  Darum steht auf der Karte „© OpenMapTiles © OpenStreetMap-Mitwirkende“
  ([Karten](karte.md)).
- Die Ansagen spricht [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)
  (Apache-2.0) mit der Stimme „thorsten“ von
  [Thorsten-Voice](https://www.thorsten-voice.de) (CC0) und den
  Aussprachedaten von [eSpeak NG](https://github.com/espeak-ng/espeak-ng)
  (GPL-3.0).

## Quellcode

Den Quellcode von CarNine gibt es jederzeit auf
[GitHub](https://github.com/DerKleinePunk/carnine2/), zu jeder Version mit
Marke (z. B. `v0.16.0`).

Den Quellcode aller Teile unter GPL oder LGPL bekommt jeder, der danach
fragt, mindestens drei Jahre lang, nachdem wir ein Image zuletzt
weitergegeben haben, und höchstens zu unseren Kosten für Datenträger und
Versand. Eine E-Mail an [software@carnine.de](mailto:software@carnine.de)
genügt, bitte mit der Version des Images. Dasselbe Angebot steht auf dem
Gerät in `/usr/share/doc/carnine/SOURCE-OFFER.txt`.
