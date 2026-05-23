import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';

/// Formats [exercise] as a single multi-line string suitable for pasting
/// into chat clients like Slack, Microsoft Teams or Messenger.
///
/// The text has four blocks separated by blank lines:
///
/// 1. **Header** — exercise name on its own line, raw from
///    `exercise.name` so observers see the same label they see in the
///    app (typically already "Øvelse N").
/// 2. **Meta line** — `HH:MM-HH:MM | N runder | M lag | K poster`. The
///    counts use the existing localized plural forms (`l10n.round`,
///    `l10n.team`, `l10n.station`), lower-cased to match the inline
///    counts used elsewhere in the app (see `ExerciseCard`).
/// 3. **Station list** — `Poster` header followed by a numbered list
///    `1. {name}`, `2. {name}`, ... Only station names are included;
///    coordinates are deliberately omitted because they add noise in a
///    chat message and observers who need to navigate look them up in
///    the app instead.
/// 4. **Rotation block** — exactly the historical format observers
///    already paste by hand:
///
///    ```
///    Generelt hver runde: 15 | 10 | 5 (øve | evaluere | rullere / inntransport)
///
///    Rullering (klokkeslett)
///    Runde 1: 0930 | 0945 | 0955 (neste)
///    ...
///    Runde 6: 1200 | 1215 | 1225 (retur)
///    ```
///
/// Conventions preserved in the rotation block:
///
/// * Clock times use `HHMM` without a colon. Avoids accidental
///   phone-number linkification in some chat clients and matches the
///   historical manual format.
/// * Phases are separated by `|`. Works the same in proportional and
///   monospace fonts because no horizontal alignment is implied.
/// * All rounds except the last carry `(neste)`. The last carries
///   `(retur)` to signal the inbound transport at the end of the
///   exercise.
///
/// Kept as a pure top-level function (no Flutter widget imports) so it
/// can be unit-tested against a golden string without spinning up a
/// widget tree.
String formatExerciseForShare(Exercise exercise, AppLocalizations l10n) {
  String hhmm(SimpleTimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}'
      '${t.minute.toString().padLeft(2, '0')}';

  final buf = StringBuffer();

  // 1. Header
  buf.writeln(exercise.name);

  // 2. Meta line
  final meta = [
    '${exercise.startTime}-${exercise.endTime}',
    '${exercise.numberOfRounds} '
        '${l10n.round(exercise.numberOfRounds).toLowerCase()}',
    '${exercise.numberOfTeams} '
        '${l10n.team(exercise.numberOfTeams).toLowerCase()}',
    '${exercise.stations.length} '
        '${l10n.station(exercise.stations.length).toLowerCase()}',
  ].join(' | ');
  buf.writeln(meta);
  buf.writeln();

  // 3. Station list. The header uses the plural form so it reads as a
  // section title rather than a count.
  buf.writeln(l10n.station(2));
  for (var i = 0; i < exercise.stations.length; i++) {
    buf.writeln('${i + 1}. ${exercise.stations[i].name}');
  }
  buf.writeln();

  // 4. Rotation block. The "Generelt hver runde" line and the
  // round-by-round listing match the manual template observers have
  // been pasting by hand for months.
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
    // No trailing newline on the last round so paste targets don't gain
    // a dangling blank line.
    if (r == rounds - 1) {
      buf.write(line);
    } else {
      buf.writeln(line);
    }
  }
  return buf.toString();
}
