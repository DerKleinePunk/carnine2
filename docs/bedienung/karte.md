# Karten

[← Inhalt](README.md)

Offline-Karte aus den lokal installierten Kacheln (`/var/lib/carnine/maps/`);
Suche, Standortname und Routen kommen vom Backend (Valhalla und
Namensdatenbank). Die Karte selbst funktioniert auch ohne Backend. Das Image
bringt Hessen mit, carnine-pc zeigt seit 26.09.2026 ganz Deutschland.

## Karte bewegen

- **Ein Finger:** verschieben. Das beendet den Folgemodus (siehe unten).
- **Zwei Finger** oder **Doppeltipp:** zoomen. Hinein geht es bis Stufe 17, hinaus bis Stufe 8 (etwa ein Bundesland).
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
2. Schon während des Tippens erscheinen bis zu 15 Treffer (vier Zeilen
   sichtbar, der Rest scrollt). Unter dem Namen steht **Art · Ort ·
   Entfernung**, z. B. „Straße · Alsfeld · 3,2 km“; das Symbol links zeigt die
   Art ebenfalls. Arten: Ort, Gebiet (Bundesland, Kreis …), POI, Berg,
   Gewässer, Straße. Ohne GPS-Position fehlt die Entfernung.

   Reihenfolge: genau passende Namen vor denen, die nur so anfangen („Fulda“
   vor „Fulda-Galerie“), dann Orte, POIs, Berge, Gewässer, Straßen; innerhalb
   davon die nächsten zuerst. Ab drei Zeichen wird zuerst im Umkreis von 50 km
   gesucht. Name und Ort lassen sich kombinieren: „Obergasse Alsfeld“ findet
   die Obergasse in Alsfeld. Eine Haltestelle, die wie eine Straße im selben
   Ort heißt, steht hinter der Straße.

   Bekannte Schwäche: Ein gleichnamiger POI weit weg (Bahnhof „Hauptstraße“
   in Freiburg) kann vor den Straßen in der Nähe stehen.
3. **Treffer antippen:** Die Route wird von der aktuellen Position aus
   berechnet („Route wird berechnet …“), danach zeigt die Karte die ganze
   Route im Überblick.
4. Für die Fahransicht den **Kompass-Knopf** antippen.

Mögliche Meldungen: „Keine Treffer“, „Keine Route gefunden“, „Keine
GPS-Position“, „Route konnte nicht berechnet werden“, „Navigation nicht
erreichbar“ (Backend weg, rot).

## Während der Fahrt

- **Abbiegekarte** oben links: Manöver-Symbol, Entfernung, „NÄCHSTE
  ABBIEGUNG“ und Straßenname.
- **Leiste unten:** ANKUNFT (Uhrzeit aus der GPS-Zeit; nach Mitternacht
  „ANKUNFT MORGEN“, ab zwei Tagen „+2“ hinter der Uhrzeit), DAUER („35 min“,
  „4 h 49 min“, „2 h“), Fortschritt, DISTANZ.
- **Entfernungen** überall gleich: unter 1 km in Metern auf 10 m gerundet
  („350 m“), bis 10 km mit einer Nachkommastelle („3,2 km“), darüber ganze
  Kilometer („498 km“). Das Dezimalzeichen folgt der Sprache (Englisch,
  Chinesisch, Japanisch: Punkt).
- **ABBRECHEN** (roter Knopf rechts unten) löscht die Route.

Die Fahranweisungen erscheinen in der unter [Optionen → Sprache](optionen.md)
gewählten Sprache.

## Wo bin ich?

Ohne Route steht unten links, wo das Auto ist: **Straße, Ort (Ortsteil)**,
z. B. „Willy-Brandt-Platz, Braunschweig (Bebelhof)“. Der Text wird nach je
25 m Fahrt erneuert. Auf freiem Feld fehlt die Straße; weiß das Backend an der
Stelle nichts, verschwindet der Hinweis. Mit einer Namensdatenbank von vor
September 2026 gibt es ihn gar nicht (und die Suche zeigt keinen Ort).

## Replay statt GPS

Auf dem Test-Pi liefert das Backend meist eine aufgezeichnete Tour statt
echtem GPS. Angezeigt wird das nirgends. Im Replay lädt die Karte die Route der
Aufzeichnung selbst und schaltet den Navigationsmodus ein; die Tour beginnt
nach dem Ende von vorn. Nach **ABBRECHEN** kommt die Replay-Route erst wieder,
wenn die Positionsquelle wechselt (z. B. Backend-Neustart). Erst ohne Route
erscheint unten links der Standort (siehe oben).
