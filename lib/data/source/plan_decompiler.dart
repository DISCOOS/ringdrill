/// Turns a [Plan] back into a source document: the inverse of
/// `plan_builder.dart`.
///
/// The contract is that `build(decompile(d))` produces a plan with the same
/// `contentHash` as `d`. Two things make that achievable rather than aspirational:
///
/// * **uuids are emitted, always.** They are not derivable, and exercise, role
///   play and team uuids are inside `computeContentHash` *and* are its sort keys
///   (DESIGN-014). Dropping them would change the hash and the ordering.
/// * **nothing is rewritten.** Names come out byte for byte, including a legacy
///   baked-in "#6 " — numbering comes from order and names are opaque (ADR-0059).
///   Every value written here is either authored content, verbatim, or an
///   authored field converted between two representations of the same value
///   (`{hour, minute}` → `"HH:MM"`).
///
/// What is dropped is exactly what the format excludes by design: derived fields,
/// `Staff` (local PII, stripped at publish anyway), and `Session` run records.
/// Nothing dangles when staff go, because a role play's effective identity is
/// already denormalized onto it (worked example decision 9).
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

import 'package:latlong2/latlong.dart';
import 'package:ringdrill/data/source/source_emitter.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';

/// A decompiled document, as source-shaped maps plus the rendered YAML.
class DecompiledPlan {
  const DecompiledPlan({
    required this.plan,
    required this.exercises,
    required this.teams,
    required this.yaml,
  });

  final Map<String, dynamic> plan;
  final List<Map<String, dynamic>> exercises;
  final List<Map<String, dynamic>> teams;

  /// The document as YAML text.
  final String yaml;
}

/// Reverses the compiler.
class PlanDecompiler {
  const PlanDecompiler._();

  /// Decompiles [plan].
  ///
  /// [header] is prepended as YAML comments — used by the CLI to record where a
  /// document came from, which matters because a decompiled file is a derived
  /// artefact someone will otherwise mistake for hand-written source.
  static DecompiledPlan decompile(Plan plan, {String? header}) {
    final planMap = <String, dynamic>{
      'uuid': plan.uuid,
      'name': plan.name,
      if (plan.description.isNotEmpty) 'description': plan.description,
      if (plan.metadata.languageCode != null)
        'language': plan.metadata.languageCode,
      if (plan.tags.isNotEmpty) 'tags': plan.tags,
      // Number formats are always written rather than defaulted: they change the
      // labels a reader sees, and a document that omits them would silently
      // adopt whatever this build's default happens to be.
      'exerciseNumberFormat': plan.exerciseNumberFormat.name,
      'stationNumberFormat': plan.stationNumberFormat.name,
      if (plan.briefIntroMd != null) 'intro': plan.briefIntroMd,
      if (plan.commsMd != null) 'comms': plan.commsMd,
      if (plan.beforeRoundMd != null) 'before_round': plan.beforeRoundMd,
      if (plan.variables.isNotEmpty) 'variables': _variables(plan.variables),
    };

    // Exercises in index order, and stations within them likewise: the archive's
    // own order is not guaranteed (manifests are uuid-named files), while `index`
    // is what every surface in the app sorts by.
    final exercises =
        (plan.exercises.toList()..sort((a, b) => a.index.compareTo(b.index)))
            .map((exercise) => _exercise(exercise, plan.rolePlays))
            .toList();

    final teams =
        (plan.teams.toList()..sort((a, b) => a.index.compareTo(b.index)))
            .map(
              (team) => <String, dynamic>{
                'uuid': team.uuid,
                'name': team.name,
                if (team.numberOfMembers != null)
                  'numberOfMembers': team.numberOfMembers,
                if (team.position != null)
                  'position': _position(team.position!),
              },
            )
            .toList();

    return DecompiledPlan(
      plan: planMap,
      exercises: exercises,
      teams: teams,
      yaml: SourceEmitter.emit(
        plan: planMap,
        exercises: exercises,
        teams: teams,
        header: header,
      ),
    );
  }

