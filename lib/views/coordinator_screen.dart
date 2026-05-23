import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/phase_headers.dart';
import 'package:ringdrill/views/phase_tile.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/team_station_widget.dart';
import 'package:ringdrill/views/vertical_divider_widget.dart';

import 'exercise_control_button.dart';
import 'exercise_form_screen.dart';

/// Width of the combined hero card when it's used as a sidebar to the
/// right of the round table. Below this the colour squares plus the
/// label/time pair become hard to read, so the layout falls back to
/// the stacked variant.
const double _kHeroSidebarWidth = 150;

class CoordinatorScreen extends StatefulWidget {
  final String uuid;

  const CoordinatorScreen({super.key, required this.uuid});

  @override
  State<CoordinatorScreen> createState() => _CoordinatorScreenState();
}

/// Which list the coordinator is currently looking at. The two columns
/// (station rotations / team rotations) are mutually exclusive now, so the
/// coordinator picks one via a SegmentedButton at the top of the body.
enum _CoordinatorView { stations, teams }

class _CoordinatorScreenState extends State<CoordinatorScreen> {
  late bool _isStarted;

  final _programService = ProgramService();
  final _exerciseService = ExerciseService();
  final _subscriptions = <StreamSubscription>[];

  Exercise? _exercise;
  bool _promptShowNotification = false;
  _CoordinatorView _view = _CoordinatorView.stations;

  // Mutual-exclusive expansion state for the station and team lists.
  // At most one row may be expanded in either list at any time. We keep
  // a pool of [ExpansionTileController]s so we can programmatically
  // collapse the previously-expanded row when the coordinator taps a
  // different one — `initiallyExpanded` alone only sets state on the
  // first mount, so a controller is needed for later updates.
  final _stationControllers = <ExpansionTileController>[];
  final _teamControllers = <ExpansionTileController>[];
  int? _expandedStationIndex;
  int? _expandedTeamIndex;

  ExpansionTileController _controllerFor(
    List<ExpansionTileController> pool,
    int index,
  ) {
    while (pool.length <= index) {
      pool.add(ExpansionTileController());
    }
    return pool[index];
  }

  /// Handles an `onExpansionChanged` callback so only one row in [pool]
  /// is expanded at a time. [readIndex]/[writeIndex] read and update the
  /// state field that tracks the expanded index for this list. Calling
  /// `controller.collapse()` re-enters `onExpansionChanged(false)` for
  /// the previous tile, but by then `readIndex()` no longer matches its
  /// index so the recursive call is a no-op.
  void _handleExpansionChange({
    required bool expanded,
    required int tappedIndex,
    required List<ExpansionTileController> pool,
    required int? Function() readIndex,
    required void Function(int?) writeIndex,
  }) {
    if (expanded) {
      final prev = readIndex();
      setState(() => writeIndex(tappedIndex));
      if (prev != null && prev != tappedIndex && prev < pool.length) {
        pool[prev].collapse();
      }
    } else if (readIndex() == tappedIndex) {
      setState(() => writeIndex(null));
    }
  }

  @override
  void initState() {
    _isStarted = _exerciseService.isStartedOn(widget.uuid);

    // Listen to ProgramService state changes
    _subscriptions.add(
      _programService.events.listen((event) {
        if (event.exercise?.uuid == widget.uuid) {
          if (mounted) {
            setState(() {
              _exercise = event.exercise;
            });
          }
        }
      }),
    );

    // Listen to ExerciseService state changes. The phase transition snackbar
    // that used to live here has been removed because the persistent
    // status-bar at the bottom of the screen already shows the same info
    // (round, phase, remaining time) more prominently and without dismissing
    // itself after a few seconds.
    _subscriptions.add(
      _exerciseService.events.listen((event) {
        if (mounted) {
          setState(() {
            _isStarted = event.isRunning || event.isPending;
          });
        }
      }),
    );

    // Listen to Notification Events
    _subscriptions.add(
      NotificationService().events
          .where((_) => _exercise != null)
          .where((e) => e.action == NotificationAction.promptReshow)
          .where((e) => e.exercise?.uuid == _exercise?.uuid)
          .listen((event) {
            if (mounted) {
              setState(() {
                _promptShowNotification = true;
              });
            }
          }),
    );

    super.initState();
  }

