/// Localized strings without `package:flutter` — the headless half of the
/// ADR-0048 amendment recorded in DESIGN-014.
///
/// `AppLocalizations` is generated from the same ARB files but is a Flutter
/// type, so anything that must also run under `dart run` / `dart compile exe`
/// (the CLI's `build` and `render`, AGENTS.md rule 7, ADR-0005) cannot depend on
/// it. The messages are baked into `headless_labels.g.dart` by
/// `tools/generate_headless_labels.dart` rather than read from the ARB at
/// runtime, because a compiled executable has no package directory to resolve
/// `lib/l10n/*.arb` from.
///
/// This file is the reader: locale selection, ICU plural arm selection, and
/// `{placeholder}` substitution. It is deliberately not a general ICU
/// implementation — see the generator for what is and is not supported.
library;

import 'package:ringdrill/l10n/headless_labels.g.dart';

/// Looks up ARB messages for one locale, headlessly.
///
/// [languageCode] is an ISO 639-1 code, normally a plan's
/// `metadata.languageCode` (ADR-0007 addendum). An unknown or null code falls
/// back to [fallbackLanguageCode] — never guessed from the host locale, which
/// would make a rendered brief depend on which machine rendered it.
///
/// Note that `localeName` is not an ARB message: neither `app_en.arb` nor
/// `app_nb.arb` carries an `@@locale` key, so the generated `AppLocalizations`
/// derives it from the file name. Here it is simply [languageCode], which is the
/// same value by construction.
class HeadlessLabels {
  HeadlessLabels({String? languageCode, this.fallbackLanguageCode = 'en'})
    : localeName = _resolve(languageCode, fallbackLanguageCode);

  /// Used when a plan names a language the app has no ARB for.
  final String fallbackLanguageCode;

  /// The language actually in use — the resolved code, not the requested one.
  final String localeName;

  /// Locales this build can serve, in ARB order.
  static List<String> get supportedLanguageCodes =>
      headlessLabelMessages.keys.toList();

  static String _resolve(String? requested, String fallback) {
    final code = requested?.trim().toLowerCase();
    if (code != null && headlessLabelMessages.containsKey(code)) return code;
    // A regional code ("nb_NO", "en-GB") still names a language we may have.
    if (code != null && code.length > 2) {
      final base = code.substring(0, 2);
      if (headlessLabelMessages.containsKey(base)) return base;
    }
    return headlessLabelMessages.containsKey(fallback)
        ? fallback
        : headlessLabelMessages.keys.first;
  }

  Map<String, Object> get _table => headlessLabelMessages[localeName]!;

  /// The message for [key], with `{name}`-style placeholders filled from [args].
  ///
  /// Throws [ArgumentError] for a key the generator was never told about, since
  /// that is a programming error the sync test cannot catch: the caller asked
  /// for a message that is not in `headlessKeys`.
  String message(String key, {Map<String, Object?> args = const {}}) {
    final raw = _table[key];
    if (raw == null) {
      throw ArgumentError.value(
        key,
        'key',
        'not a headless message; add it to headlessKeys in '
            'tools/generate_headless_labels.dart and regenerate',
      );
    }
    if (raw is String) return _substitute(raw, args);
    throw ArgumentError.value(
      key,
      'key',
      'is a plural message — call plural() instead',
    );
  }

  /// The [key] plural arm for [count], with placeholders filled from [args].
  ///
  /// Arm selection follows the ARB's own arms: an exact `=n` wins, then the
  /// CLDR category for the locale, then `other`. Only `one`/`other` categories
  /// are distinguished — both `en` and `nb` are one-vs-other languages, and the
  /// generator refuses messages needing more.
  String plural(String key, int count, {Map<String, Object?> args = const {}}) {
    final raw = _table[key];
    if (raw == null) {
      throw ArgumentError.value(
        key,
        'key',
        'not a headless message; add it to headlessKeys in '
            'tools/generate_headless_labels.dart and regenerate',
      );
    }
    if (raw is String) return _substitute(raw, {'count': count, ...args});
    final arms = raw as Map<String, String>;
    final arm =
        arms['=$count'] ?? (count == 1 ? arms['one'] : null) ?? arms['other']!;
    return _substitute(arm, {'count': count, ...args});
  }

  String _substitute(String template, Map<String, Object?> args) {
    if (args.isEmpty || !template.contains('{')) return template;
    var out = template;
    for (final entry in args.entries) {
      out = out.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return out;
  }
}
