import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/drill_player/exercise_picker_sheet.dart';
import 'package:ringdrill/views/drill_player/player_mode.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/ringdrill_picker.dart';
import 'package:ringdrill/views/widgets/role_number_badge.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:ringdrill/views/widgets/team_number_badge.dart';

/// The mini bar's badge picker, scoped to the player's current [PlayerMode]
/// (ADR-0056): exercises in exercise mode, and the current exercise's stations,
/// roleplays or teams in the other three.
///
/// The badge is a *within-mode* selector — switching modes happens by tapping
/// content (a station row inside the exercise view enters station mode). The
/// one exception is going back *up*: since X always closes the player rather
/// than unwinding a history, every non-exercise picker opens with the parent
/// exercise pinned as its first row, carrying its own exercise badge above a
/// divider. The rest of the list stays purely siblings.
///
/// Returns the picked target, or null when the user dismissed the picker or
/// re-picked what was already showing.
Future<ContextSheetTarget?> showPlayerTargetPicker(
  BuildContext context, {
  required PlayerMode mode,
  required Exercise exercise,
}) async {
  switch (mode) {
    case ExercisePlayerMode():
      // Exercise mode has no parent to pin and an existing picker that already
      // renders exercise rows (with start/end times and variable-resolved
      // names). Reuse it rather than duplicating that row.
      final picked = await showExercisePickerSheet(context, current: exercise);
      if (picked == null) return null;
      return ExerciseSheetTarget(exerciseUuid: picked.uuid);
    case StationPlayerMode(:final stationIndex):
      return _showScopedPicker(
        context,
        exercise: exercise,
        title: AppLocalizations.of(context)!.pickerSelectStationTitle,
        siblings: (plan, exerciseNumber) => _stationEntries(
          plan: plan,
          exercise: exercise,
          exerciseNumber: exerciseNumber,
          currentIndex: stationIndex,
        ),
      );
    case RolePlayerMode(:final rolePlayUuid):
      return _showScopedPicker(
        context,
        exercise: exercise,
        title: AppLocalizations.of(context)!.pickerSelectRoleTitle,
        siblings: (plan, exerciseNumber) => _roleEntries(
          plan: plan,
          exercise: exercise,
          exerciseNumber: exerciseNumber,
          currentUuid: rolePlayUuid,
        ),
      );
    case TeamPlayerMode(:final teamIndex):
      return _showScopedPicker(
        context,
        exercise: exercise,
        title: AppLocalizations.of(context)!.pickerSelectTeamTitle,
        siblings: (plan, exerciseNumber) => _teamEntries(
          context,
          plan: plan,
          exercise: exercise,
          currentIndex: teamIndex,
        ),
      );
  }
}

/// One picker row. A private record rather than a bare [ContextSheetTarget]
/// list: the badge, label and current-ness are all derived from the underlying
/// object, and deriving them here — where that object is still in hand — keeps
/// the row builder from re-looking-up (and re-guarding) each target.
class _Entry {
  const _Entry({
    required this.target,
    required this.badge,
    required this.title,
    required this.isCurrent,
    this.subtitle,
    this.isParent = false,
  });

  final ContextSheetTarget target;
  final Widget badge;
  final String title;
  final String? subtitle;
  final bool isCurrent;

  /// The pinned parent-exercise row: the way *up* out of a station, roleplay or
  /// team mode. Rendered above a divider so the list below reads as siblings.
  final bool isParent;
}

typedef _SiblingBuilder = List<_Entry> Function(Plan? plan, int exerciseNumber);

