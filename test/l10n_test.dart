import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/l10n/app_localizations.dart';

Map<String, String> _readArb(String locale) {
  final file = File('lib/l10n/app_$locale.arb');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  // Skip ARB metadata entries (keys starting with '@').
  return {
    for (final e in json.entries)
      if (!e.key.startsWith('@')) e.key: e.value as String,
  };
}

/// Returns the set of `{placeholder}` names used in an ARB value.
Set<String> _placeholders(String value) =>
    RegExp(r'\{(\w+)\}')
        .allMatches(value)
        .map((m) => m.group(1)!)
        .toSet();

void main() {
  final en = _readArb('en');
  final ru = _readArb('ru');
  final uk = _readArb('uk');

  test('all supported locales declared on AppLocalizations', () {
    final codes =
        AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
    expect(codes, containsAll(<String>{'en', 'ru', 'uk'}));
  });

  test('ru has a translation for every English key', () {
    final missing = en.keys.where((k) => !ru.containsKey(k)).toList();
    expect(missing, isEmpty, reason: 'Missing ru keys: $missing');
  });

  test('uk has a translation for every English key', () {
    final missing = en.keys.where((k) => !uk.containsKey(k)).toList();
    expect(missing, isEmpty, reason: 'Missing uk keys: $missing');
  });

  test('no locale has extra/orphan keys not present in English', () {
    for (final entry in {'ru': ru, 'uk': uk}.entries) {
      final extra =
          entry.value.keys.where((k) => !en.containsKey(k)).toList();
      expect(extra, isEmpty,
          reason: 'Orphan keys in ${entry.key}: $extra');
    }
  });

  test('no translation value is empty', () {
    for (final entry in {'en': en, 'ru': ru, 'uk': uk}.entries) {
      final empties =
          entry.value.entries.where((e) => e.value.trim().isEmpty).map((e) => e.key);
      expect(empties, isEmpty,
          reason: 'Empty values in ${entry.key}: ${empties.toList()}');
    }
  });

  test('placeholders match the English template for every key', () {
    for (final key in en.keys) {
      final expected = _placeholders(en[key]!);
      for (final entry in {'ru': ru, 'uk': uk}.entries) {
        final value = entry.value[key];
        if (value == null) continue; // covered by the missing-key tests
        expect(_placeholders(value), expected,
            reason: 'Placeholder mismatch for "$key" in ${entry.key}');
      }
    }
  });

  testWidgets('lookupAppLocalizations resolves each supported locale',
      (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      expect(l10n.appTitle, isNotEmpty);
    }
  });
}
