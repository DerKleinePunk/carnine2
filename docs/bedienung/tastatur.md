# Bildschirmtastatur

[← Inhalt](README.md)

Erscheint, sobald ein Eingabefeld angetippt wird (Bibliothekssuche,
Zielsuche, Playlist-Name, Passwort). Sie schließt sich mit **Fertig** oder
durch Antippen außerhalb von Feld und Tastatur.

## Belegung

Ein Layout für alle Sprachen, **QWERTY** (nicht QWERTZ):

![Bildschirmtastatur mit Buchstaben, ⇧ ist im leeren Feld schon an](bilder/tastatur.png)

```
q w e r t y u i o p ⌫
 a s d f g h j k l
⇧ z x c v b n m
123   ,   [Leertaste]   .   Fertig
```

**123** schaltet auf Ziffern und Zeichen (`1–0`, `@ # $ _ & - + ( ) /`,
`* " ' : ; ! ?`), **ABC** zurück. Beim Öffnen stehen immer die Buchstaben.

![Tastatur auf der Ebene 123 mit Ziffern und Zeichen](bilder/tastatur-123.png)

## Umlaute und Sonderzeichen

**Buchstabe lang drücken**, Finger auf die gewünschte Variante ziehen,
loslassen:

| Taste | Varianten |
|---|---|
| a | à á â **ä** ã å æ ą |
| o | ò ó ô **ö** õ ø ő |
| u | ù ú û **ü** ů ű |
| s | **ß** ś š ş |
| e | è é ê ë ě ę |
| i | ì í î ï ı |
| c | ç ć č |
| n | ñ ń ň |
| z | ź ż ž |
| weitere | r: ř, t: ť, y: ý, d: ď, g: ğ, l: ł |

![Lang gedrücktes „a“: Varianten a à á â ä ã å æ ą](bilder/tastatur-sonderzeichen.png)

## Sonstiges

- **⇧** gilt nur für das nächste Zeichen, eine Feststelltaste gibt es nicht. In
  einem leeren Feld ist ⇧ schon an.
- **⌫** löscht beim Drücken ein Zeichen, nach einer halben Sekunde Halten
  laufend weiter; markierter Text wird als Ganzes gelöscht.
- **Fertig** schließt die Tastatur und bestätigt die Eingabe – beim
  Playlist-Namen legt das die Playlist an, beim Passwort bestätigt es.
- Chinesisch und Japanisch haben noch keine eigene Eingabemethode (#13).
