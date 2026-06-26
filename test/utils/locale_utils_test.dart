import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/utils/locale_utils.dart';

void main() {
  group('normalizeLanguageSubtag', () {
    test('maps legacy Norwegian codes onto Bokmål', () {
      expect(normalizeLanguageSubtag('no'), 'nb');
      expect(normalizeLanguageSubtag('NO'), 'nb');
      expect(normalizeLanguageSubtag('nn'), 'nb');
    });

    test('lowercases other codes without remapping', () {
      expect(normalizeLanguageSubtag('EN'), 'en');
      expect(normalizeLanguageSubtag('nb'), 'nb');
      expect(normalizeLanguageSubtag('de'), 'de');
    });
  });

  group('languageOfLocaleTag', () {
    test('strips region and normalises legacy Norwegian', () {
      expect(languageOfLocaleTag('no_NO'), 'nb');
      expect(languageOfLocaleTag('no-NO'), 'nb');
      expect(languageOfLocaleTag('nn_NO'), 'nb');
    });

    test('handles BCP 47 and ICU separators', () {
      expect(languageOfLocaleTag('en_US'), 'en');
      expect(languageOfLocaleTag('nb-NO'), 'nb');
      expect(languageOfLocaleTag('en'), 'en');
    });

    test('defaults to en on empty input', () {
      expect(languageOfLocaleTag(''), 'en');
      expect(languageOfLocaleTag('   '), 'en');
    });
  });

  group('resolveSupportedLocale', () {
    const supported = [Locale('en'), Locale('nb')];

    test('maps a no_NO device locale onto nb', () {
      final resolved = resolveSupportedLocale(
        const [Locale('no', 'NO')],
        supported,
      );
      expect(resolved, const Locale('nb'));
    });

    test('matches by language even when region differs', () {
      final resolved = resolveSupportedLocale(
        const [Locale('en', 'US')],
        supported,
      );
      expect(resolved, const Locale('en'));
    });

    test('walks the device list in order', () {
      final resolved = resolveSupportedLocale(
        const [Locale('de'), Locale('nb', 'NO')],
        supported,
      );
      expect(resolved, const Locale('nb'));
    });

    test('falls back to the first supported locale when nothing matches', () {
      final resolved = resolveSupportedLocale(
        const [Locale('fr'), Locale('de')],
        supported,
      );
      expect(resolved, const Locale('en'));
    });

    test('falls back when device locale list is null', () {
      final resolved = resolveSupportedLocale(null, supported);
      expect(resolved, const Locale('en'));
    });
  });
}