  @override
  void didChangeDependencies() {
    _exercise = _programService.getExercise(widget.uuid);
    assert(_exercise != null, 'Exercise with uuid [${widget.uuid}] not found');
    _isStarted = _exerciseService.isStartedOn(widget.uuid);
    super.didChangeDependencies();
  }

  /// Function to handle editing the exercise
  void _deleteExercise(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.confirm),
        content: Text(localizations.confirmDeleteExercise),
        actions: [
          // Cancel Button
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(localizations.cancel),
          ),
          // Delete Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: Text(
              localizations.delete,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (context.mounted && confirmed) {
      await _programService.deleteExercise(_exercise!.uuid);
      if (context.mounted) {
        Navigator.of(context).pop(false);
      }
    }
  }

  /// Function to handle editing the exercise
  void _editExercise(BuildContext context) async {
    final numberOfTeams = _programService.loadTeams().length;
    // Navigate to the edit exercise screen
    final newExercise = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseFormScreen(
          exercise: _exercise,
          numberOfTeams: numberOfTeams == 0 ? null : numberOfTeams,
        ),
      ),
    );
    if (context.mounted && newExercise != null) {
      await _programService.saveExercise(
        AppLocalizations.of(context)!,
        newExercise,
      );
      setState(() {
        _exercise = newExercise;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return StreamBuilder(
      stream: _exerciseService.events,
      initialData: _exerciseService.last,
      builder: (context, asyncSnapshot) {
        final event =
            asyncSnapshot.data ??
            ExerciseEvent.pending(_programService.getExercise(widget.uuid)!);
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _exercise!.name,
            ), // Dynamic title shows the exercise's name
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_on),
                padding: const EdgeInsets.all(8.0),
                onPressed: _promptShowNotification
                    ? () {
                        unawaited(NotificationService().initFromPrefs());
                        setState(() {
                          _promptShowNotification = false;
                        });
                      }
                    : null,
                tooltip: localizations.showNotification,
              ),

              // Delete Exercise Button
              IconButton(
                icon: const Icon(Icons.delete),
                padding: const EdgeInsets.all(8.0),
                onPressed: _isStarted ? null : () => _deleteExercise(context),
              ),

              // Edit Exercise Button
              IconButton(
                icon: const Icon(Icons.edit),
                padding: const EdgeInsets.all(8.0),
                onPressed: _isStarted ? null : () => _editExercise(context),
              ),
            ],
            actionsPadding: EdgeInsets.only(right: 16.0),
          ),
          body: SafeArea(
            child: _exercise!.schedule.isEmpty
                ? Center(child: Text(localizations.noRoundsScheduled))
                : _buildBody(event),
          ),
          floatingActionButton: ExerciseControlButton(
            // Stable identity so the Scaffold treats the play→stop swap as
            // the same FAB and animates the position change instead of
            // scaling the green FAB out and the red FAB in. Combined with
            // [_SlideFloatingActionButtonAnimator] below this gives the
            // hero-like glide from the corner to the centre of the status
            // bar when the exercise is started, mirroring the player
            // mockup in docs/design/mockups/coordinator-oversikt.html.
            key: const ValueKey('coordinator-exercise-fab'),
            exercise: _exercise!,
            service: _exerciseService,
            localizations: localizations,
          ),
          floatingActionButtonLocation: _isStarted
              ? FloatingActionButtonLocation.centerDocked
              : FloatingActionButtonLocation.endFloat,
          floatingActionButtonAnimator:
              const _SlideFloatingActionButtonAnimator(),
          bottomNavigationBar: _buildExerciseStatus(event),
        );
      },
    );
  }

  Widget _buildBody(ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    // Hero row only makes sense once the coordinator has started (or is
    // about to start) the exercise. The StreamBuilder above falls back to
    // a synthetic `ExerciseEvent.pending` whenever no service event has
    // arrived yet, so `event.isPending` is `true` even before the user
    // presses play. Reading the service directly avoids that false
    // positive and matches the gate used for `_buildExerciseStatus`.
    final showHero = _exerciseService.isStartedOn(widget.uuid);
    // The whole screen scrolls as one unit, so the round table, the
    // segmented switch and the chosen list move together when the
    // coordinator scrolls. Previously only the inner list scrolled, which
    // pinned the round table to the top and forced the coordinator to
    // scroll inside a small viewport.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopSection(event, showHero: showHero),
          const SizedBox(height: 16),
          Center(
            child: SegmentedButton<_CoordinatorView>(
              segments: [
                ButtonSegment<_CoordinatorView>(
                  value: _CoordinatorView.stations,
                  label: Text(
                    '${localizations.stationRotations}'
                    ' (${_exercise!.stations.length})',
                  ),
                  icon: const Icon(Icons.location_on),
                ),
                ButtonSegment<_CoordinatorView>(
                  value: _CoordinatorView.teams,
                  label: Text(
                    '${localizations.teamRotations}'
                    ' (${_exercise!.numberOfTeams})',
                  ),
                  icon: const Icon(Icons.group),
                ),
              ],
              selected: <_CoordinatorView>{_view},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() => _view = selection.first);
              },
            ),
          ),
          const SizedBox(height: 8),
          _view == _CoordinatorView.stations
              ? _buildStationList(event)
              : _buildTeamList(event),
        ],
      ),
    );
  }

  /// Compact live status row anchored to the bottom of the screen: round
  /// number, phase name and remaining time. Only built when the coordinator
  /// has actually pressed start on this exercise — the app is not
  /// date-driven, so "time until start" is not meaningful before the user
  /// activates the timer. Returns `null` when the bar should be hidden, so
  /// the Scaffold reclaims the bottom space entirely instead of reserving
  /// an empty strip.
  Widget? _buildExerciseStatus(ExerciseEvent event) {
    if (!_exerciseService.isStartedOn(widget.uuid)) return null;
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final roundLabel =
        '${localizations.round(1)} ${event.currentRound + 1}'
        ' · ${event.getState(localizations)}';
    final timeLabel = event.isPending
        ? DateTimeX.fromMinutes(event.remainingTime).formal(localizations)
        : localizations.minute(event.remainingTime);
    return Material(
      elevation: 4,
      color: colorScheme.primaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  roundLabel,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top of the body. Layout depends on two things:
  ///
  /// * `showHero`: only true once the coordinator has started the
  ///   exercise. Before start there's nothing to show "now / next" for
  ///   and the round table claims the full width.
  /// * Available width: when there's room for the round table at its
  ///   natural width plus the [_kHeroSidebarWidth] sidebar next to it
  ///   the combined hero card is placed to the right of the table. On
  ///   narrower screens we stack the card above the table instead, so
  ///   phone-portrait keeps working without horizontal scrolling.
  Widget _buildTopSection(ExerciseEvent event, {required bool showHero}) {
    if (!showHero) {
      return Align(
        alignment: Alignment.topCenter,
        child: _buildRoundTable(event, true),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Threshold leaves room for the round table (~280 px) + 12 px
        // gap + sidebar. A slight buffer above the bare minimum avoids
        // the 1.2 px overflow we saw at the edge case where Expanded
        // pinned the table to a barely-too-narrow column.
        final wideEnough =
            constraints.maxWidth >= _kHeroSidebarWidth + 12 + 300;
        if (wideEnough) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Round table keeps its natural width. We need
                // IntrinsicWidth here because PhaseTile and
                // PhaseHeaders are `Row` widgets with the default
                // `MainAxisSize.max`, which would otherwise try to fill
                // the unbounded width that Row gives non-flex children.
                // IntrinsicWidth measures the table's natural width and
                // supplies it as a tight constraint so those inner rows
                // have something finite to fill.
                IntrinsicWidth(child: _buildRoundTable(event, true)),
                const SizedBox(width: 12),
                // Fixed-width sidebar so the typography stays stable
                // regardless of how wide the parent is. Any leftover
                // horizontal space falls to the right of the card,
                // which keeps the table-and-card group anchored to the
                // left of the screen.
                SizedBox(
                  width: _kHeroSidebarWidth,
                  child: _buildCombinedHeroCard(event, isSidebar: true),
                ),
              ],
            ),
          );
        }
        // Narrow fallback: the combined card stretches above the
        // table. One full-width card reads cleaner than two
        // half-width cards in the same horizontal strip.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCombinedHeroCard(event, isSidebar: false),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.topCenter,
              child: _buildRoundTable(event, true),
            ),
          ],
        );
      },
    );
  }

  /// One combined card that stacks the Phase Now and Next sections,
  /// separated by a divider. Replaces the two-card layout we had before
  /// so the sidebar reads as a single unit. See the user-supplied
  /// design with the card placed to the right of the round table.
  Widget _buildCombinedHeroCard(ExerciseEvent event, {bool isSidebar = false}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_buildPhaseNowSection(event, isSidebar: isSidebar)],
        ),
      ),
    );
  }

  /// Top half of the combined hero card. Pure content (no Card or
  /// padding) so it composes cleanly inside any container the layout
  /// puts it in.
  Widget _buildPhaseNowSection(ExerciseEvent event, {required bool isSidebar}) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final phaseIdx = event.isPending ? -1 : event.phase.index - 1;
    final isPending = phaseIdx < 0;
    final caption = isPending
        ? event.getState(localizations)
        : localizations.remainingInPhase.toUpperCase();
    final endTime = isPending
        ? _exercise!.startTime
        : _phaseEndTime(event.currentRound, phaseIdx);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildRemainingTime(event.remainingTime, theme, isSidebar: isSidebar),
        const SizedBox(height: 6),
        Text(
          caption,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        if (endTime != null) ...[
          const SizedBox(height: 2),
          Text(
            localizations.phaseEndsAt(endTime.toString()),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// Renders the dominant remaining-time element in the Phase Now
  /// section. For short durations (< 60 min) we use "X" big plus
  /// " min" small so the unit reads naturally; for longer durations —
  /// which only happen during the pending state when the start time is
  /// more than an hour away — we collapse to a timer-style "H:MM" so
  /// the number stays compact instead of growing into something like
  /// "826 min".
  Widget _buildRemainingTime(
    int minutes,
    ThemeData theme, {
    required bool isSidebar,
  }) {
    final bigStyle = theme.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
      height: 1.0,
    );
    if (minutes < 60) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$minutes', style: bigStyle),
            TextSpan(
              text: ' min',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      );
    }
    final h = minutes ~/ 60;
    final m = (minutes % 60).toString().padLeft(2, '0');
    return Text('$h:$m', style: bigStyle, textAlign: TextAlign.center);
  }

  /// End time of a phase as a wall-clock value. For execution and
  /// evaluation this is the start of the next phase in the same round.
  /// For rotation (the last phase of a round) this is the start of the
  /// next round's execution phase, or the exercise's [Exercise.endTime]
  /// if we're already on the last round.
  SimpleTimeOfDay? _phaseEndTime(int roundIndex, int phaseIndex) {
    final schedule = _exercise!.schedule;
    if (roundIndex < 0 || roundIndex >= schedule.length) return null;
    if (phaseIndex < 0 || phaseIndex > 2) return null;
    if (phaseIndex < 2) return schedule[roundIndex][phaseIndex + 1];
    if (roundIndex + 1 < schedule.length) return schedule[roundIndex + 1][0];
    return _exercise!.endTime;
  }

  String _phaseLabel(int phaseIndex, AppLocalizations l10n) {
    return switch (phaseIndex) {
      0 => l10n.drill,
      1 => l10n.eval,
      2 => l10n.roll,
      _ => '',
    }.toUpperCase();
  }

  /// Phase colour palette aligned with the player mockup at
  /// `docs/design/mockups/coordinator-oversikt.html`. Drill is green,
  /// eval is blue, roll is orange. These are hard-coded for now because
  /// they don't map cleanly onto the Material colour scheme — when the
  /// player view is extracted to its own widget tree this is a good
  /// candidate to move into a shared theming layer.
  Color _phaseColor(int phaseIndex) {
    return switch (phaseIndex) {
      0 => const Color(0xFF1D9E75),
      1 => const Color(0xFF378ADD),
      2 => const Color(0xFFBA7517),
      _ => Colors.grey,
    };
  }

  IconData _phaseIcon(int phaseIndex) {
    return switch (phaseIndex) {
      0 => Icons.local_fire_department,
      1 => Icons.assignment_turned_in,
      2 => Icons.swap_horiz,
      _ => Icons.help_outline,
    };
  }

  /// Returns up to [maxItems] phases that come after the [currentPhase]
  /// of [currentRound], iterating first through the remaining phases of
  /// the current round and then through phases of subsequent rounds.
  /// Pass `-1` as [currentPhase] to start from the very first phase of
  /// [currentRound] (used during the pending state, when no phase has
  /// actually begun yet).
  List<({int round, int phase})> _upcomingPhases(
    int currentRound,
    int currentPhase,
    int maxItems,
  ) {
    final upcoming = <({int round, int phase})>[];
    final lastRound = _exercise!.schedule.length - 1;
    for (var p = currentPhase + 1; p < 3 && upcoming.length < maxItems; p++) {
      upcoming.add((round: currentRound, phase: p));
    }
    for (
      var r = currentRound + 1;
      r <= lastRound && upcoming.length < maxItems;
      r++
    ) {
      for (var p = 0; p < 3 && upcoming.length < maxItems; p++) {
        upcoming.add((round: r, phase: p));
      }
    }
    return upcoming;
  }

  Widget _buildRoundTable(ExerciseEvent event, bool isPortrait) {
    final localizations = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(8.0),
      child: Column(
        children: [
          PhaseHeaders(
            titleWidth: 90,
            title: localizations.schedule,
            mainAxisAlignment: MainAxisAlignment.center,
          ),
          SizedBox(height: 8),
          ...List<Widget>.generate(_exercise!.schedule.length, (roundIndex) {
            // Determine whether this round is completed or current
            return PhaseTile(
              title:
                  "${AppLocalizations.of(context)!.round(1)} "
                  "${roundIndex + 1}",
              event: event,
              exercise: _exercise!,
              roundIndex: roundIndex,
              isPortrait: isPortrait,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStationList(ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    // The list is rendered as a plain Column instead of a ListView so it
    // can take part in the parent SingleChildScrollView. Station counts
    // are small (typically <20) so eager-building every card is cheaper
    // than the indirection a nested-scroll ListView would add.
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(_exercise!.stations.length, (
          stationIndex,
        ) {
          final station = _exercise!.stations[stationIndex];
          final colorScheme = Theme.of(context).colorScheme;
          // A station is "live" when the current round assigns a team to
          // it. Used to auto-expand the relevant row so the coordinator
          // sees the active station's detail without an extra tap, and
          // to highlight the card so the active station is recognisable
          // even when collapsed. Mirrors the live styling used in
          // TeamScreen._ExerciseSection.
          final isLive =
              event.isRunning &&
              _exercise!.teamIndex(stationIndex, event.currentRound) >= 0;
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            clipBehavior: Clip.antiAlias,
            color: isLive ? colorScheme.primaryContainer : null,
            shape: isLive
                ? RoundedRectangleBorder(
                    side: BorderSide(color: colorScheme.primary, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: ExpansionTile(
              // Do NOT use a PageStorageKey here: ExpansionTile would
              // write a bool into the PageStorageBucket, and any
              // SelectableText below (e.g. UtmWidget inside the
              // station detail) reads from the same bucket-path for
              // its scroll offset, casting the bool to double? and
              // crashing at didChangeDependencies. Widget identity
              // already keeps the expanded state stable across
              // exercise-event rebuilds.
              key: ValueKey<String>('coordinator-station-$stationIndex'),
              controller: _controllerFor(_stationControllers, stationIndex),
              // Mutual exclusivity: only the row matching
              // `_expandedStationIndex` is expanded. The previous
              // `initiallyExpanded: isLive` would auto-expand every
              // station that had a team assigned in the current round,
              // which conflicts with one-row-at-a-time. The live
              // styling below (border, primaryContainer fill, play
              // icon) still makes active stations easy to spot when
              // collapsed.
              initiallyExpanded: _expandedStationIndex == stationIndex,
              onExpansionChanged: (expanded) => _handleExpansionChange(
                expanded: expanded,
                tappedIndex: stationIndex,
                pool: _stationControllers,
                readIndex: () => _expandedStationIndex,
                writeIndex: (v) => _expandedStationIndex = v,
              ),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: EdgeInsets.zero,
              iconColor: isLive ? colorScheme.primary : null,
              collapsedIconColor: isLive ? colorScheme.primary : null,
              textColor: isLive ? colorScheme.onPrimaryContainer : null,
              collapsedTextColor: isLive
                  ? colorScheme.onPrimaryContainer
                  : null,
              leading: isLive
                  ? Icon(Icons.play_circle_fill, color: colorScheme.primary)
                  : null,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      station.name,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: VerticalDividerWidget(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      localizations.team(1),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  ...List<Widget>.generate(_exercise!.schedule.length, (
                    roundIndex,
                  ) {
                    final isCurrent =
                        event.isRunning && roundIndex == event.currentRound;
                    final teamIndex =
                        _exercise!.teamIndex(stationIndex, roundIndex) + 1;
                    final none = teamIndex == 0;
                    return Container(
                      padding: EdgeInsets.all(4),
                      color: isCurrent
                          ? none
                                ? Colors.grey
                                : Colors.blueAccent
                          : Colors.transparent,
                      child: Text(
                        '${none ? '×' : teamIndex}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal, // Emphasize current round
                          color: isCurrent ? Colors.white : null,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              children: [_buildStationDetail(stationIndex)],
            ),
          );
        }),
      ),
    );
  }

  /// Inline detail for a station row in the coordinator station list. Shown
  /// when the user expands the [ExpansionTile] for that station. Shows
  /// description and a static map thumbnail centred on the station's
  /// position. The round-by-round time table is intentionally NOT repeated
  /// here — that information already lives in the round table above the
  /// SegmentedButton.
  Widget _buildStationDetail(int stationIndex) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final station = _exercise!.stations[stationIndex];
    final description = station.description;
    final hasPosition = station.position != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description != null && description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Text(description),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasPosition ? Icons.place : Icons.place_outlined,
                  color: hasPosition
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: hasPosition
                      ? PositionWidget(
                          wrapped: false,
                          format: PositionFormat.utm,
                          position: station.position,
                          style: theme.textTheme.bodyMedium,
                        )
                      : Text(
                          localizations.noLocation,
                          style: theme.textTheme.bodyMedium,
                        ),
                ),
              ],
            ),
          ),
          if (hasPosition)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 200,
                  // ValueKey gives each station its own MapView instance so
                  // expanding station A doesn't accidentally share map
                  // state with station B. PageStorageKey would collide
                  // with SelectableText scroll-state above — see the note
                  // on the ExpansionTile key further up.
                  child: MapView<int>(
                    key: ValueKey<String>(
                      'coordinator-station-map-$stationIndex',
                    ),
                    withCross: true,
                    initialZoom: 16,
                    initialCenter: station.position!,
                    layers: MapConfig.layers,
                    interactionFlags: MapConfig.static,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamList(ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    // See `_buildStationList`: rendered as a Column so the parent
    // SingleChildScrollView owns the scrolling. Team counts are bounded
    // by exercise configuration and stay small in practice.
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(event.exercise.numberOfTeams, (
          teamIndex,
        ) {
          // The team's current station, in plain text. Shown as the
          // ExpansionTile subtitle while the exercise is running so
          // the coordinator can read off where each team is without
          // scanning the rotation matrix column-by-column. The matrix
          // already highlights the current round, but the subtitle is
          // faster to read for exercises with many rounds.
          final currentStationIndex = event.isRunning
              ? _exercise!.stationIndex(teamIndex, event.currentRound)
              : -1;
          final currentStationName =
              (currentStationIndex >= 0 &&
                  currentStationIndex < _exercise!.stations.length)
              ? _exercise!.stations[currentStationIndex].name
              : null;
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              // Use ValueKey (not PageStorageKey) — see the comment
              // on the station ExpansionTile above for the reason.
              // Teams are NOT auto-expanded on "live": every team
              // always has a station via the rotation, so a naive
              // isLive check would expand every row at once. Leave
              // the team list collapsed and let the coordinator
              // pick which team to focus on.
              key: ValueKey<String>('coordinator-team-$teamIndex'),
              controller: _controllerFor(_teamControllers, teamIndex),
              // Mutual exclusivity: only one team row stays open at a
              // time. See `_handleExpansionChange` for how the prior
              // tile is collapsed.
              initiallyExpanded: _expandedTeamIndex == teamIndex,
              onExpansionChanged: (expanded) => _handleExpansionChange(
                expanded: expanded,
                tappedIndex: teamIndex,
                pool: _teamControllers,
                readIndex: () => _expandedTeamIndex,
                writeIndex: (v) => _expandedTeamIndex = v,
              ),
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: EdgeInsets.zero,
              subtitle: currentStationName == null
                  ? null
                  : Text(
                      '→ $currentStationName',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '${localizations.team(1)} ${teamIndex + 1}',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: VerticalDividerWidget(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      localizations.station(1),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  ...List<Widget>.generate(_exercise!.schedule.length, (
                    roundIndex,
                  ) {
                    final isCurrent =
                        event.isRunning && roundIndex == event.currentRound;
                    return TeamStationWidget(
                      isCurrent: isCurrent,
                      exercise: _exercise!,
                      teamIndex: teamIndex,
                      roundIndex: roundIndex,
                    );
                  }),
                ],
              ),
              children: [_buildTeamDetail(teamIndex, event)],
            ),
          );
        }),
      ),
    );
  }

  /// Inline detail for a team row in the coordinator team list. Shown when
  /// the user expands the [ExpansionTile] for that team. Lists the station
  /// rotation per round so the coordinator can track where the team is going
  /// without leaving the overview.
  Widget _buildTeamDetail(int teamIndex, ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List<Widget>.generate(_exercise!.schedule.length, (roundIndex) {
            final stationIndex = _exercise!.stationIndex(teamIndex, roundIndex);
            final none = stationIndex < 0;
            final title = none
                ? '${localizations.station(1)} ×'
                : _exercise!.stations[stationIndex].name;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: PhaseTile(
                  event: event,
                  title: title,
                  // Fixed width keeps station-name cells aligned across
                  // rounds so the drill/eval/roll columns line up
                  // vertically. Names longer than this are ellipsed.
                  titleWidth: 120,
                  roundIndex: roundIndex,
                  exercise: _exercise!,
                  mainAxisAlignment: MainAxisAlignment.start,
                  decoration: none ? TextDecoration.lineThrough : null,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final it in _subscriptions) {
      it.cancel();
    }
    super.dispose();
  }
}

/// Coloured rounded square that fronts each row in the "Next" card on
/// [CoordinatorScreen]. The colour comes from the mockup-aligned phase
/// palette in [_CoordinatorScreenState._phaseColor]; the icon sits in
/// the centre on a white-tinted surface so it stays legible regardless
/// of theme. Mirrors the `width: 36; height: 36; background: …` squares
/// in `docs/design/mockups/coordinator-oversikt.html`.
class _PhaseIconSquare extends StatelessWidget {
  const _PhaseIconSquare({
    required this.color,
    required this.icon,
    this.size = 44.0,
  });

  final Color color;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white, size: size * 24 / 44),
    );
  }
}

/// Animator that slides the [FloatingActionButton] between
/// [FloatingActionButtonLocation]s instead of the default scale-out /
/// scale-in. The position is interpolated with an ease-in-out curve and the
/// scale is held at `1.0`, so the FAB visually glides from the previous
/// location to the new one. This gives the same visual effect as a Hero
/// transition, but inside the Scaffold instead of across routes.
///
/// Used on [CoordinatorScreen] so the play/stop FAB glides from the corner
/// to the centre of the bottom status bar when an exercise starts (and back
/// when it stops), matching the player-style design in
/// `docs/design/mockups/coordinator-oversikt.html`.
class _SlideFloatingActionButtonAnimator extends FloatingActionButtonAnimator {
  const _SlideFloatingActionButtonAnimator();

  @override
  Offset getOffset({
    required Offset begin,
    required Offset end,
    required double progress,
  }) {
    final eased = Curves.easeInOut.transform(progress);
    return Offset.lerp(begin, end, eased)!;
  }

  @override
  Animation<double> getScaleAnimation({required Animation<double> parent}) =>
      const AlwaysStoppedAnimation<double>(1.0);

  @override
  Animation<double> getRotationAnimation({required Animation<double> parent}) =>
      const AlwaysStoppedAnimation<double>(1.0);
}
