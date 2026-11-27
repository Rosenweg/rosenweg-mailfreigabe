// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:rosenweg_basis/rosenweg_basis.dart';

import 'daten.dart';

/// Alle Aufrufe der App gegen die Haupt-API – dieselben Endpunkte wie
/// verwaltung-mail-outbox.html. Die Rechte prueft die API je Mail selbst
/// (mailQueueZugang in api/server.js):
///
///  * Technik und Praesident sehen alle Mails
///  * wer laut Freigabe-Regel (mail_approval_config.required_groups) eine Mail
///    freigeben darf, sieht, bearbeitet, lehnt ab und gibt frei
///  * wer eine Mail eingestellt hat, sieht sie (nur lesen)
///
/// Freigeben verlangt immer eine Gruppe aus der Regel der Mail (auch fuer
/// Technik/Praesident) und zaehlt fuer das 4-Augen-Prinzip. Mit der Karte
/// angemeldet: erlaubt, die API protokolliert es (kartenAdmin).
class MailApi {
  MailApi(this.sitzung);
  final RosenwegSitzung sitzung;
  RosenwegApi get api => sitzung.api;

  static const _basis = '/api/verwaltung-mail-queue';

  static List<Mail> _mails(Object? l) => [
    for (final e in l is List ? l : const [])
      if (e is Map<String, dynamic>) Mail.aus(e),
  ];

  /// Mails, die jetzt auf MEINE Freigabe warten (aelteste zuerst).
  ///
  /// GET …/zur-freigabe; fehlt der Endpunkt (API noch aelter, 404), die
  /// Liste der wartenden Mails, gefiltert wie die Web-Seite (_can_approve;
  /// ohne das Feld = Technik/Praesident).
  Future<List<Mail>> zurFreigabe() async {
    try {
      final j = await api.objekt('$_basis/zur-freigabe');
      return _mails(j['mails']);
    } on ApiFehler catch (e) {
      if (e.status != 404) rethrow;
    }
    final j = await api.objekt('$_basis?status=pending');
    final alle = _mails(j['mails']);
    return [
      for (final m in alle.reversed)
        if (m.darfFreigeben ?? true) m,
    ];
  }

  /// Alle Mails, die ich sehen darf; [status] null = alle.
  Future<List<Mail>> liste({MailStatus? status}) async {
    final j = await api.objekt(status == null ? _basis : '$_basis?status=${status.wert}');
    return _mails(j['mails']);
  }

  Future<Mail> mail(int id) async => Mail.aus(await api.objekt('$_basis/$id'));

  Future<FreigabeErgebnis> freigeben(int id) async {
    final j = await api.post('$_basis/$id/freigeben');
    final m = j is Map ? j : const {};
    return FreigabeErgebnis(
      gesendet: m['sent'] == true,
      freigaben: m['approvals'] is num ? (m['approvals'] as num).toInt() : 0,
      noetig: m['required'] is num ? (m['required'] as num).toInt() : 1,
    );
  }

  Future<void> ablehnen(int id, String grund) => api.post('$_basis/$id/ablehnen', {'grund': grund});

  /// Inhalt korrigieren (nur solange sie wartet). Liefert, wie viele
  /// Freigaben dadurch zurueckgesetzt wurden.
  Future<int> bearbeiten(int id, {required String an, String? cc, String? antwortAn, required String betreff, required String text}) async {
    final j = await api.put('$_basis/$id', {
      'mail_to': an.trim(),
      'mail_cc': (cc ?? '').trim().isEmpty ? null : cc!.trim(),
      'mail_reply_to': (antwortAn ?? '').trim().isEmpty ? null : antwortAn!.trim(),
      'subject': betreff.trim(),
      'body_text': text,
    });
    return j is Map && j['_invalidated_approvals'] is num ? (j['_invalidated_approvals'] as num).toInt() : 0;
  }

  Future<DateiDaten> anhang(int id, Anhang a, {Fortschritt? fortschritt}) =>
      sitzung.dateien.herunterladen('$_basis/$id/attachment/${a.index}', name: a.name, fortschritt: fortschritt);
}
