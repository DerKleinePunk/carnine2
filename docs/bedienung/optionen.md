# Optionen

[← Inhalt](README.md)

Vier Kacheln; der Pfeil oben links in jeder Unterseite führt zurück zur
Übersicht.

| Kachel | Inhalt |
|---|---|
| **Karteneinstellungen** | noch leer („… vorbereitet“) |
| **Darstellung** | noch leer („… vorbereitet“) |
| **Sprache** | Anzeigesprache wählen |
| **System** | Logs, Neustart, Beenden, Updates |

## Sprache

- Oben die aktive Sprache mit Flagge, darunter alle 15 Sprachen (Chinesisch,
  Dänisch, Deutsch, English, Französisch, Italienisch, Japanisch,
  Niederländisch, Polnisch, Portugiesisch, Schwedisch, Spanisch, Tschechisch,
  Türkisch, Ungarisch).
- Antippen stellt sofort um, ohne Neustart. Die Liste ist nach dem Namen in der
  aktuellen Sprache sortiert, ihre Reihenfolge ändert sich also beim Umschalten.
- **Die Wahl wird nicht gespeichert** – nach einem Neustart ist wieder Deutsch
  eingestellt (#30).

## System

- **Aktuelle Frontend-Logs:** die letzten 30 Zeilen.
- **Logansicht öffnen:** alle gepufferten Zeilen (bis 200) in einem Dialog.
- **Nach Updates suchen:** zeigt nur „Noch nicht verfügbar“ (#20).
- **Neustart:** startet **nur die Oberfläche** neu, sofort und ohne Rückfrage.
  Auf dem Pi übernimmt systemd den Neustart; Backend und Musik laufen weiter.
- **Beenden** – der **Wartungsmodus**: fragt nach einem Passwort und beendet
  dann die Oberfläche. Das Passwort ist vorläufig fest im Code eingetragen
  (`exit_password_dialog.dart`); bei falscher Eingabe „Falsches Passwort“.
  Antippen außerhalb des Dialogs bricht ab. Die Oberfläche startet danach
  **absichtlich nicht** von selbst neu: Wer das Passwort kennt, soll am Gerät
  eine Konsole bekommen und dort arbeiten können. Das Backend läuft weiter.
  Zurück zur Oberfläche mit `sudo systemctl start carnine-frontend` oder einem
  Neustart des Geräts. Dass statt der Konsole bisher nur ein blinkender Cursor
  erscheint, ist #21.
