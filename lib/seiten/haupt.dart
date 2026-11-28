// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../abfrage.dart';
import '../daten.dart';
import '../mail_api.dart';
import 'alle.dart';
import 'freigabe.dart';
import 'mail.dart';

/// Die App nach der Anmeldung. Zwei Bereiche – auf dem Handy unten, am
/// Computer links:
///
///  * Freigeben: was jetzt auf **meine** Freigabe wartet; Freigeben und
///    Ablehnen direkt auf der Karte, antippen = ganze Mail
///  * Alle Mails: die Outbox, soweit ich sie sehen darf, mit Filter
///
/// Rechte wie verwaltung-mail-outbox.html und die API (mailQueueZugang):
/// angemeldet genuegt fuer die App; was jemand sieht, freigibt, bearbeitet
/// oder ablehnt, entscheidet die API je Mail (Technik/Praesident alles,
/// sonst die Gruppen der Freigabe-Regel, eigene Mails nur lesen).
///
/// Benachrichtigung "Neue Mail wartet auf Freigabe" ohne Push: Android/iOS
/// ueber die Abfrage im Hintergrund ([mailAbfrage]); solange die App offen
/// ist, laedt sie alle 2 Minuten neu (am Computer kommt auch dann die
/// Benachrichtigung). Antippen oeffnet die Mail.
class Haupt extends StatefulWidget {
  const Haupt({super.key, required this.sitzung, this.hintergrund});
  final RosenwegSitzung sitzung;

  /// Abfrage im Hintergrund beim System anmelden (main.dart); null = nicht
  /// (Attrappe, Tests).
  final Future<void> Function()? hintergrund;

  @override
  State<Haupt> createState() => _HauptState();
}

class _HauptState extends State<Haupt> {
  late final MailApi _api = MailApi(widget.sitzung);
  final _stand = ValueNotifier<({List<Mail>? mails, Object? fehler})>((mails: null, fehler: null));

  /// Zaehlt Aenderungen (Freigabe, Ablehnung, Bearbeitung): "Alle" laedt neu.
  final _runde = ValueNotifier<int>(0);
  final _abos = <StreamSubscription<Object>>[];

  /// Gerade offene Mail (Benachrichtigung fuer dieselbe nicht doppelt oeffnen).
  int? _offen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _benachrichtigungen());
  }

  /// Benachrichtigungen einrichten, Abfrage im Hintergrund anmelden, beim
  /// ersten Mal um Erlaubnis fragen; Antippen oeffnet die Mail.
  Future<void> _benachrichtigungen() async {
    try {
      await Benachrichtigung.einrichten(widget.sitzung.app);
      _abos.add(Benachrichtigung.angetippt.listen(_ziel));
      final z = await Benachrichtigung.startZiel();
      if (z != null) _ziel(z);
      await widget.hintergrund?.call();
      final sp = await AppSpeicher.app();
      if (await sp.lesen('erlaubnis-gefragt') != true) {
        await sp.schreiben('erlaubnis-gefragt', true);
        await Benachrichtigung.erlaubnisFragen();
      }
    } catch (e) {
      Protokoll.schreiben('Benachrichtigungen', e);
    }
  }

  /// Ziel einer Benachrichtigung: `mail/41`.
  @visibleForTesting
  void oeffneZiel(String ziel) => _ziel(ziel);

  void _ziel(String ziel) {
    final t = ziel.split('/');
    final id = t.length == 2 && t[0] == 'mail' ? int.tryParse(t[1]) : null;
    if (id != null) _oeffnen(id);
  }

  Future<void> _oeffnen(int id) async {
    if (!mounted || _offen == id) return;
    _offen = id;
    unawaited(Benachrichtigung.entfernen(benachrichtigungFuer(id)));
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MailSeite(api: _api, id: id, geaendert: _nachAktion),
      ),
    );
    _offen = null;
  }

  /// Was wartet auf mich? Beim Oeffnen, bei der Rueckkehr in den Vordergrund,
  /// alle 2 Minuten und nach jeder eigenen Aenderung.
  Future<void> _laden() async {
    try {
      final mails = await _api.zurFreigabe();
      _stand.value = (mails: mails, fehler: null);
      // Am Computer gibt es keine Abfrage des Systems: Benachrichtigungen,
      // solange die App laeuft (Android/iOS macht das der Hintergrund)
      if (!HintergrundAbfrage.vomSystem && !widget.sitzung.geteiltesTelefon) {
        await Benachrichtigung.einrichten(widget.sitzung.app);
        await mailsMelden(await AppSpeicher.app('hintergrund'), mails);
      }
    } catch (e) {
      // letzte Liste stehen lassen, Fehler darueber zeigen
      _stand.value = (mails: _stand.value.mails, fehler: e);
    }
  }

  /// Nach Freigabe, Ablehnung, Bearbeitung: beide Listen neu.
  Future<void> _nachAktion() async {
    _runde.value++;
    await _laden();
  }

  @override
  void dispose() {
    for (final a in _abos) {
      a.cancel();
    }
    _stand.dispose();
    _runde.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sitzung;
    return BeimOeffnen(
      pruefen: _laden,
      alle: const Duration(minutes: 2),
      child: RosenwegGeruest(
        titel: Text(s.app.name),
        logo: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset('assets/logo/rosenweg-mailfreigabe-klein.png', semanticLabel: 'Logo'),
        ),
        aktionen: [_Menue(sitzung: s)],
        ziele: [
          GeruestZiel(
            titel: 'Freigeben',
            symbol: Icons.mark_email_unread_outlined,
            gewaehltSymbol: Icons.mark_email_unread,
            seite: (_) => FreigabeSeite(api: _api, stand: _stand, neuLaden: _nachAktion, oeffnen: _oeffnen),
          ),
          GeruestZiel(
            titel: 'Alle Mails',
            symbol: Icons.outbox_outlined,
            gewaehltSymbol: Icons.outbox,
            seite: (_) => AlleSeite(api: _api, oeffnen: _oeffnen, runde: _runde),
          ),
        ],
      ),
    );
  }
}

/// Menue oben rechts: Anmeldung (echter Stand, "Nach Updates suchen"),
/// Ueber, Abmelden (nicht auf geteilten Telefonen – dort meldet Rosenweg
/// Geraet ab).
class _Menue extends StatelessWidget {
  const _Menue({required this.sitzung});
  final RosenwegSitzung sitzung;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Mehr',
    onSelected: (w) async {
      switch (w) {
        case 'anmeldung':
          await zeigeAnmeldung(context, sitzung);
        case 'ueber':
          await zeigeUeber(context, sitzung.app);
        case 'abmelden':
          if (await frage(
            context,
            'Abmelden?',
            'Danach musst du dich neu anmelden. Benachrichtigungen kommen erst wieder nach der Anmeldung.',
            ja: 'Abmelden',
          )) {
            await HintergrundAbfrage.abmelden(sitzung.app);
            await sitzung.abmelden();
          }
      }
    },
    itemBuilder: (_) => [
      PopupMenuItem(value: 'anmeldung', child: Text('Anmeldung: ${sitzung.name ?? 'angemeldet'}')),
      PopupMenuItem(value: 'ueber', child: Text('Über ${sitzung.app.name}')),
      if (!sitzung.geteiltesTelefon) const PopupMenuItem(value: 'abmelden', child: Text('Abmelden')),
    ],
  );
}
