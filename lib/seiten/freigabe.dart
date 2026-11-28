// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../daten.dart';
import '../mail_api.dart';
import 'aktionen.dart';

/// "Freigeben": was jetzt auf MICH wartet, aelteste zuerst. Jede Mail mit
/// Empfaengern und Anfang des Textes; Freigeben und Ablehnen direkt auf der
/// Karte (mit Rueckfrage), antippen = ganze Mail mit Anhaengen.
class FreigabeSeite extends StatelessWidget {
  const FreigabeSeite({super.key, required this.api, required this.stand, required this.neuLaden, required this.oeffnen});
  final MailApi api;

  /// null = laedt noch; Fehler als [Object] im Stand.
  final ValueNotifier<({List<Mail>? mails, Object? fehler})> stand;
  final Future<void> Function() neuLaden;
  final void Function(int id) oeffnen;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: stand,
    builder: (context, s, _) {
      final mails = s.mails;
      if (mails == null && s.fehler != null) return FehlerAnzeige(text: fehlerText(s.fehler!), nochmals: neuLaden);
      if (mails == null) return const LadeAnzeige();
      return RefreshIndicator(
        onRefresh: neuLaden,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            if (s.fehler != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Hinweis(fehlerText(s.fehler!), art: HinweisArt.warnung),
              ),
            if (mails.isEmpty)
              const _Leer()
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  mails.length == 1 ? '1 Mail wartet auf deine Freigabe' : '${mails.length} Mails warten auf deine Freigabe',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final m in mails)
                MailKarte(
                  m: m,
                  antippen: () => oeffnen(m.id),
                  unten: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () async {
                          if (await ablehnenMitGrund(context, api, m)) await neuLaden();
                        },
                        style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                        child: const Text('Ablehnen'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () async {
                          if (await freigebenMitFrage(context, api, m)) await neuLaden();
                        },
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('Freigeben'),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _Leer extends StatelessWidget {
  const _Leer();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.mark_email_read_outlined, size: 56, color: RosenwegFarben.gut),
          const SizedBox(height: 12),
          Text('Nichts zur Freigabe', style: t.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Sobald eine Mail auf deine Freigabe wartet, meldet sich die App – auch wenn sie geschlossen ist.',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: f.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Eine Mail als Karte: Betreff, Empfaenger, wer und wann, Anfang des Textes.
class MailKarte extends StatelessWidget {
  const MailKarte({super.key, required this.m, this.antippen, this.unten, this.mitStatus = false});
  final Mail m;
  final VoidCallback? antippen;
  final Widget? unten;
  final bool mitStatus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = Theme.of(context).colorScheme;
    final klein = t.bodySmall?.copyWith(color: f.onSurfaceVariant);
    return Card(
      // Karten haben im Rosenweg-Thema keinen Rand: Abstand zur naechsten
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: antippen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(m.betreff, style: t.titleSmall)),
                  if (mitStatus) ...[const SizedBox(width: 8), StatusSchild(m.status)],
                ],
              ),
              const SizedBox(height: 6),
              EmpfaengerZeilen(m, kurz: true),
              if (m.vorschau != null) ...[
                const SizedBox(height: 6),
                Text(m.vorschau!.replaceAll(RegExp(r'\s+'), ' '), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.bodyMedium),
              ],
              const SizedBox(height: 6),
              Text(
                [
                  ?m.eingestelltVon,
                  wannText(m.eingestellt),
                  if (m.anhangAnzahl > 0) '${m.anhangAnzahl} Anhang${m.anhangAnzahl == 1 ? '' : 'e'}',
                  if (m.wartet && m.noetig > 1) '${m.freigabenAnzahl} von ${m.noetig} Freigaben',
                  if (m.bearbeitetVon != null) 'bearbeitet',
                ].where((x) => x.isNotEmpty).join(' · '),
                style: klein,
              ),
              ?unten,
            ],
          ),
        ),
      ),
    );
  }
}
