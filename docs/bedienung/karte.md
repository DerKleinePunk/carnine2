# Karten

[← Inhalt](README.md)

Offline-Karte aus den lokal installierten Kacheln (`/var/lib/carnine/maps/`);
Suche und Routen kommen vom Backend (Valhalla). Die Karte selbst funktioniert
auch ohne Backend.

## Karte bewegen

- **Ein Finger:** verschieben. Das beendet den Folgemodus (siehe unten).
- **Zwei Finger** oder **Doppeltipp:** zoomen (Stufe 8–17).
- Drehen per Geste ist ausgeschaltet.
- Tipp auf die Karte entfernt eine Ortsmarkierung.

Fehlen die Kartendaten, steht dort „Keine Kartendaten installiert“.

## Knöpfe am rechten Rand

| Knopf | Wirkung |
|---|---|
| **＋** / **−** | eine Zoomstufe hinein bzw. heraus |
| **Kompass** (◎, aus) | Navigationsmodus an: Karte folgt der eigenen Position, **Fahrtrichtung oben** – zentriert also auch wieder auf die Position |
| **Navigation** (▲, an) | zurück auf **Norden oben**; die Karte folgt weiter |

Einen eigenen „Zentrieren“-Knopf gibt es nicht; nach dem Verschieben holt der
Kompass-Knopf die Position zurück.

## Ziel suchen und Route starten

1. Oben in **Ziel eingeben** tippen – die [Bildschirmtastatur](tastatur.md)
   öffnet sich.
2. Schon während des Tippens erscheinen bis zu 15 Treffer, Orte in der Nähe
   zuerst (vier Zeilen sichtbar, der Rest scrollt). Das Symbol zeigt die Art:
   Ort, POI, Berg, Gewässer, Straße.
3. **Treffer antippen:** Die Route wird von der aktuellen Position aus
   berechnet („Route wird berechnet …“), danach zeigt die Karte die ganze
   Route im Überblick.
4. Für die Fahransicht den **Kompass-Knopf** antippen.

Mögliche Meldungen: „Keine Treffer“, „Keine Route gefunden“, „Keine
GPS-Position“, „Route konnte nicht berechnet werden“, „Navigation nicht
erreichbar“ (Backend weg, rot).

## Während der Fahrt

- **Abbiegekarte** oben links: Manöver-Symbol, Entfernung (unter 1 km auf
  10 m gerundet), „NÄCHSTE ABBIEGUNG“ und Straßenname.
- **Leiste unten:** ANKUNFT (Uhrzeit aus der GPS-Zeit), DAUER, Fortschritt,
  DISTANZ.
- **ABBRECHEN** (roter Knopf rechts unten) löscht die Route.

Die Fahranweisungen erscheinen in der unter [Optionen → Sprache](optionen.md)
gewählten Sprache.

## Replay statt GPS

Auf dem Test-Pi liefert das Backend meist eine aufgezeichnete Tour statt
echtem GPS. Angezeigt wird das nirgends. Im Replay lädt die Karte die Route der
Aufzeichnung selbst und schaltet den Navigationsmodus ein; die Tour beginnt
nach dem Ende von vorn. Nach **ABBRECHEN** kommt die Replay-Route erst wieder,
wenn die Positionsquelle wechselt (z. B. Backend-Neustart).
