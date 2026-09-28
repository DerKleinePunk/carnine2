# Bedienungsanleitung carnine2

Für Entwickler und Tester. Beschreibt, was man auf dem Bildschirm sieht und
was jedes Bedienelement tut – Stand **0.8.0** (2026-09-28). Die Anleitung für
Messebesucher entsteht getrennt.

Wenn sich im Frontend etwas an der Bedienung ändert, gehört die Änderung
dieser Seiten in denselben Commit.

## Inhalt

1. [Aufbau des Bildschirms](#aufbau-des-bildschirms) (diese Seite)
2. [Medien](medien.md) – Player, Warteschlange, Bibliothek, Playlists, USB-Import
3. [Karten](karte.md) – Zielsuche, Route, Navigationsmodus, Standort
4. [Optionen](optionen.md) – Sprache, Logs, Neustart, Beenden
5. [Bildschirmtastatur](tastatur.md)
6. [Verhalten über Neustarts und ohne Backend](verhalten.md) – was gespeichert
   wird, was bei Verbindungsverlust passiert, was noch Platzhalter ist,
   Dauertest einrichten

## Die häufigsten Abläufe

- **Musik hören:** Seitenmenü → **Medien** → Kachel **SAMMLUNGEN** → bei einer
  Playlist auf **▶**. Einzelne Titel startet man aus der **BIBLIOTHEK**
  ([Medien](medien.md)).
- **Ziel ansteuern:** Seitenmenü → **Karten** → oben **Ziel eingeben**,
  Treffer antippen, dann den **Kompass-Knopf** für die Fahransicht
  ([Karten](karte.md#ziel-suchen-und-route-starten)).
- **Oberfläche neu starten:** **Optionen** → **System** → **Neustart**. Die Musik
  läuft dabei weiter ([Optionen](optionen.md#system)).

## Aufbau des Bildschirms

Die Oberfläche ist fest auf das 7-Zoll-Panel mit 1024 × 600 Pixeln ausgelegt.
Links steht das Seitenmenü, rechts oben die Kopfleiste, darunter der Inhalt
der gewählten Seite. Die Oberfläche startet immer auf Deutsch.

![Seite Karten: links das Seitenmenü mit NOTFALL, oben rechts Kopfleiste und Uhr, darunter die Karte](bilder/start.png)

*Die Bilder in dieser Anleitung stammen vom Test-Pi (Panel 1024 × 600,
Replay-Tour in Hessen).*

### Seitenmenü (links)

Oben das Logo „CarNine / V8-ACTIVE“ (ohne Funktion), darunter die Seiten:

| Menüpunkt | Inhalt |
|---|---|
| **Start** | Platzhalter für Entwickler (siehe unten) |
| **Karten** | [Offline-Karte mit Navigation](karte.md) |
| **Medien** | [Musik-Player](medien.md) |
| **Klima** | Platzhalter |
| **Technik** | Platzhalter |
| **Optionen** | [Einstellungen](optionen.md) |

- Antippen wechselt die Seite. Der aktive Punkt leuchtet in der Primärfarbe,
  ein Balken gleitet zu ihm.
- Beim Wechsel bleibt der Zustand von Medien und Karten erhalten
  (Warteschlange, Unterseite, Route). Die Optionen fangen dagegen jedes Mal
  in der Übersicht an.
- Der rote Knopf **NOTFALL** unten hat noch keine Funktion (#34).

### Kopfleiste (oben rechts)

Drei kleine Symbole (Mobilfunk, Akku, Sonne) und die Uhr. Die drei Symbole
sind Attrappen ohne Datenquelle (#34). Die Uhr springt genau zum
Minutenwechsel um. Nichts davon ist antippbar.

Nur auf einem Gerät mit Netzteil-Modul im Auto
([docs/23](../23-power-supply.md)) steht vor der Uhr zusätzlich das Netzteil:

| Anzeige | Bedeutung |
|---|---|
| Schlüssel und Eingangsspannung, z. B. „12,6 V“ | Zündung an, Netzteil meldet sich |
| durchgestrichener Schlüssel | Zündung aus |
| Schlüssel und Spannung **rot** | das Netzteil schaltet gleich ab |
| roter Stecker | Netzteil antwortet nicht |

Schaltet das Netzteil ab, erscheint auf jeder Seite unter der Kopfleiste ein
roter Streifen: „Zündung aus – das Netzteil schaltet ab“ oder „Das Netzteil
schaltet ab“. Er sagt nur an, was kommt: Das Gerät fährt dabei noch nicht von
selbst herunter (#36). Ohne Netzteil-Modul fehlt beides.

### Letzte Seite nach dem Start

Die Oberfläche merkt sich die zuletzt gewählte Seite (außer **Optionen**) und
öffnet sie beim nächsten Start wieder. Gespeichert wird 2 Sekunden nach dem
Wechsel, beim Beenden sofort. Ist das Backend beim Start nicht erreichbar,
bleibt sie ohne Meldung auf **Start**.

### Start, Klima, Technik

Entwickler-Platzhalter: Text „Dashboard-Inhalt für …“, der gRPC-Status und der
Knopf **gRPC testen**. Der fragt einen CAN-Wert (`engine_temp`) beim Backend ab
und zeigt das Ergebnis als Liste; schlägt es fehl, erscheint der Dialog
**Verbindungsfehler**.
