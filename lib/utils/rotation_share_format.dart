import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';

/// Formats the rotation table of [exercise] as a single multi-line string
/// suitable for pasting into chat clients like Slack, Microsoft Teams or
/// Messenger.
///
/// The exact text format is locked to the manual template observers have
/// already been using when sharing rotations by hand:
///
/// ```
/// Øvelse 2
/// Generelt hver runde: 15 | 10 | 5 (øve | evaluere | rullere / inntransport)
///
/// Rullering (klokkeslett)
/// Runde 1: 0930 | 0945 | 0955 (neste)
/// Runde 2: 1000 | 1015 | 1025 (neste)
/// ...
/// Runde 6: 1200 | 1215 | 1225 (retur)
/// ```
///
/// Conventions preserved on purpose:
///
/// * Clock times use `HHMM` without a colon. Avoids accidental phone-number
///   linkification in some chat clients and matches the historical format
///   observers expect.
/// * Phases are separated by `|`. Works the same in proportional and
///   monospace fonts because no horizontal alignment is implied.
/// * All rounds except the last carry `(neste)`. The last carries `(retur)`
///   to signal the inbound transport at the end of the exercise.
///
/// Kept as a pure top-level function (no Flutter imports) so it can be unit
/// tested against a golden string without spinning up a widget tree.
String formatRotationForShare(Exercise exercise, AppLocalizations l10n) {
  String hhmm(SimpleTimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}'
      '${t.minute.toString().padLeft(2, '0')}';

  final buf = StringBuffer();
  buf.writeln(exercise.name);
  buf.writeln(
    '${l10n.rotationShareEachRound}: '
    '${exercise.executionTime} | '
    '${exercise.evaluationTime} | '
    '${exercise.rotationTime} '
    '(${l10n.rotationShareLegendPhases})',
  );
  buf.writeln();
  buf.writeln(l10n.rotationShareTitle);

  final rounds = exercise.schedule.length;
  for (var r = 0; r < rounds; r++) {
    final times = exercise.schedule[r].map(hhmm).join(' | ');
    final suffix = (r == rounds - 1)
        ? l10n.rotationShareReturn
        : l10n.rotationShareNext;
    final line = '${l10n.round(1)} ${r + 1}: $times ($suffix)';
    // No trailing newline on the last round so paste targets don't gain a
    // dangling blank line.
    if (r == rounds - 1) {
      buf.write(line);
    } else {
      buf.writeln(line);
    }
  }
  return buf.toString();
}
