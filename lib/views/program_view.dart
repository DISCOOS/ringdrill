import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/theme.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/program_form_screen.dart';
import 'package:ringdrill/views/roleplays_view.dart';
import 'package:ringdrill/views/shared_file_widget.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/drill_player_sheet.dart';
import 'package:ringdrill/views/widgets/exercise_mini_map.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';
import 'package:ringdrill/views/widgets/reorderable_section.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:ringdrill/views/widgets/station_role_summary.dart';
import 'package:ringdrill/views/widgets/start_here_pill.dart';
import 'package:ringdrill/views/widgets/teaching_empty_state.dart';

import 'exercise_form_screen.dart';

export 'package:ringdrill/web/program_page_controller.dart'
    if (dart.library.io) 'program_page_controller.dart';

enum ProgramSegment { exercises, stations, script, teams }

/// URL slug for a [ProgramSegment]. Mirrors the constants in
/// [app_routes.dart] and is used by the segment switcher and the router
/// redirect gate (ADR-0032 *Activation contract*).
extension ProgramSegmentUrl on ProgramSegment {
  String get urlSlug => switch (this) {
    ProgramSegment.exercises => programSegmentExercisesSlug,
    ProgramSegment.stations => programSegmentStationsSlug,
    ProgramSegment.script => programSegmentScriptSlug,
    ProgramSegment.teams => programSegmentTeamsSlug,
  };
}

/// Inverse of [ProgramSegmentUrl.urlSlug]. Returns `null` for unknown
/// slugs so the redirect gate can fall back to the default segment.
ProgramSegment? programSegmentFromSlug(String slug) => switch (slug) {
  programSegmentExercisesSlug => ProgramSegment.exercises,
  programSegmentStationsSlug => ProgramSegment.stations,
  programSegmentScriptSlug => ProgramSegment.script,
  programSegmentTeamsSlug => ProgramSegment.teams,
  _ => null,
};

enum _SortAction { byStartTime, alphabetically }

class ProgramView extends StatefulWidget {
  const ProgramView({
    super.key,
    required this.controller,
    required this.stationListController,
    required this.rolePlaysController,
  });

  final ProgramPageControllerBase controller;
  final StationListController stationListController;
  final RolePlaysController rolePlaysController;

  @override
  State<ProgramView> createState() => _ProgramViewState();
}

class _ProgramViewState extends State<ProgramView> {
  final _programService = ProgramService();
  final List<StreamSubscription> _subscriptions = [];
  List<Exercise> _exercises = [];
  ExerciseEvent? _liveEvent;
  String? _expandedExerciseUuid;
  // The collapsing overview hides while the active segment list scrolls down
  // and reappears on scroll up. The switcher stays pinned as a normal row.
  bool _overviewVisible = true;

  // Distance from the top (in logical pixels) within which the overview is
  // force-revealed. A small slack absorbs sub-pixel rest positions and the
  // iOS bounce so "back at the top" reliably brings the overview back.
  static const double _kOverviewRevealSlack = 8.0;

  // Measured rendered height of the overview while it is shown. Collapsing the
  // overview hands this height back to the list viewport, so we only collapse
  // when the active list can scroll *more* than this much. Otherwise hiding it
  // makes the whole list fit, the scroll position snaps back to the top, and
  // the reveal-at-top rule immediately re-extends it — the short-list "falls
  // back down on release" flicker. The threshold is therefore the overview's
  // own height (plus the reveal slack), not an arbitrary drag distance.
  double _overviewExtent = 0;
  final GlobalKey _overviewKey = GlobalKey();
  // Whether the overview prose is expanded ("show more"). Held here so it
  // survives the overview being hidden/shown by the scroll collapse.
  bool _overviewExpanded = false;

  @override
  void initState() {
    super.initState();
    _initExercises();
    // Treat a `done` event as "no live exercise" so a stopped exercise
    // stops being painted with the blue live-card treatment and the
    // "FERDIG" subtitle stub. The service keeps `_last` around after
    // `stop()` for diagnostics, but the list views only care about
    // currently-live exercises.
    _liveEvent = _filterLive(ExerciseService().last);

    // Listen to exercise changes
    _subscriptions.add(
      _programService.events.listen((event) {
        setState(() {
          _exercises = _programService.loadExercises();
        });
      }),
    );

    // The play/stop control used to live on each card; that part no longer
    // needs ExerciseService updates here. We re-subscribe so the live "blue
    // card" marker on the running exercise — mirroring the team view —
    // tracks start/stop/phase transitions while the user is on this tab.
    _subscriptions.add(
      ExerciseService().events.listen((event) {
        if (!mounted) return;
        setState(() {
          _liveEvent = _filterLive(event);
        });
      }),
    );

    // Reveal the overview again on every segment switch. `_overviewVisible` is
    // a single flag, so once it is hidden by scrolling one segment down it
    // would otherwise stay hidden on a freshly-selected segment (which has no
    // scroll-up event to bring it back). Each new lens starts with the
    // overview shown; scrolling that lens down hides it again.
    widget.controller.activeSegment.addListener(_onSegmentChanged);
  }

  void _onSegmentChanged() {
    // Exit reorder mode whenever the user switches to another segment so the
    // exercises list always starts in the clean default view on re-entry.
    widget.controller.exerciseReorderMode.value = false;
    if (mounted && !_overviewVisible) {
      setState(() => _overviewVisible = true);
    }
  }

