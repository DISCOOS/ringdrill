import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/theme.dart';
import 'package:ringdrill/utils/context_extensions.dart';
import 'package:ringdrill/utils/exercise_share_format.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/subscription_bag.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/phase_headers.dart';
import 'package:ringdrill/views/phase_tile.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/team_form_screen.dart';
import 'package:ringdrill/views/team_station_widget.dart';
import 'package:ringdrill/views/vertical_divider_widget.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:ringdrill/views/widgets/station_role_summary.dart';

import 'exercise_control_button.dart';
import 'exercise_form_screen.dart';

/// Width of the combined hero card when it's used as a sidebar to the
/// right of the round table. Below this the colour squares plus the
/// label/time pair become hard to read, so the layout falls back to
/// the stacked variant.
const double _kHeroSidebarWidth = 150;
const double _kCoordinatorTwoColumnViewportWidth = 1120;
const double _kCoordinatorTwoColumnContentWidth = 900;
const double _kCoordinatorBodyPadding = 16;
const double _kCoordinatorWideTopSectionHeight = 300;

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

/// Entries in the appbar overflow menu. Edit and delete used to live as
/// standalone icon buttons next to brief and the notification bell, but
/// the four-icon row crowded the title out of the appbar on narrow
/// devices. These two actions are structural or destructive and rarely
/// used during an active exercise, so they're grouped behind a single
/// three-dot trigger. See [_CoordinatorScreenState.build] for the wiring.
enum _AppBarMenuAction { edit, delete }

