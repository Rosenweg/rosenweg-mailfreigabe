// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../daten.dart';
import '../mail_api.dart';
import 'freigabe.dart';

/// "Alle Mails": die ganze Outbox, soweit ich sie sehen darf (Technik und
/// Praesident alles; sonst die Mails, die ich laut Regel freigeben darf, und
/// die ich selbst eingestellt habe) – mit Filter nach Stand.
class AlleSeite extends StatefulWidget {
  const AlleSeite({super.key, required this.api, required this.oeffnen, required this.runde});
  final MailApi api;
  final void Function(int id) oeffnen;

  /// Aendert sich nach jeder Freigabe/Ablehnung: neu laden.
  final ValueNotifier<int> runde;

  @override
  State<AlleSeite> createState() => _AlleSeiteState();
}

class _AlleSeiteState extends State<AlleSeite> {
  MailStatus? _status;
  List<Mail>? _mails;
  Object? _fehler;

  @override
  void initState() {
    super.initState();
    widget.runde.addListener(_laden);
    _laden();
  }

  @override
  void dispose() {
    widget.runde.removeListener(_laden);
    super.dispose();
  }

  Future<void> _laden() async {
    final s = _status;
    setState(() => _fehler = null);
    try {
      final l = await widget.api.liste(status: s);
      if (mounted && s == _status) setState(() => _mails = l);
    } catch (e) {
      if (mounted) setState(() => _fehler = e);
    }
  }

  void _filter(MailStatus? s) {
    setState(() {
      _status = s;
      _mails = null;
    });
    _laden();
  }

  @override
  Widget build(BuildContext context) {
    final mails = _mails;
    return Column(
      children: [
        // alle Filter auf einen Blick (umbrechen statt seitwaerts schieben)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final s in <MailStatus?>[null, ...MailStatus.values])
                ChoiceChip(label: Text(s?.text ?? 'Alle'), selected: _status == s, onSelected: (_) => _filter(s)),
            ],
          ),
        ),
        Expanded(
          child: _fehler != null && mails == null
              ? FehlerAnzeige(text: fehlerText(_fehler!), nochmals: _laden)
              : mails == null
              ? const LadeAnzeige()
              : RefreshIndicator(
                  onRefresh: _laden,
                  child: mails.isEmpty
                      ? ListView(
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: Text('Keine Mails.')),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          itemCount: mails.length,
                          itemBuilder: (_, i) => MailKarte(m: mails[i], mitStatus: true, antippen: () => widget.oeffnen(mails[i].id)),
                        ),
                ),
        ),
      ],
    );
  }
}
