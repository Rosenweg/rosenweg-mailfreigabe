// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

import '../daten.dart';
import '../mail_api.dart';

/// Inhalt vor dem Versand korrigieren (wie die Outbox im Web): An, CC,
/// Antwort an, Betreff, Text. Jede inhaltliche Aenderung setzt bisherige
/// Freigaben zurueck (4-Augen-Prinzip, API). Pop mit true = gespeichert.
class BearbeitenSeite extends StatefulWidget {
  const BearbeitenSeite({super.key, required this.api, required this.m});
  final MailApi api;
  final Mail m;

  @override
  State<BearbeitenSeite> createState() => _BearbeitenSeiteState();
}

class _BearbeitenSeiteState extends State<BearbeitenSeite> {
  final _form = GlobalKey<FormState>();
  late final _an = TextEditingController(text: widget.m.an);
  late final _cc = TextEditingController(text: widget.m.cc ?? '');
  late final _antwort = TextEditingController(text: widget.m.antwortAn ?? '');
  late final _betreff = TextEditingController(text: widget.m.betreff);
  late final _text = TextEditingController(text: widget.m.text ?? '');
  bool _speichert = false;

  @override
  void dispose() {
    for (final c in [_an, _cc, _antwort, _betreff, _text]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _speichern() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (widget.m.freigabenAnzahl > 0 &&
        !await frage(
          context,
          'Freigaben zurücksetzen?',
          'Wer schon freigegeben hat, muss die geänderte Mail nochmals freigeben.',
          ja: 'Speichern',
        )) {
      return;
    }
    setState(() => _speichert = true);
    try {
      final weg = await widget.api.bearbeiten(
        widget.m.id,
        an: _an.text,
        cc: _cc.text,
        antwortAn: _antwort.text,
        betreff: _betreff.text,
        text: _text.text,
      );
      if (!mounted) return;
      zeigeMeldung(context, weg > 0 ? 'Gespeichert – $weg Freigabe${weg == 1 ? '' : 'n'} zurückgesetzt.' : 'Gespeichert.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) zeigeMeldung(context, fehlerText(e), fehler: true);
    } finally {
      if (mounted) setState(() => _speichert = false);
    }
  }

  String? _pflicht(String? v) => (v ?? '').trim().isEmpty ? 'Bitte ausfüllen.' : null;

  @override
  Widget build(BuildContext context) {
    InputDecoration deko(String titel, [String? hinweis]) =>
        InputDecoration(labelText: titel, helperText: hinweis, border: const OutlineInputBorder());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mail bearbeiten'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(onPressed: _speichert ? null : _speichern, child: const Text('Speichern')),
          ),
        ],
      ),
      body: RosenwegInhalt(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _an,
                decoration: deko('An', 'Mehrere mit Komma trennen'),
                validator: _pflicht,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _cc, decoration: deko('CC'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextFormField(controller: _antwort, decoration: deko('Antwort an'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextFormField(controller: _betreff, decoration: deko('Betreff'), validator: _pflicht),
              const SizedBox(height: 12),
              TextFormField(
                controller: _text,
                decoration: deko('Text'),
                minLines: 10,
                maxLines: null,
                keyboardType: TextInputType.multiline,
              ),
              if (adressen(widget.m.bcc).isNotEmpty || widget.m.bccAnzahl > 0) ...[
                const SizedBox(height: 12),
                const Hinweis('Die verdeckten Empfänger (BCC) bleiben, wie sie sind.'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