  static Map<String, Map<String, dynamic>> _variables(
    List<DrillVariable> variables,
  ) {
    final sorted = variables.toList()..sort((a, b) => a.name.compareTo(b.name));
    return {
      for (final variable in sorted)
        variable.name: <String, dynamic>{
          if (variable.value.isNotEmpty) 'value': variable.value,
          if (variable.hint != null) 'hint': variable.hint,
          // Only written when it is not the back-compatible default, so a plain
          // string variable stays a two-line entry.
          if (variable.type != VariableType.string) 'type': variable.type.name,
          if (variable.location != null)
            'location': <String, dynamic>{
              if (variable.location!.place.isNotEmpty)
                'place': variable.location!.place,
              if (variable.location!.position != null)
                'position': _position(variable.location!.position!),
            },
        },
    };
  }

  static Map<String, dynamic> _exercise(
    Exercise exercise,
    List<RolePlay> allRolePlays,
  ) {
    final stations = exercise.stations.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return <String, dynamic>{
      'uuid': exercise.uuid,
      'name': exercise.name,
      'startTime': _time(exercise.startTime),
      'numberOfTeams': exercise.numberOfTeams,
      'numberOfRounds': exercise.numberOfRounds,
      // Emitted only when it is not the default, so a ring route decompiles to
      // exactly the document it did before ADR-0062 and every plan in the catalog
      // round-trips unchanged.
      if (exercise.mode != ExerciseMode.ring) 'mode': exercise.mode.name,
      if (exercise.groups.isNotEmpty)
        'groups': [
          for (final group in exercise.groups)
            {
              'stations': [
                for (final slot in group.stations)
                  {'station': slot.stationIndex, 'teams': slot.teams},
              ],
            },
        ],
      'executionTime': exercise.executionTime,
      'evaluationTime': exercise.evaluationTime,
      'rotationTime': exercise.rotationTime,
      if (exercise.templateId != null) 'templateId': exercise.templateId,
      if (exercise.variableOverrides.isNotEmpty)
        'variableOverrides': exercise.variableOverrides,
      if (exercise.methodMd != null) 'method': exercise.methodMd,
      if (exercise.learningGoalsMd != null)
        'learning_goals': exercise.learningGoalsMd,
      if (exercise.trainingFocusMd != null)
        'training_focus': exercise.trainingFocusMd,
      if (exercise.orderFormatMd != null)
        'order_format': exercise.orderFormatMd,
      if (exercise.executionTipsMd != null)
        'execution_tips': exercise.executionTipsMd,
      if (exercise.commsMd != null) 'comms': exercise.commsMd,
      'stations': [
        for (final station in stations)
          _station(station, exercise, allRolePlays),
      ],
    };
  }

  static Map<String, dynamic> _station(
    Station station,
    Exercise exercise,
    List<RolePlay> allRolePlays,
  ) {
    // Role plays are stored flat on the plan and nested here — the inverse of the
    // builder's relocation. Matching on (exerciseUuid, stationIndex) is the
    // station's identity, since stations have no uuid of their own.
    final rolePlays =
        allRolePlays
            .where(
              (rp) =>
                  rp.exerciseUuid == exercise.uuid &&
                  rp.stationIndex == station.index,
            )
            .toList()
          ..sort((a, b) => a.index.compareTo(b.index));

    return <String, dynamic>{
      'name': station.name,
      // Only when the station has its own; an inheriting station emits nothing, as
      // it did before ADR-0062.
      if (station.executionTime != null) 'executionTime': station.executionTime,
      if (station.evaluationTime != null)
        'evaluationTime': station.evaluationTime,
      if (station.rotationTime != null) 'rotationTime': station.rotationTime,
      if (station.variantSuffix != null) 'variantSuffix': station.variantSuffix,
      if (station.position != null) 'position': _position(station.position!),
      if (station.description != null) 'description': station.description,
      if (station.variableOverrides.isNotEmpty)
        'variableOverrides': station.variableOverrides,
      if (station.equipmentMd != null) 'equipment': station.equipmentMd,
      if (station.situationMd != null) 'situation': station.situationMd,
      if (station.missionMd != null) 'mission': station.missionMd,
      if (station.logisticsMd != null) 'logistics': station.logisticsMd,
      if (station.criticalQuestionsMd != null)
        'critical_questions': station.criticalQuestionsMd,
      if (station.leaderAnswersMd != null)
        'leader_answers': station.leaderAnswersMd,
      if (station.directorNotesMd != null)
        'director_notes': station.directorNotesMd,
      if (station.locations.isNotEmpty)
        'locations': [for (final l in _sortedLocations(station)) _location(l)],
      if (station.persons.isNotEmpty)
        'persons': [for (final p in _sortedPersons(station)) _person(p)],
      if (rolePlays.isNotEmpty)
        'roleplays': [for (final rp in rolePlays) _rolePlay(rp, station)],
    };
  }

