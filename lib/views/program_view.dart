import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/theme.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/page_widget.dart';
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
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:ringdrill/views/widgets/station_role_summary.dart';

import 'exercise_form_screen.dart';

export 'package:ringdrill/web/program_page_controller.dart'
    if (dart.library.io) 'program_page_controller.dart';

enum ProgramSegment { exercises, stations, roleplays, teams }

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
  }

  @override
  void dispose() {
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
      return ListView.builder(
        itemCount: _exercises.length,
        itemBuilder: (context, index) {
          final exercise = _exercises[index];
          final markers = exercise.getLocations(false);
          final isSelected =
              selectedTarget is ExerciseSheetTarget &&
              selectedTarget.exerciseUuid == exercise.uuid;

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
              localizations: localizations,
              markers: markers,
              liveEvent: _liveEvent,
              selected: isSelected,
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
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(
          child: _ProgramOverview(controller: widget.controller),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _SegmentSwitcherDelegate(
            controller: widget.controller,
          ),
        ),
      ],
      body: ValueListenableBuilder<ProgramSegment>(
        valueListenable: widget.controller.activeSegment,
        builder: (context, activeSegment, _) {
          return switch (activeSegment) {
            ProgramSegment.exercises => exerciseBody,
            ProgramSegment.stations =>
              StationListView(controller: widget.stationListController),
            ProgramSegment.roleplays =>
              RolePlaysView(controller: widget.rolePlaysController),
            ProgramSegment.teams => const TeamsView(),
          };
        },
      ),
    );
  }

  void _initExercises() {
    _exercises = _programService.loadExercises();
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
                      value: ProgramSegment.roleplays,
                      icon: Icons.theater_comedy,
                      label: localizations.rolePlaysTab,
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

// Height of _ProgramSegmentSwitcher: Padding(top: 8) + SegmentedButton (M3 ~40).
const double _kSwitcherHeight = 48.0;

/// Collapsing read-only overview rendered above the pinned segment switcher.
/// Scrolls off as the user moves down the active segment list.
class _ProgramOverview extends StatelessWidget {
  const _ProgramOverview({required this.controller});

  final ProgramPageControllerBase controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<ProgramSegment>(
      valueListenable: controller.activeSegment,
      builder: (context, activeSegment, _) {
        final program = ProgramService().activeProgram;
        if (program == null) return const SizedBox.shrink();

        final service = ProgramService();
        final teamCount = service.loadTeams().length;

        final String? segmentCountPhrase = switch (activeSegment) {
          ProgramSegment.exercises => l10n.exercise(service.loadExercises().length),
          ProgramSegment.stations => l10n.station(
              service.loadExercises().fold(0, (n, e) => n + e.stations.length),
            ),
          ProgramSegment.roleplays => l10n.roleplay(service.loadRolePlays().length),
          ProgramSegment.teams => null,
        };

        final summaryParts = [l10n.team(teamCount), ?segmentCountPhrase];
        final summary = summaryParts.join(' · ');

        final description = program.description.trim();
        final briefIntro = _firstParagraphText(program.briefIntroMd);

        final textTheme = Theme.of(context).textTheme;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(summary, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  description,
                  style: textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (briefIntro != null) ...[
                const SizedBox(height: 6),
                Text(
                  briefIntro,
                  style: textTheme.bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // TODO(DESIGN-004): render program.commsMd preview here when
              // program-level brief fields land.
            ],
          ),
        );
      },
    );
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

/// Pinned [SliverPersistentHeaderDelegate] wrapping [_ProgramSegmentSwitcher].
/// Uses a fixed height so only the overview sliver above it scrolls off.
class _SegmentSwitcherDelegate extends SliverPersistentHeaderDelegate {
  const _SegmentSwitcherDelegate({required this.controller});

  final ProgramPageControllerBase controller;

  @override
  double get minExtent => _kSwitcherHeight;

  @override
  double get maxExtent => _kSwitcherHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _ProgramSegmentSwitcher(controller: controller),
    );
  }

  @override
  bool shouldRebuild(_SegmentSwitcherDelegate old) =>
      controller != old.controller;
}

class ExerciseCard extends StatefulWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
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

    return ExpandableTile(
      accent: accent,
      selected: widget.selected,
      leading: accent.indicator,
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
      ProgramSegment.roleplays => rolePlaysController.buildFAB(
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
    return switch (activeSegment.value) {
      ProgramSegment.exercises => _buildExercisesActions(context),
      ProgramSegment.stations => stationListController.buildActions(
        context,
        constraints,
      ),
      ProgramSegment.roleplays => rolePlaysController.buildActions(
        context,
        constraints,
      ),
      ProgramSegment.teams => teamsPageController.buildActions(
        context,
        constraints,
      ),
    };
  }

  List<Widget>? _buildExercisesActions(BuildContext context) {
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
