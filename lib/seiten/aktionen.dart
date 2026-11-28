// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../abfrage.dart';
import '../daten.dart';
import '../mail_api.dart';

/// Freigeben mit Rueckfrage: zeigt noch einmal Empfaenger und Betreff –
/// nach dem letzten Ja geht die Mail sofort hinaus. true = erledigt.
Future<bool> freigebenMitFrage(BuildContext context, MailApi api, Mail m) async {
  final rest = m.noetig - m.freigabenAnzahl;
  final sendet = rest <= 1;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(sendet ? 'Freigeben und senden?' : 'Deine Freigabe geben?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.betreff, style: Theme.of(c).textTheme.titleSmall),
            const SizedBox(height: 8),
            EmpfaengerZeilen(m, kurz: true),
            const SizedBox(height: 12),
            Text(
              sendet
                  ? 'Die Mail geht sofort an alle Empfänger.'
                  : 'Vier-Augen-Prinzip: gesendet wird erst, wenn noch ${rest - 1} weitere Person${rest - 1 == 1 ? '' : 'en'} freigibt.',
              style: Theme.of(c).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
        FilledButton.icon(onPressed: () => Navigator.pop(c, true), icon: const Icon(Icons.send), label: const Text('Freigeben')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  try {
    final r = await api.freigeben(m.id);
    await Benachrichtigung.entfernen(benachrichtigungFuer(m.id));
    if (context.mounted) zeigeMeldung(context, r.text);
    return true;
  } catch (e) {
    if (context.mounted) zeigeMeldung(context, fehlerText(e), fehler: true);
    return false;
  }
}

/// Ablehnen: Grund ist Pflicht (wie die API); er geht bei Auszahlungen an die
/// Person, die die Auslage eingereicht hat. true = erledigt.
Future<bool> ablehnenMitGrund(BuildContext context, MailApi api, Mail m) async {
  final grund = await showDialog<String>(context: context, builder: (_) => _AblehnenDialog(m));
  if (grund == null || !context.mounted) return false;
  try {
    await api.ablehnen(m.id, grund);
    await Benachrichtigung.entfernen(benachrichtigungFuer(m.id));
    if (context.mounted) zeigeMeldung(context, 'Abgelehnt – die Mail wird nicht gesendet.');
    return true;
  } catch (e) {
    if (context.mounted) zeigeMeldung(context, fehlerText(e), fehler: true);
    return false;
  }
}

class _AblehnenDialog extends StatefulWidget {
  const _AblehnenDialog(this.m);
  final Mail m;
  @override
  State<_AblehnenDialog> createState() => _AblehnenDialogState();
}

class _AblehnenDialogState extends State<_AblehnenDialog> {
  final _grund = TextEditingController();

  @override
  void dispose() {
    _grund.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leer = _grund.text.trim().isEmpty;
    return AlertDialog(
      title: const Text('Mail ablehnen?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.m.betreff, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          TextField(
            controller: _grund,
            autofocus: true,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Grund', hintText: 'Was soll anders sein?', border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: leer ? null : () => Navigator.pop(context, _grund.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          child: const Text('Ablehnen'),
        ),
      ],
    );
  }
}

/// An, CC, BCC (nur Anzahl), Antwort an – als kurze Zeilen.
/// [kurz]: hoechstens drei Adressen je Zeile, dann "+ N weitere".
class EmpfaengerZeilen extends StatelessWidget {
  const EmpfaengerZeilen(this.m, {super.key, this.kurz = false});
  final Mail m;
  final bool kurz;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = Theme.of(context).colorScheme;
    String liste(List<String> l) {
      if (!kurz || l.length <= 3) return l.join(', ');
      return '${l.take(3).join(', ')} + ${l.length - 3} weitere';
    }

    final bcc = m.bcc != null ? adressen(m.bcc).length : m.bccAnzahl;
    Widget zeile(String was, String wert) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(was, style: t.bodySmall?.copyWith(color: f.onSurfaceVariant)),
          ),
          Expanded(child: Text(wert, style: t.bodyMedium)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        zeile('An', liste(adressen(m.an))),
        if (adressen(m.cc).isNotEmpty) zeile('CC', liste(adressen(m.cc))),
        if (bcc > 0) zeile('BCC', '$bcc verdeckte Empfänger'),
        if (!kurz && m.antwortAn != null) zeile('Antwort', m.antwortAn!),
      ],
    );
  }
}

/// Stand als farbiges Schild.
class StatusSchild extends StatelessWidget {
  const StatusSchild(this.status, {super.key});
  final MailStatus status;

  @override
  Widget build(BuildContext context) {
    final c = status.farbe(Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        border: Border.all(color: c.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.text,
        style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