  static List<Location> _sortedLocations(Station station) =>
      station.locations.toList()..sort((a, b) => a.slug.compareTo(b.slug));

  static List<Person> _sortedPersons(Station station) =>
      station.persons.toList()..sort((a, b) => a.slug.compareTo(b.slug));

  static Map<String, dynamic> _location(Location location) => <String, dynamic>{
    'slug': location.slug,
    if (location.label.isNotEmpty) 'label': location.label,
    // Written only when it is not the fallback, matching how `type` is handled
    // for variables — an unknown kind decodes to `other`, so emitting it would
    // add noise to every location that never declared one.
    if (location.kind != LocationKind.other) 'kind': location.kind.name,
    if (location.place.isNotEmpty) 'place': location.place,
    if (location.position != null) 'position': _position(location.position!),
    if (location.note != null) 'note': location.note,
  };

  static Map<String, dynamic> _person(Person person) => <String, dynamic>{
    'slug': person.slug,
    if (person.name.isNotEmpty) 'name': person.name,
    if (person.age != null) 'age': person.age,
    if (person.gender != null) 'gender': person.gender,
    if (person.description != null) 'description': person.description,
    if (person.locSlug != null) 'locSlug': person.locSlug,
    if (person.notes != null) 'notes': person.notes,
  };

  /// A role play, with inherited identity fields elided.
  ///
  /// The source expresses inheritance by *omission* (worked example decision 8),
  /// so a field equal to the portrayed person's value is left out and one that
  /// differs is written. Emitting the denormalized value unconditionally would
  /// still round-trip, but every decompiled role play would look like a
  /// deliberate override of every field, which is exactly the information the
  /// format is designed to carry.
  ///
  /// `staffUuid` is dropped: it is the casting to a real human (PII), stripped at
  /// publish and never authored here.
  static Map<String, dynamic> _rolePlay(RolePlay rolePlay, Station station) {
    Person? person;
    if (rolePlay.personRef != null) {
      for (final candidate in station.persons) {
        if (candidate.slug == rolePlay.personRef) {
          person = candidate;
          break;
        }
      }
    }

    final inheritedPosition = _personPosition(person, station);
    return <String, dynamic>{
      'uuid': rolePlay.uuid,
      if (rolePlay.personRef != null) 'personRef': rolePlay.personRef,
      if (person == null || rolePlay.name != person.name) 'name': rolePlay.name,
      if (rolePlay.age != null && rolePlay.age != person?.age)
        'age': rolePlay.age,
      if (rolePlay.gender != null && rolePlay.gender != person?.gender)
        'gender': rolePlay.gender,
      if (rolePlay.description != null &&
          rolePlay.description != person?.description)
        'description': rolePlay.description,
      if (rolePlay.position != null && rolePlay.position != inheritedPosition)
        'position': _position(rolePlay.position!),
      if (rolePlay.behavior != null) 'behavior': rolePlay.behavior,
      if (rolePlay.background != null) 'background': rolePlay.background,
      if (rolePlay.propsMd != null) 'props': rolePlay.propsMd,
    };
  }

  static LatLng? _personPosition(Person? person, Station station) {
    if (person?.locSlug == null) return null;
    for (final location in station.locations) {
      if (location.slug == person!.locSlug) return location.position;
    }
    return null;
  }

  static String _time(SimpleTimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  static Map<String, dynamic> _position(LatLng position) => {
    'lat': position.latitude,
    'lng': position.longitude,
  };
}
