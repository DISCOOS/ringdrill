import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/brief/field_resolver.dart'
    show ActionChipFormatter;
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/plan_additions.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/cast_picker_sheet.dart';
import 'package:ringdrill/views/widgets/cast_pill.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/face_badge_icon.dart';
import 'package:ringdrill/views/widgets/ringdrill_picker.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';
import 'package:ringdrill/views/widgets/role_mini_map.dart';
import 'package:ringdrill/views/widgets/role_number_badge.dart';
import 'package:ringdrill/views/widgets/role_position_panel.dart';
import 'package:ringdrill/views/widgets/roleplay_description_rollup.dart';
import 'package:ringdrill/views/widgets/roleplay_scope.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';
import 'package:ringdrill/views/widgets/teaching_empty_state.dart';

/// Flat list of all [RolePlay] rows across all exercises, sorted by
/// exercise order then role index. Each row uses [ExpandableTile].
///
/// The tab also carries an exercise filter (mirrors [StationListView])
/// and a cast roster button in the AppBar.
class RolePlayListView extends StatefulWidget {
  const RolePlayListView({super.key, required this.controller});

  final RolePlaysController controller;

  @override
  State<RolePlayListView> createState() => _RolePlayListViewState();
}

class _RolePlayListViewState extends State<RolePlayListView> {
  final _service = PlanService();
  StreamSubscription? _subscription;

  int? _expandedRowIndex;

  /// The effective plan-variable map (ADR-0046) at [rolePlay]'s station
  /// scope (DESIGN-008 follow-up 07): the active plan's declared values
  /// overlaid by [exercise]'s overrides, then the assigned station's, if
  /// any. Empty when there is no active plan.
  Map<String, String> _overridesFor(Exercise exercise, RolePlay rolePlay) {
    final plan = _service.activePlan;
    if (plan == null) return const {};
    final stationIndex = rolePlay.stationIndex;
    final stations = exercise.stations;
    final station = (stationIndex != null && stationIndex < stations.length)
        ? stations[stationIndex]
        : null;
    return effectivePlanVariables(
      plan,
      exercise: exercise,
      station: station,
    );
  }

  /// The station [rolePlay] is assigned to, or `null` when unassigned/out of
  /// range (mirrors `RolePlayScreen`'s own station resolution) — the tile's
  /// `StationScope` seed for Fix 5 (`{{station.*}}` resolution).
  Station? _stationFor(Exercise exercise, RolePlay rolePlay) {
    final stationIndex = rolePlay.stationIndex;
    final stations = exercise.stations;
    if (stationIndex == null ||
        stationIndex < 0 ||
        stationIndex >= stations.length) {
      return null;
    }
    return stations[stationIndex];
  }

