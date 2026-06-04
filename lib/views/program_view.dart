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
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/program_form_screen.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/shared_file_widget.dart';
import 'package:ringdrill/views/coordinator_screen.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/roleplays_view.dart';
import 'package:ringdrill/views/teams_view.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/drill_player_sheet.dart';
import 'package:ringdrill/views/widgets/exercise_mini_map.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:ringdrill/views/widgets/station_role_summary.dart';

import 'exercise_form_screen.dart';

export 'package:ringdrill/web/program_page_controller.dart'
    if (dart.library.io) 'program_page_controller.dart';

enum ProgramSegment { exercises, stations, script, teams }

enum _ExerciseAction { moveUp, moveDown }

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
    Widget buildList(ContextSheetTarget? selectedTarget) {
      return ReorderableListView.builder(
        // Prevent the list from scrolling the outer NotificationListener
        // while the drag handle is being used; forward scrolls as usual.
        buildDefaultDragHandles: false,
        itemCount: _exercises.length,
        onReorderItem: (oldIndex, newIndex) {
          // onReorderItem already adjusts newIndex for the removed item, so
          // no correction is needed here.
          final reordered = [..._exercises];
          final moved = reordered.removeAt(oldIndex);
          reordered.insert(newIndex, moved);
          final orderedUuids = reordered.map((e) => e.uuid).toList();
          _programService.reorderExercises(orderedUuids).then((_) {
            if (mounted) setState(_initExercises);
          });
        },
        itemBuilder: (context, index) {
          final exercise = _exercises[index];
          final markers = exercise.getLocations(false);
          final isSelected =
              selectedTarget is ExerciseSheetTarget &&
              selectedTarget.exerciseUuid == exercise.uuid;

          // The drag handle is a distinct trailing hit target (ADR-0031: row
          // body swipe and long-press are reserved for edit). It is a
          // separate affordance that does not collide with those gestures.
          // The overflow menu for move-up/move-down is stacked next to it.
          final isFirst = index == 0;
          final isLast = index == _exercises.length - 1;
          final dragHandle = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<_ExerciseAction>(
                tooltip: localizations.moreActions,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _ExerciseAction.moveUp,
                    enabled: !isFirst,
                    child: Text(localizations.exerciseMoveUp),
                  ),
                  PopupMenuItem(
                    value: _ExerciseAction.moveDown,
                    enabled: !isLast,
                    child: Text(localizations.exerciseMoveDown),
                  ),
                ],
                onSelected: (action) => _onExerciseAction(action, index),
              ),
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Icon(Icons.drag_handle),
                ),
              ),
            ],
          );

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
              trailing: dragHandle,
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
                  ContextSheet.of(context).show(
                    context,
                    ExerciseSheetTarget(exerciseUuid: exercise.uuid),
                  );
                }
              },
            ),
          );
        },
      );
    }

    final exercises = _exercises.isEmpty
        ? Center(child: Text(localizations.noExercisesYet))
        : Padding(
            // top: 11 + ExpandableTile.margin.top (5) = 16, matching the
            // detail body's `EdgeInsets.all(16)` so the first row of master
            // and detail align in the wide layout.
            padding: const EdgeInsets.only(top: 11.0),
            child: targetNotifier == null
                ? buildList(null)
                : ValueListenableBuilder<ContextSheetTarget?>(
                    valueListenable: targetNotifier,
                    builder: (context, target, _) => buildList(target),
                  ),
          );
    final exerciseBody = kIsWeb
        ? exercises
        : SharedFileWidget(child: exercises);
    // Manual collapse instead of a pinned SliverPersistentHeader. The switcher
    // is an always-visible row, so it inherits the master pane background and
    // keeps its natural M3 size rather than being forced to fill a fixed sliver
    // extent. The overview hides when the active list scrolls down and returns
    // on scroll up. The body stays an IndexedStack so each segment keeps its
    // own expansion/scroll state across switches.
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        final delta = notification.scrollDelta ?? 0;
        if (delta > 0 && _overviewVisible) {
          setState(() => _overviewVisible = false);
        } else if (delta < 0 && !_overviewVisible) {
          setState(() => _overviewVisible = true);
        }
        return false;
      },
      child: Column(
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _overviewVisible
                ? _ProgramOverview(
                    expanded: _overviewExpanded,
                    onToggleExpanded: () => setState(
                      () => _overviewExpanded = !_overviewExpanded,
                    ),
                    onEdit: () => _openProgramForm(context, localizations),
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
                    StationListView(
                      controller: widget.stationListController,
                    ),
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

  /// Handles overflow-menu move actions on exercise rows. Swaps the exercise
  /// at [index] one slot up or down, then persists via [reorderExercises].
  Future<void> _onExerciseAction(_ExerciseAction action, int index) async {
    final newIndex = action == _ExerciseAction.moveUp ? index - 1 : index + 1;
    if (newIndex < 0 || newIndex >= _exercises.length) return;
    final reordered = [..._exercises];
    final moved = reordered.removeAt(index);
    reordered.insert(newIndex, moved);
    await _programService.reorderExercises(
      reordered.map((e) => e.uuid).toList(),
    );
    if (mounted) setState(_initExercises);
  }

  Future<void> _openProgramForm(
    BuildContext context,
    AppLocalizations localizations,
  ) async {
    final program = _programService.activeProgram;
    if (program == null) return;
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
                    controller.activeSegment.value = selected.single;
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
    if (program == null) return const SizedBox.shrink();

    final description = program.description.trim();
    final briefIntro = _firstParagraphText(program.briefIntroMd);
    final hasContent = description.isNotEmpty || briefIntro != null;
    if (!hasContent) {
      // Locally-created plans start with no description and no brief content.
      // Surface the form anyway so the user has a discoverable entry point,
      // rather than returning to the silent SizedBox.shrink the overview used
      // to render in this state.
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: Text(l10n.editProgram),
            onPressed: onEdit,
          ),
        ),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final maxLines = expanded ? null : _collapsedLines;
    final overflow = expanded ? TextOverflow.clip : TextOverflow.ellipsis;

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final truncatable =
                (description.isNotEmpty &&
                    _exceedsLines(
                      context,
                      description,
                      textTheme.bodyMedium,
                      maxWidth,
                    )) ||
                (briefIntro != null &&
                    _exceedsLines(
                      context,
                      briefIntro,
                      textTheme.bodySmall,
                      maxWidth,
                    ));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: textTheme.bodyMedium,
                    maxLines: maxLines,
                    overflow: overflow,
                  ),
                if (briefIntro != null) ...[
                  if (description.isNotEmpty) const SizedBox(height: 6),
                  Text(
                    briefIntro,
                    style: textTheme.bodySmall,
                    maxLines: maxLines,
                    overflow: overflow,
                  ),
                ],
                // TODO(DESIGN-004): render program.commsMd preview here when
                // program-level brief fields land. Brief is opened from the
                // AppBar action, not here.
                if (truncatable)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: const Size(0, 32),
                      ),
                      onPressed: onToggleExpanded,
                      child: Text(expanded ? l10n.showLess : l10n.showMore),
                    ),
                  ),
              ],
            );
          },
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
      onToggle: showStations || hasMap
          ? widget.onToggle ?? _toggleExpanded
          : null,
      expanded: widget.expanded ?? _expanded,
      body: showStations || hasMap
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
        final tile = ExpandableTile(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          color: Theme.of(context).brightness == Brightness.dark
              ? RingDrillColors.brandDeep
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          accent: accent,
          leading: accent.indicator,
          title: Text(
            station.name,
            style: TextStyle(fontSize: 18, color: accent.foreground),
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

  void dispose() {
    activeSegment.dispose();
  }

  @override
  String title(BuildContext context) =>
      programService.activeProgram?.name ??
      AppLocalizations.of(context)!.exercise(2);

  @override
  Widget? buildFAB(BuildContext context, BoxConstraints constraints) {
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
    return FloatingActionButton.extended(
      heroTag: null,
      onPressed: () => _navigateToCreateExercise(context),
      icon: const Icon(Icons.add),
      label: Text(AppLocalizations.of(context)!.newExercise),
    );
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
    final segmentActions = switch (activeSegment.value) {
      ProgramSegment.exercises => _buildExercisesSortActions(context),
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

  /// One-shot sort actions shown in the Øvelser segment AppBar overflow.
  /// After sorting, the order is manual again — users can nudge individual
  /// rows with the drag handle or the move-up/down overflow actions.
  List<Widget>? _buildExercisesSortActions(BuildContext context) {
    final exercises = programService.loadExercises();
    if (exercises.length < 2) return null;
    final l10n = AppLocalizations.of(context)!;

    return [
      PopupMenuButton<_SortAction>(
        tooltip: l10n.moreActions,
        itemBuilder: (_) => [
          PopupMenuItem(
            value: _SortAction.byStartTime,
            child: Text(l10n.exerciseSortByStartTime),
          ),
          PopupMenuItem(
            value: _SortAction.alphabetically,
            child: Text(l10n.exerciseSortAlphabetically),
          ),
        ],
        onSelected: (action) async {
          final sorted = [...exercises];
          switch (action) {
            case _SortAction.byStartTime:
              sorted.sort(
                (a, b) => a.startTime.compareTo(b.startTime),
              );
            case _SortAction.alphabetically:
              sorted.sort((a, b) => a.name.compareTo(b.name));
          }
          await programService.reorderExercises(
            sorted.map((e) => e.uuid).toList(),
          );
        },
      ),
    ];
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
                            onToggle: () {
                              setState(() {
                                expandedExerciseUuid =
                                    expandedExerciseUuid == uuid ? null : uuid;
                              });
                            },
                            trailing: Switch(
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
