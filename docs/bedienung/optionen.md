# Optionen

[← Inhalt](README.md)

Vier Kacheln; der Pfeil oben links in jeder Unterseite führt zurück zur
Übersicht.

![Optionen: vier Kacheln Karteneinstellungen, Darstellung, Sprache, System](bilder/optionen.png)

| Kachel | Inhalt |
|---|---|
| **Karteneinstellungen** | noch leer („… vorbereitet“) |
| **Darstellung** | noch leer („… vorbereitet“) |
| **Sprache** | Anzeigesprache wählen |
| **System** | Logs, Neustart, Beenden, Updates |

## Sprache

![Sprache: oben die aktive Sprache, darunter die Sprachen als Kacheln mit Flagge](bilder/optionen-sprache.png)

- Oben die aktive Sprache mit Flagge, darunter alle 15 Sprachen (Chinesisch,
  Dänisch, Deutsch, English, Französisch, Italienisch, Japanisch,
  Niederländisch, Polnisch, Portugiesisch, Schwedisch, Spanisch, Tschechisch,
  Türkisch, Ungarisch).
- Antippen stellt sofort um, ohne Neustart. Die Liste ist nach dem Namen in der
  aktuellen Sprache sortiert, ihre Reihenfolge ändert sich also beim Umschalten.
- **Die Wahl wird nicht gespeichert** – nach einem Neustart ist wieder Deutsch
  eingestellt (#30).

## System

![System: Frontend-Logs, darunter Logansicht öffnen, Nach Updates suchen, Neustart, Beenden](bilder/optionen-system.png)

- **Aktuelle Frontend-Logs:** die letzten 30 Zeilen.
- **Logansicht öffnen:** alle gepufferten Zeilen (bis 200) in einem Dialog.
- **Nach Updates suchen:** zeigt nur „Noch nicht verfügbar“ (#20).
- **Neustart:** startet **nur die Oberfläche** neu, sofort und ohne Rückfrage.
  Auf dem Pi übernimmt systemd den Neustart; Backend und Musik laufen weiter.
- **Beenden** – der **Wartungsmodus**: fragt nach einem Passwort und beendet
  dann die Oberfläche. Das Passwort ist vorläufig fest im Code eingetragen
  (`exit_password_dialog.dart`). **Bestätigen** oder **Fertig** auf der
  Tastatur prüft es, bei falscher Eingabe erscheint „Falsches Passwort“.
  **Abbrechen** oder Antippen außerhalb des Dialogs bricht ab.

  Die Oberfläche startet danach **absichtlich nicht** von selbst neu: Wer das
  Passwort kennt, soll am Gerät eine Konsole bekommen und dort arbeiten
  können. Etwa 5 Sekunden nach dem Beenden erscheint die Text-Anmeldung. Das
  Backend läuft weiter. Zurück zur Oberfläche mit
  `sudo systemctl start carnine-frontend` oder einem Neustart des Geräts.
  Stürzt die Oberfläche dagegen ab, startet systemd sie nach 3 Sekunden neu,
  ohne dass die Konsole dazwischen erscheint.

  ![Dialog „Passwort erforderlich“ mit leerem Feld, Abbrechen und Bestätigen, darunter die Tastatur](bilder/optionen-beenden.png)
