import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';

/// Write-back payload an editor returns alongside its own edited entity, for
/// additions created inline (the `/`/`{{` picker's "Create …" entries) whose
/// *owner* the editor does not itself hold (ADR-0047, DESIGN-009 follow-up
/// 4): new plan variables belong to `Program`; new locations/persons belong
/// to a target station; a new or edited roleplay authored inline from the
/// post editor's Persons section (DESIGN-009 prompt 4j) belongs to the
/// plan's roleplay registry, not the station. The station editor owns its
/// own locations/persons directly (adds them straight to its working
/// list, see `StationFormScreen`), so it only ever populates `variables`
/// and (since prompt 4j) `rolePlays` here; only the roleplay editor — which
/// edits a `RolePlay` but references its linked station's scenario data —
/// ever populates `stationLocations`/`stationPersons`.
///
/// A Dart 3 named record, not a bespoke `EntityEditResult<T>` class, per
/// ADR-0047's "one mechanism for all three kinds, not a class per editor"
/// call. The caller that owns the plan (an `openFormSurface` call site)
/// applies the entity change and this payload atomically — see
/// [applyVariableAdditions]/[applyStationAdditions]/
/// [applyPendingRolePlayAdditions].
typedef PlanAdditions = ({
  List<DrillVariable> variables,
  List<Location> stationLocations,
  List<Person> stationPersons,
  List<RolePlay> rolePlays,
});

/// No pending additions — every editor starts here and only grows this as
/// the author creates entities inline this session.
const PlanAdditions noPlanAdditions = (
  variables: <DrillVariable>[],
  stationLocations: <Location>[],
  stationPersons: <Person>[],
  rolePlays: <RolePlay>[],
);

/// [PlanAdditions] for an editor that never populates `stationLocations`/
/// `stationPersons` (a station owns those directly and has no need to
/// write them back to itself) — Exercise always, Station since it can now
/// also carry [rolePlays] authored inline from its own Persons section
/// (DESIGN-009 prompt 4j).
PlanAdditions variableAdditions(
  List<DrillVariable> variables, {
  List<RolePlay> rolePlays = const <RolePlay>[],
}) => (
  variables: variables,
  stationLocations: const <Location>[],
  stationPersons: const <Person>[],
  rolePlays: rolePlays,
);

/// Applies [additions.variables] to [program], skipping any name already
/// declared. Defensive: an editor's own inline-create already checks this
/// locally against what *it* has declared/seen, but the plan owner is the
/// single point where every sub-editor's session ultimately lands, so a
/// name that became declared through some other path in the meantime must
/// not be duplicated.
Program applyVariableAdditions(Program program, PlanAdditions additions) {
  if (additions.variables.isEmpty) return program;
  final existing = program.variables.map((v) => v.name).toSet();
  final toAdd = [
    for (final v in additions.variables)
      if (!existing.contains(v.name)) v,
  ];
  if (toAdd.isEmpty) return program;
  return program.copyWith(variables: [...program.variables, ...toAdd]);
}

/// Applies [additions.stationLocations]/[stationPersons] to [station] — the
/// write-back target for entities created inline from a `RolePlayFormScreen`
/// field, whose station it does not itself own (ADR-0047). Same
/// already-exists defensiveness as [applyVariableAdditions].
Station applyStationAdditions(Station station, PlanAdditions additions) {
  if (additions.stationLocations.isEmpty && additions.stationPersons.isEmpty) {
    return station;
  }
  final existingLocs = station.locations.map((l) => l.slug).toSet();
  final existingPersons = station.persons.map((p) => p.slug).toSet();
  return station.copyWith(
    locations: [
      ...station.locations,
      ...additions.stationLocations.where(
        (l) => !existingLocs.contains(l.slug),
      ),
    ],
    persons: [
      ...station.persons,
      ...additions.stationPersons.where(
        (p) => !existingPersons.contains(p.slug),
      ),
    ],
  );
}

/// Applies [additions.variables] to [service]'s active program and persists
/// it — the common `openFormSurface` call-site shape for Exercise/Station
/// editors' write-back. A no-op when there is nothing to add or (should it
/// ever happen) there is no active program.
Future<void> applyVariableAdditionsToActiveProgram(
  ProgramService service,
  PlanAdditions additions,
) async {
  if (additions.variables.isEmpty) return;
  final program = service.activeProgram;
  if (program == null) return;
  await service.replaceProgram(applyVariableAdditions(program, additions));
}

/// Applies [additions.stationLocations]/[stationPersons] to the station at
/// list position [stationIndex] within the exercise [exerciseUuid] names
/// (the same "raw position in `exercise.stations`" convention
/// `RolePlayFormScreen._parentStation` itself uses for `RolePlay.stationIndex`
/// — not `Station.index`), and persists the exercise. The write-back target
/// for a `RolePlayFormScreen` session's inline-created entities (ADR-0047).
/// A no-op when there is nothing to add or the exercise/station can no
/// longer be found (e.g. deleted concurrently — defensive, not expected in
/// normal use).
Future<void> applyStationAdditionsTo(
  ProgramService service,
  AppLocalizations l10n, {
  required String exerciseUuid,
  required int? stationIndex,
  required PlanAdditions additions,
}) async {
  if (additions.stationLocations.isEmpty && additions.stationPersons.isEmpty) {
    return;
  }
  if (stationIndex == null) return;
  final exercise = service.getExercise(exerciseUuid);
  if (exercise == null) return;
  if (stationIndex < 0 || stationIndex >= exercise.stations.length) return;
  final stations = [...exercise.stations];
  stations[stationIndex] = applyStationAdditions(
    stations[stationIndex],
    additions,
  );
  await service.saveExercise(l10n, exercise.copyWith(stations: stations));
}

/// A `RolePlayFormScreen` session's full write-back (ADR-0047, DESIGN-009
/// follow-up 4): new plan variables to the active program, and new station
/// locations/persons to [rolePlay]'s own linked station — the common
/// `openFormSurface` call-site shape, combining
/// [applyVariableAdditionsToActiveProgram] and [applyStationAdditionsTo].
Future<void> applyRolePlayAdditions(
  ProgramService service,
  AppLocalizations l10n,
  RolePlay rolePlay,
  PlanAdditions additions,
) async {
  await applyVariableAdditionsToActiveProgram(service, additions);
  await applyStationAdditionsTo(
    service,
    l10n,
    exerciseUuid: rolePlay.exerciseUuid,
    stationIndex: rolePlay.stationIndex,
    additions: additions,
  );
}

/// Persists [additions.rolePlays] via [ProgramService.saveRolePlay]
/// (DESIGN-009 prompt 4j) — the write-back target for a marker authored
/// inline from the post editor's Persons section ("Legg til markør" /
/// re-opening an existing one): unlike a station's own locations/persons, a
/// `RolePlay` is not nested inside `Station`/`Program`, so each one is
/// saved directly through the repo, the same as any other roleplay edit —
/// held in the post editor's own working copy until this call, so an
/// aborted post edit never leaves a half-saved marker on disk. A no-op
/// when there is nothing to add.
Future<void> applyPendingRolePlayAdditions(
  ProgramService service,
  AppLocalizations l10n,
  PlanAdditions additions,
) async {
  for (final rolePlay in additions.rolePlays) {
    await service.saveRolePlay(l10n, rolePlay);
  }
}