class _CoordinatorScreenState extends State<CoordinatorScreen>
    with SubscriptionBag<CoordinatorScreen> {
  late bool _isStarted;

  final _programService = ProgramService();
  final _exerciseService = ExerciseService();
  Exercise? _exercise;
  bool _promptShowNotification = false;
  _CoordinatorView _view = _CoordinatorView.stations;

  // Mutual-exclusive expansion state for the station and team lists.
  // At most one row may be expanded in either list at any time.
  int? _expandedStationIndex;
  int? _expandedTeamIndex;

  void _toggleStation(int stationIndex) {
    setState(() {
      _expandedStationIndex = _expandedStationIndex == stationIndex
          ? null
          : stationIndex;
    });
  }

  void _toggleTeam(int teamIndex) {
    setState(() {
      _expandedTeamIndex = _expandedTeamIndex == teamIndex ? null : teamIndex;
    });
  }

  @override
  void initState() {
    _isStarted = _exerciseService.isStartedOn(widget.uuid);

    // Listen to ProgramService state changes
    listen(_programService.events, (event) {
      if (event.exercise?.uuid == widget.uuid) {
        if (mounted) {
          setState(() {
            _exercise = event.exercise;
          });
        }
      }
    });

    // Listen to ExerciseService state changes. The phase transition snackbar
    // that used to live here has been removed because the persistent
    // status-bar at the bottom of the screen already shows the same info
    // (round, phase, remaining time) more prominently and without dismissing
    // itself after a few seconds.
    // Re-read isStartedOn so that events from other exercises (e.g. a
    // different exercise starting) correctly flip _isStarted to false for
    // this coordinator without having to filter by UUID here.
    listen(_exerciseService.events, (_) {
      if (mounted) {
        setState(() {
          _isStarted = _exerciseService.isStartedOn(widget.uuid);
        });
      }
    });

    // Listen to Notification Events
    listen(
      NotificationService().events
          .where((_) => _exercise != null)
          .where((e) => e.action == NotificationAction.promptReshow)
          .where((e) => e.exercise?.uuid == _exercise?.uuid),
      (event) {
        if (mounted) {
          setState(() {
            _promptShowNotification = true;
          });
        }
      },
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
    final localizations = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: localizations.confirm,
      message: localizations.confirmDeleteExercise,
      confirmLabel: localizations.delete,
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
    final newExercise = await openFormSurface<Exercise>(
      context,
      builder: (context) => ExerciseFormScreen(
        exercise: _exercise,
        numberOfTeams: numberOfTeams == 0 ? null : numberOfTeams,
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
        // Only use the service event if it belongs to this exercise.
        // Events from a different running exercise must not bleed into
        // this coordinator's progress colours and phase display.
        final raw = asyncSnapshot.data;
        final event = (raw != null && raw.exercise.uuid == widget.uuid)
            ? raw
            : ExerciseEvent.pending(_programService.getExercise(widget.uuid)!);
        return Scaffold(
          appBar: AppBar(
            // Matches the other detail screens (`StationScreen`,
            // `TeamExerciseScreen`, `RolePlayScreen`) and the master
            // AppBar so the first content row aligns across master and
            // detail in the wide layout.
            toolbarHeight: kRingdrillHeaderHeight,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                if (MasterDetailScope.maybeOf(context) != null) {
                  ContextSheet.of(context).close();
                } else {
                  Navigator.pop(context);
                }
              },
              tooltip: localizations.briefClose,
            ),
            title: SheetTitle(primary: _exercise!.name),
            actions: rdAppBarActions(context, [
              // Open Brief — scoped to this exercise. Always visible
              // because the brief is the coordinator's reading material
              // both before and during the exercise.
              IconButton(
                icon: const Icon(Icons.menu_book),
                padding: const EdgeInsets.all(8.0),
                tooltip: localizations.briefAction,
                onPressed: () => ContextSheet.of(
                  context,
                ).show(context, BriefSheetTarget(exerciseUuid: widget.uuid)),
              ),

              // Notification re-show. `_promptShowNotification` is only
              // raised by NotificationService events scoped to this
              // exercise while it's running, so the bell has nothing to
              // do outside of an active run. Hiding it (rather than
              // showing it disabled) keeps the appbar uncluttered during
              // setup/reading and frees up horizontal space so the
              // exercise title stops getting ellipsized. The bell
              // reappears as a third icon once the coordinator presses
              // start, and toggles between enabled/disabled based on
              // whether there's an actual notification to reshow.
              if (_isStarted)
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

              // Overflow menu for edit + delete. These are admin actions
              // that the original layout kept as standalone icon buttons,
              // which pushed the title into ellipsis on narrow devices.
              // Both are guarded by `_isStarted` so they keep parity with
              // the previous disabled-during-run behaviour, just expressed
              // once on the menu trigger instead of on each icon button.
              PopupMenuButton<_AppBarMenuAction>(
                tooltip: localizations.moreActions,
                enabled: !_isStarted,
                position: PopupMenuPosition.under,
                onSelected: (action) {
                  switch (action) {
                    case _AppBarMenuAction.edit:
                      _editExercise(context);
                      break;
                    case _AppBarMenuAction.delete:
                      _deleteExercise(context);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<_AppBarMenuAction>(
                    value: _AppBarMenuAction.edit,
                    child: ListTile(
                      leading: const Icon(Icons.edit),
                      title: Text(localizations.editExercise),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                  PopupMenuItem<_AppBarMenuAction>(
                    value: _AppBarMenuAction.delete,
                    child: ListTile(
                      leading: const Icon(Icons.delete),
                      title: Text(localizations.deleteExercise),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
                ],
              ),
            ]),
            actionsPadding: EdgeInsets.only(right: 16.0),
          ),
          body: SafeArea(
            child: _exercise!.schedule.isEmpty
                ? Center(child: Text(localizations.noRoundsScheduled))
                : _buildBody(event),
          ),
          floatingActionButton:
              _isStarted && MasterDetailScope.maybeOf(context) == null
              ? ExerciseControlButton(
                  key: const ValueKey('coordinator-exercise-fab'),
                  exercise: _exercise!,
                  service: _exerciseService,
                  localizations: localizations,
                )
              : null,
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
    //
    // The Stack wrapper carries a single overlay action: a small copy
    // IconButton in the top-right corner that copies the full exercise
    // (header, meta, station list, rotation block) to the clipboard.
    // Placing it on the scroll body — not on the rotation table —
    // matches the user mental model that this action is about the
    // exercise as a whole. The button does not scroll with the content
    // because it lives as a sibling of the SingleChildScrollView inside
    // the Stack, so it stays anchored to the same screen position while
    // the coordinator scrolls through the round table and lists below.
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isTwoColumn =
                MediaQuery.sizeOf(context).width >=
                    _kCoordinatorTwoColumnViewportWidth &&
                constraints.maxWidth >= _kCoordinatorTwoColumnContentWidth;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(_kCoordinatorBodyPadding),
              child: isTwoColumn
                  ? _buildTwoColumnBody(
                      event,
                      showHero: showHero,
                      viewportHeight: constraints.maxHeight,
                    )
                  : _buildSingleColumnBody(
                      event,
                      showHero: showHero,
                      localizations: localizations,
                    ),
            );
          },
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Tooltip(
            message: localizations.exerciseCopyTooltip,
            child: IconButton(
              icon: const Icon(Icons.copy_all_outlined, size: 20),
              // Tight 36 px hit-box keeps the floating button compact
              // enough to coexist with the dense top section below it
              // without obscuring content. Still above the MD3 minimum
              // touch-target for secondary actions, and the long-press
              // on the rotation table remains as a forgiving fallback.
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              visualDensity: VisualDensity.compact,
              onPressed: () => _copyExerciseToClipboard(localizations),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleColumnBody(
    ExerciseEvent event, {
    required bool showHero,
    required AppLocalizations localizations,
  }) {
    return Column(
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
    );
  }

  Widget _buildTwoColumnBody(
    ExerciseEvent event, {
    required bool showHero,
    required double viewportHeight,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: _buildStationList(event)),
            const SizedBox(width: 24),
            Expanded(
              flex: 5,
              child: Align(
                alignment: Alignment.topCenter,
                child: _buildTopSection(event, showHero: showHero),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildExercisePositionMap(viewportHeight: viewportHeight),
        ),
      ],
    );
  }

  Widget _buildExercisePositionMap({required double viewportHeight}) {
    final markers = _exercise!.stations
        .where((station) => station.position != null)
        .map(
          (station) => MapMarkerSpec<int>(
            id: station.index,
            label: station.name,
            point: station.position!,
            child: const Icon(Icons.place, color: Colors.green, size: 32),
            onTap: () => ContextSheet.of(context).show(
              context,
              StationSheetTarget(
                exerciseUuid: widget.uuid,
                stationIndex: station.index,
              ),
            ),
          ),
        )
        .toList();
    if (markers.isEmpty) return const SizedBox.shrink();

    final points = markers.map((marker) => marker.point).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height:
            (viewportHeight -
                    _kCoordinatorBodyPadding * 2 -
                    _kCoordinatorWideTopSectionHeight)
                .clamp(240.0, double.infinity),
        child: MapView<int>(
          layers: MapConfig.layers,
          withZoom: true,
          withCenter: true,
          withToggle: true,
          withClustering: false,
          interactionFlags: MapConfig.interactive,
          initialZoom: 15,
          initialCenter: points.average(MapConfig.initialCenter),
          initialFit: points.fit(const EdgeInsets.all(72)),
          markers: markers,
        ),
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
    final localizations = AppLocalizations.of(context)!;
    final child = _buildTopSectionContent(event, showHero: showHero);
    if (_exerciseService.isStartedOn(widget.uuid)) return child;
    // In master-detail layout the play control lives in the master column;
    // don't add it here so the coordinator is purely informational.
    if (MasterDetailScope.maybeOf(context) != null) return child;
    return Stack(
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 72), child: child),
        Positioned(
          right: 0,
          bottom: 0,
          child: ExerciseControlButton(
            key: const ValueKey('coordinator-exercise-play'),
            exercise: _exercise!,
            service: _exerciseService,
            localizations: localizations,
          ),
        ),
      ],
    );
  }

  Widget _buildTopSectionContent(
    ExerciseEvent event, {
    required bool showHero,
  }) {
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
        : localizations
              .remainingInPhase(event.getState(localizations))
              .toUpperCase();
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

  Widget _buildRoundTable(ExerciseEvent event, bool isPortrait) {
    final localizations = AppLocalizations.of(context)!;
    // Long-press on the rotation table is kept as a forgiving shortcut
    // that triggers the same copy-exercise action as the floating
    // button in the top-right corner of the screen (see _buildBody).
    // Observers who learned the gesture in the original prototype
    // continue to get it; new users discover the button. Both
    // affordances copy the full exercise (header, meta, station list,
    // rotation block) so there's a single mental model. `behavior:
    // opaque` makes the gesture fire on the padded area too, not just
    // on tile pixels.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _copyExerciseToClipboard(localizations),
      child: Container(
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
      ),
    );
  }

  Future<void> _copyExerciseToClipboard(AppLocalizations localizations) async {
    final exercise = _exercise;
    if (exercise == null) return;
    final text = formatExerciseForShare(exercise, localizations);
    await Clipboard.setData(ClipboardData(text: text));
    // Light haptic so the user knows the gesture or tap registered
    // even when the SnackBar is hidden behind a soft keyboard or a
    // sheet.
    await HapticFeedback.selectionClick();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(localizations.exerciseCopied),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildStationList(ExerciseEvent event) {
    final localizations = context.l10n;
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
          // A station is "live" when the current round assigns a team to
          // it. The shared accent highlights the card so the active station
          // is recognisable even when collapsed.
          final isLive =
              event.isRunning &&
              _exercise!.teamIndex(stationIndex, event.currentRound) >= 0;
          final accent = LiveAccent.of(context, isLive: isLive);
          return Dismissible(
            key: ValueKey<String>('coordinator-station-dismiss-$stationIndex'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: context.colors.secondaryContainer,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    localizations.editStation,
                    style: TextStyle(
                      color: context.colors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.edit, color: context.colors.onSecondaryContainer),
                ],
              ),
            ),
            confirmDismiss: (_) async {
              await _editStation(stationIndex);
              return false;
            },
            child: ExpandableTile(
              onLongPress: () => _editStation(stationIndex),
              // Do NOT use a PageStorageKey here: any SelectableText below
              // (e.g. UtmWidget inside the station detail) reads from the
              // same bucket-path for its scroll offset, casting an
              // expansion bool to double? and crashing at
              // didChangeDependencies.
              key: ValueKey<String>('coordinator-station-$stationIndex'),
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
              accent: accent,
              leading: accent.indicator,
              title: Text(
                station.name,
                style: TextStyle(fontSize: 18, color: accent.foreground),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: VerticalDividerWidget(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      localizations.team(1),
                      style: TextStyle(fontSize: 18, color: accent.foreground),
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
                      padding: const EdgeInsets.all(4),
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
                              : FontWeight.normal,
                          color: isCurrent ? Colors.white : accent.foreground,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              expanded: _expandedStationIndex == stationIndex,
              onToggle: () => _toggleStation(stationIndex),
              body: _buildStationDetail(stationIndex),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _editStation(int stationIndex) async {
    final localizations = context.l10n;
    if (_isStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.stopExerciseFirst(_exercise!.name)),
        ),
      );
      return;
    }
    final updated = await openFormSurface<Station>(
      context,
      builder: (_) => StationFormScreen(
        station: _exercise!.stations[stationIndex],
        markers: _programService.getLocations().toMarkerSpecs(),
      ),
    );
    if (!mounted || updated == null) return;
    final stations = [..._exercise!.stations];
    stations[stationIndex] = updated;
    await _programService.saveExercise(
      localizations,
      _exercise!.copyWith(stations: stations),
    );
  }

  /// Inline detail for a station row in the coordinator station list. Shown
  /// when the user expands the [ExpandableTile] for that station. Shows
  /// description and a [StationPositionPanel] (label row + mini-map that
  /// opens the interactive bottom sheet). The round-by-round time table
  /// is intentionally NOT repeated here — that information already lives
  /// in the round table above the SegmentedButton.
  Widget _buildStationDetail(int stationIndex) {
    final station = _exercise!.stations[stationIndex];
    final description = station.description;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (description != null && description.isNotEmpty)
            InkWell(
              onTap: () => ContextSheet.of(context).show(
                context,
                StationSheetTarget(
                  exerciseUuid: widget.uuid,
                  stationIndex: stationIndex,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Text(description),
              ),
            ),
          // Shared panel handles both the "Posisjon ... pin coords"
          // label row and the tappable mini-map (which opens the
          // interactive variant in a bottom sheet). The ValueKey on
          // the embedded mini-map keeps each station's MapView state
          // isolated — without it, expanding station A and then B
          // would briefly share camera state. PageStorageKey would
          // collide with SelectableText scroll-state, hence ValueKey.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: StationPositionPanel(
              exercise: _exercise!,
              station: station,
              miniMapKey: ValueKey<String>(
                'coordinator-station-map-$stationIndex',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: StationRoleSummary(
              exercise: _exercise!,
              stationIndex: stationIndex,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamList(ExerciseEvent event) {
    final localizations = context.l10n;
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
          // ExpandableTile subtitle while the exercise is running so
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
          // A team is "live" when the exercise is live.
          // Mirrors the live styling used in TeamScreen._ExerciseSection.
          final isLive = event.isRunning;
          final accent = LiveAccent.of(context, isLive: isLive);
          final teamName =
              _programService.getTeam(teamIndex)?.name ??
              '${localizations.team(1)} ${teamIndex + 1}';
          return ExpandableTile(
            onLongPress: () => _editTeam(teamIndex),
            // Use ValueKey (not PageStorageKey) — see the comment
            // on the station ExpandableTile above for the reason.
            key: ValueKey<String>('coordinator-team-$teamIndex'),
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
            accent: accent,
            leading: accent.indicator,
            title: Text(
              teamName,
              style: TextStyle(fontSize: 18, color: accent.foreground),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: currentStationName == null
                ? null
                : Text(
                    '→ $currentStationName',
                    style:
                        accent.textStyle ??
                        TextStyle(
                          color: context.colors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: VerticalDividerWidget(),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    localizations.station(1),
                    style: TextStyle(fontSize: 18, color: accent.foreground),
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
            expanded: _expandedTeamIndex == teamIndex,
            onToggle: () => _toggleTeam(teamIndex),
            body: _buildTeamDetail(teamIndex, event),
          );
        }),
      ),
    );
  }

  Future<void> _editTeam(int teamIndex) async {
    final localizations = context.l10n;
    if (_isStarted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.stopExerciseFirst(_exercise!.name)),
        ),
      );
      return;
    }
    final team = _programService.getTeam(teamIndex);
    if (team == null) return;
    final updated = await openFormSurface<Team>(
      context,
      builder: (_) => TeamFormScreen(team: team),
    );
    if (!mounted || updated == null) return;
    await _programService.saveTeam(localizations, updated);
    if (mounted) setState(() {});
  }

  /// Inline detail for a team row in the coordinator team list. Shown when
  /// the user expands the [ExpandableTile] for that team. Lists the station
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
            // Mirror the description tap in _buildStationDetail: a round
            // card here represents "team T at station S in round R", so a
            // tap should open the same StationExerciseScreen the
            // station-list path leads to. Rounds where the team has no
            // station (`none`) keep their line-through styling and no
            // tap handler so the dead cell can't trigger navigation.
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: none
                    ? null
                    : () => ContextSheet.of(context).show(
                        context,
                        StationSheetTarget(
                          exerciseUuid: widget.uuid,
                          stationIndex: stationIndex,
                        ),
                      ),
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
              ),
            );
          }),
        ],
      ),
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