  RolePlaysController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _subscription = _service.events.listen((_) {
      if (mounted) setState(() {});
    });
    _controller.filterExerciseUuid.addListener(_onFilterChanged);
  }

  @override
  void didUpdateWidget(covariant RolePlayListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.filterExerciseUuid.removeListener(_onFilterChanged);
      widget.controller.filterExerciseUuid.addListener(_onFilterChanged);
    }
  }

  void _onFilterChanged() {
    if (!mounted) return;
    setState(() {
      _expandedRowIndex = null;
    });
  }

  @override
  void dispose() {
    _controller.filterExerciseUuid.removeListener(_onFilterChanged);
    _subscription?.cancel();
    super.dispose();
  }

  /// Returns a flat list of `(exerciseNumber, exercise, rolePlay)` triples
  /// sorted by exercise order (1-based) then by role index.
  List<(int, Exercise, RolePlay)> _collectRows() {
    final exercises = _service.loadExercises();
    final rolePlays = _service.loadRolePlays();
    final filterUuid = _controller.filterExerciseUuid.value;
    final rows = <(int, Exercise, RolePlay)>[];
    for (var i = 0; i < exercises.length; i++) {
      final exercise = exercises[i];
      if (filterUuid != null && exercise.uuid != filterUuid) continue;
      final exerciseNumber = i + 1;
      final roles =
          rolePlays.where((rp) => rp.exerciseUuid == exercise.uuid).toList()
            ..sort((a, b) => a.index.compareTo(b.index));
      for (final rp in roles) {
        rows.add((exerciseNumber, exercise, rp));
      }
    }
    return rows;
  }

  bool get _hasAnyRole => _service.loadRolePlays().isNotEmpty;

  /// Returns the sliver content for the role rows, meant to be embedded
  /// directly in plan_view.dart's per-segment `CustomScrollView`. The
  /// exercise filter banner and the "Ny rolle" FAB are separate widgets
  /// ([RolePlaysFilterBanner], [RolePlaysCreateFab]) rendered by the host
  /// outside the scroll view — they need to stay pinned to the bottom of the
  /// segment's viewport rather than scroll with the rows.
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    // No active plan: loadRolePlays / loadExercises both return empty, so we
    // fall through to the teaching empty state below (icon + title + body) for
    // a consistent surface across all four Plan segments per DESIGN-007
    // stage 1. The create FAB stays hidden (canCreateRole is false) and the
    // filter FAB is disabled in the controller's buildActions.

    final rows = _collectRows();

    if (!_hasAnyRole) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: TeachingEmptyState(
          icon: Icons.theater_comedy,
          title: localizations.emptyRolesTitle,
          body: localizations.emptyRolesBody,
        ),
      );
    }
    if (rows.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              localizations.noRolesInExercise,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final targetNotifier = MasterDetailScope.maybeOf(context)?.target;
    Widget buildList(ContextSheetTarget? selectedTarget) {
      return SliverPadding(
        // top: 11 + ExpandableTile.margin.top (5) = 16, matching the
        // detail body's `EdgeInsets.all(16)` so the first row of master
        // and detail align in the wide layout.
        padding: const EdgeInsets.only(top: 11, bottom: 96),
        sliver: SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final (exerciseNumber, exercise, rolePlay) = rows[index];
            final isSelected =
                selectedTarget is RoleSheetTarget &&
                selectedTarget.rolePlayUuid == rolePlay.uuid;
            return _buildRoleplayRow(
              context,
              localizations,
              exerciseNumber: exerciseNumber,
              exercise: exercise,
              rolePlay: rolePlay,
              rowIndex: index,
              selected: isSelected,
            );
          },
        ),
      );
    }

    return targetNotifier == null
        ? buildList(null)
        : ValueListenableBuilder<ContextSheetTarget?>(
            valueListenable: targetNotifier,
            builder: (context, target, _) => buildList(target),
          );
  }

  /// Composite badge label for a markør: the station code plus the role's
  /// 1-based number at that station (e.g. `1.1-1`, `1a-2`). When no post is
  /// assigned yet (legacy data) the post/markør parts show as `?`.
  String _roleBadgeLabel(RolePlay rolePlay, int exerciseNumber) {
    final format =
        _service.activePlan?.stationNumberFormat ??
        StationNumberFormat.dotted;
    final stationIndex = rolePlay.stationIndex;
    final roleNumber = stationIndex == null
        ? 0
        : _service.roleNumberAtStation(rolePlay, stationIndex);
    return rolePlay.numberLabel(
      format,
      exerciseNumber: exerciseNumber,
      roleNumber: roleNumber,
    );
  }

  Widget _buildRoleplayRow(
    BuildContext context,
    AppLocalizations localizations, {
    required int exerciseNumber,
    required Exercise exercise,
    required RolePlay rolePlay,
    required int rowIndex,
    bool selected = false,
  }) {
    final expanded = _expandedRowIndex == rowIndex;
    final colorScheme = Theme.of(context).colorScheme;
    final actor = rolePlay.actorUuid != null
        ? _service.getActor(rolePlay.actorUuid!)
        : null;
    final station = _stationFor(exercise, rolePlay);

    final tile = Dismissible(
      key: ValueKey('role-row-${rolePlay.uuid}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: colorScheme.secondaryContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              localizations.roleSection,
              style: TextStyle(color: colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit, color: colorScheme.onSecondaryContainer),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _openRolePlayForm(exercise, rolePlay);
        return false;
      },
      child: ExpandableTile(
        onLongPress: () => _openRolePlayForm(exercise, rolePlay),
        selected: selected,
        leading: RoleNumberBadge(
          label: _roleBadgeLabel(rolePlay, exerciseNumber),
          highlight: actor != null,
        ),
        title: RingDrillText.plain(
          () {
            final tb = StringBuffer(rolePlay.name);
            if (rolePlay.age != null) tb.write(', ${rolePlay.age}');
            // Marker (actor) in parentheses, first name only, and only while
            // collapsed: the expanded body's cast section already names the
            // actor via "Spilles av …", so the parenthesis would be redundant.
            if (actor != null && !expanded) tb.write(' (${actor.firstName})');
            return tb.toString();
          }(),
          overrides: _overridesFor(exercise, rolePlay),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // Deliberately NOT RingDrillText: this subtitle resolves from
        // PlanService().activePlan via `_overridesFor`'s full
        // effective-value map regardless of any PlanScope ancestor (unlike
        // the role-name title above, which needs one) — see
        // roleplays_view_variables_test.dart. Only `{{var.*}}` is in scope
        // here; a `resolveScopedField` swap would make this resolve nothing
        // at all outside a PlanScope, a regression this call site's test
        // guards against.
        subtitle: Text(
          (rolePlay.stationIndex != null &&
                  rolePlay.stationIndex! < exercise.stations.length)
              ? localizations.roleSubtitleStation(
                  substitutePlanVariables(
                    exercise.stations[rolePlay.stationIndex!].numberAndName(
                      _service.activePlan?.stationNumberFormat ??
                          StationNumberFormat.dotted,
                      exerciseNumber: exerciseNumber,
                    ),
                    _overridesFor(exercise, rolePlay),
                  ),
                )
              : localizations.roleSubtitleExercise(
                  substitutePlanVariables(
                    exercise.name,
                    _overridesFor(exercise, rolePlay),
                  ),
                ),
        ),
        trailing: _buildCastAction(context, localizations, rolePlay, actor),
        expanded: expanded,
        onOpen: () => _openRolePlay(rolePlay),
        onToggle: () {
          setState(() {
            _expandedRowIndex = expanded ? null : rowIndex;
          });
        },
        body: _buildExpandedBody(
          context,
          localizations,
          exercise,
          rolePlay,
          actor,
          exerciseNumber,
        ),
      ),
    );

    // Each row is a different roleplay, so it seeds its own scopes: the
    // roleplay's own facets (so `{{roleplay.*}}` in the scenario fields
    // resolves) plus the linked station's/exercise's (so `{{station.*}}`
    // resolves), skipped for an unassigned roleplay.
    return StationScope.forStation(
      exercise: exercise,
      station: station,
      child: RoleplayScope.forRoleplay(rolePlay, child: tile),
    );
  }

  Widget _buildCastAction(
    BuildContext context,
    AppLocalizations localizations,
    RolePlay rolePlay,
    Actor? actor,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: actor != null ? localizations.editCast : localizations.addCast,
      // The actor (face) glyph: cast shows a plain face, uncast the face + plus
      // "assign an actor" affordance. person/add-person is reserved for the
      // character (a Person), not who enacts it (the actor).
      icon: actor != null
          ? Icon(Icons.face, color: scheme.primary)
          : AddFaceIcon(color: scheme.onSurfaceVariant),
      onPressed: () => _openCastPicker(rolePlay),
    );
  }

  Widget _buildExpandedBody(
    BuildContext context,
    AppLocalizations l10n,
    Exercise exercise,
    RolePlay rolePlay,
    Actor? actor,
    int exerciseNumber,
  ) {
    final station = _stationFor(exercise, rolePlay);
    // Scenario/Position/Cast, each spaced evenly via the Column's own
    // `spacing` below — no separate divider widget needed.
    final sections = <Widget>[
      RolePlayDescriptionRollup(
        exercise: exercise,
        rolePlay: rolePlay,
        station: station,
        role: AppUserRole.director,
      ),
      if (rolePlay.position != null)
        // Builder: roleContextMarkers resolves scoped fields, so it needs a
        // context inside whatever resolve scopes wrap this tile — and the
        // same post/person context pins the RolePlayScreen detail panel
        // shows must appear here too, since compact windows only ever see
        // this tile (the detail screen is a medium/expanded surface).
        Builder(
          builder: (context) {
            final overrides = _overridesFor(exercise, rolePlay);
            return RolePositionPanel(
              key: ValueKey('role-map-${rolePlay.uuid}'),
              exercise: exercise,
              rolePlay: rolePlay,
              station: station,
              overrides: overrides,
              withTitle: true,
              withBorder: true,
              mapHeight: 140,
              extraMarkers: roleContextMarkers(
                context,
                rolePlay,
                station,
                overrides: overrides,
              ).markers,
            );
          },
        ),
      _buildCastSection(context, l10n, rolePlay, actor),
    ];

    return Column(
      spacing: 8.0,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: sections,
    );
  }

  Widget _buildCastSection(
    BuildContext context,
    AppLocalizations l10n,
    RolePlay rolePlay,
    Actor? actor,
  ) {
    if (actor == null) {
      // Uncast — the same tappable cast pill the Post surfaces use.
      return CastPill(
        variant: CastPillVariant.uncast,
        label: l10n.noCastLine,
        onTap: () => _openCastPicker(rolePlay),
      );
    }
    // No `⋮` menu here (DESIGN-010 browser tile polish): edit/clear moved
    // into the marker sheet itself (CastPickerSheet), reachable from the
    // collapsed tile's cast chip regardless of expand state.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Enacted by {realName}" as the shared cast pill — tappable to
        // change/clear the actor, the same affordance as the collapsed tile's
        // face chip and the header cast icon.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            CastPill(
              variant: CastPillVariant.cast,
              label: l10n.castedByLine(actor.realName),
              onTap: () => _openCastPicker(rolePlay),
            ),
            // A full chip (copy icon and all), not plain tappable text — tap
            // dials, the icon copies (ADR-0050, DESIGN-013).
            if (actor.phone != null && actor.phone!.isNotEmpty)
              RingDrillText.rich(
                const ActionChipFormatter().phone(actor.phone!, actor.phone!),
              ),
          ],
        ),

        if (actor.notes != null && actor.notes!.isNotEmpty)
          RingDrillText.rich(actor.notes!),
      ],
    );
  }

  Future<void> _openRolePlay(RolePlay rolePlay) async {
    await ContextSheet.of(
      context,
    ).show(context, RoleSheetTarget(rolePlayUuid: rolePlay.uuid));
    if (mounted) setState(() {});
  }

  Future<void> _openRolePlayForm(Exercise exercise, RolePlay rolePlay) async {
    final localizations = AppLocalizations.of(context)!;
    final exerciseService = ExerciseService();
    if (exerciseService.isStarted) {
      final runningExercise = exerciseService.last?.exercise;
      if (runningExercise != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.stopExerciseFirst(runningExercise.name),
            ),
          ),
        );
      }
      return;
    }
    final result = await openFormSurface<RolePlayFormResult>(
      context,
      builder: (_) => RolePlayFormScreen(
        rolePlay: rolePlay,
        exercise: exercise,
        variables: _service.activePlan?.variables ?? const [],
        isExisting: true,
      ),
    );
    if (result == null || !mounted) return;
    switch (result) {
      case RolePlayFormSave(:final rolePlay, :final additions):
        await applyRolePlayAdditions(
          _service,
          localizations,
          rolePlay,
          additions,
        );
        await _service.saveRolePlay(localizations, rolePlay);
      case RolePlayFormDelete(:final rolePlay):
        await _service.deleteRolePlay(rolePlay.uuid);
    }
    if (mounted) setState(() {});
  }

  // Select/clear/edit/add all live in the marker sheet itself now
  // (CastPickerSheet, DESIGN-010 browser tile polish) — this just opens it
  // and applies the resulting select-or-clear choice via the shared helper.
  Future<void> _openCastPicker(RolePlay rolePlay) async {
    final localizations = AppLocalizations.of(context)!;
    await openCastPickerAndApply(context, localizations, rolePlay);
    if (mounted) setState(() {});
  }
}

