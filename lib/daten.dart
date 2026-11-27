// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import 'package:rosenweg_basis/rosenweg_basis.dart';

/// Stand einer Mail in der Outbox (verwaltung_mail_queue.status).
enum MailStatus {
  wartet('pending', 'Wartet'),
  freigegeben('freigegeben', 'Freigegeben'),
  gesendet('gesendet', 'Gesendet'),
  abgelehnt('abgelehnt', 'Abgelehnt'),
  fehler('fehler', 'Fehler');

  const MailStatus(this.wert, this.text);
  final String wert;
  final String text;

  static MailStatus aus(Object? w) => values.firstWhere((s) => s.wert == w, orElse: () => wartet);

  Color farbe(ColorScheme f) => switch (this) {
    wartet => RosenwegFarben.warnung,
    freigegeben => f.primary,
    gesendet => RosenwegFarben.gut,
    abgelehnt || fehler => f.error,
  };

  IconData get symbol => switch (this) {
    wartet => Icons.hourglass_top,
    freigegeben => Icons.check,
    gesendet => Icons.mark_email_read_outlined,
    abgelehnt => Icons.block,
    fehler => Icons.error_outline,
  };
}

String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
int _zahl(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
DateTime? _zeit(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// Adressen aus "a@x, b@y; c@z" (wie die API sie speichert).
List<String> adressen(String? s) => [
  for (final a in (s ?? '').split(RegExp(r'[,;]')))
    if (a.trim().isNotEmpty) a.trim(),
];

/// Woher die Mail kommt (source_type), lesbar.
String quelleText(String typ) {
  if (typ == 'ad-hoc') return 'Mail schreiben';
  if (typ.startsWith('auslage-auszahlung')) return 'Auszahlung einer Auslage';
  if (typ.startsWith('auslage')) return 'Auslage';
  if (typ.startsWith('reklamation')) return 'Reparatur-Meldung';
  if (typ.startsWith('objekt')) return 'Objektverwaltung';
  if (typ.startsWith('zev')) return 'ZEV';
  if (typ.startsWith('wasch')) return 'Waschküche';
  if (typ.startsWith('isp')) return 'Internet (ISP)';
  return typ;
}

/// Eine Mail der Outbox, wie die Liste (GET /api/verwaltung-mail-queue,
/// …/zur-freigabe) und das Detail (GET …/:id) sie liefern. Felder, die nur das
/// Detail kennt, sind in der Liste leer.
class Mail {
  Mail({
    required this.id,
    required this.status,
    required this.betreff,
    required this.an,
    this.cc,
    this.bcc,
    this.bccAnzahl = 0,
    this.antwortAn,
    this.absender,
    this.quelle = '',
    this.quelleId,
    this.text,
    this.vorschau,
    this.anhangAnzahl = 0,
    this.anhaenge = const [],
    this.eingestelltVon,
    this.eingestellt,
    this.bearbeitetVon,
    this.bearbeitet,
    this.freigegebenVon,
    this.freigegebenAm,
    this.abgelehntVon,
    this.abgelehntAm,
    this.abgelehntGrund,
    this.gesendetAm,
    this.sendeFehler,
    this.freigaben = const [],
    this.freigabenAnzahl = 0,
    this.noetig = 1,
    this.gruppen,
    this.darfFreigeben,
    this.darfBearbeiten,
    this.schonFreigegeben = false,
  });

  final int id;
  final MailStatus status;
  final String betreff;
  final String an;
  final String? cc;

  /// BCC-Adressen (nur im Detail); in Listen nur [bccAnzahl].
  final String? bcc;
  final int bccAnzahl;
  final String? antwortAn;
  final String? absender;
  final String quelle;
  final Object? quelleId;

  /// Ganzer Text (nur Detail).
  final String? text;

  /// Anfang des Textes (nur …/zur-freigabe).
  final String? vorschau;
  final int anhangAnzahl;
  final List<Anhang> anhaenge;
  final String? eingestelltVon;
  final DateTime? eingestellt;
  final String? bearbeitetVon;
  final DateTime? bearbeitet;
  final String? freigegebenVon;
  final DateTime? freigegebenAm;
  final String? abgelehntVon;
  final DateTime? abgelehntAm;
  final String? abgelehntGrund;
  final DateTime? gesendetAm;
  final String? sendeFehler;
  final List<({String wer, DateTime? wann})> freigaben;
  final int freigabenAnzahl;

  /// Wie viele Freigaben die Regel verlangt (4-Augen-Prinzip = 2).
  final int noetig;

  /// Gruppen der Freigabe-Regel, z. B. "technik,praesident".
  final String? gruppen;

  /// Darf ich freigeben? (API: _can_approve; null = unbekannt)
  final bool? darfFreigeben;

  /// Darf ich bearbeiten und ablehnen? (API: _can_edit)
  final bool? darfBearbeiten;
  final bool schonFreigegeben;

  bool get wartet => status == MailStatus.wartet;

  /// Alle sichtbaren Empfaenger (An + CC) und die Zahl der verdeckten.
  int get empfaengerAnzahl => adressen(an).length + adressen(cc).length + (bcc != null ? adressen(bcc).length : bccAnzahl);

  /// Stand fuer [Neuigkeiten]: aendert sich, wenn die Mail bearbeitet wurde
  /// (dann sind alle Freigaben zurueckgesetzt).
  String get stand => (bearbeitet ?? eingestellt)?.toUtc().toIso8601String() ?? '$id';

  factory Mail.aus(Map<String, dynamic> j) {
    final regel = j['_approval_rule'] is Map ? j['_approval_rule'] as Map : null;
    final fr = j['_approvals'] is List ? j['_approvals'] as List : const [];
    final an = j['attachments'] is List ? j['attachments'] as List : const [];
    return Mail(
      id: _zahl(j['id']),
      status: MailStatus.aus(j['status'] ?? 'pending'),
      betreff: _text(j['subject']) ?? '(ohne Betreff)',
      an: '${j['mail_to'] ?? ''}',
      cc: _text(j['mail_cc']),
      bcc: _text(j['mail_bcc']),
      bccAnzahl: _zahl(j['bcc_count']),
      antwortAn: _text(j['mail_reply_to']),
      absender: _text(j['mail_from']),
      quelle: '${j['source_type'] ?? ''}',
      quelleId: j['source_id'],
      text: j['body_text'] is String ? j['body_text'] as String : null,
      vorschau: _text(j['vorschau']),
      anhangAnzahl: j['attachment_count'] != null ? _zahl(j['attachment_count']) : an.length,
      anhaenge: [
        for (final (i, a) in an.indexed)
          if (a is Map)
            Anhang(
              index: i,
              name: _text(a['filename']) ?? 'Anhang ${i + 1}',
              groesse: a['size'] is num ? (a['size'] as num).toInt() : null,
            ),
      ],
      eingestelltVon: _text(j['created_by']),
      eingestellt: _zeit(j['created_at']),
      bearbeitetVon: _text(j['edited_by']),
      bearbeitet: _zeit(j['edited_at']),
      freigegebenVon: _text(j['freigegeben_von']),
      freigegebenAm: _zeit(j['freigegeben_am']),
      abgelehntVon: _text(j['abgelehnt_von']),
      abgelehntAm: _zeit(j['abgelehnt_am']),
      abgelehntGrund: _text(j['abgelehnt_grund']),
      gesendetAm: _zeit(j['sent_at']),
      sendeFehler: _text(j['send_error']),
      freigaben: [
        for (final f in fr)
          if (f is Map) (wer: '${f['approver_email'] ?? ''}', wann: _zeit(f['approved_at'])),
      ],
      freigabenAnzahl: j['_approvals_count'] != null ? _zahl(j['_approvals_count']) : _zahl(j['freigaben']),
      noetig: regel != null ? (_zahl(regel['min_approvers']).clamp(1, 99)) : (j['noetig'] != null ? _zahl(j['noetig']).clamp(1, 99) : 1),
      gruppen: regel != null ? _text(regel['required_groups']) : _text(j['gruppen']),
      darfFreigeben: j['_can_approve'] is bool ? j['_can_approve'] as bool : null,
      darfBearbeiten: j['_can_edit'] is bool ? j['_can_edit'] as bool : null,
      schonFreigegeben: j['_already_approved_by_me'] == true,
    );
  }
}

class Anhang {
  const Anhang({required this.index, required this.name, this.groesse});
  final int index;
  final String name;
  final int? groesse;
}

/// Antwort von POST …/:id/freigeben.
class FreigabeErgebnis {
  const FreigabeErgebnis({required this.gesendet, this.freigaben = 0, this.noetig = 1});
  final bool gesendet;
  final int freigaben;
  final int noetig;

  String get text => gesendet
      ? 'Freigegeben und versendet.'
      : 'Deine Freigabe ist verbucht ($freigaben von $noetig). Es braucht noch ${noetig - freigaben} weitere.';
}

/// "heute 14:05", "gestern 09:12", "27.11. 08:00", "27.11.2025".
String wannText(DateTime? d, {DateTime? jetzt}) {
  if (d == null) return '';
  final n = jetzt ?? DateTime.now();
  String zz(int x) => x.toString().padLeft(2, '0');
  final zeit = '${zz(d.hour)}:${zz(d.minute)}';
  final tag = DateTime(d.year, d.month, d.day);
  final heute = DateTime(n.year, n.month, n.day);
  final diff = heute.difference(tag).inDays;
  if (diff == 0) return 'heute $zeit';
  if (diff == 1) return 'gestern $zeit';
  if (d.year == n.year) return '${zz(d.day)}.${zz(d.month)}. $zeit';
  return '${zz(d.day)}.${zz(d.month)}.${d.year}';
}
