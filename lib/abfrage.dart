// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:rosenweg_basis/rosenweg_basis.dart';

import 'daten.dart';
import 'mail_api.dart';

/// Schluessel der gemerkten Liste ([Neuigkeiten]) – Abfrage und Oberflaeche.
const zurFreigabeSchluessel = 'zur-freigabe';

/// Benachrichtigungs-Nummer je Mail (gleiche Nummer ersetzt die fruehere).
int benachrichtigungFuer(int id) => Benachrichtigung.idFuer('mail-$id');

/// Abfrage fuer Benachrichtigungen (ohne Push, ohne ntfy): Android etwa alle
/// 15 Minuten im Hintergrund, iOS wann iOS will, am Computer jede Minute,
/// solange die App laeuft.
///
///  * neue Mail, die auf **meine** Freigabe wartet → "Neue Mail wartet auf
///    Freigabe" mit Betreff und Empfaengern; antippen = die Mail
///  * bearbeitete Mail (Freigaben zurueckgesetzt) → "Geänderte Mail wartet
///    wieder auf Freigabe"
///  * erledigt (von mir oder jemand anderem freigegeben/abgelehnt) → die
///    Benachrichtigung verschwindet
///
/// Beim allerersten Lauf merkt sie sich nur den Stand (sonst kaeme fuer
/// jede schon wartende Mail eine Benachrichtigung – die zeigt die App selbst).
Future<void> mailAbfrage(HintergrundKontext k) async => mailsMelden(k.speicher, await MailApi(k.sitzung).zurFreigabe());

/// Vergleicht [mails] (wartet auf mich) mit dem gemerkten Stand in
/// [speicher] und benachrichtigt bzw. raeumt auf. Am Computer (keine Abfrage
/// des Systems, nur ein Isolate) ruft die laufende App das nach jedem Laden
/// der Liste mit dem Speicher `hintergrund` – ohne zweite Anfrage. Auf
/// Android/iOS nie aus der Oberflaeche: dort schreibt der Hintergrund-Isolate
/// diese Datei (AppSpeicher: ein Isolate je Datei).
Future<void> mailsMelden(AppSpeicher speicher, List<Mail> mails) async {
  final vorher = await speicher.lesen('neuigkeiten:$zurFreigabeSchluessel');
  final bekannt = vorher is Map ? vorher.keys.map((x) => '$x').toSet() : const <String>{};
  final neu = await Neuigkeiten(speicher, zurFreigabeSchluessel).vergleichen({for (final m in mails) '${m.id}': m.stand});
  for (final m in mails) {
    if (!neu.contains('${m.id}')) continue;
    final geaendert = bekannt.contains('${m.id}');
    await Benachrichtigung.zeigen(
      id: benachrichtigungFuer(m.id),
      titel: geaendert ? 'Geänderte Mail wartet wieder auf Freigabe' : 'Neue Mail wartet auf Freigabe',
      text: benachrichtigungText(m),
      ziel: 'mail/${m.id}',
      kanal: 'freigaben',
    );
  }
  // Was nicht mehr auf mich wartet, braucht keine Benachrichtigung mehr
  final jetzt = {for (final m in mails) '${m.id}'};
  for (final id in bekannt.difference(jetzt)) {
    final n = int.tryParse(id);
    if (n != null) await Benachrichtigung.entfernen(benachrichtigungFuer(n));
  }
}

/// "Betreff · an verwaltung@… (+3) · von erika@…"
String benachrichtigungText(Mail m) {
  final an = adressen(m.an);
  final weitere = m.empfaengerAnzahl - (an.isEmpty ? 0 : 1);
  return [
    m.betreff,
    if (an.isNotEmpty) 'an ${an.first}${weitere > 0 ? ' (+$weitere)' : ''}',
    if (m.eingestelltVon != null) 'von ${m.eingestelltVon}',
  ].join(' · ');
}