// ---------------------------------------------------------------------------
// Fixed banner and FAB — rendered by plan_view.dart as siblings of the
// Script segment's `CustomScrollView` (not inside it) so they stay pinned to
// the viewport instead of scrolling with the rows. Mirrors StationFilterBanner
// / the retired station filter-FAB layout.
// ---------------------------------------------------------------------------

/// Fixed banner shown below the Script tab's scroll view while filtered to
/// one exercise. Renders nothing when no filter is active, or if the
/// filtered exercise has since been deleted.
class RolePlaysFilterBanner extends StatelessWidget {
  const RolePlaysFilterBanner({super.key, required this.controller});

  final RolePlaysController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: controller.filterExerciseUuid,
      builder: (context, uuid, _) {
        final exercise = uuid == null
            ? null
            : PlanService().getExercise(uuid);
        if (exercise == null) return const SizedBox.shrink();
        final localizations = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        return Material(
          color: theme.colorScheme.secondaryContainer,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_alt,
                    size: 18,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RingDrillText.plain(
                      localizations.showingRolesIn(exercise.name),
                      overrides: PlanService().activePlan == null
                          ? const {}
                          : effectivePlanVariables(
                              PlanService().activePlan!,
                              exercise: exercise,
                            ),
                      style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => controller.filterExerciseUuid.value = null,
                    child: Text(localizations.showAllRoles),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "Ny rolle" FAB for the Script tab, floating above whatever is rendered
/// below it in plan_view.dart's layout (the filter banner, when present).
/// Hidden when there is no active plan or no exercises to attach a role
/// to, matching the previous `canCreateRole` gate.
class RolePlaysCreateFab extends StatelessWidget {
  const RolePlaysCreateFab({super.key, required this.controller});

  final RolePlaysController controller;

  @override
  Widget build(BuildContext context) {
    final canCreateRole = PlanService().loadExercises().isNotEmpty;
    if (PlanService().activePlanUuid == null || !canCreateRole) {
      return const SizedBox.shrink();
    }
    final localizations = AppLocalizations.of(context)!;
    return Positioned(
      right: 16,
      bottom: 16,
      child: WindowSizeClass.of(context) == WindowSizeClass.compact
          ? FloatingActionButton(
              heroTag: null,
              tooltip: localizations.newPlay,
              onPressed: () => controller.openCreateRolePlay(context),
              child: const Icon(Icons.add),
            )
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => controller.openCreateRolePlay(context),
              icon: const Icon(Icons.add),
              label: Text(localizations.newPlay),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Owns the current exercise filter selection for the RolePlays tab.
/// Mirrors [StationListController] in structure.
class RolePlaysController extends ScreenController {
  RolePlaysController();

  final ValueNotifier<String?> filterExerciseUuid = ValueNotifier<String?>(
    null,
  );

  void dispose() {
    filterExerciseUuid.dispose();
  }

  @override
  String title(BuildContext context) =>
      AppLocalizations.of(context)!.rolePlaysTab;

  // "Ny rolle" is rendered as a FAB inside RolePlayListView's body (above the
  // filter banner) rather than a Scaffold FAB, so the banner pushes it up
  // instead of covering it. The create flow stays here.
  Future<void> openCreateRolePlay(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final service = PlanService();
    final exercises = service.loadExercises();

    // No exercises yet — nothing to attach a role to.
    if (exercises.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(localizations.noExercisesYet)));
      return;
    }

    // Pick the exercise to create the role in — adaptive picker (ADR-0049):
    // bottom sheet on compact, dialog on medium/expanded.
    final exerciseFormat =
        service.activePlan?.exerciseNumberFormat ??
        ExerciseNumberFormat.hash;
    final exercise = await showRingdrillPicker<Exercise>(
      context: context,
      title: localizations.pickExerciseForRole,
      items: exercises,
      itemBuilder: (context, ex, onTap) {
        final index = exercises.indexWhere((e) => e.uuid == ex.uuid);
        return ListTile(
          leading: ExerciseNumberBadge(
            label: Numbering.exercise(exerciseFormat, index + 1),
            size: 36,
          ),
          title: Text(ex.name),
          onTap: onTap,
        );
      },
      searchText: (ex) => ex.name,
      searchHint: localizations.pickerSearchHint,
    );
    if (exercise == null || !context.mounted) return;

    // Build a blank draft with the next available index.
    final existingCount = service
        .loadRolePlays()
        .where((r) => r.exerciseUuid == exercise.uuid)
        .length;
    final draft = RolePlay(
      uuid: nanoid(10),
      index: existingCount,
      exerciseUuid: exercise.uuid,
      name: '',
    );

    final result = await openFormSurface<RolePlayFormResult>(
      context,
      builder: (_) => RolePlayFormScreen(
        rolePlay: draft,
        exercise: exercise,
        variables: service.activePlan?.variables ?? const [],
      ),
    );
    // A fresh draft has no delete affordance, so only a save (or cancel) here.
    if (result is! RolePlayFormSave || !context.mounted) return;
    await applyRolePlayAdditions(
      service,
      localizations,
      result.rolePlay,
      result.additions,
    );
    await service.saveRolePlay(localizations, result.rolePlay);
  }

  @override
  List<Widget>? buildActions(BuildContext context, BoxConstraints constraints) {
    final localizations = AppLocalizations.of(context)!;
    final hasActivePlan = PlanService().activePlanUuid != null;
    return [
      // Filter by exercise — moved from the body FAB to the AppBar.
      // The cast-roster action (Icons.recent_actors) that used to live here
      // was retired once the Roster tab became the actor registry's home;
      // the per-role cast picker stays on each role.
      ValueListenableBuilder<String?>(
        valueListenable: filterExerciseUuid,
        builder: (context, active, _) {
          final button = IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: localizations.selectExercises,
            onPressed: hasActivePlan ? () => openFilterSheet(context) : null,
          );
          if (active == null) return button;
          return Badge.count(count: 1, child: button);
        },
      ),
    ];
  }

  Future<void> openFilterSheet(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final plan = PlanService().activePlan;
    final exercises = PlanService().loadExercises();
    final exerciseFormat =
        plan?.exerciseNumberFormat ?? ExerciseNumberFormat.hash;
    final current = filterExerciseUuid.value;
    // "All exercises" first, then one choice per exercise. Adaptive picker
    // (ADR-0049): bottom sheet on compact, dialog on medium/expanded. Tap
    // applies the filter (a check marks the active one) — no radios.
    final choices = <_FilterChoice>[
      const _FilterChoice.all(),
      for (final ex in exercises) _FilterChoice.one(ex.uuid),
    ];
    final selected = await showRingdrillPicker<_FilterChoice>(
      context: context,
      title: localizations.pickerFilterByExerciseTitle,
      items: choices,
      itemBuilder: (context, choice, onTap) {
        final theme = Theme.of(context);
        final isActive = choice.uuid == current;
        final check = isActive
            ? Icon(Icons.check, color: theme.colorScheme.primary)
            : null;
        if (choice.uuid == null) {
          return ListTile(
            leading: const Icon(Icons.clear_all),
            title: Text(localizations.allExercises),
            trailing: check,
            onTap: onTap,
          );
        }
        final index = exercises.indexWhere((e) => e.uuid == choice.uuid);
        return ListTile(
          leading: ExerciseNumberBadge(
            label: Numbering.exercise(exerciseFormat, index + 1),
            size: 36,
          ),
          title: Text(exercises[index].name),
          trailing: check,
          onTap: onTap,
        );
      },
      searchText: (choice) => choice.uuid == null
          ? localizations.allExercises
          : exercises.firstWhere((e) => e.uuid == choice.uuid).name,
      searchHint: localizations.pickerSearchHint,
    );
    if (selected != null) {
      filterExerciseUuid.value = selected.uuid;
    }
  }
}

class _FilterChoice {
  final String? uuid;
  const _FilterChoice.all() : uuid = null;
  const _FilterChoice.one(String this.uuid);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _FilterChoice && other.uuid == uuid;

  @override
  int get hashCode => uuid.hashCode;
}
