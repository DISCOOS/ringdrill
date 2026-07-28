import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/views/widgets/schedule_card.dart';

/// The summary line shown by the Post viewer's Tidsplan card, the Spill viewer's
/// "Når aktiv" card and both team schedules.
///
/// It subtracted two clock faces, so a window past midnight produced a negative
/// duration: 01:00 - 23:00 = -1320 minutes. Same family as an exercise started after
/// midnight waiting a day, and as "20:15 - 01:15 | 19 timer".
void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('a window inside one day is unchanged', () {
    final summary = scheduleWindowSummary(
      l10n,
      const SimpleTimeOfDay(hour: 8, minute: 0),
      const SimpleTimeOfDay(hour: 11, minute: 30),
    );

    expect(summary, contains('08:00 - 11:30'));
    expect(summary, contains(l10n.hoursMinutesShort(3, 30)));
  });

  test('a window past midnight reads its real length', () {
    final summary = scheduleWindowSummary(
      l10n,
      const SimpleTimeOfDay(hour: 23, minute: 0),
      const SimpleTimeOfDay(hour: 1, minute: 0),
    );

    expect(summary, contains('23:00 - 01:00'));
    // The parenthetical is the duration; the hyphen between the times is the
    // separator, so assert on the duration itself rather than the whole line.
    final duration = summary.substring(summary.indexOf('('));
    expect(
      duration,
      isNot(contains('-')),
      reason: 'a negative duration is what the bare subtraction produced',
    );
    expect(duration, contains('2'));
  });

  test('the reported 20:15-01:15 is five hours', () {
    final summary = scheduleWindowSummary(
      l10n,
      const SimpleTimeOfDay(hour: 20, minute: 15),
      const SimpleTimeOfDay(hour: 1, minute: 15),
    );

    final duration = summary.substring(summary.indexOf('('));
    expect(duration, contains('5'));
    expect(duration, isNot(contains('19')));
  });
}
