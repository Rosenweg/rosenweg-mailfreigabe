// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../daten.dart';
import '../mail_api.dart';
import 'aktionen.dart';
import 'bearbeiten.dart';

/// Eine Mail ganz: Empfaenger, Betreff, Text, Anhaenge, Stand der Freigabe.
/// Unten fest die zwei Knoepfe (nur fuer Freigebende, solange sie wartet):
/// Ablehnen und Freigeben – oben rechts Bearbeiten.
class MailSeite extends StatefulWidget {
  const MailSeite({super.key, required this.api, required this.id, this.geaendert});
  final MailApi api;
  final int id;

  /// Nach Freigabe, Ablehnung oder Bearbeitung (Listen neu laden).
  final VoidCallback? geaendert;

  @override
  State<MailSeite> createState() => _MailSeiteState();
}

class _MailSeiteState extends State<MailSeite> {
  Mail? _m;
  Object? _fehler;
  bool _beschaeftigt = false;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    setState(() => _fehler = null);
    try {
      final m = await widget.api.mail(widget.id);
      if (mounted) setState(() => _m = m);
    } catch (e) {
      if (mounted) setState(() => _fehler = e);
    }
  }

  Future<void> _aktion(Future<bool> Function() f) async {
    setState(() => _beschaeftigt = true);
    try {
      if (await f()) {
        widget.geaendert?.call();
        await _laden();
      }
    } finally {
      if (mounted) setState(() => _beschaeftigt = false);
    }
  }

  Future<void> _anhang(Mail m, Anhang a) async {
    try {
      if (a.name.toLowerCase().endsWith('.pdf')) {
        await pdfOeffnen(context, titel: a.name, laden: () => widget.api.anhang(m.id, a));
        return;
      }
      final d = await mitFortschritt(context, a.name, (fp) => widget.api.anhang(m.id, a, fortschritt: fp));
      if (mounted) await dateiTeilen(context, d);
    } catch (e) {
      if (mounted) zeigeMeldung(context, fehlerText(e), fehler: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    final darfBearbeiten = m != null && m.wartet && (m.darfBearbeiten ?? false);
    final darfFreigeben = m != null && m.wartet && (m.darfFreigeben ?? false) && !m.schonFreigegeben;
    return Scaffold(
      appBar: AppBar(
        title: Text('Mail #${widget.id}'),
        actions: [
          if (darfBearbeiten)
            IconButton(
              tooltip: 'Bearbeiten',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _beschaeftigt
                  ? null
                  : () => _aktion(() async {
                      final r = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => BearbeitenSeite(api: widget.api, m: m),
                        ),
                      );
                      return r == true;
                    }),
            ),
        ],
      ),
      body: _fehler != null && m == null
          ? FehlerAnzeige(text: fehlerText(_fehler!), nochmals: _laden)
          : m == null
          ? const LadeAnzeige()
          : RosenwegInhalt(
              child: RefreshIndicator(
                onRefresh: _laden,
                child: _Inhalt(m: m, anhang: (a) => _anhang(m, a)),
              ),
            ),
      bottomNavigationBar: m == null || !darfBearbeiten
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _beschaeftigt ? null : () => _aktion(() => ablehnenMitGrund(context, widget.api, m)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Ablehnen'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _beschaeftigt || !darfFreigeben ? null : () => _aktion(() => freigebenMitFrage(context, widget.api, m)),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        icon: const Icon(Icons.send),
                        label: Text(m.schonFreigegeben ? 'Schon freigegeben' : 'Freigeben'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Inhalt extends StatelessWidget {
  const _Inhalt({required this.m, required this.anhang});
  final Mail m;
  final void Function(Anhang a) anhang;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final f = Theme.of(context).colorScheme;
    final klein = t.bodySmall?.copyWith(color: f.onSurfaceVariant);
    final bcc = adressen(m.bcc);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Row(
          children: [
            StatusSchild(m.status),
            const SizedBox(width: 8),
            Expanded(child: Text([quelleText(m.quelle), if (m.quelleId != null) '#${m.quelleId}'].join(' '), style: klein)),
          ],
        ),
        const SizedBox(height: 8),
        if (m.wartet && !(m.darfBearbeiten ?? false))
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Hinweis('Wartet auf Freigabe. Freigeben dürfen die Personen aus der Freigabe-Regel; den Stand siehst du hier.'),
          ),
        if (m.wartet && m.schonFreigegeben)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Hinweis('Du hast schon freigegeben – es braucht noch ${m.noetig - m.freigabenAnzahl} weitere Freigabe.'),
          ),
        if (m.status == MailStatus.fehler && m.sendeFehler != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Hinweis('Senden ging nicht: ${m.sendeFehler}', art: HinweisArt.fehler),
          ),
        if (m.status == MailStatus.abgelehnt)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Hinweis('Abgelehnt von ${m.abgelehntVon ?? '–'}: ${m.abgelehntGrund ?? ''}', art: HinweisArt.warnung),
          ),
        Abschnitt(
          titel: 'Empfänger',
          symbol: Icons.group_outlined,
          kind: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EmpfaengerZeilen(m),
              if (m.absender != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Absender: ${m.absender}', style: klein),
                ),
              if (bcc.isNotEmpty)
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('${bcc.length} verdeckte Empfänger zeigen', style: t.bodyMedium),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SelectableText(bcc.join('\n'), style: t.bodySmall),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Abschnitt(
          titel: m.betreff,
          symbol: Icons.mail_outline,
          kind: SelectableText(m.text ?? '', style: t.bodyMedium?.copyWith(height: 1.4)),
        ),
        if (m.anhaenge.isNotEmpty)
          Abschnitt(
            titel: 'Anhänge',
            symbol: Icons.attach_file,
            kind: Column(
              children: [
                for (final a in m.anhaenge)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(a.name.toLowerCase().endsWith('.pdf') ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined),
                    title: Text(a.name),
                    subtitle: a.groesse != null ? Text(groesseText(a.groesse!)) : null,
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => anhang(a),
                  ),
              ],
            ),
          ),
        Abschnitt(
          titel: 'Freigabe',
          symbol: Icons.verified_outlined,
          erklaerung: m.gruppen == null ? null : 'Freigeben dürfen: ${m.gruppen!.split(',').map((g) => g.trim()).join(', ')}',
          kind: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (m.wartet)
                Text(
                  m.noetig > 1 ? '${m.freigabenAnzahl} von ${m.noetig} Freigaben (Vier-Augen-Prinzip)' : 'Eine Freigabe genügt',
                  style: t.bodyMedium,
                ),
              for (final fr in m.freigaben) Text('✓ ${fr.wer} · ${wannText(fr.wann)}', style: t.bodySmall),
              const SizedBox(height: 8),
              for (final z in [
                if (m.eingestelltVon != null || m.eingestellt != null)
                  'Eingestellt von ${m.eingestelltVon ?? 'System'} · ${wannText(m.eingestellt)}',
                if (m.bearbeitetVon != null) 'Bearbeitet von ${m.bearbeitetVon} · ${wannText(m.bearbeitet)}',
                if (m.freigegebenVon != null) 'Freigegeben von ${m.freigegebenVon} · ${wannText(m.freigegebenAm)}',
                if (m.gesendetAm != null) 'Gesendet ${wannText(m.gesendetAm)}',
                if (m.abgelehntVon != null) 'Abgelehnt von ${m.abgelehntVon} · ${wannText(m.abgelehntAm)}',
              ])
                Text(z, style: klein),
            ],
          ),
        ),
      ],
    );
  }
}
