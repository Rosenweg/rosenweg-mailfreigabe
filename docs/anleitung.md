# Rosenweg Mail-Freigabe – Anleitung

Mails der Verwaltung prüfen und freigeben – mit Benachrichtigung, sobald eine wartet.

## Installieren

Auf [www.rosenweg4303.ch/apps](https://www.rosenweg4303.ch/apps) die Datei für das
eigene Gerät laden. An den Rosenweg-Stationen ist die App schon da (Startmenü,
Bereich „Rosenweg“).

## Anmelden

Beim ersten Start „Mit Rosenweg-Konto anmelden“, die Rosenweg-Karte an den Leser
halten oder den QR-Code mit dem Handy bestätigen. An den Stationen geht es ohne
Eingabe (Domänenanmeldung). Auf den geteilten Telefonen meldet die Karte am
Telefon an – in der App gibt es dann kein „Abmelden“.

## Bedienung

Zwei Bereiche – auf dem Handy unten, am Computer links:

- **Freigeben**: alle Mails, die jetzt auf *deine* Freigabe warten, die älteste
  zuerst. Jede Karte zeigt Betreff, Empfänger (An, CC, Anzahl BCC), den Anfang
  des Textes, wer sie eingestellt hat und – beim Vier-Augen-Prinzip – wie viele
  Freigaben schon da sind.
  - **Freigeben** auf der Karte: eine Rückfrage zeigt noch einmal Betreff und
    Empfänger, dann geht die Mail hinaus (beim Vier-Augen-Prinzip erst nach der
    letzten nötigen Freigabe).
  - **Ablehnen**: mit Grund (Pflicht). Bei Auszahlungen bekommt die Person, die
    die Auslage eingereicht hat, den Grund per Mail.
  - **Antippen**: die ganze Mail mit Text, Anhängen (PDF direkt in der App),
    allen verdeckten Empfängern und dem Stand der Freigabe. Oben rechts
    **Bearbeiten** (An, CC, Antwort an, Betreff, Text) – danach braucht es alle
    Freigaben neu.
- **Alle Mails**: die Outbox mit Filter nach Stand (wartet, freigegeben,
  gesendet, abgelehnt, Fehler).

**Benachrichtigung**: „Neue Mail wartet auf Freigabe“ mit Betreff und
Empfängern; antippen öffnet die Mail. Auf Android etwa alle 15 Minuten auch bei
geschlossener App, auf iOS wann iOS es erlaubt, am Computer solange die App
läuft (alle 2 Minuten). Gibt jemand anderes die Mail frei, verschwindet die
Benachrichtigung. Auf geteilten Telefonen gibt es keine Benachrichtigungen.

**Wer darf was** (wie die Web-Seite *Mail Outbox* und die API):

| | sehen | freigeben | bearbeiten, ablehnen |
|---|---|---|---|
| Technik, Präsident | alle Mails | wenn die Freigabe-Regel der Mail ihre Gruppe nennt (Standard: Technik oder Präsident) | alle wartenden |
| Gruppen aus einer Freigabe-Regel | die Mails dieser Regel | ja | ja |
| wer eine Mail eingestellt hat (z. B. über *Mail schreiben*) | die eigenen, nur lesen | – | – |

Mit der Rosenweg-Karte angemeldet geht alles ebenso; die API protokolliert es.
Die Freigabe-Regeln selbst stellt man weiter im Portal ein (*Freigabe-Regeln*).

## Aktualisieren

Die App meldet neue Fassungen selbst („Neue Fassung verfügbar“). Auf den
Stationen und mit Rosenweg Gerät aktualisiert die Technik, dort kommt kein
Hinweis.
