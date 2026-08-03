/// A brief's shape without its prose (ADR-0064).
///
/// The two questions an author asks while iterating are "does this resolve" and
/// "what is actually in there" — and answering them by reading the whole brief
/// costs the reader (or the agent) the entire document. The LSOR booklet's
/// director brief is 75 KB; its summary is about a page.
///
/// Deliberately built from the plan rather than by post-processing rendered
/// markdown: the sections a summary lists are the ones the renderer would emit for
/// this audience, which is a property of the plan and the field table, not of the
/// output text. Parsing headings back out of markdown would invent a second,
/// drifting answer to the same question.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7): the CLI renders too.
library;

import 'package:ringdrill/data/source/source_fields.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/utils/exercise_share_format.dart';

/// One markdown field of one scope, as the summary names it.
typedef _Field = ({String label, String? content});

/// Renders the shape of [plan]'s brief for [audience] as markdown.
///
/// Names every exercise and station with the code the brief would give it, lists
/// the sections present, and says which are empty — an empty section is the more
/// useful half, because it is what an author forgot rather than what they wrote.
String renderBriefSummary({
  required Plan plan,
  required BriefAudience audience,
  Exercise? exercise,
}) {
  final out = StringBuffer()
    ..writeln('# ${plan.name} — summary')
    ..writeln()
    ..writeln(
      'Audience: ${audience.name}. Sections listed are the ones the brief',
    )
    ..writeln(
      'would render; a field withheld from this audience is not counted.',
    )
    ..writeln();

  final exercises = exercise != null
      ? [exercise]
      : (plan.exercises.toList()..sort((a, b) => a.index.compareTo(b.index)));

  _writeScope(
    out,
    'Plan',
    [
      (label: 'intro', content: plan.briefIntroMd),
      (label: 'comms', content: plan.commsMd),
      (label: 'before_round', content: plan.beforeRoundMd),
    ],
    audience,
    wireKeys: const {
      'intro': 'briefIntroMd',
      'comms': 'commsMd',
      'before_round': 'beforeRoundMd',
    },
  );

  for (final ex in exercises) {
    // From the exercise's own index, not its position in the list: a scoped call
    // passes a filtered copy that `indexOf` cannot find, which numbered it 0.
    // Station codes already work this way, so the two agree by construction.
    final number = ex.index + 1;
    final code = Numbering.exercise(plan.exerciseNumberFormat, number);
    // Both corrections the Organisering line got (ADR-0062), because this line
    // made the same two claims. The phases come from the rounds the schedule
    // actually has rather than the exercise's own three, which stopped being the
    // answer the moment a station overrode one — and are wrong in `ring` too, not
    // only in the uneven modes, since there the longest station sets every round.
    // And `×` asserts a uniform cycle, so it stands only where the rounds share
    // one: a product of a span is not arithmetic.
    //
    // The mode is named for the same reason the brief names its conduct. `ring`
    // stays silent and so renders byte-identically: it is the default, and the
    // absence is what says so.
    final minutes = effectivePhaseMinutes(ex);
    final uniform = minutes.every((m) => m == minutes.first);
    out
      ..writeln()
      ..writeln('## $code ${ex.name}')
      ..writeln()
      ..writeln(
        '${ex.numberOfRounds} round(s)${uniform ? ' ×' : ''} '
        '(${rotationPhaseBreakdown(ex)}) min, '
        '${ex.numberOfTeams} team(s), ${ex.stations.length} station(s)'
        '${ex.mode == ExerciseMode.ring ? '' : ', mode: ${ex.mode.name}'}',
      );
    _writeScope(
      out,
      'Exercise',
      [
        (label: 'method', content: ex.methodMd),
        (label: 'learning_goals', content: ex.learningGoalsMd),
        (label: 'training_focus', content: ex.trainingFocusMd),
        (label: 'order_format', content: ex.orderFormatMd),
        (label: 'execution_tips', content: ex.executionTipsMd),
        (label: 'comms', content: ex.commsMd),
      ],
      audience,
      wireKeys: const {
        'method': 'methodMd',
        'learning_goals': 'learningGoalsMd',
        'training_focus': 'trainingFocusMd',
        'order_format': 'orderFormatMd',
        'execution_tips': 'executionTipsMd',
        'comms': 'commsMd',
      },
    );

    final stations = ex.stations.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    for (final station in stations) {
      _writeStation(out, plan, number, station, audience);
    }
  }

  return out.toString();
}

void _writeStation(
  StringBuffer out,
  Plan plan,
  int exerciseNumber,
  Station station,
  BriefAudience audience,
) {
  final code = Numbering.station(
    plan.stationNumberFormat,
    exerciseNumber: exerciseNumber,
    stationIndex: station.index,
  );
  out
    ..writeln()
    ..writeln('### $code ${station.name}');
  final scenario = <String>[
    if (station.position != null) 'position',
    if (station.locations.isNotEmpty) '${station.locations.length} location(s)',
    if (station.persons.isNotEmpty) '${station.persons.length} person(s)',
  ];
  if (scenario.isNotEmpty) out.writeln('Scenario: ${scenario.join(', ')}');
  _writeScope(
    out,
    'Station',
    [
      (label: 'equipment', content: station.equipmentMd),
      (label: 'situation', content: station.situationMd),
      (label: 'mission', content: station.missionMd),
      (label: 'logistics', content: station.logisticsMd),
      (label: 'critical_questions', content: station.criticalQuestionsMd),
      (label: 'leader_answers', content: station.leaderAnswersMd),
      (label: 'director_notes', content: station.directorNotesMd),
    ],
    audience,
    wireKeys: const {
      'equipment': 'equipmentMd',
      'situation': 'situationMd',
      'mission': 'missionMd',
      'logistics': 'logisticsMd',
      'critical_questions': 'criticalQuestionsMd',
      'leader_answers': 'leaderAnswersMd',
      'director_notes': 'directorNotesMd',
    },
  );
}

/// Lists which of [fields] this audience would see, and which are empty.
///
/// A field the audience may not see is omitted entirely rather than reported as
/// empty: from that audience's side it does not exist, and calling it "missing"
/// would read as something to go and write.
void _writeScope(
  StringBuffer out,
  String scopeLabel,
  List<_Field> fields,
  BriefAudience audience, {
  required Map<String, String> wireKeys,
}) {
  final present = <String>[];
  final empty = <String>[];
  for (final field in fields) {
    final wireKey = wireKeys[field.label];
    final declared = wireKey == null
        ? null
        : SourceScopes.markdownByWireKey[wireKey];
    if (declared != null && !declared.visibleTo(audience)) continue;
    final content = field.content?.trim() ?? '';
    (content.isEmpty ? empty : present).add(field.label);
  }
  if (present.isNotEmpty) {
    out.writeln('$scopeLabel sections: ${present.join(', ')}');
  }
  if (empty.isNotEmpty) {
    out.writeln('$scopeLabel empty: ${empty.join(', ')}');
  }
}
