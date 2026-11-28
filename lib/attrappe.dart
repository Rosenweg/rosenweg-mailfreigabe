// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

/// Antwortet wie die Haupt-API (Mail-Outbox), mit erfundenen Daten – keine
/// echten Personen, Adressen oder Mails, es wird nichts versendet. Fuer
/// Tests, Bildschirmfotos und Entwicklung ohne Server
/// (--dart-define=RW_ATTRAPPE=1).
class Attrappe implements Transport {
  Attrappe({this.gruppen = const ['technik'], this.mitZurFreigabe = true, DateTime? jetzt}) : _jetzt = jetzt ?? DateTime.now() {
    _mails.addAll(_vorfuehrung());
  }

  /// Gruppen der angemeldeten Person.
  final List<String> gruppen;

  /// false = API ohne GET …/zur-freigabe (vor dem Ausrollen).
  final bool mitZurFreigabe;
  final DateTime _jetzt;

  /// Alle Anfragen in der Reihenfolge (fuer Tests).
  final anfragen = <({String methode, String pfad, Object? koerper})>[];

  /// Naechste Antwort fuer einen Pfad erzwingen (Tests).
  final erzwungen = <String, ApiAntwort>{};

  static const ich = 'erika.muster@example.org';
  final _mails = <Map<String, dynamic>>[];

  String _vor(Duration d) => _jetzt.subtract(d).toUtc().toIso8601String();
  static String _nun() => DateTime.now().toUtc().toIso8601String();

  /// Neue wartende Mail einstellen (Tests: Benachrichtigung).
  void einstellen({required int id, required String betreff, String an = 'verwaltung@example.org'}) => _mails.insert(0, {
    'id': id,
    'source_type': 'ad-hoc',
    'source_id': null,
    'mail_to': an,
    'subject': betreff,
    'body_text': 'Erfundener Text.',
    'status': 'pending',
    'created_by': 'hans.beispiel@example.org',
    'created_at': _nun(),
    'attachments': <Object>[],
    'regel': _standard,
    'freigaben': <Map<String, dynamic>>[],
  });

  /// Mail von jemand anderem erledigt (Tests).
  void erledigen(int id) => _mail('$id')?['status'] = 'gesendet';

  static const _standard = {'source_type_pattern': 'default', 'required_groups': 'technik,praesident', 'min_approvers': 1};

  List<Map<String, dynamic>> _vorfuehrung() => [
    {
      'id': 41,
      'source_type': 'ad-hoc',
      'source_id': null,
      'mail_from': 'ausschuss@example.org',
      'mail_to': 'eigentuemer-haus9@example.org',
      'mail_cc': 'verwaltung@example.org',
      'mail_bcc': [for (var i = 1; i <= 14; i++) 'person$i@example.org'].join(', '),
      'mail_reply_to': 'ausschuss@example.org',
      'subject': 'Einladung zur Ausschusssitzung am 9. Dezember',
      'body_text':
          'Liebe Eigentümerinnen und Eigentümer\n\n'
          'Der Ausschuss trifft sich am Dienstag, 9. Dezember, um 19 Uhr im Gemeinschaftsraum. '
          'Die Traktanden findet ihr im Anhang.\n\n'
          'Anliegen bitte bis zum 5. Dezember an den Ausschuss.\n\n'
          'Freundliche Grüsse\nHans Beispiel, Ausschuss',
      'status': 'pending',
      'created_by': 'hans.beispiel@example.org',
      'created_at': _vor(const Duration(minutes: 12)),
      'attachments': [
        {'filename': 'Traktanden.pdf', 'size': 48213},
      ],
      'regel': _standard,
      'freigaben': <Map<String, dynamic>>[],
    },
    {
      'id': 40,
      'source_type': 'auslage-auszahlung',
      'source_id': 57,
      'mail_from': 'ausschuss@example.org',
      'mail_to': 'buchhaltung@verwaltung.example.org',
      'mail_cc': 'max.probe@example.org',
      'mail_bcc': null,
      'mail_reply_to': null,
      'subject': 'Auszahlung Auslage #57: Leuchtmittel Treppenhaus (CHF 84.50)',
      'body_text':
          'Guten Tag\n\nBitte zahlt die folgende Auslage aus:\n\n'
          'Auslage #57 – Leuchtmittel Treppenhaus Haus 9\nBetrag: CHF 84.50\n'
          'Empfänger: Max Probe, IBAN CH00 0000 0000 0000 0000 0\n\nBeleg im Anhang.\n\nFreundliche Grüsse\nAusschuss',
      'status': 'pending',
      'created_by': 'max.probe@example.org',
      'created_at': _vor(const Duration(hours: 3)),
      'attachments': [
        {'filename': 'Quittung-57.pdf', 'size': 120400},
      ],
      'regel': {'source_type_pattern': 'auslage-auszahlung', 'required_groups': 'technik,praesident', 'min_approvers': 2},
      'freigaben': <Map<String, dynamic>>[
        {'approver_email': 'paul.vorlage@example.org', 'approved_at': _vor(const Duration(hours: 2))},
      ],
    },
    {
      'id': 39,
      'source_type': 'ad-hoc',
      'source_id': null,
      'mail_to': 'bewohner-haus9@example.org',
      'subject': 'Wasserunterbruch am Donnerstag',
      'body_text': 'Am Donnerstag ist das Wasser von 8 bis 10 Uhr abgestellt.',
      'status': 'gesendet',
      'created_by': 'hans.beispiel@example.org',
      'created_at': _vor(const Duration(days: 1, hours: 2)),
      'freigegeben_von': 'paul.vorlage@example.org',
      'freigegeben_am': _vor(const Duration(days: 1, hours: 1)),
      'sent_at': _vor(const Duration(days: 1, hours: 1)),
      'attachments': <Object>[],
      'regel': _standard,
      'freigaben': <Map<String, dynamic>>[
        {'approver_email': 'paul.vorlage@example.org', 'approved_at': _vor(const Duration(days: 1, hours: 1))},
      ],
    },
    {
      'id': 38,
      'source_type': 'ad-hoc',
      'source_id': null,
      'mail_to': 'alle@example.org',
      'subject': 'Test bitte ignorieren',
      'body_text': 'Test',
      'status': 'abgelehnt',
      'created_by': 'hans.beispiel@example.org',
      'created_at': _vor(const Duration(days: 3)),
      'abgelehnt_von': ich,
      'abgelehnt_am': _vor(const Duration(days: 3)),
      'abgelehnt_grund': 'Versehentlich an alle – bitte an den Ausschuss schicken.',
      'attachments': <Object>[],
      'regel': _standard,
      'freigaben': <Map<String, dynamic>>[],
    },
  ];

