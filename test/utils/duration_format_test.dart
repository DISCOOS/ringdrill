import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/time_utils.dart';

/// A span is formatted as a span.
///
/// The coordinator's pending countdown used to build a `DateTime` whose hour and
/// minute *fields* were the remaining hours and minutes — today 01:30 to mean "90
/// minutes" — and then take its difference from the wall clock. What it printed
/// therefore depended on the time of day: "0 sec" for anything under an hour,
/// "47 min" for 90 minutes, "9 hours" for 10. These cases are fixed values now, so
/// they cannot drift with the clock.
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('a sub-hour wait reads in minutes, not as zero', () {
    expect(const Duration(minutes: 5).formal(l10n), l10n.minute(5));
    expect(const Duration(minutes: 45).formal(l10n), l10n.minute(45));
  });

  test('an hour or more reads in hours', () {
    expect(const Duration(minutes: 90).formal(l10n), l10n.hour(1));
    expect(const Duration(minutes: 180).formal(l10n), l10n.hour(3));
    expect(const Duration(minutes: 600).formal(l10n), l10n.hour(10));
  });

  test('under a minute reads in seconds', () {
    expect(const Duration(seconds: 30).formal(l10n), l10n.second(30));
  });

  // DateTimeX.formal delegates to this, so the two phrasings cannot drift.
  test('the DateTime form agrees with the Duration form', () {
    final reference = DateTime(2026, 7, 29, 8);
    final later = reference.add(const Duration(hours: 3));

    expect(
      later.formal(l10n, reference),
      const Duration(hours: 3).formal(l10n),
    );
  });
}
