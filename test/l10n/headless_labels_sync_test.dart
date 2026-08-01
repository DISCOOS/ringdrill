// Keeps the baked-in headless messages honest against the ARBs they came from.
//
// `lib/l10n/headless_labels.g.dart` is a copy of a handful of ARB messages
// (DESIGN-014's ADR-0048 amendment): the CLI's `build` and `render` need them
// but cannot use the Flutter-generated `AppLocalizations`. A copy can drift, and
// the failure mode is quiet — a Norwegian brief silently rendering an old
// string. So this test re-reads the ARBs and asserts the generated table still
// matches. When it fails, the fix is to regenerate, not to edit the .g.dart:
//
//   dart run tools/generate_headless_labels.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/headless_labels.dart';
import 'package:ringdrill/l10n/headless_labels.g.dart';

void main() {
  group('headless labels', () {
    for (final locale in headlessLabelMessages.keys) {
      test('$locale matches app_$locale.arb', () {
        final arb =
            jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
                as Map<String, dynamic>;
        final table = headlessLabelMessages[locale]!;
        for (final entry in table.entries) {
          final raw = arb[entry.key];
          expect(
            raw,
            isA<String>(),
            reason:
                'ARB message "${entry.key}" is missing from app_$locale.arb — '
                'remove it from headlessKeys or restore it',
          );
          final value = entry.value;
          if (value is String) {
            expect(
              value,
              raw,
              reason:
                  '"${entry.key}" drifted; run '
                  'dart run tools/generate_headless_labels.dart',
            );
          } else {
            // A plural: every generated arm body must appear verbatim inside the
            // ARB's ICU string, and the arm count must match. Comparing bodies
            // rather than re-parsing keeps this test independent of the
            // generator's parser, so a bug there cannot make the test agree with
            // it by construction.
            final arms = value as Map<String, String>;
            expect(
              RegExp(r'\{\w+,\s*plural,').hasMatch(raw as String),
              isTrue,
              reason: '"${entry.key}" is a plural here but not in the ARB',
            );
            expect(
              RegExp(
                r'(^|\s)(=\d+|zero|one|two|few|many|other)\{',
              ).allMatches(raw).length,
              arms.length,
              reason:
                  '"${entry.key}" has a different number of plural arms than '
                  'the ARB; run dart run tools/generate_headless_labels.dart',
            );
            for (final arm in arms.entries) {
              expect(
                raw,
                contains('${arm.key}{${arm.value}}'),
                reason:
                    '"${entry.key}" arm "${arm.key}" drifted; run '
                    'dart run tools/generate_headless_labels.dart',
              );
            }
          }
        }
      });
    }

    test('every supported locale is served', () {
      for (final code in HeadlessLabels.supportedLanguageCodes) {
        expect(File('lib/l10n/app_$code.arb').existsSync(), isTrue);
      }
    });
  });

  group('HeadlessLabels', () {
    test('resolves a plan language, a regional variant and an unknown code', () {
      expect(HeadlessLabels(languageCode: 'nb').localeName, 'nb');
      expect(HeadlessLabels(languageCode: 'NB').localeName, 'nb');
      expect(HeadlessLabels(languageCode: 'nb_NO').localeName, 'nb');
      expect(HeadlessLabels(languageCode: 'en-GB').localeName, 'en');
      // Never guessed from the host locale — an unsupported language falls back
      // to the explicit default, so a rendered brief does not depend on which
      // machine rendered it.
      expect(HeadlessLabels(languageCode: 'de').localeName, 'en');
      expect(HeadlessLabels().localeName, 'en');
      expect(
        HeadlessLabels(
          languageCode: 'de',
          fallbackLanguageCode: 'nb',
        ).localeName,
        'nb',
      );
    });

    test('picks plural arms the way the ARB declares them', () {
      final nb = HeadlessLabels(languageCode: 'nb');
      final en = HeadlessLabels(languageCode: 'en');
      // nb declares only =0 and other, and both read "Lag".
      expect(nb.plural('team', 0), 'Lag');
      expect(nb.plural('team', 1), 'Lag');
      expect(nb.plural('team', 4), 'Lag');
      // en declares =0, =1 and other.
      expect(en.plural('team', 1), 'Team');
      expect(en.plural('team', 3), 'Teams');
      expect(nb.plural('station', 1), 'Post');
      expect(nb.plural('station', 2), 'Poster');
    });

    test('substitutes placeholders', () {
      final labels = HeadlessLabels(languageCode: 'en');
      expect(
        labels.message('briefUnknownVariable', args: {'name': 'talegruppe'}),
        '‹missing variable: talegruppe›',
      );
      expect(labels.message('briefRingRoute'), 'Ring Route');
    });

    test(
      'rejects an unknown key and a plural asked for as a plain message',
      () {
        final labels = HeadlessLabels(languageCode: 'en');
        expect(() => labels.message('nopeNotAKey'), throwsArgumentError);
        expect(() => labels.message('team'), throwsArgumentError);
      },
    );
  });
}
