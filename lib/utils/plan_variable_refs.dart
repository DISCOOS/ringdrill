/// Plan-wide `{{var.<name>}}` reference bookkeeping (ADR-0046): counting,
/// locating and rewriting references across every markdown field, every
/// name/description field, and every `variableOverrides` map in a
/// [Plan]. Pure and Flutter-free — safe for the CLI
/// (`bin/ringdrill.dart`) to import transitively.
///
/// Deliberately does not depend on `AppLocalizations` (a Flutter type), so
/// [variableReferences] returns structured [PlanVariableReference]s rather
/// than pre-formatted strings — the caller (a view, which already has an
/// `AppLocalizations`) turns each one into a display string like "Øvelse 3
/// › Metode" via ARB-sourced field labels. This keeps the localization
/// dependency in `lib/views/`, matching every other pure `lib/utils/`
/// module in this repo.
library;

import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/utils/plan_variables.dart';

/// One markdown field (or `variableOverrides` map, or a name/description
/// field — DESIGN-008 follow-up 10, added alongside follow-ups 05/09's
/// resolution of `{{var.<name>}}` in names/descriptions) a reference — or an
/// override key naming it — can occur in.
enum PlanVariableField {
  planName,
  planDescription,
  planBriefIntro,
  planComms,
  planBeforeRound,
  exerciseName,
  exerciseMethod,
  exerciseLearningGoals,
  exerciseTrainingFocus,
  exerciseOrderFormat,
  exerciseExecutionTips,
  exerciseComms,
  exerciseOverride,
  stationName,
  stationDescription,
  stationEquipment,
  stationSituation,
  stationMission,
  stationLogistics,
  stationCriticalQuestions,
  stationLeaderAnswers,
  stationDirectorNotes,
  stationOverride,
  roleplayNameField,
  roleplayBehavior,
  roleplayBackground,
  roleplayProps,
}

/// One location referencing a variable. At most one of [exerciseNumber]
/// (1-based), [stationCode] (pre-formatted, e.g. "3a" — [Numbering] is
/// itself Flutter-free so this module computes it directly) and
/// [roleplayName] is set, matching [field]'s scope; plan-scope fields
/// set none of them.
class PlanVariableReference {
  const PlanVariableReference({
    required this.field,
    this.exerciseNumber,
    this.stationCode,
    this.roleplayName,
  });

  final PlanVariableField field;
  final int? exerciseNumber;
  final String? stationCode;
  final String? roleplayName;

  @override
  String toString() =>
      'PlanVariableReference($field, exercise: $exerciseNumber, '
      'station: $stationCode, roleplay: $roleplayName)';
}

class _FieldHit {
  const _FieldHit(
    this.field,
    this.matchCount, {
    this.exerciseNumber,
    this.stationCode,
    this.roleplayName,
  });

  final PlanVariableField field;
  final int matchCount;
  final int? exerciseNumber;
  final String? stationCode;
  final String? roleplayName;
}