Future<ContextSheetTarget?> _showScopedPicker(
  BuildContext context, {
  required Exercise exercise,
  required String title,
  required _SiblingBuilder siblings,
}) async {
  final service = PlanService();
  final plan = service.activePlan;
  // 1-based, and 0 when the exercise is not in the active plan (see
  // PlanService.getExerciseNumber) — clamp so the badge never reads "#0".
  final exerciseNumber = service
      .getExerciseNumber(exercise.uuid)
      .clamp(1, 1 << 30);
  final entries = <_Entry>[
    _parentEntry(
      plan: plan,
      exercise: exercise,
      exerciseNumber: exerciseNumber,
    ),
    ...siblings(plan, exerciseNumber),
  ];

  final picked = await showRingdrillPicker<_Entry>(
    context: context,
    title: title,
    items: entries,
    itemBuilder: (context, entry, onTap) {
      final theme = Theme.of(context);
      final tile = ListTile(
        leading: entry.badge,
        title: Text(
          entry.title,
          style: TextStyle(
            fontWeight: entry.isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: entry.subtitle == null ? null : Text(entry.subtitle!),
        trailing: entry.isCurrent
            ? Icon(Icons.check, color: theme.colorScheme.primary)
            : null,
        // Re-picking what is already showing is a no-op, matching
        // showExercisePickerSheet.
        onTap: entry.isCurrent ? () => Navigator.of(context).pop() : onTap,
      );
      if (!entry.isParent) return tile;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [tile, const Divider(height: 1)],
      );
    },
    searchText: (entry) => entry.title,
    searchHint: AppLocalizations.of(context)!.pickerSearchHint,
  );
  return picked?.target;
}

_Entry _parentEntry({
  required Plan? plan,
  required Exercise exercise,
  required int exerciseNumber,
}) {
  return _Entry(
    target: ExerciseSheetTarget(exerciseUuid: exercise.uuid),
    badge: ExerciseNumberBadge(
      label: Numbering.exercise(
        plan?.exerciseNumberFormat ?? ExerciseNumberFormat.hash,
        exerciseNumber,
      ),
    ),
    title: _resolve(plan, exercise, exercise.name),
    isCurrent: false,
    isParent: true,
  );
}

List<_Entry> _stationEntries({
  required Plan? plan,
  required Exercise exercise,
  required int exerciseNumber,
  required int currentIndex,
}) {
  final format = plan?.stationNumberFormat ?? StationNumberFormat.dotted;
  return [
    for (final station in exercise.stations)
      _Entry(
        target: StationSheetTarget(
          exerciseUuid: exercise.uuid,
          stationIndex: station.index,
        ),
        badge: StationNumberBadge(
          label: station.numberLabel(format, exerciseNumber: exerciseNumber),
          highlight: station.index == currentIndex,
        ),
        title: _resolve(plan, exercise, station.name),
        isCurrent: station.index == currentIndex,
      ),
  ];
}

List<_Entry> _roleEntries({
  required Plan? plan,
  required Exercise exercise,
  required int exerciseNumber,
  required String currentUuid,
}) {
  final service = PlanService();
  final format = plan?.stationNumberFormat ?? StationNumberFormat.dotted;
  // There is no per-exercise roleplay accessor; filter the flat list, then
  // order by the roleplay's own ordinal so the picker matches the Markører
  // list.
  final roles =
      service
          .loadRolePlays()
          .where((r) => r.exerciseUuid == exercise.uuid)
          .toList()
        ..sort((a, b) => a.index.compareTo(b.index));
  return [
    for (final role in roles)
      _Entry(
        target: RoleSheetTarget(rolePlayUuid: role.uuid),
        badge: RoleNumberBadge(
          label: service.roleLabel(
            role,
            format: format,
            exerciseNumber: exerciseNumber,
          ),
          highlight: role.uuid == currentUuid,
        ),
        title: _resolve(plan, exercise, role.name),
        subtitle: _stationNameFor(plan, exercise, role),
        isCurrent: role.uuid == currentUuid,
      ),
  ];
}

/// The teams that rotate through this exercise.
///
/// Bounded by `Exercise.numberOfTeams`, not by the plan's roster: the roster can
/// hold more teams than a given exercise runs (a team not in this exercise has no
/// rotation to show), and `PlanService.ensureTeams` guarantees a Team exists for
/// every index below that bound.
List<_Entry> _teamEntries(
  BuildContext context, {
  required Plan? plan,
  required Exercise exercise,
  required int currentIndex,
}) {
  final service = PlanService();
  final fallback = AppLocalizations.of(context)!.team(1);
  return [
    for (var index = 0; index < exercise.numberOfTeams; index++)
      _Entry(
        target: TeamSheetTarget(exerciseUuid: exercise.uuid, teamIndex: index),
        badge: TeamNumberBadge(
          label: Numbering.team(index + 1),
          highlight: index == currentIndex,
        ),
        // Teams carry a name, so unlike the other modes the badge's number is
        // not the whole label — mirrors TeamExerciseScreen's own AppBar title.
        title: _resolve(
          plan,
          exercise,
          service.getTeam(index)?.name ?? '$fallback ${index + 1}',
        ),
        isCurrent: index == currentIndex,
      ),
  ];
}

/// The post a markør is placed at, as a row subtitle — the picker lists every
/// markør in the exercise, so which post each belongs to is the one piece of
/// context that makes the list navigable. Null when unassigned.
String? _stationNameFor(Plan? plan, Exercise exercise, RolePlay role) {
  final index = role.stationIndex;
  if (index == null || index < 0 || index >= exercise.stations.length) {
    return null;
  }
  return _resolve(plan, exercise, exercise.stations[index].name);
}

/// Names may carry `{{var.*}}` tokens. Resolves them the way
/// [showExercisePickerSheet] does — plan variables only. A picker row is not a
/// scope host, so `{{station.*}}` / `{{exercise.*}}` are deliberately out of
/// reach here; the surfaces that own those scopes render them.
String _resolve(Plan? plan, Exercise exercise, String text) {
  if (plan == null) return text;
  return substitutePlanVariables(
    text,
    effectivePlanVariables(plan, exercise: exercise),
  );
}
