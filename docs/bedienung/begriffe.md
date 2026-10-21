# Begriffe

[← Inhalt](README.md)

Fachwörter, die in dieser Anleitung vorkommen, kurz erklärt.

| Begriff | Bedeutung |
|---|---|
| **5.1-Decoder** | Kleines Gerät zwischen Pi und Display, das den Ton aus dem HDMI-Kabel holt und auf mehrere Boxen verteilt (vorne, hinten, Mitte, Bass). Siehe [Ton über vier Boxen](ton-vier-boxen.md). |
| **Backend** | Der Teil von carnine2, den man nicht sieht: Er spielt die Musik, rechnet die Navigation, liest Kamera und Fahrzeugdaten. Die Oberfläche fragt ihn nur. Ohne Backend zeigt sie ein Verbindungsbanner. |
| **Banner** | Hinweiszeile oben über dem Inhalt einer Seite, z. B. wenn etwas fehlt oder nicht geklappt hat. |
| **bmaptool** | Programm unter Linux, das ein Image auf eine SD-Karte schreibt und dabei prüft. Siehe [Image auf die SD-Karte schreiben](image-schreiben.md). |
| **Cover** | Das Bild zu einem Album oder einer Playlist, wie die Hülle einer CD. |
| **Dienst** | Ein Programm, das beim Einschalten von selbst startet und im Hintergrund läuft, z. B. das Backend. Siehe [Befehle auf dem Gerät](befehle.md). |
| **Display** | Der Bildschirm mit Touch, auf dem carnine2 läuft. Die Oberfläche ist auf 7 Zoll mit 1024 × 600 Pixeln ausgelegt. |
| **Frontend** | Die Oberfläche auf dem Display: alles, was man sieht und antippt. |
| **GPS** | Ortung über Satelliten. Daraus kennt die Navigation den Standort. |
| **HDMI** | Kabel und Buchse für Bild und Ton zwischen Pi und Display. Hat das Display Lautsprecher, kommt der Ton darüber. |
| **Image** | Eine Datei mit dem kompletten System für den Pi (Betriebssystem und carnine2). Man schreibt sie einmal auf die SD-Karte. |
| **Kachel** | Ein großes, rechteckiges Feld zum Antippen, z. B. **BIBLIOTHEK** im Player oder die vier Felder unter **Optionen**. |
| **Kartendaten** | Die Karte von Hessen für Anzeige, Suche und Routen. Sie ist nicht im Image und wird nach der Installation einmal heruntergeladen. |
| **Klinke** | Die runde 3,5-mm-Kopfhörerbuchse am Pi, wie an einem Handy oder Laptop. Dort kommt der Ton heraus, wenn er nicht über HDMI zum Display geht. Siehe [Ton über die Klinke](ton-klinke.md). |
| **Kopfleiste** | Die Zeile oben rechts auf dem Display mit Uhr und Statussymbolen. |
| **Log** | Ein Protokoll, in das ein Programm schreibt, was es gerade tut. Hilft bei der Fehlersuche. |
| **Messe-Modus** | Das Gerät fährt auf dem Messestand eine aufgezeichnete Tour immer wieder ab, mit Ansagen und Musik, ohne dass jemand etwas tun muss. Siehe [Verhalten](verhalten.md). |
| **Netzteil-Modul** | Die Stromversorgung im Auto. Sie schaltet den Pi mit der Zündung ein. Bei „Zündung aus“ sagt sie dem Pi Bescheid, der fährt sich geordnet herunter, danach nimmt sie den Strom weg. Sie schaltet auch Display und Verstärker. |
| **OpenStreetMap, OpenMapTiles** | OpenStreetMap ist die freie Weltkarte, aus der die Kartendaten stammen. OpenMapTiles ist das Schema, nach dem daraus die Karte gebaut wird. Beide stehen klein unten rechts auf der Karte. |
| **Pi, Raspberry Pi** | Der kleine Computer, auf dem carnine2 läuft. Getestet und freigegeben ist der Raspberry Pi 4. |
| **Playlist** | Eine selbst zusammengestellte Liste von Titeln, die nacheinander spielen. Zu finden unter **SAMMLUNGEN**. |
| **Reiter** | Umschalter oben auf einer Seite, wie Karteikarten. Wer einen antippt, sieht dessen Inhalt. |
| **Rufus** | Kostenloses Programm unter Windows, das ein Image auf eine SD-Karte schreibt. Siehe [Image auf die SD-Karte schreiben](image-schreiben.md). |
| **SD-Karte** | Die kleine Speicherkarte im Pi. Auf ihr liegen System, Musik und Kartendaten. |
| **Seitenmenü** | Die Leiste links auf dem Display mit **Start**, **Karten**, **Medien**, **Kamera**, **Technik** und **Optionen**. |
| **Soundkarte** | Der Teil des Pi, der Ton ausgibt. Der Pi hat mehrere: eine für HDMI, eine für die Klinke, dazu ggf. eine über USB. |
| **SSH** | Anmeldung am Pi über das Netzwerk von einem anderen Rechner aus, um dort Befehle einzugeben. |
| **sudo** | Steht vor einem Befehl, der Verwalterrechte braucht. Der Pi fragt dann nach dem Passwort. |
| **Valhalla** | Das Programm auf dem Pi, das die Routen berechnet. Es läuft als Dienst. |
| **Warteschlange** | Die Titel, die als Nächstes gespielt werden. Sie steht rechts im Player unter **NÄCHSTE TITEL**. |
| **WLAN** | Funknetz. Darüber erreicht man den Pi ohne Kabel, z. B. per SSH oder zum Herunterladen der Kartendaten. |
| **Zündung** | Der Zündschlüssel des Autos. Mit „Zündung an“ startet das Netzteil-Modul den Pi, bei „Zündung aus“ fährt der Pi sich geordnet herunter. |