/// Walks every markdown field and `variableOverrides` map in [plan]
/// once, yielding a hit per field/override that references [name] — shared
/// by [variableReferenceCount] and [variableReferences] so the field list
/// (plan, every exercise, every station, every roleplay) is only
/// enumerated in one place.
Iterable<_FieldHit> _hits(Plan plan, String name) sync* {
  final pattern = planVariableTokenPatternFor(name);
  int matches(String? content) =>
      content == null ? 0 : pattern.allMatches(content).length;

  final planName = matches(plan.name);
  if (planName > 0) {
    yield _FieldHit(PlanVariableField.planName, planName);
  }
  final planDescription = matches(plan.description);
  if (planDescription > 0) {
    yield _FieldHit(PlanVariableField.planDescription, planDescription);
  }
  final planBriefIntro = matches(plan.briefIntroMd);
  if (planBriefIntro > 0) {
    yield _FieldHit(PlanVariableField.planBriefIntro, planBriefIntro);
  }
  final planComms = matches(plan.commsMd);
  if (planComms > 0) {
    yield _FieldHit(PlanVariableField.planComms, planComms);
  }
  final planBeforeRound = matches(plan.beforeRoundMd);
  if (planBeforeRound > 0) {
    yield _FieldHit(PlanVariableField.planBeforeRound, planBeforeRound);
  }

  for (var i = 0; i < plan.exercises.length; i++) {
    final exercise = plan.exercises[i];
    final exerciseNumber = i + 1;

    final exerciseName = matches(exercise.name);
    if (exerciseName > 0) {
      yield _FieldHit(
        PlanVariableField.exerciseName,
        exerciseName,
        exerciseNumber: exerciseNumber,
      );
    }
    final method = matches(exercise.methodMd);
    if (method > 0) {
      yield _FieldHit(
        PlanVariableField.exerciseMethod,
        method,
        exerciseNumber: exerciseNumber,
      );
    }
    final learningGoals = matches(exercise.learningGoalsMd);
    if (learningGoals > 0) {
      yield _FieldHit(
        PlanVariableField.exerciseLearningGoals,
        learningGoals,
        exerciseNumber: exerciseNumber,
      );
    }
    final trainingFocus = matches(exercise.trainingFocusMd);
    if (trainingFocus > 0) {
      yield _FieldHit(
        PlanVariableField.exerciseTrainingFocus,
        trainingFocus,
        exerciseNumber: exerciseNumber,
      );
    }
    final orderFormat = matches(exercise.orderFormatMd);
    if (orderFormat > 0) {
      yield _FieldHit(
        PlanVariableField.exerciseOrderFormat,
        orderFormat,
        exerciseNumber: exerciseNumber,
      );
    }
    final executionTips = matches(exercise.executionTipsMd);
    if (executionTips > 0) {
      yield _FieldHit(
        PlanVariableField.exerciseExecutionTips,
        executionTips,
        exerciseNumber: exerciseNumber,
      );
    }
    final exerciseComms = matches(exercise.commsMd);
    if (exerciseComms > 0) {
      yield _FieldHit(
        PlanVariableField.exerciseComms,
        exerciseComms,
        exerciseNumber: exerciseNumber,
      );
    }
    if (exercise.variableOverrides.containsKey(name)) {
      yield _FieldHit(
        PlanVariableField.exerciseOverride,
        1,
        exerciseNumber: exerciseNumber,
      );
    }

    for (final station in exercise.stations) {
      final stationCode = Numbering.station(
        plan.stationNumberFormat,
        exerciseNumber: exerciseNumber,
        stationIndex: station.index,
      );

      final stationName = matches(station.name);
      if (stationName > 0) {
        yield _FieldHit(
          PlanVariableField.stationName,
          stationName,
          stationCode: stationCode,
        );
      }
      final stationDescription = matches(station.description);
      if (stationDescription > 0) {
        yield _FieldHit(
          PlanVariableField.stationDescription,
          stationDescription,
          stationCode: stationCode,
        );
      }
      final equipment = matches(station.equipmentMd);
      if (equipment > 0) {
        yield _FieldHit(
          PlanVariableField.stationEquipment,
          equipment,
          stationCode: stationCode,
        );
      }
      final situation = matches(station.situationMd);
      if (situation > 0) {
        yield _FieldHit(
          PlanVariableField.stationSituation,
          situation,
          stationCode: stationCode,
        );
      }
      final mission = matches(station.missionMd);
      if (mission > 0) {
        yield _FieldHit(
          PlanVariableField.stationMission,
          mission,
          stationCode: stationCode,
        );
      }
      final logistics = matches(station.logisticsMd);
      if (logistics > 0) {
        yield _FieldHit(
          PlanVariableField.stationLogistics,
          logistics,
          stationCode: stationCode,
        );
      }
      final criticalQuestions = matches(station.criticalQuestionsMd);
      if (criticalQuestions > 0) {
        yield _FieldHit(
          PlanVariableField.stationCriticalQuestions,
          criticalQuestions,
          stationCode: stationCode,
        );
      }
      final leaderAnswers = matches(station.leaderAnswersMd);
      if (leaderAnswers > 0) {
        yield _FieldHit(
          PlanVariableField.stationLeaderAnswers,
          leaderAnswers,
          stationCode: stationCode,
        );
      }
      final directorNotes = matches(station.directorNotesMd);
      if (directorNotes > 0) {
        yield _FieldHit(
          PlanVariableField.stationDirectorNotes,
          directorNotes,
          stationCode: stationCode,
        );
      }
      if (station.variableOverrides.containsKey(name)) {
        yield _FieldHit(
          PlanVariableField.stationOverride,
          1,
          stationCode: stationCode,
        );
      }
    }
  }

  for (final rolePlay in plan.rolePlays) {
    final roleplayNameField = matches(rolePlay.name);
    if (roleplayNameField > 0) {
      yield _FieldHit(
        PlanVariableField.roleplayNameField,
        roleplayNameField,
        roleplayName: rolePlay.name,
      );
    }
    final behavior = matches(rolePlay.behavior);
    if (behavior > 0) {
      yield _FieldHit(
        PlanVariableField.roleplayBehavior,
        behavior,
        roleplayName: rolePlay.name,
      );
    }
    final background = matches(rolePlay.background);
    if (background > 0) {
      yield _FieldHit(
        PlanVariableField.roleplayBackground,
        background,
        roleplayName: rolePlay.name,
      );
    }
    final props = matches(rolePlay.propsMd);
    if (props > 0) {
      yield _FieldHit(
        PlanVariableField.roleplayProps,
        props,
        roleplayName: rolePlay.name,
      );
    }
  }
}

/// Total number of `{{var.<name>}}` occurrences across every markdown field
/// in [plan], plus one for every `variableOverrides` map that keys on
/// [name]. Zero means [name] is safe to delete.
int variableReferenceCount(Plan plan, String name) =>
    _hits(plan, name).fold(0, (sum, hit) => sum + hit.matchCount);

/// One entry per distinct location referencing [name] — a field counted
/// once regardless of how many times the token appears inside it, unlike
/// [variableReferenceCount]. For the delete-blocked message: "this is
/// referenced in these N places", not "this appears M times total".
List<PlanVariableReference> variableReferences(Plan plan, String name) {
  return [
    for (final hit in _hits(plan, name))
      PlanVariableReference(
        field: hit.field,
        exerciseNumber: hit.exerciseNumber,
        stationCode: hit.stationCode,
        roleplayName: hit.roleplayName,
      ),
  ];
}

