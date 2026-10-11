import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_fontLicenses);
  runApp(const LedgerShieldApp());
}

/// Both bundled fonts are SIL OFL 1.1; their license texts are listed under
/// assets so they show up on the Flutter licenses page.
Stream<LicenseEntry> _fontLicenses() async* {
  final inter = await rootBundle.loadString('assets/fonts/OFL-Inter.txt');
  yield LicenseEntryWithLineBreaks(const ['Inter'], inter);
  final mono = await rootBundle.loadString(
    'assets/fonts/OFL-JetBrainsMono.txt',
  );
  yield LicenseEntryWithLineBreaks(const ['JetBrains Mono'], mono);
}
