import 'package:ringdrill/services/brief/brief_labels.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/utils/plan_variables.dart';

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
/// The last round gets [BriefLabels.rotationShareReturn]; all others
/// get [BriefLabels.rotationShareNext].
List<RotationRound> rotationRounds(Exercise exercise, BriefLabels l10n) {
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

/// The rotation as a GFM table: one row per round, with the round number, the
/// three phase clock faces, and what happens after it.
///
/// Exists so an author never has to hand-roll it. Those times are *derived* from
/// `startTime`, `numberOfRounds` and the three durations, so a table typed into a
/// markdown field is a copy that goes stale the moment any of them changes — and it
/// did, in the first real plan converted into this format. `{{exercise.roundTable}}`
/// resolves to this at render, so the copy cannot drift.
///
/// Built on [rotationRounds], the same source the brief's Organisering block reads,
/// so the token and the block can never disagree.
String rotationRoundTable(Exercise exercise, BriefLabels l10n) {
  final rounds = rotationRounds(exercise, l10n);
  if (rounds.isEmpty) return '';
  // Everything here is pipe-joined — the phase times *and* the legend that names
  // them — so both need escaping to survive a table cell. Unescaped, the legend
  // alone turned a three-column header into five and broke the whole table.
  String cell(String text) => text.replaceAll('|', r'\|');
  final buf = StringBuffer()
    ..writeln(
      '| ${cell(l10n.round(1))} '
      '| ${cell(l10n.rotationShareLegendPhases)} | |',
    )
    ..writeln('|---|---|---|');
  for (final r in rounds) {
    buf.writeln('| ${r.index} | ${cell(r.timesText)} | ${r.suffix} |');
  }
  return buf.toString().trimRight();
}

/// Per-round duration with phase breakdown for one station: "30 min (15 | 10 | 5)".
///
/// What a team actually gets at a post, which is what a course booklet prints
/// under every station and therefore what an author would otherwise type by hand
/// (`{{station.duration}}`). Lives here rather than in `BriefRenderer` because the
/// brief and the app's own field preview both need it, and a second copy in the
/// preview resolver is exactly the drift that made `{{exercise.roundTable}}`
/// resolve in the brief and not in the editor.
String stationDurationLabel(Exercise exercise) =>
    '${rotationRoundMinutes(exercise)} min '
    '(${rotationPhaseBreakdown(exercise)})';

/// Returns the phase pipe-join string for [exercise]:
/// `"executionTime | evaluationTime | rotationTime"` (all in minutes).
String rotationPhaseBreakdown(Exercise exercise) =>
    '${exercise.executionTime} | '
    '${exercise.evaluationTime} | '
    '${exercise.rotationTime}';

/// Clock-time span for [exercise]: "08:30–10:30". "Tid" in copy is reserved
/// for clock-time, never duration. Shared by `BriefRenderer` (the
/// `{{exercise.timeLabel}}` brief facet) and DESIGN-010's view-layer field
/// resolution, so both read the same string — see `rotationPhaseBreakdown`
/// above for the same one-function-two-callers shape.
String exerciseTimeLabel(Exercise exercise) =>
    '${exercise.startTime}–${exercise.endTime}';

/// Total duration with per-round breakdown for [exercise].
/// "2 timer (60 min pr oppdrag)" when total is a whole number of hours,
/// "90 min (30 min pr oppdrag)" otherwise. Single-round exercises show
/// just the total without the per-round suffix. Shared by `BriefRenderer`
/// (`{{exercise.durationLabel}}`) and DESIGN-010's view-layer resolution.
String exerciseDurationLabel(Exercise exercise, BriefLabels l10n) {
  final round = rotationRoundMinutes(exercise);
  final total = exercise.numberOfRounds * round;
  final totalStr = (total >= 60 && total % 60 == 0)
      ? l10n.hour(total ~/ 60)
      : '$total min';
  if (exercise.numberOfRounds <= 1) return totalStr;
  return '$totalStr ($round min ${l10n.briefPerStation})';
}

/// Sum of one round's three phases (execution + evaluation + rotation), in
/// minutes — the repeated `executionTime + evaluationTime + rotationTime`
/// expression `exerciseDurationLabel` and [stationDurationLabel] both need.
int rotationRoundMinutes(Exercise exercise) =>
    exercise.executionTime + exercise.evaluationTime + exercise.rotationTime;

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
///    Generelt hver runde: 15 | 10 | 5 (øve | eval | rull / retur)
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
///
/// [variables] resolves `{{var.name}}` tokens (ADR-0046) in the exercise
/// name and the station names — the caller's `effectivePlanVariables` at
/// the exercise's scope. Omit where there is no active plan or the
/// exercise declares no overrides; a station's own override (rather than
/// the exercise's) is not applied here, since a share-text station list
/// carries names only, not per-station scope.
String formatExerciseForShare(
  Exercise exercise,
  BriefLabels l10n, {
  Map<String, String> variables = const {},
}) {
  final buf = StringBuffer();

  // 1. Header
  buf.writeln(substitutePlanVariables(exercise.name, variables));

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
    buf.writeln(
      '${i + 1}. ${substitutePlanVariables(exercise.stations[i].name, variables)}',
    );
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