  @override
  void dispose() {
    widget.controller.activeSegment.removeListener(_onSegmentChanged);
    super.dispose();
    for (var e in _subscriptions) {
      e.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final targetNotifier = MasterDetailScope.maybeOf(context)?.target;
    // ----------------------------------------------------------------
    // The exercises segment body: a slim list header (sort + reorder
    // toggle) pinned above the scrollable list. ReorderableSection owns
    // the mode toggle, the in-memory draft, and the deferred-commit
    // logic (ADR-0035, ADR-0036). The host supplies the reorderMode
    // notifier so _onSegmentChanged can force-exit reorder mode on
    // segment switch.
    // ----------------------------------------------------------------

    // Build a row for a given exercise. [reordering] drives gesture
    // suspension; [dragHandle] is passed as ExerciseCard.trailing in
    // reorder mode and ignored in default mode.
    Widget buildExerciseRow(
      BuildContext context,
      Exercise exercise,
      int index,
      bool reordering,
      Widget dragHandle,
    ) {
      final markers = exercise.getLocations(false);
      final selectedTarget = targetNotifier?.value;
      final isSelected =
          selectedTarget is ExerciseSheetTarget &&
          selectedTarget.exerciseUuid == exercise.uuid;

      if (reordering) {
        // Drag-handle variant: trailing is the handle; row body gestures
        // suspended (no onOpen, onLongPress, onToggle).
        return ExerciseCard(
          exercise: exercise,
          program: _programService.activeProgram,
          exerciseNumber: index + 1,
          localizations: localizations,
          markers: markers,
          liveEvent: _liveEvent,
          selected: isSelected,
          trailing: dragHandle,
          // allowExpand: false suppresses the chevron; the drag handle is
          // the only trailing affordance in reorder mode.
          allowExpand: false,
        );
      }

      // Default mode: Dismissible swipe-to-edit wrapping ExerciseCard with
      // full gestures.
      return Dismissible(
        key: ValueKey(exercise.uuid),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Theme.of(context).colorScheme.secondaryContainer,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                localizations.editExercise,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.edit,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          await _openExerciseForm(context, localizations, exercise);
          // Always return false — the item should not be removed.
          return false;
        },
        child: ExerciseCard(
          exercise: exercise,
          program: _programService.activeProgram,
          exerciseNumber: index + 1,
          localizations: localizations,
          markers: markers,
          liveEvent: _liveEvent,
          selected: isSelected,
          // trailing: null → ExpandableTile shows its own expand chevron.
          expanded: _expandedExerciseUuid == exercise.uuid,
          onToggle: () {
            setState(() {
              _expandedExerciseUuid = _expandedExerciseUuid == exercise.uuid
                  ? null
                  : exercise.uuid;
            });
          },
          onLongPress: () =>
              _openExerciseForm(context, localizations, exercise),
          // V1: live card opens the DrillPlayer sheet (DESIGN-001).
          // All other cards keep the ContextSheet flow.
          onOpen: () {
            final isLive =
                _liveEvent?.exercise.uuid == exercise.uuid &&
                ExerciseService().isStarted;
            if (isLive) {
              showDrillPlayerSheet<void>(
                context: context,
                builder: (_) => CoordinatorScreen(uuid: exercise.uuid),
              );
            } else {
              ContextSheet.of(
                context,
              ).show(context, ExerciseSheetTarget(exerciseUuid: exercise.uuid));
            }
          },
        ),
      );
    }

    final exerciseSegment = _exercises.isEmpty
        ? TeachingEmptyState(
            icon: Icons.update,
            title: localizations.emptyExercisesTitle,
            body: localizations.emptyExercisesBody,
          )
        : ReorderableSection<Exercise>(
            items: _exercises,
            keyOf: (e) => ValueKey(e.uuid),
            orderLabel: localizations.exerciseSortBy,
            sortActions: [
              (
                label: localizations.exerciseSortByStartTimeShort,
                onPressed: () => _sortExercises(_SortAction.byStartTime),
              ),
              (
                label: localizations.exerciseSortAlphabeticallyShort,
                onPressed: () => _sortExercises(_SortAction.alphabetically),
              ),
            ],
            // Hand the controller notifier to ReorderableSection so
            // _onSegmentChanged can force-exit reorder mode by flipping it.
            reorderMode: widget.controller.exerciseReorderMode,
            onCommitReorder: (newOrder) {
              // Show the committed order immediately (no async round-trip).
              setState(() => _exercises = newOrder);
              _programService.reorderExercises(
                newOrder.map((e) => e.uuid).toList(),
              );
            },
            itemBuilder: buildExerciseRow,
          );
    final exerciseBody = kIsWeb
        ? exerciseSegment
        : SharedFileWidget(child: exerciseSegment);
    // Manual collapse instead of a pinned SliverPersistentHeader. The switcher
    // is an always-visible row, so it inherits the master pane background and
    // keeps its natural M3 size rather than being forced to fill a fixed sliver
    // extent. The overview hides when the active list scrolls down and returns
    // on scroll up. The body stays an IndexedStack so each segment keeps its
    // own expansion/scroll state across switches.
    // Keep _overviewExtent in sync with the overview's rendered height while it
    // is shown. Measured after layout so it reflects the current description /
    // "show more" state; the cached value is reused while the overview is
    // hidden (when there is nothing to measure).
    if (_overviewVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _measureOverview();
      });
    }

    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        // Only the active segment's vertical list drives the collapse.
        // Horizontal scrollables (e.g. the inline station mini-maps) must not
        // toggle the overview.
        if (metrics.axis != Axis.vertical) return false;
        final delta = notification.scrollDelta ?? 0;
        // Reveal is anchored to the top position, not to scroll direction.
        // Whenever the list is back at — or bounced past — the top, force the
        // overview visible; otherwise hide it once the user scrolls down.
        //
        // A directional "reveal on any scroll-up" was tried first but proved
        // too eager: on iOS the settle/bounce after a downward drag produces a
        // small negative scrollDelta, which re-extended the overview mid-list
        // instead of letting it stay collapsed. Keying the reveal off the top
        // position keeps it collapsed while scrolled and brings it back only
        // when the user actually returns to the top.
        if (metrics.pixels <= metrics.minScrollExtent + _kOverviewRevealSlack) {
          if (!_overviewVisible) setState(() => _overviewVisible = true);
        } else if (delta > 0 &&
            _overviewVisible &&
            // Only collapse when the list can stay scrolled after it reclaims
            // the overview's height. `maxScrollExtent` here is measured with
            // the overview shown; subtracting its extent leaves the room the
            // list keeps once it is hidden, which must clear the reveal slack
            // or the list snaps back to the top and the overview re-extends.
            metrics.maxScrollExtent - _overviewExtent >
                metrics.minScrollExtent + _kOverviewRevealSlack) {
          setState(() => _overviewVisible = false);
        }
        return false;
      },
      child: Column(
        // Stretch so every child fills the available width. Without
        // this the default cross-axis center alignment was sizing
        // the `AnimatedSize` to its child's intrinsic width and
        // centering it within the parent — which made the
        // description and brief-intro snippets render visually
        // centered instead of left-aligned.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _overviewVisible
                ? KeyedSubtree(
                    key: _overviewKey,
                    child: _ProgramOverview(
                      expanded: _overviewExpanded,
                      onToggleExpanded: () => setState(
                        () => _overviewExpanded = !_overviewExpanded,
                      ),
                      onEdit: () => _openProgramForm(context, localizations),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          _ProgramSegmentSwitcher(controller: widget.controller),
          Expanded(
            child: ValueListenableBuilder<ProgramSegment>(
              valueListenable: widget.controller.activeSegment,
              builder: (context, activeSegment, _) {
                return IndexedStack(
                  index: activeSegment.index,
                  children: [
                    exerciseBody,
                    StationListView(controller: widget.stationListController),
                    RolePlaysView(controller: widget.rolePlaysController),
                    const TeamsView(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _initExercises() {
    _exercises = _programService.loadExercises();
  }

  /// Caches the overview's current rendered height into [_overviewExtent].
  /// Read by the scroll handler to decide whether collapsing the overview
  /// would leave the list scrollable (and thus stay collapsed) or make it fit
  /// and snap back to the top.
  void _measureOverview() {
    final renderObject = _overviewKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final height = renderObject.size.height;
      if (height > 0) _overviewExtent = height;
    }
  }

  Future<void> _openProgramForm(
    BuildContext context,
    AppLocalizations localizations,
  ) async {
    // On the very first launch there is no active plan yet — the
    // user tapped the empty-state "Edit plan" action without ever
    // adding an exercise. The previous early-return left the button
    // doing nothing; instead, create the default plan on demand
    // (same pattern as `saveExercise` and friends) so the form has
    // something to edit. After `ensureActiveProgram`,
    // `activeProgram` is guaranteed non-null.
    await _programService.ensureActiveProgram(localizations);
    final program = _programService.activeProgram;
    if (program == null || !context.mounted) return;
    final updated = await openFormSurface<Program>(
      context,
      builder: (_) => ProgramFormScreen(program: program),
    );
    if (updated != null && context.mounted) {
      await _programService.replaceProgram(updated);
      // The overview reads from ProgramService.activeProgram on each build,
      // but the description/briefIntro shown comes from that snapshot —
      // setState forces a rebuild so the new prose appears immediately
      // instead of waiting for the next external event.
      setState(() {});
    }
  }

  Future<void> _openExerciseForm(
    BuildContext context,
    AppLocalizations localizations,
    Exercise exercise,
  ) async {
    final numberOfTeams = _programService.loadTeams().length;
    final updated = await openFormSurface<Exercise>(
      context,
      builder: (_) => ExerciseFormScreen(
        exercise: exercise,
        numberOfTeams: numberOfTeams == 0 ? null : numberOfTeams,
      ),
    );
    if (updated != null && context.mounted) {
      await _programService.saveExercise(localizations, updated);
      setState(_initExercises);
    }
  }

  /// One-shot sort: rewrites all exercise indices in the chosen order via
  /// [ProgramService.reorderExercises] and refreshes the list. Available
  /// without entering reorder mode (ADR-0035 §"One-shot sort").
  Future<void> _sortExercises(_SortAction action) async {
    final sorted = [..._exercises];
    switch (action) {
      case _SortAction.byStartTime:
        sorted.sort((a, b) => a.startTime.compareTo(b.startTime));
      case _SortAction.alphabetically:
        sorted.sort((a, b) => a.name.compareTo(b.name));
    }
    await _programService.reorderExercises(sorted.map((e) => e.uuid).toList());
    if (mounted) setState(_initExercises);
  }

  /// Returns `event` only when it represents a currently-live exercise.
  /// A `done` event is dropped so the list view stops styling the
  /// stopped exercise as live (no "FERDIG" subtitle, no blue card).
  ExerciseEvent? _filterLive(ExerciseEvent? event) {
    if (event == null || event.isDone) return null;
    return event;
  }
}

class _ProgramSegmentSwitcher extends StatelessWidget {
  const _ProgramSegmentSwitcher({required this.controller});

  final ProgramPageControllerBase controller;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconOnly = constraints.maxWidth < 340;
        return ValueListenableBuilder<ProgramSegment>(
          valueListenable: controller.activeSegment,
          builder: (context, activeSegment, _) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ProgramSegment>(
                  expandedInsets: EdgeInsets.zero,
                  // No check on the selected segment. It would add width on
                  // the selected item and wrap its label in the narrow
                  // master pane.
                  showSelectedIcon: false,
                  segments: [
                    _segment(
                      value: ProgramSegment.exercises,
                      icon: Icons.update,
                      label: localizations.exercise(2),
                      iconOnly: iconOnly,
                    ),
                    _segment(
                      value: ProgramSegment.stations,
                      icon: Icons.place,
                      label: localizations.stationsTab,
                      iconOnly: iconOnly,
                    ),
                    _segment(
                      value: ProgramSegment.script,
                      icon: Icons.theater_comedy,
                      label: localizations.scriptSegment,
                      iconOnly: iconOnly,
                    ),
                    _segment(
                      value: ProgramSegment.teams,
                      icon: Icons.group,
                      label: localizations.team(2),
                      iconOnly: iconOnly,
                    ),
                  ],
                  selected: {activeSegment},
                  onSelectionChanged: (selected) {
                    // ADR-0032 *Activation contract*: segment selection
                    // flows URL → state. Push the canonical path and let
                    // MainScreen._initTab write `activeSegment` when the
                    // router rebuilds. Falls back to a direct write only
                    // if no program is active (defensive — the switcher
                    // should not be visible in that case).
                    final uuid = ProgramService().activeProgramUuid;
                    if (uuid == null) {
                      controller.activeSegment.value = selected.single;
                      return;
                    }
                    context.go(
                      programSegmentPath(uuid, selected.single.urlSlug),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  ButtonSegment<ProgramSegment> _segment({
    required ProgramSegment value,
    required IconData icon,
    required String label,
    required bool iconOnly,
  }) {
    return ButtonSegment<ProgramSegment>(
      value: value,
      // Never show icon and label together: four icon+label segments
      // overflow the master pane (320-420 px) and wrap the label. Show the
      // label only in normal mode, and fall back to icon-only (with a
      // tooltip) when the pane is too narrow for text.
      icon: iconOnly ? Tooltip(message: label, child: Icon(icon)) : null,
      label: iconOnly
          ? null
          : Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}

/// Collapsing read-only overview rendered above the segment switcher.
/// Scrolls off as the user moves down the active segment list.
class _ProgramOverview extends StatelessWidget {
  const _ProgramOverview({
    required this.expanded,
    required this.onToggleExpanded,
    required this.onEdit,
  });

  /// Whether the prose is shown in full. Owned by [_ProgramViewState] so it
  /// survives the overview being hidden and shown by the scroll collapse.
  final bool expanded;
  final VoidCallback onToggleExpanded;

  /// Opens the [ProgramFormScreen] so the active plan's description and brief
  /// markdown sections can be edited from the overview. The AppBar title still
  /// owns the quick-rename action; this is the deeper edit entry point.
  final VoidCallback onEdit;

  static const int _collapsedLines = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final program = ProgramService().activeProgram;

    // The "no content" branch covers two cases that present the same
    // way to the user: there is no plan yet at all (first launch
    // before they tap anything), or there is a plan but its
    // description / brief sections are empty. Render the same
    // teaching affordance in both — the row turns the otherwise
    // empty space above the segmented switcher into a discoverable
    // entry point for the ProgramFormScreen.
    final description = program?.description.trim() ?? '';
    final briefIntro = program == null
        ? null
        : _firstParagraphText(program.briefIntroMd);
    final comms = program == null
        ? null
        : _firstParagraphText(program.commsMd);
    final beforeRound = program == null
        ? null
        : _firstParagraphText(program.beforeRoundMd);
    final hasContent =
        description.isNotEmpty ||
        briefIntro != null ||
        comms != null ||
        beforeRound != null;
    if (!hasContent) {
      final scheme = Theme.of(context).colorScheme;
      final textTheme = Theme.of(context).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        // Subtle "settings-row" affordance: muted background + leading
        // pencil + trailing chevron read as tappable without competing
        // with the segmented switcher below or the FAB's add-exercise
        // CTA. Less prominent than a FilledButton/tonal would be, more
        // discoverable than the bare TextButton it replaces.
        child: Material(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.editProgram,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Render the filled state in the SAME soft container the empty
    // state uses, so the visual language is consistent: same muted
    // surface, same rounded corners, same tap target opening the
    // ProgramFormScreen. The content inside the container changes
    // (description + optional brief sections + Show more/less),
    // but the container itself is one stable element above the
    // segmented switcher — no competing Card elevation.
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final briefSections = <({String label, String text})>[
      if (briefIntro != null)
        (label: l10n.briefSectionProgramIntro, text: briefIntro),
      if (comms != null)
        (label: l10n.briefSectionProgramComms, text: comms),
      if (beforeRound != null)
        (label: l10n.briefSectionProgramBeforeRound, text: beforeRound),
    ];
    final maxLines = expanded ? null : _collapsedLines;
    final overflow = expanded ? TextOverflow.clip : TextOverflow.ellipsis;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final descriptionOverflows =
                    description.isNotEmpty &&
                    _exceedsLines(
                      context,
                      description,
                      textTheme.bodyMedium,
                      maxWidth,
                    );

                // Edge case: brief sections are filled but
                // description is empty. Collapsed-state would
                // otherwise be blank above the toggle, so promote
                // the first brief section into the always-visible
                // slot (with its label, since it's not the
                // description). The remaining sections still hide
                // behind "Show more".
                final hasDescription = description.isNotEmpty;
                final primaryBrief = hasDescription
                    ? null
                    : briefSections.firstOrNull;
                final hiddenWhenCollapsed = hasDescription
                    ? briefSections
                    : briefSections.skip(1).toList();
                final toggleVisible =
                    descriptionOverflows || hiddenWhenCollapsed.isNotEmpty;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasDescription)
                      Text(
                        description,
                        style: textTheme.bodyMedium,
                        maxLines: maxLines,
                        overflow: overflow,
                      )
                    else if (primaryBrief != null) ...[
                      Text(primaryBrief.label, style: labelStyle),
                      const SizedBox(height: 2),
                      Text(
                        primaryBrief.text,
                        style: textTheme.bodyMedium,
                        maxLines: maxLines,
                        overflow: overflow,
                      ),
                    ],
                    if (expanded)
                      for (final section in hiddenWhenCollapsed) ...[
                        const SizedBox(height: 8),
                        Text(section.label, style: labelStyle),
                        const SizedBox(height: 2),
                        Text(section.text, style: textTheme.bodySmall),
                      ],
                    if (toggleVisible)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: const Size(0, 32),
                          ),
                          onPressed: onToggleExpanded,
                          child: Text(
                            expanded ? l10n.showLess : l10n.showMore,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Whether [text] would exceed [_collapsedLines] at [maxWidth], used to
  /// decide whether the "show more" toggle is needed.
  bool _exceedsLines(
    BuildContext context,
    String text,
    TextStyle? style,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: _collapsedLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }

  /// Returns the first paragraph of a markdown string stripped of leading
  /// markers (`#`, `>`, `-`), or null when the input is null or empty.
  String? _firstParagraphText(String? md) {
    if (md == null || md.trim().isEmpty) return null;
    final first = md.trim().split('\n\n').first.trim();
    // Strip leading markdown markers from each line.
    final stripped = first
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^[#>*-]+\s*'), '').trim())
        .where((l) => l.isNotEmpty)
        .join(' ');
    return stripped.isEmpty ? null : stripped;
  }
}

class ExerciseCard extends StatefulWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    this.program,
    this.exerciseNumber,
    required this.localizations,
    this.trailing,
    required this.markers,
    this.liveEvent,
    this.selected = false,
    this.expanded,
    this.onOpen,
    this.onLongPress,
    this.onToggle,
    this.allowStationActions = true,
    this.allowExpand = true,
  });

  final Widget? trailing;
  final Exercise exercise;

  /// Owning program, used to resolve [exerciseNumberFormat] for the badge.
  /// When null, no badge is shown in [leading] and the live indicator
  /// falls back to the standard [LiveAccent.indicator] behaviour.
  final Program? program;

  /// 1-based position of [exercise] in [program.exercises]. When null,
  /// no badge is shown (picker mode, no numbering needed).
  final int? exerciseNumber;

  final AppLocalizations localizations;
  final List<StationLocation> markers;

  /// Latest [ExerciseEvent] from [ExerciseService], if any. When this
  /// event belongs to the card's exercise, the card is rendered with
  /// the same blue "live" treatment used in `team_screen.dart` so the
  /// running exercise stands out at a glance. Default `null` keeps the
  /// neutral look — that is what the export/import picker uses, where
  /// "live" styling would be misleading.
  final ExerciseEvent? liveEvent;

  /// Whether this card is the currently selected item in a master-detail
  /// layout. Forwarded to [ExpandableTile.selected].
  final bool selected;

  /// Controlled expansion state. List owners set this together with
  /// [onToggle] so opening one card can collapse the previously-open card.
  /// Standalone cards leave it null and use local state.
  final bool? expanded;

  /// Fires when the row is tapped. When `null`, tapping the row toggles
  /// the inline map preview instead (used by the export/import picker
  /// where there is no detail screen to navigate to).
  final VoidCallback? onOpen;

  /// Fires when the row is long-pressed. The exercises tab uses this as
  /// its direct edit gesture; picker cards leave it unset.
  final VoidCallback? onLongPress;

  /// Controlled expansion callback. See [expanded].
  final VoidCallback? onToggle;

  /// Whether the expanded station list offers edit (swipe / long-press)
  /// and tap-to-open-detail gestures. The exercises tab enables them so
  /// the inline station list mirrors `StationListView` and the
  /// `CoordinatorScreen` station list. The export/import picker leaves it
  /// `false`: there the card is a read-only selection row, so the
  /// expanded body shows the map preview only.
  final bool allowStationActions;

  /// Whether the inline expand/collapse affordance (chevron + body) is
  /// active. Set to `false` in exercise reorder mode to suppress the
  /// chevron so the only trailing affordance is the drag handle.
  final bool allowExpand;

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  bool _expanded = false;

  /// Index of the station row whose inline detail is currently open, or
  /// null when all rows are collapsed. Single-value because each card
  /// shows exactly one exercise, so opening a row collapses the previous
  /// one — same mutex behaviour as `StationListView`.
  int? _expandedStationIndex;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final localizations = widget.localizations;
    final markers = widget.markers;
    final hasMap = markers.isNotEmpty;
    // The picker disables station actions, so it falls back to the
    // map-only preview rather than rendering an interactive station list.
    final showStations =
        widget.allowStationActions && exercise.stations.isNotEmpty;
    // In reorder mode allowExpand is false, which suppresses the chevron and
    // the body so the only trailing affordance is the drag handle.
    final allowExpand = widget.allowExpand;
    final st = exercise.startTime.toMaterial();
    final et = exercise.endTime.toMaterial();
    final liveEvent = widget.liveEvent;
    final isLive = liveEvent?.exercise.uuid == exercise.uuid;
    final accent = LiveAccent.of(context, isLive: isLive);
    final subtitleParts = <String>[
      if (isLive) liveEvent!.getState(localizations),
      '${st.formal()} - ${et.formal()}',
      et.toDateTime().formal(localizations, st.toDateTime()),
      '${exercise.numberOfRounds} ${localizations.round(exercise.numberOfRounds).toLowerCase()}',
      '${exercise.numberOfTeams} ${localizations.team(exercise.numberOfTeams).toLowerCase()}',
    ];

    final exerciseNum = widget.exerciseNumber;
    final program = widget.program;
    final leading = (exerciseNum != null && program != null)
        ? ExerciseNumberBadge(
            label: Numbering.exercise(
              program.exerciseNumberFormat,
              exerciseNum,
            ),
            highlight: isLive,
          )
        : accent.indicator;

    return ExpandableTile(
      accent: accent,
      selected: widget.selected,
      leading: leading,
      title: Text(
        exercise.name,
        style: TextStyle(fontWeight: FontWeight.bold, color: accent.foreground),
      ),
      subtitle: Text(subtitleParts.join(' | '), style: accent.textStyle),
      trailing: widget.trailing,
      onOpen: widget.onOpen,
      onLongPress: widget.onLongPress,
      onToggle: allowExpand && (showStations || hasMap)
          ? widget.onToggle ?? _toggleExpanded
          : null,
      expanded: widget.expanded ?? _expanded,
      body: allowExpand && (showStations || hasMap)
          ? _buildExpandedBody(exercise, markers, showStations)
          : null,
    );
  }

  Widget _buildExpandedBody(
    Exercise exercise,
    List<StationLocation> markers,
    bool showStations,
  ) {
    final liveEvent = widget.liveEvent?.exercise.uuid == exercise.uuid
        ? widget.liveEvent
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (markers.isNotEmpty) ...[
          ExerciseMiniMap(
            markers: markers,
            mapKey: ValueKey<String>('exercise-card-map-${exercise.uuid}'),
          ),
          if (showStations) const SizedBox(height: 8),
        ],
        if (showStations)
          for (
            var stationIndex = 0;
            stationIndex < exercise.stations.length;
            stationIndex++
          )
            _buildStationRow(exercise, stationIndex, liveEvent),
      ],
    );
  }

  /// One station row inside the expanded card. Mirrors the
  /// `CoordinatorScreen` station list: swipe end-to-start or long-press to
  /// edit the station, and tap the row to open `StationScreen` in the
  /// context sheet. The round-by-round rotation strip is deliberately
  /// omitted here — the exercises list is an overview, so per-round team
  /// allocation belongs to the live player, not this card.
  Widget _buildStationRow(
    Exercise exercise,
    int stationIndex,
    ExerciseEvent? liveEvent,
  ) {
    return Builder(
      builder: (context) {
        final localizations = AppLocalizations.of(context)!;
        final station = exercise.stations[stationIndex];
        final isLive =
            liveEvent?.isRunning == true &&
            exercise.teamIndex(stationIndex, liveEvent!.currentRound) >= 0;
        final accent = LiveAccent.of(context, isLive: isLive);
        // Show the same numbered badge as the Poster segment so a station
        // reads as "1a", "2c" etc. here too. `stationIndex` is already the
        // 0-based position within this exercise, so the sub-index restarts
        // per exercise. Falls back to the live-accent indicator only when
        // the card has no owning program / exercise number to format with.
        final exerciseNum = widget.exerciseNumber;
        final program = widget.program;
        final hasRoles = ProgramService().loadRolePlays().any(
          (rp) =>
              rp.exerciseUuid == exercise.uuid &&
              rp.stationIndex == station.index,
        );
        final leading = (exerciseNum != null && program != null)
            ? StationNumberBadge(
                label: Numbering.station(
                  program.stationNumberFormat,
                  exerciseNumber: exerciseNum,
                  stationIndex: stationIndex,
                ),
                highlight: isLive,
                hasRoles: hasRoles,
              )
            : accent.indicator;
        final tile = ExpandableTile(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          color: Theme.of(context).brightness == Brightness.dark
              ? RingDrillColors.brandDeep
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          accent: accent,
          leading: leading,
          title: Text(
            station.name,
            // ADR-0037 drillAccent: centralised size instead of hardcoded 18.
            style: TextStyle(
              fontSize: kDrillAccentFontSize,
              color: accent.foreground,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onOpen: () => _openStation(context, exercise, station),
          onLongPress: () =>
              _openStationForm(context, localizations, exercise, station),
          expanded: _expandedStationIndex == stationIndex,
          onToggle: () => setState(() {
            _expandedStationIndex = _expandedStationIndex == stationIndex
                ? null
                : stationIndex;
          }),
          body: _buildStationDetail(exercise, station),
        );
        return Dismissible(
          key: ValueKey<String>(
            'exercise-card-station-${exercise.uuid}-${station.index}',
          ),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            color: Theme.of(context).colorScheme.secondaryContainer,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  localizations.editStation,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.edit,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ],
            ),
          ),
          confirmDismiss: (_) async {
            await _openStationForm(context, localizations, exercise, station);
            return false;
          },
          child: tile,
        );
      },
    );
  }

  /// Opens the station detail in the context sheet (or detail pane on
  /// wide layouts), matching the tap behaviour of `StationListView`.
  Future<void> _openStation(
    BuildContext context,
    Exercise exercise,
    Station station,
  ) async {
    await ContextSheet.of(context).show(
      context,
      StationSheetTarget(
        exerciseUuid: exercise.uuid,
        stationIndex: station.index,
      ),
    );
  }

  /// Opens the station form, guarding against edits while an exercise is
  /// running, then persists the edited station back into its exercise.
  /// Same flow as `StationListView._openStationForm`.
  Future<void> _openStationForm(
    BuildContext context,
    AppLocalizations localizations,
    Exercise exercise,
    Station station,
  ) async {
    final programService = ProgramService();
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
    final newStation = await openFormSurface<Station>(
      context,
      builder: (_) => StationFormScreen(
        station: station,
        markers: programService.getLocations().toMarkerSpecs(),
      ),
    );
    if (!mounted || newStation == null) return;

    final current = programService.getExercise(exercise.uuid);
    if (current == null) return;
    final stations = [...current.stations];
    final idxInList = stations.indexWhere((s) => s.index == station.index);
    if (idxInList < 0) return;
    stations[idxInList] = newStation;
    await programService.saveExercise(
      localizations,
      current.copyWith(stations: stations),
    );
  }

  /// Inline detail shown when a station row is expanded. Mirrors the
  /// `StationListView` / `CoordinatorScreen` body: description, the shared
  /// position panel (label row + tappable mini-map) and the role summary.
  /// The mini-map height is kept compact (140) so the detail stays tight
  /// inside the already-expanded card.
  Widget _buildStationDetail(Exercise exercise, Station station) {
    final description = station.description;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (description != null && description.trim().isNotEmpty) ...[
          Text(description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
        ],
        StationPositionPanel(
          exercise: exercise,
          station: station,
          mapHeight: 140,
          miniMapKey: ValueKey<String>(
            'exercise-card-station-map-${exercise.uuid}-${station.index}',
          ),
        ),
        const SizedBox(height: 12),
        StationRoleSummary(exercise: exercise, stationIndex: station.index),
      ],
    );
  }
}

abstract class ProgramPageControllerBase extends ScreenController {
  ProgramPageControllerBase({
    required this.stationListController,
    required this.rolePlaysController,
    required this.teamsPageController,
  });

  @protected
  final programService = ProgramService();
  final StationListController stationListController;
  final RolePlaysController rolePlaysController;
  final TeamsPageController teamsPageController;
  final ValueNotifier<ProgramSegment> activeSegment =
      ValueNotifier<ProgramSegment>(ProgramSegment.exercises);

  /// Whether the Øvelser segment is currently in reorder mode.
  ///
  /// When `true` the list switches to [ReorderableListView] with trailing
  /// drag handles; when `false` it uses a plain [ListView] with the standard
  /// chevron affordance (ADR-0035).
  final ValueNotifier<bool> exerciseReorderMode = ValueNotifier<bool>(false);

  void dispose() {
    activeSegment.dispose();
    exerciseReorderMode.dispose();
  }

  @override
  String title(BuildContext context) =>
      programService.activeProgram?.name ??
      // Generic tab label when no plan is active yet (first launch
      // before any plan has been created). Matches the bottom nav
      // label so the user sees a consistent name in both chrome
      // surfaces.
      AppLocalizations.of(context)!.programTab;

  @override
  Widget? buildFAB(BuildContext context, BoxConstraints constraints) {
    // Hide the "New exercise" FAB while the Øvelser segment is in reorder
    // mode: it floats over the trailing drag handles and blocks dragging the
    // bottom rows. Reorder mode has its own "Done" affordance in the list
    // header (ADR-0035/0036), so no FAB is needed there.
    if (activeSegment.value == ProgramSegment.exercises &&
        exerciseReorderMode.value) {
      return null;
    }
    return switch (activeSegment.value) {
      ProgramSegment.exercises => _buildExercisesFAB(context),
      ProgramSegment.stations => stationListController.buildFAB(
        context,
        constraints,
      ),
      ProgramSegment.script => rolePlaysController.buildFAB(
        context,
        constraints,
      ),
      ProgramSegment.teams => teamsPageController.buildFAB(
        context,
        constraints,
      ),
    };
  }

  Widget _buildExercisesFAB(BuildContext context) {
    // heroTag is intentionally null. The FAB pushes ExerciseFormScreen via a
    // The destination has no FAB to morph into, so there is no hero
    // animation to preserve. With an explicit string tag the Scaffold's
    // _FloatingActionButtonTransition can keep both the outgoing and incoming
    // FAB widgets briefly alive (in its internal Stack) when the user switches
    // tabs faster than the FAB scale-in/out animation completes — that
    // produced the "multiple heroes that share the same tag" assertion seen
    // when bouncing between /program and /stations. Disabling the Hero wrapper
    // entirely is the safe fix.
    final label = AppLocalizations.of(context)!.newExercise;
    // On a phone the extended FAB is wide enough to cover the bottom list
    // rows. Use the compact circular FAB there and keep the labelled extended
    // variant only where there is room (medium/expanded).
    final Widget fab;
    if (WindowSizeClass.of(context) == WindowSizeClass.compact) {
      fab = FloatingActionButton(
        heroTag: null,
        onPressed: () => _navigateToCreateExercise(context),
        tooltip: label,
        child: const Icon(Icons.add),
      );
    } else {
      fab = FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _navigateToCreateExercise(context),
        icon: const Icon(Icons.add),
        label: Text(label),
      );
    }

    if (programService.loadExercises().isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          StartHerePill(onActivate: () => _navigateToCreateExercise(context)),
          const SizedBox(width: 12),
          fab,
        ],
      );
    }
    return fab;
  }

  // Navigate to the CreateExerciseScreen to add a new exercise
  Future<void> _navigateToCreateExercise(BuildContext context) async {
    final newExercise = await openFormSurface<Exercise>(
      context,
      builder: (context) => ExerciseFormScreen(),
    );

    if (context.mounted && newExercise != null) {
      // Add the new exercise and reload the list
      await programService.saveExercise(
        AppLocalizations.of(context)!,
        newExercise,
      );
    }
  }

  @override
  List<Widget>? buildActions(BuildContext context, BoxConstraints constraints) {
    // Sort and reorder controls for the Øvelser segment live in the in-list
    // ReorderableSection header rather than the AppBar (ADR-0035 §"List
    // header", ADR-0036). The AppBar only carries segment-independent actions.
    final segmentActions = switch (activeSegment.value) {
      ProgramSegment.exercises => null,
      ProgramSegment.stations => stationListController.buildActions(
        context,
        constraints,
      ),
      ProgramSegment.script => rolePlaysController.buildActions(
        context,
        constraints,
      ),
      ProgramSegment.teams => teamsPageController.buildActions(
        context,
        constraints,
      ),
    };
    // The brief renders the whole plan and is segment-independent, so it shows
    // on every lens, pinned rightmost (next to the status badge). Segment
    // actions (filter, cast roster) sit to its left.
    return [...?segmentActions, ...?_briefAction(context)];
  }

  List<Widget>? _briefAction(BuildContext context) {
    final activeProgram = programService.activeProgram;
    if (activeProgram == null) return null;
    final localizations = AppLocalizations.of(context)!;
    return [
      IconButton(
        icon: const Icon(Icons.menu_book),
        tooltip: localizations.briefAction,
        onPressed: () =>
            GoRouter.of(context).push(programBriefPath(activeProgram.uuid)),
      ),
    ];
  }

  /// Shows the exercise picker as a bottom sheet on small form factors and as
  /// a centered modal dialog on wide ones (same responsive behaviour as
  /// `showOpenPlanDialog`).
  ///
  /// Each row renders the expandable [ExerciseCard] so the user can see start
  /// and end time, rounds, teams, and tap the chevron to peek at a small map
  /// of the exercise's stations before choosing whether to include it.
  ///
  /// Named parameters drive the export/import flows:
  /// - [confirmLabel] overrides the primary-button label (e.g. "EKSPORTER",
  ///   "IMPORTER"). When omitted, falls back to [AppLocalizations.confirm].
  /// - [preselectAll] starts with every exercise checked. The export/import
  ///   flows use this so the default state is "everything on".
  /// - [showSelectAllControls] adds a row with "VELG ALLE" / "VELG INGEN"
  ///   text buttons above the list, plus a "N av M valgt" counter.
  static Future<List<String>> selectExercises(
    BuildContext context,
    String title,
    List<Exercise> exercises,
    AppLocalizations localizations, {
    String? confirmLabel,
    bool preselectAll = false,
    bool showSelectAllControls = false,
  }) async {
    final List<String> selected = preselectAll
        ? exercises.map((e) => e.uuid).toList()
        : <String>[];
    final allUuids = exercises.map((e) => e.uuid).toList();
    String? expandedExerciseUuid;

    // We rely on the popped return value (not the mutated [selected] list) to
    // tell cancel from confirm. The list is pre-populated when
    // [preselectAll] is true, so reading it directly would treat a cancel
    // as "everything selected" and trigger an unintended export/import.
    final List<String>?
    popped = await showResponsiveSheetOrDialog<List<String>>(
      context,
      maximizeHeight: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final headerLabelStyle = Theme.of(context).textTheme.titleSmall
                ?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                );
            return Padding(
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 8.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    if (showSelectAllControls) ...[
                      const SizedBox(height: 8.0),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              localizations.selectedOfTotal(
                                selected.length,
                                exercises.length,
                              ),
                              style: headerLabelStyle,
                            ),
                          ),
                          TextButton(
                            onPressed: selected.length == exercises.length
                                ? null
                                : () {
                                    setState(() {
                                      selected
                                        ..clear()
                                        ..addAll(allUuids);
                                    });
                                  },
                            child: Text(localizations.selectAll),
                          ),
                          TextButton(
                            onPressed: selected.isEmpty
                                ? null
                                : () {
                                    setState(() => selected.clear());
                                  },
                            child: Text(localizations.selectNone),
                          ),
                        ],
                      ),
                      const Divider(height: 16.0),
                    ] else
                      const SizedBox(height: 16.0),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = exercises[index];
                          final uuid = exercise.uuid;
                          final markers = exercise.getLocations(false);
                          return ExerciseCard(
                            exercise: exercise,
                            localizations: localizations,
                            markers: markers,
                            allowStationActions: false,
                            expanded: expandedExerciseUuid == uuid,
                            // House rule (ExpandableTile): a row with an
                            // expandable body + chevron must supply onOpen.
                            // The picker has no context sheet to open, so a
                            // row tap toggles this exercise's selection —
                            // matching the trailing switch. The chevron still
                            // expands the map preview.
                            onOpen: () {
                              setState(() {
                                if (selected.contains(uuid)) {
                                  selected.remove(uuid);
                                } else {
                                  selected.add(uuid);
                                }
                              });
                            },
                            onToggle: () {
                              setState(() {
                                expandedExerciseUuid =
                                    expandedExerciseUuid == uuid ? null : uuid;
                              });
                            },
                            trailing: Switch.adaptive(
                              value: selected.contains(uuid),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    selected.add(uuid);
                                  } else {
                                    selected.remove(uuid);
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: headerLabelStyle,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context, null);
                          },
                          child: Text(localizations.cancel),
                        ),
                        const SizedBox(width: 8.0),
                        FilledButton(
                          onPressed: selected.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(context, selected);
                                },
                          child: Text(confirmLabel ?? localizations.confirm),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return popped ?? <String>[];
  }
}
