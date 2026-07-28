import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/drill_player/player_mode.dart';
import 'package:ringdrill/views/drill_player/player_targets.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/ringdrill_picker.dart';
import 'package:ringdrill/views/widgets/role_number_badge.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:ringdrill/views/widgets/team_number_badge.dart';

/// The drill player's navigator: every target reachable from where the player is
/// now, grouped by kind (ADR-0056).
///
/// It started as a *within-mode* selector — siblings of the current kind only,
/// with the parent exercise pinned on top as the one way back up. That made
/// moving between kinds a two-step trip (up to the exercise, then down again),
/// and the pinned row existed solely to work around it. Listing every group
/// instead puts any target one tap away and retires the special row: the parent
/// exercise is simply a member of the exercise group.
///
/// Scope: **all** exercises in the plan, and the *current* exercise's stations,
/// roleplays and teams. A station belongs to one exercise, so listing every
/// exercise's posts would bury the ones being run; picking another exercise
/// re-scopes the list on the next open.
///
/// [mode] identifies what is showing now, so it can be marked and made a no-op.
///
/// While an exercise is **running**, the exercise group holds only that one. This
/// is where the "cannot switch the live exercise" rule lives now: the mini bar
/// used to enforce it by refusing to open at all in exercise mode, which also
/// blocked navigating *within* the running exercise — the one thing the player
/// exists for. Omitting the others rather than disabling them keeps the list
/// short and every row actionable, which matters most in the situation this
/// picker is used in.
///
/// Returns the picked target, or null when the user dismissed the picker or
/// re-picked what was already showing.
Future<ContextSheetTarget?> showPlayerTargetPicker(
  BuildContext context, {
  required PlayerMode mode,
  required Exercise exercise,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final plan = PlanService().activePlan;
  // Non-null only while a session is live: the exercise the player must stay on,
  // and then the only one listed. Shared with the swipe pager, so widening one
  // surface cannot become a way around the rule.
  final lockedTo = lockedExerciseUuid();
  final entries = <_Entry>[
    ..._exerciseEntries(
      l10n,
      plan: plan,
      current: exercise,
      mode: mode,
      lockedTo: lockedTo,
    ),
    ..._stationEntries(l10n, plan: plan, exercise: exercise, mode: mode),
    ..._roleEntries(l10n, plan: plan, exercise: exercise, mode: mode),
    ..._teamEntries(l10n, plan: plan, exercise: exercise, mode: mode),
  ];

  final picked = await showRingdrillPicker<_Entry>(
    context: context,
    title: l10n.pickerGoToTitle,
    items: entries,
    sectionLabel: (entry) => entry.group,
    itemBuilder: (context, entry, onTap) {
      final theme = Theme.of(context);
      return ListTile(
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
        // Re-picking what is already showing closes without navigating, so the
        // host is only ever called with a real change.
        onTap: entry.isCurrent ? () => Navigator.of(context).pop() : onTap,
      );
    },
    // The badge label and group name are searchable alongside the title, so a
    // number reaches its row directly ("1.2", "1.2-1", "#2") and a kind name
    // ("post", "lag") narrows to that group. Operators know their posts and
    // markers by number, which is exactly what the row shows.
    searchText: (entry) => '${entry.label} ${entry.group} ${entry.title}',
    searchHint: l10n.pickerSearchHint,
  );
  return picked?.target;
}

/// One picker row. A private record rather than a bare [ContextSheetTarget]
/// list: the badge, label, group and current-ness are all derived from the
/// underlying object, and deriving them where that object is still in hand keeps
/// the row builder from re-looking-up (and re-guarding) each target.
class _Entry {
  const _Entry({
    required this.target,
    required this.group,
    required this.label,
    required this.badge,
    required this.title,
    required this.isCurrent,
    this.subtitle,
  });

  final ContextSheetTarget target;

  /// Section header text. Reuses the Plan tab's own segment labels, since those
  /// are the names the user already navigates by.
  final String group;

  /// The badge's formatted number (`#1`, `1.2`, `1.2-1`, `1`) — held as text so
  /// search can match it, since the badge itself is an opaque widget.
  final String label;

  final Widget badge;
  final String title;
  final String? subtitle;
  final bool isCurrent;
}

List<_Entry> _exerciseEntries(
  AppLocalizations l10n, {
  required Plan? plan,
  required Exercise current,
  required PlayerMode mode,
  required String? lockedTo,
}) {
  final format = plan?.exerciseNumberFormat ?? ExerciseNumberFormat.hash;
  final exercises = plan?.exercises ?? const <Exercise>[];
  final group = l10n.exercise(2);
  return [
    for (final (index, exercise) in exercises.indexed)
      if (lockedTo == null || exercise.uuid == lockedTo)
        _Entry(
          target: ExerciseSheetTarget(exerciseUuid: exercise.uuid),
          group: group,
          label: Numbering.exercise(format, index + 1),
          badge: ExerciseNumberBadge(
            label: Numbering.exercise(format, index + 1),
            highlight: _isCurrentExercise(mode, exercise, current),
          ),
          title: _resolve(plan, exercise, exercise.name),
          subtitle:
              '${exercise.startTime.toMaterial().formal()} – '
              '${exercise.endTime.toMaterial().formal()}',
          isCurrent: _isCurrentExercise(mode, exercise, current),
        ),
  ];
}

/// Only in exercise mode is an exercise row the *current target*. From a
/// station, roleplay or team, the parent exercise is somewhere to go, not where
/// you are — marking it would claim the wrong thing is showing.
bool _isCurrentExercise(PlayerMode mode, Exercise exercise, Exercise current) =>
    mode is ExercisePlayerMode && exercise.uuid == current.uuid;

List<_Entry> _stationEntries(
  AppLocalizations l10n, {
  required Plan? plan,
  required Exercise exercise,
  required PlayerMode mode,
}) {
  final format = plan?.stationNumberFormat ?? StationNumberFormat.dotted;
  final exerciseNumber = _exerciseNumber(exercise);
  final currentIndex = mode is StationPlayerMode ? mode.stationIndex : null;
  final group = l10n.stationsTab;
  return [
    for (final station in exercise.stations)
      _Entry(
        target: StationSheetTarget(
          exerciseUuid: exercise.uuid,
          stationIndex: station.index,
        ),
        group: group,
        label: station.numberLabel(format, exerciseNumber: exerciseNumber),
        badge: StationNumberBadge(
          label: station.numberLabel(format, exerciseNumber: exerciseNumber),
          highlight: station.index == currentIndex,
        ),
        title: _resolve(plan, exercise, station.name),
        isCurrent: station.index == currentIndex,
      ),
  ];
}

List<_Entry> _roleEntries(
  AppLocalizations l10n, {
  required Plan? plan,
  required Exercise exercise,
  required PlayerMode mode,
}) {
  final service = PlanService();
  final format = plan?.stationNumberFormat ?? StationNumberFormat.dotted;
  final exerciseNumber = _exerciseNumber(exercise);
  final currentUuid = mode is RolePlayerMode ? mode.rolePlayUuid : null;
  final group = l10n.scriptSegment;
  // Shared accessor, so this group's order and the swipe pager's sibling
  // sequence cannot drift — a swipe must land on the row the picker lists next.
  final roles = service.rolePlaysOf(exercise.uuid);
  return [
    for (final role in roles)
      _Entry(
        target: RoleSheetTarget(rolePlayUuid: role.uuid),
        group: group,
        label: service.roleLabel(
          role,
          format: format,
          exerciseNumber: exerciseNumber,
        ),
        badge: RoleNumberBadge(
          label: service.roleLabel(
            role,
            format: format,
            exerciseNumber: exerciseNumber,
          ),
          highlight: role.uuid == currentUuid,
        ),
        title: _resolve(plan, exercise, role.name),
        subtitle: _stationNameFor(plan, exercise, role.stationIndex),
        isCurrent: role.uuid == currentUuid,
      ),
  ];
}

/// The teams that rotate through this exercise.
///
/// Bounded by `Exercise.numberOfTeams`, not by the plan's roster: the roster can
/// hold more teams than a given exercise runs, and `PlanService.ensureTeams`
/// guarantees a Team exists for every index below that bound.
List<_Entry> _teamEntries(
  AppLocalizations l10n, {
  required Plan? plan,
  required Exercise exercise,
  required PlayerMode mode,
}) {
  final service = PlanService();
  final currentIndex = mode is TeamPlayerMode ? mode.teamIndex : null;
  final group = l10n.team(2);
  final fallback = l10n.team(1);
  return [
    for (var index = 0; index < exercise.numberOfTeams; index++)
      _Entry(
        target: TeamSheetTarget(exerciseUuid: exercise.uuid, teamIndex: index),
        group: group,
        label: Numbering.team(index + 1),
        badge: TeamNumberBadge(
          label: Numbering.team(index + 1),
          highlight: index == currentIndex,
        ),
        // Teams carry a name, so unlike the other kinds the badge's number is
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

/// 1-based, and 0 when the exercise is not in the active plan (see
/// `PlanService.getExerciseNumber`) — clamped so a badge never reads "0.1".
int _exerciseNumber(Exercise exercise) =>
    PlanService().getExerciseNumber(exercise.uuid).clamp(1, 1 << 30);

/// The post a markør is placed at, as a row subtitle — the group lists every
/// markør in the exercise, so which post each belongs to is the one piece of
/// context that makes it navigable. Null when unassigned.
String? _stationNameFor(Plan? plan, Exercise exercise, int? stationIndex) {
  if (stationIndex == null ||
      stationIndex < 0 ||
      stationIndex >= exercise.stations.length) {
    return null;
  }
  return _resolve(plan, exercise, exercise.stations[stationIndex].name);
}

/// Names may carry `{{var.*}}` tokens. Resolves them the way the exercise picker
/// does — plan variables only. A picker row is not a scope host, so
/// `{{station.*}}` / `{{exercise.*}}` are deliberately out of reach here; the
/// surfaces that own those scopes render them.
String _resolve(Plan? plan, Exercise exercise, String text) {
  if (plan == null) return text;
  return substitutePlanVariables(
    text,
    effectivePlanVariables(plan, exercise: exercise),
  );
}