  bool _darf(Map<String, dynamic> m) {
    String norm(String s) => s.trim().toLowerCase().replaceAll('ä', 'ae');
    final regel = {for (final g in '${(m['regel'] as Map)['required_groups']}'.split(',')) norm(g)};
    return gruppen.any((g) => regel.contains(norm(g)));
  }

  bool _vonMir(Map<String, dynamic> m) => (m['freigaben'] as List).any((f) => f['approver_email'] == ich);

  Map<String, dynamic> _kopf(Map<String, dynamic> m) => {
    for (final k in [
      'id', 'source_type', 'source_id', 'mail_to', 'mail_cc', 'mail_reply_to', 'subject', 'status', 'created_by', //
      'created_at', 'edited_by', 'edited_at', 'freigegeben_von', 'freigegeben_am', 'abgelehnt_von', 'abgelehnt_am',
      'abgelehnt_grund', 'sent_at', 'send_error',
    ])
      k: m[k],
    'bcc_count': (m['mail_bcc'] as String?)?.split(',').length ?? 0,
    'attachment_count': (m['attachments'] as List).length,
  };

  Map<String, dynamic>? _mail(String id) {
    for (final m in _mails) {
      if ('${m['id']}' == id) return m;
    }
    return null;
  }

  @override
  Future<ApiAntwort> senden(String methode, String pfad, {Object? koerper}) async {
    anfragen.add((methode: methode, pfad: pfad, koerper: koerper));
    final z = erzwungen.remove('$methode $pfad');
    if (z != null) return z;
    final uri = Uri.parse(pfad);
    final teile = uri.pathSegments;
    if ('$methode $pfad' == 'GET /api/auth/me') {
      return (
        status: 200,
        json: {
          'user': {
            'id': 7,
            'username': 'erika.muster',
            'name': 'Erika Muster',
            'email': ich,
            'groups': gruppen,
            'permissions': <String, String>{},
          },
        },
      );
    }
    if (teile.length < 2 || teile[1] != 'verwaltung-mail-queue') {
      return (status: 404, json: {'error': 'Nicht gefunden: $methode $pfad'});
    }
    final rest = teile.skip(2).toList();
    final admin = gruppen.any((g) => ['technik', 'präsident', 'praesident'].contains(g.toLowerCase()));
    if (methode == 'GET' && rest.isEmpty) {
      final s = uri.queryParameters['status'];
      final l = [
        for (final m in _mails)
          if ((s == null || m['status'] == s) && (admin || _darf(m))) {..._kopf(m), if (!admin) '_can_approve': _darf(m)},
      ];
      return (status: 200, json: {'mails': l, 'pending_count': l.where((m) => m['status'] == 'pending').length, 'darf_alle': admin});
    }
    if (methode == 'GET' && rest.length == 1 && rest[0] == 'zur-freigabe') {
      if (!mitZurFreigabe) return (status: 404, json: {'error': 'Nicht gefunden'});
      final l = [
        for (final m in _mails.reversed)
          if (m['status'] == 'pending' && _darf(m) && !_vonMir(m))
            {
              ..._kopf(m),
              'vorschau': '${m['body_text']}'.length > 280 ? '${m['body_text']}'.substring(0, 280) : m['body_text'],
              'freigaben': (m['freigaben'] as List).length,
              'noetig': (m['regel'] as Map)['min_approvers'],
              'gruppen': (m['regel'] as Map)['required_groups'],
            },
      ];
      return (status: 200, json: {'mails': l, 'anzahl': l.length, 'jetzt': _nun()});
    }
    final m = rest.isEmpty ? null : _mail(rest[0]);
    if (m == null) return (status: 404, json: {'error': 'Nicht gefunden'});
    if (methode == 'GET' && rest.length == 1) {
      final fr = m['freigaben'] as List;
      return (
        status: 200,
        json: {
          ...m,
          '_approval_rule': m['regel'],
          '_approvals': fr,
          '_approvals_count': fr.length,
          '_can_approve': _darf(m),
          '_can_edit': admin || _darf(m),
          '_already_approved_by_me': _vonMir(m),
        },
      );
    }
    if (m['status'] != 'pending') {
      return (status: 409, json: {'error': "Status ist '${m['status']}', erwartet 'pending'"});
    }
    if (methode == 'POST' && rest.length == 2 && rest[1] == 'freigeben') {
      if (!_darf(m)) return (status: 403, json: {'error': 'Freigabe erfordert eine der Gruppen: technik,praesident'});
      if (_vonMir(m)) return (status: 409, json: {'error': 'Du hast bereits freigegeben'});
      final fr = m['freigaben'] as List;
      fr.add({'approver_email': ich, 'approved_at': _nun()});
      final noetig = (m['regel'] as Map)['min_approvers'] as int;
      if (fr.length < noetig) {
        return (
          status: 200,
          json: {'success': true, 'sent': false, 'awaiting_more_approvers': true, 'approvals': fr.length, 'required': noetig},
        );
      }
      // Vorfuehrung: nichts wird versendet, nur der Stand wechselt
      m['status'] = 'gesendet';
      m['freigegeben_von'] = ich;
      m['freigegeben_am'] = m['sent_at'] = _nun();
      return (status: 200, json: {'success': true, 'sent': true, 'approvals': fr.length, 'required': noetig});
    }
    if (methode == 'POST' && rest.length == 2 && rest[1] == 'ablehnen') {
      final grund = koerper is Map ? '${koerper['grund'] ?? ''}'.trim() : '';
      if (grund.isEmpty) return (status: 400, json: {'error': 'Grund erforderlich'});
      m['status'] = 'abgelehnt';
      m['abgelehnt_von'] = ich;
      m['abgelehnt_am'] = _nun();
      m['abgelehnt_grund'] = grund;
      return (status: 200, json: {'success': true});
    }
    if (methode == 'PUT' && rest.length == 1) {
      final b = koerper is Map ? koerper : const {};
      var geaendert = false;
      for (final k in ['mail_to', 'mail_cc', 'mail_reply_to', 'subject', 'body_text']) {
        if (b.containsKey(k) && '${b[k] ?? ''}' != '${m[k] ?? ''}') {
          m[k] = b[k];
          geaendert = true;
        }
      }
      final weg = geaendert ? (m['freigaben'] as List).length : 0;
      if (geaendert) {
        (m['freigaben'] as List).clear();
        m['edited_by'] = ich;
        m['edited_at'] = _nun();
      }
      return (status: 200, json: {..._kopf(m), '_invalidated_approvals': weg});
    }
    return (status: 404, json: {'error': 'Nicht gefunden: $methode $pfad'});
  }
}

