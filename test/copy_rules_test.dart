import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The copy rules from the spec: never a currency name, never "fraud",
/// never "saved" or "prevented", and "goods receipt" spelled out. The
/// abbreviation is allowed only inside `match_type` data values, which the
/// cards show verbatim.
const Map<String, String> _bannedPatterns = {
  'RM': r'\bRM\b',
  'fraud': r'fraud',
  'saved': r'\bsaved\b',
  'prevented': r'prevented',
  'GR': r'\bGR\b',
};

final RegExp _matchTypeValue = RegExp(r'"match_type"\s*:\s*"[^"]*"');

List<File> _sourceFiles() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [...files, File('assets/data/batch.json')];
}

void main() {
  test('copy rules hold across lib/ and batch.json', () {
    final files = _sourceFiles();
    expect(files, isNotEmpty);

    final violations = <String>[];
    for (final file in files) {
      final text = file.readAsStringSync().replaceAll(_matchTypeValue, '');
      final lines = text.split('\n');
      for (final entry in _bannedPatterns.entries) {
        // The two abbreviations stay case-sensitive so ordinary words such
        // as "arm" or "grid" never trip the scan; the three words are checked
        // in any capitalisation.
        final isAbbreviation = entry.key == 'RM' || entry.key == 'GR';
        final regex = RegExp(entry.value, caseSensitive: isAbbreviation);
        for (var i = 0; i < lines.length; i++) {
          if (regex.hasMatch(lines[i])) {
            violations.add('${file.path}:${i + 1} contains "${entry.key}": '
                '${lines[i].trim()}');
          }
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
