import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';

/// Formats [t] as a four-digit clock string without a colon ("0930").
/// Used in rotation blocks and the phase breakdown for share/brief output.
String _hhmm(SimpleTimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}'
    '${t.minute.toString().padLeft(2, '0')}';

/// One round in the rotation block. [index] is 1-based.
/// [timesText] is the pre-formatted `"HHMM | HHMM | HHMM"` joined string.
/// [suffix] is the resolved `neste` / `retur` label from l10n (no parens).
class RotationRound {
  const RotationRound({
    required this.index,
    required this.timesText,
    required this.suffix,
  });

  final int index;
  final String timesText;
  final String suffix;
}

/// Returns one [RotationRound] per entry in [exercise.schedule].
/// The last round gets [AppLocalizations.rotationShareReturn]; all others
/// get [AppLocalizations.rotationShareNext].
List<RotationRound> rotationRounds(Exercise exercise, AppLocalizations l10n) {
  final rounds = exercise.schedule.length;
  return [
    for (var r = 0; r < rounds; r++)
      RotationRound(
        index: r + 1,
        timesText: exercise.schedule[r].map(_hhmm).join(' | '),
        suffix: (r == rounds - 1)
            ? l10n.rotationShareReturn
            : l10n.rotationShareNext,
      ),
  ];
}

/// Returns the phase pipe-join string for [exercise]:
/// `"executionTime | evaluationTime | rotationTime"` (all in minutes).
String rotationPhaseBreakdown(Exercise exercise) =>
    '${exercise.executionTime} | '
    '${exercise.evaluationTime} | '
    '${exercise.rotationTime}';

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
  if (exercise.numberOfRounds != exercise.stations.length) {
    buf.writeln(
      exercise.numberOfRounds > exercise.stations.length
          ? l10n.shareNoteRevisits(
              exercise.numberOfRounds,
              exercise.stations.length,
            )
          : l10n.shareNoteUnderCoverage(
              exercise.numberOfRounds,
              exercise.stations.length,
            ),
    );
  }
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
    '${rotationPhaseBreakdown(exercise)} '
    '(${l10n.rotationShareLegendPhases})',
  );
  buf.writeln();
  buf.writeln(l10n.rotationShareTitle);

  final rounds = rotationRounds(exercise, l10n);
  for (var i = 0; i < rounds.length; i++) {
    final r = rounds[i];
    final line = '${l10n.round(1)} ${r.index}: ${r.timesText} (${r.suffix})';
    // No trailing newline on the last round so paste targets don't gain
    // a dangling blank line.
    if (i == rounds.length - 1) {
      buf.write(line);
    } else {
      buf.writeln(line);
    }
  }
  return buf.toString();
}
