# Karten

[← Inhalt](README.md)

Offline-Karte aus den lokal installierten Kacheln (`/var/lib/carnine/maps/`);
Suche, Standortname und Routen kommen vom Backend (Valhalla und
Namensdatenbank). Die Karte selbst funktioniert auch ohne Backend. Das Image
bringt keine Kartendaten mit. Die Karte von Hessen installiert man nach dem
ersten Start ([Kartendaten installieren](nach-der-installation.md#kartendaten-installieren)).

![Karte ohne Route: Suchfeld oben, Knöpfe rechts, darunter „© OpenMapTiles © OpenStreetMap-Mitwirkende“, unten links der Standort](bilder/start.png)

Rechts unten auf der Karte steht „© OpenMapTiles © OpenStreetMap-Mitwirkende“.
Die Kartendaten kommen von [OpenStreetMap](https://www.openstreetmap.org/copyright),
die Kacheln sind nach dem Schema von [OpenMapTiles](https://openmaptiles.org/)
gebaut. Beide Lizenzen verlangen diesen Hinweis. Während einer Route steht er
über der Leiste mit Ankunft und Distanz.

## Karte bewegen

- **Ein Finger:** verschieben. Das beendet den Folgemodus (siehe unten).
- **Zwei Finger** oder **Doppeltipp:** zoomen. Hinein geht es bis Stufe 17, hinaus bis Stufe 8 (etwa ein Bundesland).
- Drehen per Geste ist ausgeschaltet.
- Tipp auf die Karte entfernt eine Ortsmarkierung.

Fehlen die Kartendaten, steht dort „Keine Kartendaten installiert“. Wie man sie
installiert: [Nach der Installation](nach-der-installation.md#kartendaten-installieren).

## Knöpfe am rechten Rand

| Knopf | Wirkung |
|---|---|
| ![Symbol Plus](bilder/symbole/add.svg) / ![Symbol Minus](bilder/symbole/remove.svg) | eine Zoomstufe hinein bzw. heraus |
| ![Symbol Kompass](bilder/symbole/explore.svg) **Kompass** (aus) | Navigationsmodus an: Karte folgt der eigenen Position, **Fahrtrichtung oben** – zentriert also auch wieder auf die Position. Die Beschriftung dreht mit, siehe [Während der Fahrt](#während-der-fahrt) |
| ![Symbol Navigation](bilder/symbole/navigation.svg) **Navigation** (an) | zurück auf **Norden oben**; die Karte folgt weiter |

Einen eigenen „Zentrieren“-Knopf gibt es nicht; nach dem Verschieben holt der
Kompass-Knopf die Position zurück.

**Zoom beim Folgen:** Jedes Mal, wenn die Karte anfängt, der eigenen Position
zu folgen – nach dem Start, nach dem Laden einer Route und mit dem
Kompass-Knopf –, geht sie auf Zoomstufe 16. Mit zwei Fingern oder Plus/Minus
lässt sich weiter zoomen, die Karte folgt dabei weiter; dieser Zoom bleibt,
bis das Folgen das nächste Mal angeht.

## Ziel suchen und Route starten

1. Oben in **Ziel eingeben** tippen – die [Bildschirmtastatur](tastatur.md)
   öffnet sich.
2. Schon während des Tippens erscheinen bis zu 15 Treffer (vier Zeilen
   sichtbar, der Rest scrollt). Unter dem Namen steht **Art · Ort ·
   Entfernung**, z. B. „Straße · Alsfeld · 3,2 km“; das Symbol links zeigt die
   Art ebenfalls. Arten: Ort, Gebiet (Bundesland, Kreis …), POI, Berg,
   Gewässer, Straße. Ohne GPS-Position fehlt die Entfernung.

   Reihenfolge: genau passende Namen vor denen, die nur so anfangen („Fulda“
   vor „Fulda-Galerie“). Eine Stadt, deren Name mit dem ganzen Suchwort
   beginnt, zählt dabei als genau passend: „Frankfurt“ findet zuerst
   Frankfurt am Main, nicht das Dorf Frankfurt bei Scheinfeld. Danach kommen
   Orte, POIs, Berge, Gewässer, Straßen. Mit GPS-Position stehen Orte vorn,
   dann alles im Umkreis von 50 km, dann der Rest des Landes; so steht die
   Straße in der Nähe vor einem gleichnamigen Bahnhof weit weg. Große Städte
   gehen anderen Orten vor, sonst gilt: die nächsten zuerst („Hausen“ bei
   Alsfeld ist das Dorf in der Nähe). Ab drei Zeichen wird zuerst im Umkreis von
   50 km gesucht. Name und Ort lassen sich kombinieren: „Obergasse Alsfeld“
   findet die Obergasse in Alsfeld. Eine Haltestelle, die wie eine Straße im
   selben Ort heißt, steht hinter der Straße.

   ![Zielsuche „Alsfeld“ mit Treffern „Ort · 39 km“ und „Ort · Kirtorf · 40 km“, darunter die Bildschirmtastatur](bilder/karte-suche.png)
3. **Treffer antippen:** Die Route wird von der aktuellen Position aus
   berechnet („Route wird berechnet …“), danach zeigt die Karte die ganze
   Route im Überblick. Abbiegekarte und Leiste unten erscheinen schon jetzt.

   ![Route im Überblick: türkise Linie bis zum Ziel Alsfeld, Abbiegekarte oben links mit dem Start, unten Ankunft, Dauer, Distanz und ABBRECHEN](bilder/karte-route.png)
4. Für die Fahransicht den **Kompass-Knopf** antippen.

Mögliche Meldungen: „Keine Treffer“, „Keine Route gefunden“, „Keine
GPS-Position“, „Route konnte nicht berechnet werden“, „Navigation nicht
erreichbar“ (Backend weg, rot).

## Während der Fahrt

![Navigationsmodus: Abbiegekarte oben links, unten Ankunft, Dauer, Fortschritt, Distanz und ABBRECHEN](bilder/karte-navigation.png)

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
- **Von der Route abgekommen:** Liegt das Auto drei Positionen hintereinander
  mehr als 50 m neben der Route oder fährt es mehr als 120° gegen sie, berechnet
  CarNine die Route zum selben Ziel von der aktuellen Position aus neu. Die
  neue Route beginnt möglichst in Fahrtrichtung, schickt also nicht erst zum
  Wenden zurück; nur wo keine Straße in Fahrtrichtung passt (Sackgasse), kann
  sie mit einer Wendung beginnen. Bis sie da ist, bleibt die alte stehen.
  Fährt das Auto vorher von selbst zurück auf die alte Route, gilt diese
  wieder.
  - Höchstens alle 15 s, nach einem Fehler (z. B. Routing nicht erreichbar)
    erst nach 30 s, dann 60 s. Im Stand und nach der Ankunft wird nicht neu
    berechnet, im Replay nie.
  - Einen Hinweis darauf zeigt die Abbiegekarte noch nicht (#103), die Linie
    und die Werte unten springen einfach auf die neue Route.
- **Beschriftung:** Mit der Fahrtrichtung oben dreht sich die Karte, und die
  Straßen- und Ortsnamen drehen mit. Sie stehen nie auf dem Kopf, höchstens
  etwas schräg, weil die Karte für die Beschriftung in 45°-Schritten neu
  gezeichnet wird (flutter_local_map #1).

  ![Navigationsmodus mit gedrehter Karte: Namen wie „Bilsteinstraße“, „Hoherodskopfstraße“ und „Schwarzer Fluss“ stehen schräg, aber keiner kopfüber](bilder/karte-mitdrehen.png)

Die Fahranweisungen erscheinen in der unter [Optionen → Darstellung & Sprache](optionen.md#darstellung--sprache)
gewählten Sprache.

## Sprachansagen

Während der Navigation sagt CarNine die Abbiegungen an, zum Beispiel
„In 300 Metern rechts auf Bahnhofstraße abbiegen. Dann weiter auf L 3195.“
und an der Kreuzung „Rechts auf Bahnhofstraße abbiegen.“ Die Stimme entsteht
im Gerät selbst, Internet braucht es dafür nicht.

- **Wann:** unter 80 km/h einmal 300 m vor der Abbiegung, ab 80 km/h bei
  1 km und 400 m, dazu kurz vor der Abbiegung selbst. Vor dem Ziel „In 300
  Metern erreichen Sie Ihr Ziel.“, am Ziel etwa „Sie haben Ihr Ziel
  erreicht.“
- **Neu berechnen:** Kommt das Auto von der Route ab, sagt CarNine einmal „Die
  Route wird neu berechnet.“
- Im Stand und neben der Route gibt es keine Ansagen. Jede Ansage kommt
  höchstens einmal.
- **Musik:** Während einer Ansage wird die Musik leiser und danach wieder
  lauter. Pausierte Musik bleibt still.
- **Nur auf Deutsch:** Ansagen gibt es nur, wenn die Oberfläche auf Deutsch
  steht ([Optionen → Darstellung & Sprache](optionen.md#darstellung--sprache)).
  In jeder anderen Sprache bleibt die Navigation stumm. Wer während einer
  Fahrt auf Deutsch umstellt, hört bis zur nächsten Routenberechnung ein
  Gemisch aus Deutsch und der vorigen Sprache; ein neues Ziel behebt das.
- **Ein- und ausschalten** und die Lautstärke der Ansagen gibt es in den
  Optionen noch nicht (#110). Ab Werk sind die Ansagen an, mit voller
  Lautstärke.

## Wo bin ich?

Ohne Route steht unten links, wo das Auto ist: **Straße, Ort (Ortsteil)**,
z. B. „Willy-Brandt-Platz, Braunschweig (Bebelhof)“ oder auf dem Land
„L 3195, Rabenstein“. Die Straße ist bei Autobahnen und Landstraßen oft nur die
Nummer („A 66, Salmünster“, siehe Bild oben). Der Ortsteil in Klammern kommt
nur dazu, wenn einer nahe liegt und anders heißt als der Ort: ein Stadtteil
bis 1,5 km, ein Bezirk bis 2 km, ein Viertel bis 800 m, eine Nachbarschaft bis
500 m. Der Text wird nach je 25 m Fahrt erneuert. Auf freiem Feld fehlt die Straße; weiß das Backend an der
Stelle nichts, verschwindet der Hinweis. Mit einer Namensdatenbank von vor
September 2026 gibt es ihn gar nicht (und die Suche zeigt keinen Ort).

## Replay statt GPS

Auf dem Test-Pi liefert das Backend meist eine aufgezeichnete Tour statt
echtem GPS. Angezeigt wird das nirgends. Im Replay lädt die Karte die Route der
Aufzeichnung selbst und schaltet den Navigationsmodus ein; die Tour beginnt
nach dem Ende von vorn. Nach **ABBRECHEN** kommt die Replay-Route erst wieder,
wenn die Positionsquelle wechselt (z. B. Backend-Neustart). Erst ohne Route
erscheint unten links der Standort (siehe oben).
