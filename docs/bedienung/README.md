# Bedienungsanleitung carnine2

**Diese Anleitung gilt ab CarNine 0.18.0.**

Für Entwickler und Tester. Beschreibt, was man auf dem Bildschirm sieht und
was jedes Bedienelement tut. Die Anleitung für Messebesucher entsteht
getrennt.

Wenn sich im Frontend etwas an der Bedienung ändert, gehört die Änderung
dieser Seiten in denselben Commit.

## Inhalt

Die Kapitel 2 bis 6 folgen dem Seitenmenü von oben nach unten.

1. [Aufbau des Bildschirms](#aufbau-des-bildschirms) und Seite Start (diese Seite)
2. [Karten](karte.md) – Zielsuche, Route, Navigationsmodus, Standort
3. [Medien](medien.md) – Player, Warteschlange, Bibliothek, Playlists, USB-Import
4. [Kamera](kamera.md) – Rückfahrkamera, Hinweise, Einstellungen
5. [Technik](technik.md) – Schalter und Regler, Hinweise, Einrichten
6. [Optionen](optionen.md) – Darstellung & Sprache, Geräte, Logs, Neustart, Beenden
7. [Bildschirmtastatur](tastatur.md)
8. [Verhalten über Neustarts und ohne Backend](verhalten.md) – was gespeichert
   wird, was bei Verbindungsverlust, ohne Tonausgang und bei Überhitzung
   passiert, Messe-Modus, was noch Platzhalter ist, Dauertest einrichten
9. [Ton über die Klinke](ton-klinke.md) – für Displays ohne Lautsprecher
   (z. B. Waveshare 7C)
10. [Ton über vier Boxen](ton-vier-boxen.md) – vorne und hinten über einen
    5.1-Decoder, Ansagen nur vorne
11. [Image auf die SD-Karte schreiben](image-schreiben.md) – unter Windows
    mit Rufus, unter Linux mit `bmaptool`, welche Variante, erster Start
12. [Nach der Installation](nach-der-installation.md) – Standardpasswort und
    Gerätenamen ändern, WLAN einrichten, Kartendaten installieren
13. [Befehle auf dem Gerät](befehle.md) – alle Befehle, die das Image
    mitbringt, und was von selbst läuft
14. [Lizenzen](lizenzen.md) – wo die Lizenztexte auf dem Gerät liegen und
    wie man den Quellcode bekommt

## Die häufigsten Abläufe

- **Ziel ansteuern:** Seitenmenü → **Karten** → oben **Ziel eingeben**,
  Treffer antippen, dann den **Kompass-Knopf** für die Fahransicht
  ([Karten](karte.md#ziel-suchen-und-route-starten)).
- **Musik hören:** Seitenmenü → **Medien** → Kachel **SAMMLUNGEN** → bei einer
  Playlist auf **▶**. Einzelne Titel startet man aus der **BIBLIOTHEK**
  ([Medien](medien.md)).
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
| **Start** | Übersicht: Uhr, Navigation, Musik, Schnellschalter, Fahrzeug (siehe unten) |
| **Karten** | [Offline-Karte mit Navigation](karte.md) |
| **Medien** | [Musik-Player](medien.md) |
| **Kamera** | [Bild der Rückfahrkamera](kamera.md) |
| **Technik** | [Schalter und Regler](technik.md) |
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
schaltet ab“. Das Gerät fährt dann **sofort von selbst sauber herunter**,
bevor das Netzteil nach 15 Sekunden den Strom nimmt. Schaltet man die Zündung
in dieser Zeit wieder ein, fährt es trotzdem herunter. Ohne Netzteil-Modul
fehlt beides.

Hängt der Pi nicht am Relais des Netzteils, sondern an einem eigenen Netzteil
(Basteltisch, Vorführung), bleibt er nach dem Herunterfahren aus (rote LED).
Wieder an geht er erst, wenn er einmal keinen Strom hatte: Stecker kurz
ziehen. Wer dort nur die Zündung ausprobieren will, schaltet das Herunterfahren
ab, siehe [docs/23](../23-power-supply.md#what-carnine2-needs-for-it)
(`shutdown_on_poweroff = false`).

### Letzte Seite nach dem Start

Die Oberfläche merkt sich die zuletzt gewählte Seite (außer **Optionen**) und
öffnet sie beim nächsten Start wieder. Gespeichert wird 2 Sekunden nach dem
Wechsel, beim Beenden sofort. Ist das Backend beim Start noch nicht
erreichbar, etwa weil die Oberfläche beim Einschalten schneller ist, fragt sie
bis zu 2 Minuten lang immer wieder nach und springt dann auf die gemerkte
Seite. Wählt man in der Zeit selbst eine Seite, bleibt es bei dieser. Kommt
das Backend nicht, bleibt sie ohne Meldung auf **Start** (#52).

### Start

![Start: oben Uhrzeit und Datum, darunter die Kacheln Navigation mit der nächsten Abbiegung, Ankunft und Distanz, Musik mit Cover und Tasten, Schnellschalter mit vier Schaltern und Fahrzeug mit der CPU-Temperatur](bilder/startseite.png)

Oben stehen die Uhrzeit groß und rechts daneben das Datum, ausgeschrieben und in
der Sprache der Oberfläche („Mittwoch, 14. Oktober 2026“). Die Uhrzeit springt
zum Minutenwechsel um, wie die in der Kopfleiste. Darunter vier Kacheln:

| Kachel | Zeigt | Antippen |
|---|---|---|
| **NAVIGATION** (links oben, die größte) | siehe unten | öffnet **Karten** |
| **SCHNELLSCHALTER** (links unten) | die ersten vier Schalter der Seite [Technik](technik.md) | schaltet den einzelnen Schalter |
| **MUSIK** (rechts oben) | Cover, Titel, Interpret, Fortschritt | öffnet **Medien** |
| **FAHRZEUG** (rechts unten) | Zündung, Spannung, CPU-Temperatur | nichts, nur Anzeige |

**Navigation.** Mit Route zeigt die Kachel dasselbe wie die Karte: links den
Pfeil der nächsten Abbiegung, daneben die Entfernung bis dorthin und die
Straße (hat die Straße keinen Namen, die Anweisung), darunter **ANKUNFT**
(Uhrzeit, nach Mitternacht „ANKUNFT MORGEN“) und **DISTANZ** (Rest der Strecke).
Nach der letzten Abbiegung zeigt sie die Zielflagge, die Entfernung bis zum
Ziel und die Anweisung, z. B. „Ziel erreicht.“
Verlässt das Auto die Route, steht an Stelle der Abbiegung „Route wird neu
berechnet …“, bei nicht erreichbarer Navigation rot „Route verlassen –
Navigation nicht erreichbar“. Ohne Route steht dort **Ziel eingeben**, solange
eine Route berechnet wird „Route wird berechnet …“. Das Ziel sucht man auf der
Karte: ein Tipp auf die Kachel öffnet sie.

Oben rechts in der Kachel zeigt ein Punkt, ob das Auto weiß, wo es ist:

| Anzeige | Bedeutung |
|---|---|
| Punkt in der Primärfarbe, **GPS** | gültige Position |
| roter Punkt, **Keine GPS-Position** | die GPS-Quelle ist da, hat aber noch keine Position |
| nichts | keine GPS-Quelle eingerichtet, oder das Backend antwortet nicht |

**Musik.** Die Kachel zeigt den aktuellen Titel (auch pausiert), darunter einen
Fortschrittsbalken (nur Anzeige, zum Springen dient der Player) und die Knöpfe
**Vorheriger Titel**, **Wiedergabe/Pause** und **Nächster Titel**. Die Knöpfe
wirken wie im Player; ein Tipp daneben öffnet **Medien**. Läuft nichts, steht
„Keine Wiedergabe“ und „Medien öffnen“, die drei Knöpfe sind grau.

**Schnellschalter.** Die Kachel zeigt bis zu vier Schalter in der Reihenfolge
der Seite Technik, Regler überspringt sie. Die Schalter sehen aus und wirken
wie dort: ein Tipp schaltet, ein Schalter, dessen Modul nicht antwortet, ist
grau und reagiert nicht. Gibt es keinen Schalter, oder ist das Backend nicht
erreichbar, fehlt die Kachel ganz und die Navigation nimmt ihren Platz ein.

**Fahrzeug.** Nur auf einem Gerät mit Netzteil-Modul stehen dort **Zündung**
(An/Aus) und **Spannung** (z. B. „12,6 V“); schaltet das Netzteil gerade ab,
sind beide rot. Antwortet das Netzteil nicht, steht „Netzteil antwortet nicht“
in Rot. Darunter steht die **CPU**-Temperatur in °C, die sich alle paar
Sekunden aktualisiert; sie wird rot, sobald die Warnung vor Überhitzung gilt
([Verhalten](verhalten.md)). Hat das Gerät kein Netzteil-Modul und keinen
Temperaturfühler, fehlt die Kachel und die Musik nimmt ihren Platz ein.