/// Rewrites every `{{var.<oldName>[.facet]}}` match of [pattern] to the
/// new name, carrying any facet path (the pattern's group 1, e.g. `.utm`
/// on a `location`-typed variable — DESIGN-008 follow-up 11) over
/// unchanged: `{{var.old.utm}}` becomes `{{var.new.utm}}`, never a bare
/// `{{var.new}}`.
String? _rewrite(String? content, RegExp pattern, String newName) {
  if (content == null || !pattern.hasMatch(content)) return content;
  return content.replaceAllMapped(
    pattern,
    (m) => '{{var.$newName${m.group(1) ?? ''}}}',
  );
}

/// Same as [_rewrite], for the non-nullable name/description fields
/// (`Plan.name`/`description`, `Exercise.name`, `Station.name`,
/// `RolePlay.name` — DESIGN-008 follow-up 10).
String _rewriteRequired(String content, RegExp pattern, String newName) =>
    _rewrite(content, pattern, newName)!;

Map<String, String> _renameOverrideKey(
  Map<String, String> overrides,
  String oldName,
  String newName,
) {
  if (!overrides.containsKey(oldName)) return overrides;
  final value = overrides[oldName]!;
  return {
    for (final entry in overrides.entries)
      if (entry.key != oldName) entry.key: entry.value,
    newName: value,
  };
}

/// Returns a copy of [plan] with every `{{var.<oldName>}}` reference
/// rewritten to `{{var.<newName>}}` (every markdown field and every
/// name/description field: plan, every exercise, every station, every
/// roleplay — DESIGN-008 follow-up 10 extends this to the same
/// name/description surface follow-ups 05/09 taught the renderer and the
/// live UI to resolve), every `variableOverrides` key named [oldName]
/// renamed to [newName], and the [oldName] entry in `plan.variables`
/// itself renamed. Does not mutate [plan]; uses `copyWith` throughout,
/// per ADR-0046's plan-wide rename requirement.
Plan renameVariable(Plan plan, String oldName, String newName) {
  final pattern = planVariableTokenPatternFor(oldName);

  Station rewriteStation(Station station) => station.copyWith(
    name: _rewriteRequired(station.name, pattern, newName),
    description: _rewrite(station.description, pattern, newName),
    equipmentMd: _rewrite(station.equipmentMd, pattern, newName),
    situationMd: _rewrite(station.situationMd, pattern, newName),
    missionMd: _rewrite(station.missionMd, pattern, newName),
    logisticsMd: _rewrite(station.logisticsMd, pattern, newName),
    criticalQuestionsMd: _rewrite(
      station.criticalQuestionsMd,
      pattern,
      newName,
    ),
    leaderAnswersMd: _rewrite(station.leaderAnswersMd, pattern, newName),
    directorNotesMd: _rewrite(station.directorNotesMd, pattern, newName),
    variableOverrides: _renameOverrideKey(
      station.variableOverrides,
      oldName,
      newName,
    ),
  );

  Exercise rewriteExercise(Exercise exercise) => exercise.copyWith(
    name: _rewriteRequired(exercise.name, pattern, newName),
    methodMd: _rewrite(exercise.methodMd, pattern, newName),
    learningGoalsMd: _rewrite(exercise.learningGoalsMd, pattern, newName),
    trainingFocusMd: _rewrite(exercise.trainingFocusMd, pattern, newName),
    orderFormatMd: _rewrite(exercise.orderFormatMd, pattern, newName),
    executionTipsMd: _rewrite(exercise.executionTipsMd, pattern, newName),
    commsMd: _rewrite(exercise.commsMd, pattern, newName),
    variableOverrides: _renameOverrideKey(
      exercise.variableOverrides,
      oldName,
      newName,
    ),
    stations: exercise.stations.map(rewriteStation).toList(),
  );

  RolePlay rewriteRolePlay(RolePlay rolePlay) => rolePlay.copyWith(
    name: _rewriteRequired(rolePlay.name, pattern, newName),
    behavior: _rewrite(rolePlay.behavior, pattern, newName),
    background: _rewrite(rolePlay.background, pattern, newName),
    propsMd: _rewrite(rolePlay.propsMd, pattern, newName),
  );

  return plan.copyWith(
    name: _rewriteRequired(plan.name, pattern, newName),
    description: _rewriteRequired(plan.description, pattern, newName),
    briefIntroMd: _rewrite(plan.briefIntroMd, pattern, newName),
    commsMd: _rewrite(plan.commsMd, pattern, newName),
    beforeRoundMd: _rewrite(plan.beforeRoundMd, pattern, newName),
    exercises: plan.exercises.map(rewriteExercise).toList(),
    rolePlays: plan.rolePlays.map(rewriteRolePlay).toList(),
    variables: [
      for (final v in plan.variables)
        if (v.name == oldName) v.copyWith(name: newName) else v,
    ],
  );
}
