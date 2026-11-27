// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/painting.dart';
import 'package:rosenweg_basis/rosenweg_basis.dart';

/// Angaben der App fuer rosenweg_basis.
///
/// kennung = applicationId (Android) = Bundle-ID (iOS/macOS) = GTK-ID (Linux)
/// = Schema des Ruecksprungs (ch.rosenweg4303.mailfreigabe:/anmeldung, in Authentik
/// bei rosenweg-apps eintragen) = Paket im App-Katalog (/apps, Updater).
const appAngaben = RosenwegApp(
  kennung: 'ch.rosenweg4303.mailfreigabe',
  name: 'Rosenweg Mail-Freigabe',
  ordner: 'rosenweg-mailfreigabe',
  beschreibung: 'Mails der Verwaltung prüfen und freigeben – mit Benachrichtigung, sobald eine wartet.',
  quelle: 'https://github.com/Rosenweg/rosenweg-mailfreigabe',
  logo: AssetImage('assets/logo/rosenweg-mailfreigabe-512.png'),
  // Farbe des Anmeldeschirms wie der Logo-Grund (assets/logo/erzeugen.sh GRUPPE);
  // neue-app.sh setzt sie aus werkzeug/logo/flutter-apps.txt
  gruppe: RosenwegGruppe.technik,
);

/// --dart-define=RW_ATTRAPPE=1: ohne Anmeldung und ohne Server, mit
/// erfundenen Vorfuehrdaten (Entwicklung, Bildschirmfotos, Tests).
const attrappe = bool.fromEnvironment('RW_ATTRAPPE');
