// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';
import 'package:rosenweg_mailfreigabe/abfrage.dart';
import 'package:rosenweg_mailfreigabe/app.dart';
import 'package:rosenweg_mailfreigabe/attrappe.dart';
import 'package:rosenweg_mailfreigabe/daten.dart';
import 'package:rosenweg_mailfreigabe/mail_api.dart';
import 'package:rosenweg_mailfreigabe/seiten/haupt.dart';

Finder bereich(String titel) => find.widgetWithText(NavigationDestination, titel);

/// Knopf auf der Karte einer Mail (nach Betreff).
Finder aufKarte(String betreff, String knopf) => find.descendant(
  of: find.ancestor(of: find.text(betreff), matching: find.byType(Card)),
  matching: find.text(knopf),
);

Future<void> sichtbar(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).last);
  await t.pumpAndSettle();
}

void main() {
  setUpAll(() => Protokoll.nurKonsole = true);
  setUp(() {
    Benachrichtigung.attrappe = [];
    AppVerweise.attrappe = const Stream.empty();
  });

  Future<Attrappe> zeigen(WidgetTester t, {Size groesse = const Size(412, 900), Attrappe? a}) async {
    t.view.physicalSize = groesse;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final at = a ?? Attrappe();
    final s = attrappeSitzung(appAngaben, at);
    await s.starten();
    await t.pumpWidget(
      RosenwegRahmen(
        sitzung: s,
        inhalt: (_) => Haupt(sitzung: s),
      ),
    );
    await t.pumpAndSettle();
    return at;
  }

  const einladung = 'Einladung zur Ausschusssitzung am 9. Dezember';
  const auszahlung = 'Auszahlung Auslage #57: Leuchtmittel Treppenhaus (CHF 84.50)';

  testWidgets('Freigeben zeigt, was auf mich wartet – mit Empfaengern und Vorschau', (t) async {
    final a = await zeigen(t);
    expect(bereich('Freigeben'), findsOneWidget);
    expect(bereich('Alle Mails'), findsOneWidget);
    expect(find.text('2 Mails warten auf deine Freigabe'), findsOneWidget);
    expect(find.text(einladung), findsOneWidget);
    expect(find.text(auszahlung), findsOneWidget);
    expect(find.text('14 verdeckte Empfänger'), findsOneWidget);
    expect(find.textContaining('Der Ausschuss trifft sich'), findsOneWidget);
    expect(find.textContaining('1 von 2 Freigaben'), findsOneWidget);
    expect(a.anfragen.any((r) => r.pfad == '/api/verwaltung-mail-queue/zur-freigabe'), isTrue);
    // aelteste zuerst
    expect(t.getTopLeft(find.text(auszahlung)).dy, lessThan(t.getTopLeft(find.text(einladung)).dy));
  });

  testWidgets('Freigeben direkt auf der Karte: Rueckfrage mit Empfaengern, dann weg aus der Liste', (t) async {
    final a = await zeigen(t);
    await t.tap(aufKarte(einladung, 'Freigeben'));
    await t.pumpAndSettle();
    expect(find.text('Freigeben und senden?'), findsOneWidget);
    expect(find.text('Die Mail geht sofort an alle Empfänger.'), findsOneWidget);
    await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Freigeben')));
    await t.pumpAndSettle();
    expect(a.anfragen.where((r) => r.methode == 'POST').map((r) => r.pfad), ['/api/verwaltung-mail-queue/41/freigeben']);
    expect(find.text('Freigegeben und versendet.'), findsOneWidget);
    expect(find.text('1 Mail wartet auf deine Freigabe'), findsOneWidget);
    expect(find.text(einladung), findsNothing);
  });

  testWidgets('Abbrechen bei der Rueckfrage sendet nichts', (t) async {
    final a = await zeigen(t);
    await t.tap(aufKarte(einladung, 'Freigeben'));
    await t.pumpAndSettle();
    await t.tap(find.text('Abbrechen'));
    await t.pumpAndSettle();
    expect(a.anfragen.where((r) => r.methode != 'GET'), isEmpty);
    expect(find.text(einladung), findsOneWidget);
  });

  testWidgets('Ablehnen braucht einen Grund', (t) async {
    final a = await zeigen(t);
    await t.tap(aufKarte(auszahlung, 'Ablehnen'));
    await t.pumpAndSettle();
    final knopf = find.widgetWithText(FilledButton, 'Ablehnen');
    expect(t.widget<FilledButton>(knopf).onPressed, isNull);
    await t.enterText(find.byType(TextField), 'Betrag stimmt nicht');
    await t.pump();
    await t.tap(knopf);
    await t.pumpAndSettle();
    final post = a.anfragen.singleWhere((r) => r.methode == 'POST');
    expect(post.pfad, '/api/verwaltung-mail-queue/40/ablehnen');
    expect(post.koerper, {'grund': 'Betrag stimmt nicht'});
    expect(find.text(auszahlung), findsNothing);
  });

  testWidgets('Benachrichtigung antippen oeffnet die Mail mit Inhalt, Anhang und Knoepfen', (t) async {
    await zeigen(t);
    (t.state(find.byType(Haupt)) as dynamic).oeffneZiel('mail/41');
    await t.pumpAndSettle();
    expect(find.text('Mail #41'), findsOneWidget);
    expect(find.textContaining('Anliegen bitte bis zum 5. Dezember'), findsOneWidget);
    expect(find.text('14 verdeckte Empfänger zeigen'), findsOneWidget);
    await sichtbar(t, find.text('Traktanden.pdf'));
    expect(find.text('Traktanden.pdf'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Freigeben'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Ablehnen'), findsOneWidget);
    expect(find.byTooltip('Bearbeiten'), findsOneWidget);
  });

  testWidgets('Vier-Augen: zweite Freigabe sendet; Hinweis auf die erste', (t) async {
    final a = await zeigen(t);
    (t.state(find.byType(Haupt)) as dynamic).oeffneZiel('mail/40');
    await t.pumpAndSettle();
    await sichtbar(t, find.text('1 von 2 Freigaben (Vier-Augen-Prinzip)'));
    expect(find.text('1 von 2 Freigaben (Vier-Augen-Prinzip)'), findsOneWidget);
    expect(find.textContaining('paul.vorlage@example.org'), findsWidgets);
    await t.tap(find.widgetWithText(FilledButton, 'Freigeben'));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Freigeben')));
    await t.pumpAndSettle();
    expect(a.anfragen.any((r) => r.pfad == '/api/verwaltung-mail-queue/40/freigeben'), isTrue);
    // jetzt gesendet: keine Knoepfe mehr
    expect(find.textContaining('Gesendet heute'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Ablehnen'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Freigeben'), findsNothing);
  });

  testWidgets('Bearbeiten: Freigaben zuruecksetzen erst nach Rueckfrage', (t) async {
    final a = await zeigen(t);
    (t.state(find.byType(Haupt)) as dynamic).oeffneZiel('mail/40');
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Bearbeiten'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'Betreff'), 'Auszahlung Auslage #57 (korrigiert)');
    await t.tap(find.text('Speichern'));
    await t.pumpAndSettle();
    expect(find.text('Freigaben zurücksetzen?'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Speichern').last);
    await t.pumpAndSettle();
    final put = a.anfragen.singleWhere((r) => r.methode == 'PUT');
    expect((put.koerper as Map)['subject'], 'Auszahlung Auslage #57 (korrigiert)');
    expect(find.text('Gespeichert – 1 Freigabe zurückgesetzt.'), findsOneWidget);
    expect(find.text('Auszahlung Auslage #57 (korrigiert)'), findsOneWidget);
  });

  testWidgets('Alle Mails mit Filter nach Stand', (t) async {
    await zeigen(t);
    await t.tap(bereich('Alle Mails'));
    await t.pumpAndSettle();
    expect(find.text('Wasserunterbruch am Donnerstag', skipOffstage: false), findsOneWidget);
    expect(find.text('Test bitte ignorieren', skipOffstage: false), findsOneWidget);
    await t.tap(find.widgetWithText(ChoiceChip, 'Abgelehnt'));
    await t.pumpAndSettle();
    expect(find.text('Test bitte ignorieren'), findsOneWidget);
    expect(find.text('Wasserunterbruch am Donnerstag'), findsNothing);
  });

  testWidgets('Ohne Freigabe-Recht: nichts zur Freigabe', (t) async {
    await zeigen(t, a: Attrappe(gruppen: const ['stweg3-eigentuemer']));
    expect(find.text('Nichts zur Freigabe'), findsOneWidget);
    expect(find.text('Freigeben'), findsOneWidget); // nur der Bereich unten
  });

  testWidgets('API noch ohne zur-freigabe: Rueckfall auf die Liste', (t) async {
    final a = await zeigen(t, a: Attrappe(mitZurFreigabe: false));
    expect(find.text('2 Mails warten auf deine Freigabe'), findsOneWidget);
    expect(a.anfragen.any((r) => r.pfad == '/api/verwaltung-mail-queue?status=pending'), isTrue);
  });

  testWidgets('Desktop (Station): Leiste links', (t) async {
    await zeigen(t, groesse: const Size(1280, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  test('Abfrage: neue Mail meldet, erledigte verschwindet, geaenderte meldet wieder', () async {
    final a = Attrappe();
    final s = attrappeSitzung(appAngaben, a);
    await s.starten();
    final k = HintergrundKontext(sitzung: s, speicher: AppSpeicher.imSpeicher(), imHintergrund: true);
    await mailAbfrage(k); // erster Lauf: nur merken
    expect(Benachrichtigung.attrappe, isEmpty);

    a.einstellen(id: 42, betreff: 'Heizung: Ablesung', an: 'verwaltung@example.org');
    await mailAbfrage(k);
    final b = Benachrichtigung.attrappe!.single;
    expect(b.titel, 'Neue Mail wartet auf Freigabe');
    expect(b.text, 'Heizung: Ablesung · an verwaltung@example.org · von hans.beispiel@example.org');
    expect(b.ziel, 'mail/42');
    await mailAbfrage(k);
    expect(Benachrichtigung.attrappe!.length, 1, reason: 'nichts doppelt');

    a.erledigen(42);
    await mailAbfrage(k);
    expect(Benachrichtigung.attrappe, isEmpty, reason: 'jemand anderes hat freigegeben');

    await MailApi(s).bearbeiten(41, an: 'eigentuemer-haus9@example.org', betreff: 'Einladung (neu)', text: 'Neu');
    await mailAbfrage(k);
    expect(Benachrichtigung.attrappe!.single.titel, 'Geänderte Mail wartet wieder auf Freigabe');
  });

  test('Benachrichtigungstext mit weiteren Empfaengern', () {
    final m = Mail.aus({
      'id': 1,
      'subject': 'Info',
      'mail_to': 'a@example.org, b@example.org',
      'bcc_count': 3,
      'created_by': 'x@example.org',
    });
    expect(benachrichtigungText(m), 'Info · an a@example.org (+4) · von x@example.org');
  });

  test('Kennung, Ordner und Logo passen zusammen', () {
    expect(appAngaben.kennung, 'ch.rosenweg4303.mailfreigabe');
    expect(appAngaben.gruppe, RosenwegGruppe.technik);
    expect(File('assets/logo/${appAngaben.ordner}-512.png').existsSync(), isTrue);
    expect(File('assets/logo/${appAngaben.ordner}-klein.png').existsSync(), isTrue);
  });
}
