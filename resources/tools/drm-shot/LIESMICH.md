# drm-shot

Werkzeuge für die Bilder der Bedienungsanleitung. Sie laufen auf dem Pi selbst. Ablauf, Konfigs für die Bilder und Regeln:
[docs/25, „Screenshots for the user guide“](../../../docs/25-demo-and-touch-tools.md#screenshots-for-the-user-guide).

| Datei | Wozu | Braucht |
|---|---|---|
| `drm_shot_planes.py` | Bild vom Scanout über alle KMS-Ebenen (auch Kamera/Video); **für die Anleitung immer dieses** | root, libdrm, python3-numpy |
| `drm_shot.py` | Bild nur der Hauptebene, für eine schnelle Probe | root, libdrm |
| `carmcp.py` | Frontend über MCP steuern: Knoten auflisten, tippen, schreiben, `shot` | Frontend mit MCP-Bau und `--enable-mcp`; als Nutzer des Frontends |
| `touch_load.py` | Tippen/Halten über uinput, ohne Argumente Lastrunden auf der Karte | root, 64-Bit-Kernel |

Den Ordner als Ganzes auf den Pi kopieren (`scp -r resources/tools/drm-shot pi@<pi>:`), weil `carmcp.py shot`
`drm_shot.py` neben sich aufruft.

Tests: `python3 -m unittest discover -v` (auch in der CI; ohne numpy werden 13 übersprungen).
