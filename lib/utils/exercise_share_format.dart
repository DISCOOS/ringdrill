import 'package:ringdrill/services/brief/brief_labels.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/utils/plan_variables.dart';

/// Formats [t] as a four-digit clock string without a colon ("0930").
/// Used in rotation blocks and the phase breakdown for share/brief output.
String _hhmm(SimpleTimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}'
    '${t.minute.toString().padLeft(2, '0')}';

/// One round in the rotation block. [index] is 1-based.
/// [suffix] is the resolved `neste` / `retur` label from l10n (no parens).
class RotationRound {
  const RotationRound({
    required this.index,
    required this.times,
    required this.suffix,
  });

  final int index;

  /// The round's phase clock faces — `["2000", "2015", "2025"]`, one per entry
  /// in the schedule row. Kept as a list rather than only the joined string
  /// because the round *table* wants one column per phase, while the
  /// Organisering block wants them on one line.
  final List<String> times;

  /// [times] pipe-joined, for the single-line Organisering block.
  String get timesText => times.join(' | ');

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
        times: exercise.schedule[r].map(_hhmm).toList(),
        suffix: (r == rounds - 1)
            ? l10n.rotationShareReturn
            : l10n.rotationShareNext,
      ),
  ];
}

/// The rotation as a GFM table: one row per round, with the round number, one
/// column per phase clock face, and what happens after it.
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

  // A phase per column. The first cut put the pipe-joined `timesText` in one cell
  // and escaped the pipes, which rendered as a table whose middle column held
  // "2000 \| 2015 \| 2025" — the plain-text form, inside a table, with the
  // separators visible. The times are columns; that is what the reader is
  // comparing down the page.
  //
  // Three phases is what this format derives, but the schedule is a list and a
  // row with a different count would produce a header and body that disagree —
  // which is not a table at all. So anything else falls back to the one-cell
  // legend form, which is at least well-formed.
  final splitPhases = rounds.first.times.length == 3;
  final phaseHeaders = splitPhases
      ? [l10n.execution, l10n.evaluation, l10n.rotation]
      : [l10n.rotationShareLegendPhases];

  // Every cell needs escaping: a pipe in a header or a value ends the cell early
  // and silently changes the table's column count. The legend is the one that bit
  // — unescaped, it turned a three-column header into five.
  String cell(String text) => text.replaceAll('|', r'\|');
  String row(Iterable<String> cells) => '| ${cells.map(cell).join(' | ')} |';

  // "neste"/"retur" goes in parentheses after the rotation time rather than in a
  // column of its own: it is a note about that time, and a column with no header was
  // a cell the reader had to guess the meaning of.
  final buf = StringBuffer()
    ..writeln(row([l10n.round(1), ...phaseHeaders]))
    ..writeln('|${'---|' * (phaseHeaders.length + 1)}');
  for (final r in rounds) {
    final phases = splitPhases ? [...r.times] : [r.timesText];
    phases[phases.length - 1] = '${phases.last} (${r.suffix})';
    buf.writeln(row(['${r.index}', ...phases]));
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
String stationDurationLabel(Exercise exercise, {int? executionTime}) {
  // A station may run longer than its exercise (ADR-0062), and this label is about
  // *this* station — so its own execution time wins, in the total and in the
  // breakdown. Reading the exercise's here reported 35 min for a 100-minute post.
  final execution = executionTime ?? exercise.executionTime;
  final total = execution + exercise.evaluationTime + exercise.rotationTime;
  return '$total min '
      '($execution | ${exercise.evaluationTime} | ${exercise.rotationTime})';
}

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
  // Total from the *derived* schedule, not from numberOfRounds × cycle. With
  // rounds of differing length (ADR-0062) the multiplication is simply wrong: it
  // reported 70 min for an exercise whose own endTime said 210. startTime and
  // endTime already carry the answer, and they wrap at midnight, so a negative
  // difference means the exercise crossed 00:00.
  final span = exercise.endTime.inMinutes - exercise.startTime.inMinutes;
  final total = span >= 0 ? span : span + 24 * 60;
  final totalStr = (total >= 60 && total % 60 == 0)
      ? l10n.hour(total ~/ 60)
      : '$total min';
  if (exercise.numberOfRounds <= 1) return totalStr;
  // The per-round suffix only means anything when the rounds are the same length.
  // Where they are not, the total is the honest whole story.
  final round = rotationRoundMinutes(exercise);
  if (total != exercise.numberOfRounds * round) return totalStr;
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