class _Fest implements Zugangsquelle {
  @override
  Future<String?> zugangsToken() async => 'attrappe';
  @override
  void zugangUngueltig() {}
}

/// Anhaenge der Vorfuehrung: ein winziges, erfundenes PDF.
RosenwegDateien attrappeDateien() => RosenwegDateien(
  basis: 'https://beispiel.invalid',
  zugang: _Fest(),
  client: MockClient((r) async {
    if (r.url.path.contains('/attachment/')) {
      return http.Response.bytes(utf8.encode(_pdf), 200, headers: {'content-type': 'application/pdf'});
    }
    return http.Response(jsonEncode({'error': 'Nicht gefunden.'}), 404);
  }),
);

/// Sitzung mit Vorfuehrdaten (main.dart, Tests, Bildschirmfotos).
RosenwegSitzung attrappeSitzung(RosenwegApp app, [Attrappe? a]) =>
    RosenwegSitzung(app, transport: a ?? Attrappe())..dateien = attrappeDateien();

const _pdf =
    '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n'
    '2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n'
    '3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 595 842]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj\n'
    '4 0 obj<</Length 58>>stream\nBT /F1 24 Tf 72 760 Td (Traktanden - Vorfuehrung) Tj ET\nendstream endobj\n'
    '5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj\n'
    'trailer<</Root 1 0 R>>\n%%EOF\n';
