import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/brief/field_resolver.dart' show formatUtm;
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/theme.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/context_extensions.dart';
import 'package:ringdrill/utils/exercise_share_format.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/subscription_bag.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';
import 'package:ringdrill/views/widgets/schedule_card.dart';
import 'package:ringdrill/views/widgets/schedule_table.dart';
import 'package:ringdrill/views/shell/master_detail_leading.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/team_form_screen.dart';
import 'package:ringdrill/views/team_station_widget.dart';
import 'package:ringdrill/views/vertical_divider_widget.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';
import 'package:ringdrill/views/widgets/notification_permission_help.dart';
import 'package:ringdrill/views/widgets/player_status_card.dart';
import 'package:ringdrill/views/widgets/reorderable_section.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:ringdrill/views/widgets/station_role_summary.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'exercise_form_screen.dart';
import 'plan_additions.dart';

const double _kCoordinatorBodyPadding = kPlayerSurfaceHorizontalPadding;

/// Capped width of the expanded body's left column (status card → schedule
/// card → segment → list) — sized for the compact stack, not the map pane.
/// It must not grow with the window, since the map to its right is the
/// pane meant to claim the extra width (B2).
const double _kCoordinatorExpandedLeftColumnWidth = 400;

class CoordinatorScreen extends StatefulWidget {
  final String uuid;

  const CoordinatorScreen({super.key, required this.uuid});

  @override
  State<CoordinatorScreen> createState() => _CoordinatorScreenState();
}

/// Which view the coordinator is currently looking at. Station rotations,
/// team rotations and (in the compact/medium bodies) an all-stations map
/// are mutually exclusive; the coordinator picks one via a SegmentedButton
/// at the top of the body. [map] is only offered in the compact/medium
/// bodies — the expanded body always shows the map beside the lists, so it
/// has no map segment.
enum _CoordinatorView { stations, teams, map }

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

  /// The effective plan-variable map (ADR-0046) at [exercise]'s scope,
  /// optionally narrowed to [station]'s — mirrors `StationExerciseScreen`.
  /// Empty when there is no active plan.
  Map<String, String> _overridesFor(Exercise exercise, {Station? station}) {
    final program = _programService.activeProgram;
    if (program == null) return const {};
    return effectivePlanVariables(
      program,
      exercise: exercise,
      station: station,
    );
  }

  /// The map view only exists in the compact/medium bodies. When the
  /// expanded body is shown it has no map segment, so a `map` selection
  /// (e.g. left over after a resize to expanded) falls back to the
  /// stations list/segment there.
  _CoordinatorView get _viewWithoutMap =>
      _view == _CoordinatorView.map ? _CoordinatorView.stations : _view;

  // Mutual-exclusive expansion state for the station and team lists.
  // At most one row may be expanded in either list at any time.
  int? _expandedStationIndex;
  int? _expandedTeamIndex;

  // Optimistic display of the committed station reorder order. Set
  // synchronously in onCommitReorder so the new order is shown immediately
  // without waiting for the async save round-trip. Cleared when the program
  // refresh event arrives (new data loaded from the service).
  List<Station>? _stagedStations;

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

    // Listen to ProgramService state changes. React to direct exercise events
    // (exerciseAdded, etc.) and to programRefreshed events (emitted by
    // reorderStations and reorderExercises which carry no exercise reference).
    listen(_programService.events, (event) {
      final directMatch = event.exercise?.uuid == widget.uuid;
      final isRefresh = event.type == ProgramEventType.programRefreshed;
      if (directMatch || isRefresh) {
        if (mounted) {
          setState(() {
            // Prefer the event's exercise object when available (avoids an
            // extra service lookup for the common case). Fall back to a fresh
            // load when the event carries no exercise (e.g. programRefreshed).
            _exercise =
                event.exercise ?? _programService.getExercise(widget.uuid);
            _stagedStations = null;
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

  /// Handles the notification bell in the running-exercise app bar.
  ///
  /// The bell has two jobs. Normally it re-posts the ongoing notification
  /// after iOS/Android has silently dropped it (the watchdog raises
  /// `promptReshow`). But it is also the coordinator's escape hatch when
  /// notifications simply are not coming through: if the OS permission has
  /// been denied — or the user never granted it — re-requesting is a no-op
  /// on iOS, so we send them to the Settings app with instructions instead.
  /// See ADR-0038.
  Future<void> _onShowNotificationPressed() async {
    final service = NotificationService();

    // Already hard-denied (or the plugin failed to initialise): iOS will
    // not show the system dialog again, so guide the user to Settings.
    if (service.permissionState == NotificationPermissionState.denied ||
        service.permissionState == NotificationPermissionState.pluginFailed) {
      if (!mounted) return;
      await showNotificationPermissionHelp(context);
      return;
    }

    // Otherwise (re)attach the plugin and re-post the notification. Tapping
    // the bell is an explicit opt-in, so record consent first — that lets
    // the OS permission prompt fire on first use even for devices that
    // never saw the first-launch consent stage.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.keyNotificationConsentAsked, true);
    await service.initFromPrefs(prefs);
    if (!mounted) return;

    // If the prompt was just declined (or the OS refused silently), fall
    // back to the Settings guidance rather than leaving the bell looking
    // like it did nothing.
    if (service.permissionState == NotificationPermissionState.denied ||
        service.permissionState == NotificationPermissionState.pluginFailed) {
      await showNotificationPermissionHelp(context);
      return;
    }

    setState(() {
      _promptShowNotification = false;
    });
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
    // Captured before the await: in compact layout openFormSurface dismisses
    // the hosting context sheet around the form push, which disposes this
    // State — the context is gone by the time the form pops. The save must
    // still run (ProgramService needs no context); only UI work below is
    // gated on mounted.
    final localizations = AppLocalizations.of(context)!;
    final numberOfTeams = _programService.loadTeams().length;
    // Navigate to the edit exercise screen
    final result = await openFormSurface<ExerciseFormResult>(
      context,
      builder: (context) => ExerciseFormScreen(
        exercise: _exercise,
        numberOfTeams: numberOfTeams == 0 ? null : numberOfTeams,
        variables: _programService.activeProgram?.variables ?? const [],
      ),
    );
    switch (result) {
      case null:
        return;
      case ExerciseFormSave(:final exercise, :final additions):
        // Apply the write-back (any variable created inline, ADR-0047) before
        // the exercise itself, so a chip the exercise's own save might
        // validate against is already declared.
        await applyVariableAdditionsToActiveProgram(_programService, additions);
        await _programService.saveExercise(localizations, exercise);
        if (!mounted) return;
        setState(() {
          _exercise = exercise;
        });
      case ExerciseFormDelete(:final exercise):
        await _programService.deleteExercise(exercise.uuid);
        // The exercise this coordinator showed is gone — close the viewer.
        if (mounted) Navigator.of(context).pop(false);
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
            leading: MasterDetailLeading(
              onClose: () {
                if (MasterDetailScope.maybeOf(context) != null) {
                  ContextSheet.of(context).close();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: SheetTitle(
              primary: _exercise!.name,
              primaryOverrides: _overridesFor(_exercise!),
            ),
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
                      ? () => unawaited(_onShowNotificationPressed())
                      : null,
                  tooltip: localizations.showNotification,
                ),

              // Edit + delete admin actions (both disabled during a run). On a
              // medium/expanded window there is room to show them as standalone
              // icons; on a compact window a long exercise title would
              // ellipsize, so they collapse into an overflow menu instead.
              if (WindowSizeClass.of(context).hasMasterDetail) ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  padding: const EdgeInsets.all(8.0),
                  tooltip: localizations.editExercise,
                  onPressed: _isStarted ? null : () => _editExercise(context),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  padding: const EdgeInsets.all(8.0),
                  tooltip: localizations.deleteExercise,
                  onPressed: _isStarted ? null : () => _deleteExercise(context),
                ),
              ] else
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
          // Standalone / modal player surface: the docked mini-player owns
          // play, stop and progress, so the floating control button is
          // dropped here. In master-detail the play control lives in the
          // master column and the mini-player is anchored there, so the
          // detail pane keeps the lightweight status strip instead.
          bottomNavigationBar: MasterDetailScope.maybeOf(context) == null
              ? DrillMiniPlayer(
                  key: const ValueKey('coordinator-mini-player'),
                  exercise: _exercise,
                  height: 64,
                  // Paint the accent background through the bottom safe-area
                  // inset so the home-indicator strip matches the bar instead
                  // of reading as a dark band below it.
                  applyBottomInset: true,
                  // The tile row owns the phase/countdown, so the trailing
                  // cluster collapses to just the stop button here.
                  showInlineStatus: false,
                  // We are already inside the player; tapping the bar
                  // should not try to re-open it.
                  onOpen: () {},
                  onPlay: () {
                    unawaited(HapticFeedback.mediumImpact());
                    _exerciseService.start(_exercise!);
                  },
                  onPickExercise: (picked) => ContextSheet.of(
                    context,
                  ).replace(ExerciseSheetTarget(exerciseUuid: picked.uuid)),
                  bodyBuilder: _buildMiniPlayerBody,
                )
              : _buildExerciseStatus(event),
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
    // The Stack wrapper carries a single overlay action: a small copy
    // IconButton in the top-right corner that copies the full exercise
    // (header, meta, station list, rotation block) to the clipboard.
    // Placing it on the body — not on the schedule card — matches the
    // user mental model that this action is about the exercise as a
    // whole. The button does not scroll with the content because it
    // lives as a sibling of the scrolling content inside the Stack, so
    // it stays anchored to the same screen position while the
    // coordinator scrolls through the schedule and lists below.
    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Derived from the body's own available width — not
            // `WindowSizeClass.of(context)` (the whole window) — so the
            // coordinator picks its layout off its actual pane width. Inside
            // the wide master/detail shell the coordinator lives in the
            // detail pane, which is narrower than the window (rail + master
            // claim the rest); reading the window there made the coordinator
            // believe it had far more room than it did and overflow trying
            // to render the expanded two-pane body inside a narrow pane.
            final windowSize = WindowSizeClass.fromWidth(constraints.maxWidth);
            // Expanded gets a dedicated two-pane body: a capped-width left
            // column (that itself scrolls) beside a map pane that fills
            // the remaining, full-height space — that only works with a
            // bounded outer height, so it is NOT wrapped in the shared
            // SingleChildScrollView the other two window sizes use, where
            // the whole screen (status/schedule/segment/list) scrolls as
            // one unit.
            if (windowSize == WindowSizeClass.expanded) {
              return _buildExpandedBody(
                event,
                showHero: showHero,
                localizations: localizations,
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(_kCoordinatorBodyPadding),
              child: _buildStackedBody(
                event,
                showHero: showHero,
                localizations: localizations,
                viewportHeight: constraints.maxHeight,
                sideBySideTop: windowSize == WindowSizeClass.medium,
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
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              visualDensity: VisualDensity.compact,
              onPressed: () => _copyExerciseToClipboard(localizations),
            ),
          ),
        ),
      ],
    );
  }

  /// Compact and medium body (B2): one scrolling column — top section,
  /// segment (with the `Kart` option), then the selected list. [sideBySideTop]
  /// is medium's only difference from compact: with the extra width, the
  /// status and schedule cards share a row instead of stacking.
  Widget _buildStackedBody(
    ExerciseEvent event, {
    required bool showHero,
    required AppLocalizations localizations,
    required double viewportHeight,
    required bool sideBySideTop,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sideBySideTop
            ? _buildSideBySideTopSection(event, showHero: showHero)
            : _buildTopSection(event, showHero: showHero),
        const SizedBox(height: 16),
        _buildViewSelector(localizations, includeMap: true),
        const SizedBox(height: 8),
        switch (_view) {
          _CoordinatorView.stations => _buildStationList(event),
          _CoordinatorView.teams => _buildTeamList(event),
          _CoordinatorView.map => _buildSingleColumnMap(event, viewportHeight),
        },
      ],
    );
  }

  /// Medium's top section (B2): the status card and schedule card side by
  /// side, both full "standard" cards (no shrink-wrap) — medium already has
  /// the room `WindowSizeClass.medium` implies, so no extra width threshold
  /// is needed here. Falls back to just the schedule card before start,
  /// same as the stacked variant.
  Widget _buildSideBySideTopSection(
    ExerciseEvent event, {
    required bool showHero,
  }) {
    if (!showHero) return _buildScheduleCard(event);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildScheduleCard(event)),
        const SizedBox(width: 16),
        Expanded(child: _buildCombinedHeroCard(event)),
      ],
    );
  }

  /// Expanded body (B2): a capped-width left column (status → schedule →
  /// segment → list, scrolling independently) beside a map pane that fills
  /// the remaining width and the full height. The segment drops `Kart`
  /// (`includeMap: false`) since the map is always visible here.
  Widget _buildExpandedBody(
    ExerciseEvent event, {
    required bool showHero,
    required AppLocalizations localizations,
  }) {
    final map = _buildExercisePositionMap(event);
    return Padding(
      padding: const EdgeInsets.all(_kCoordinatorBodyPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _kCoordinatorExpandedLeftColumnWidth,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopSection(event, showHero: showHero),
                  const SizedBox(height: 16),
                  _buildViewSelector(localizations, includeMap: false),
                  const SizedBox(height: 8),
                  _viewWithoutMap == _CoordinatorView.stations
                      ? _buildStationList(event)
                      : _buildTeamList(event),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: map ?? _buildMapPlaceholder(localizations)),
        ],
      ),
    );
  }

  /// Stations/teams switch shown at the top of the list. Shared by every
  /// body so all three window sizes keep the same way to reach the team
  /// rotations — without it the expanded body could only ever show
  /// stations.
  Widget _buildViewSelector(
    AppLocalizations localizations, {
    required bool includeMap,
  }) {
    // The map segment is only offered in the compact/medium bodies; the
    // expanded body always shows the map beside the lists instead.
    // `selected` is coerced via [_viewWithoutMap] so a stale `map` selection
    // does not feed SegmentedButton a value missing from its segments after
    // a resize.
    final selectedView = includeMap ? _view : _viewWithoutMap;
    final button = SegmentedButton<_CoordinatorView>(
      segments: [
        ButtonSegment<_CoordinatorView>(
          value: _CoordinatorView.stations,
          label: Text(
            '${localizations.stationsTab}'
            ' (${_exercise!.stations.length})',
          ),
          icon: const Icon(Icons.location_on),
        ),
        ButtonSegment<_CoordinatorView>(
          value: _CoordinatorView.teams,
          label: Text(
            '${localizations.team(_exercise!.numberOfTeams)}'
            ' (${_exercise!.numberOfTeams})',
          ),
          icon: const Icon(Icons.group),
        ),
        if (includeMap)
          ButtonSegment<_CoordinatorView>(
            value: _CoordinatorView.map,
            label: Text(localizations.mapTab),
            icon: const Icon(Icons.map),
          ),
      ],
      selected: <_CoordinatorView>{selectedView},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        setState(() => _view = selection.first);
      },
    );
    // Two segments comfortably fit and stay centered. The three-segment
    // (single-column) variant can still exceed a narrow phone's width once
    // the labels carry their counts, so wrap it in a horizontal
    // scroll view whose content is forced to at least the viewport width:
    // it centers when it fits and scrolls instead of overflowing when it
    // does not.
    if (!includeMap) return Center(child: button);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Center(child: button),
          ),
        );
      },
    );
  }

  /// Map subview for the compact/medium bodies, shown when the `Kart`
  /// segment is selected. Reuses the same all-stations map as the expanded
  /// body's permanent pane and falls back to a short placeholder when no
  /// station has a position yet.
  Widget _buildSingleColumnMap(ExerciseEvent event, double viewportHeight) {
    // The map renders below the top section (status/schedule + selector)
    // inside the scrolling body, so it must leave room for that content —
    // otherwise a near-full-viewport map pushes the page well past one
    // screen. Reserve a chunk for the chrome above so the map stays inside
    // the viewport rather than dominating it.
    final map = _buildExercisePositionMap(
      event,
      height: (viewportHeight - 320).clamp(240.0, double.infinity),
    );
    if (map == null) {
      return _buildMapPlaceholder(AppLocalizations.of(context)!);
    }
    return Padding(padding: const EdgeInsets.all(8.0), child: map);
  }

  /// Placeholder shown in place of the all-stations map when no station has
  /// a position yet — shared by the compact/medium `Kart` segment and the
  /// expanded body's permanent map pane.
  Widget _buildMapPlaceholder(AppLocalizations localizations) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Text(
          _exercise!.stations.isEmpty
              ? localizations.notStationsCreated
              : localizations.noLocation,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// All-stations map for this exercise. Returns null when no station has a
  /// position so callers can omit the block (expanded body) or show a
  /// placeholder (compact/medium `Kart` segment). [height] fixes the map
  /// box's height inside the scrolling compact/medium body; left `null` for
  /// the expanded body's pane, which fills whatever height its `Expanded`
  /// ancestor gives it instead.
  Widget? _buildExercisePositionMap(ExerciseEvent event, {double? height}) {
    final markers = <MapMarkerSpec<int>>[];
    final format =
        ProgramService().activeProgram?.stationNumberFormat ??
        StationNumberFormat.dotted;
    final exNum =
        ProgramService().loadExercises().indexWhere(
          (e) => e.uuid == _exercise!.uuid,
        ) +
        1;
    final exerciseNumber = exNum < 1 ? 1 : exNum;
    for (
      var stationIndex = 0;
      stationIndex < _exercise!.stations.length;
      stationIndex++
    ) {
      final station = _exercise!.stations[stationIndex];
      if (!station.position.isFiniteOrNull) continue;
      // Same "live" test as the station list: the current round assigns a
      // team to this station. Live pins switch to the orange live accent so
      // the map matches the highlighted rows in the player.
      final isLive =
          event.isRunning &&
          _exercise!.teamIndex(stationIndex, event.currentRound) >= 0;
      markers.add(
        MapMarkerSpec<int>(
          id: station.index,
          label:
              resolveScopedField(
                context,
                station.numberAndName(format, exerciseNumber: exerciseNumber),
                overrides: _overridesFor(_exercise!, station: station),
              ) ??
              station.numberAndName(format, exerciseNumber: exerciseNumber),
          point: station.position!,
          highlighted: isLive,
          child: Icon(
            Icons.place,
            color: isLive ? RingDrillColors.brandAccent : Colors.green,
            size: 32,
          ),
          onTap: () => ContextSheet.of(context).show(
            context,
            StationSheetTarget(
              exerciseUuid: widget.uuid,
              stationIndex: station.index,
            ),
          ),
        ),
      );
    }
    if (markers.isEmpty) return null;

    final points = markers.map((marker) => marker.point).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: height,
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
                    fontSize: kDrillAccentFontSize,
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
                  fontSize: kDrillAccentFontSize,
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

  /// Top of the body: the same shared status-card + schedule-card stack
  /// the Post/Lag/Spill players use (DESIGN-010 follow-up), full width of
  /// their container. `showHero` is only true once the coordinator has
  /// started the exercise — before start there's nothing to show "now /
  /// next" for, so only the schedule card is shown.
  Widget _buildTopSection(ExerciseEvent event, {required bool showHero}) {
    // Play and stop now live in the docked mini-player (or, in
    // master-detail, in the master column), so the top section is purely
    // informational in every layout.
    return _buildTopSectionContent(event, showHero: showHero);
  }

  /// Override for [DrillMiniPlayer]'s central area (replacing the default
  /// round row, which would duplicate the rotation table). Pending: show
  /// when the exercise starts. Running: show elapsed/total alongside the
  /// finish time, mirroring the total-progress strip below.
  /// Override for [DrillMiniPlayer]'s central area: a row of tiles (big
  /// value, small subtitle). Pending shows the wait countdown and start
  /// time; running shows elapsed/total, round and the phase countdown.
  /// [remainingSeconds] is the per-second-smoothed phase countdown so the
  /// "Fase"/"VENT" tile ticks rather than jumping per minute.
  Widget _buildMiniPlayerBody(
    BuildContext context,
    ExerciseEvent event,
    int remainingSeconds,
    int elapsedSeconds,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final accent = LiveAccent.of(context, isLive: true);
    final fg =
        accent.foreground ?? Theme.of(context).colorScheme.onPrimaryContainer;
    final exercise = event.exercise;

    // One `now` shared by the clock tile and the phase countdown so they
    // tick on the same instant. The service schedules phases on whole
    // wall-clock minutes, so we anchor the countdown to the whole minute of
    // the event rather than its exact (sub-second) emission time — that
    // keeps the countdown seconds the exact complement of the clock seconds
    // instead of drifting by ±1s. The smoothed `remainingSeconds` from the
    // player is still used to tell idle (0) from a ticking pending state.
    final now = DateTime.now();
    final whenMinute = DateTime(
      event.when.year,
      event.when.month,
      event.when.day,
      event.when.hour,
      event.when.minute,
    );
    final phaseRemaining = whenMinute
        .add(Duration(minutes: event.remainingTime))
        .difference(now)
        .inSeconds
        .clamp(0, 1 << 30);

    if (event.isPending) {
      // Idle (not started yet) carries no live countdown, so only the
      // scheduled start time is shown. Once pending starts ticking
      // (remainingSeconds > 0) the wait countdown joins it.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (remainingSeconds > 0) ...[
                _buildMiniTile(
                  context,
                  value: _formatCountdown(phaseRemaining),
                  subtitle: event.getState(localizations),
                  fg: fg,
                ),
                const SizedBox(width: 32),
              ],
              _buildMiniTile(
                context,
                value: exercise.startTime.toString(),
                subtitle: localizations.startTime,
                fg: fg,
              ),
              const SizedBox(width: 32),
              _buildMiniTile(
                context,
                value: _formatClock(now),
                subtitle: localizations.clockLabel,
                fg: fg,
              ),
            ],
          ),
        ),
      );
    }

    final totalMinutes =
        exercise.numberOfRounds *
        (exercise.executionTime +
            exercise.evaluationTime +
            exercise.rotationTime);
    final totalSeconds = totalMinutes * 60;
    final clampedElapsed = elapsedSeconds.clamp(0, totalSeconds);
    // All tiles are grouped on the right, next to the stop button, so only
    // the exercise badge sits on the left. 32px between tiles. The row is
    // horizontally scrollable (reverse, so it pins to the right and reveals
    // the leftmost tiles on scroll) — same overflow handling as the default
    // MiniRoundRow, instead of clipping when the tiles get wide.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMiniTile(
              context,
              value: _formatDuration(localizations, clampedElapsed),
              subtitle: localizations.elapsedLabel,
              fg: fg,
            ),
            const SizedBox(width: 32),
            _buildMiniTile(
              context,
              value: _formatDuration(localizations, totalSeconds),
              subtitle: localizations.totalLabel,
              fg: fg,
            ),
            const SizedBox(width: 32),
            _buildMiniTile(
              context,
              value: localizations.roundOfTotal(
                event.currentRound + 1,
                exercise.numberOfRounds,
              ),
              subtitle: localizations.round(1),
              fg: fg,
            ),
            const SizedBox(width: 32),
            _buildMiniTile(
              context,
              value: _formatClock(now),
              subtitle: localizations.clockLabel,
              fg: fg,
            ),
            const SizedBox(width: 32),
            _buildMiniTile(
              context,
              value: _formatCountdown(phaseRemaining),
              subtitle: event.getState(localizations),
              fg: fg,
            ),
          ],
        ),
      ),
    );
  }

  /// One mini-player tile: a large value over a small subtitle.
  Widget _buildMiniTile(
    BuildContext context, {
    required String value,
    required String subtitle,
    required Color fg,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: fg.withValues(alpha: 0.7),
            letterSpacing: 0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Wall-clock `HH:MM` label for the current-time tile.
  String _formatClock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Human-readable duration label for the elapsed/total tiles:
  /// under a minute "x sek", under an hour "x min", whole hours
  /// "1 time"/"2 timer", and hours with a remainder "2 t 30 min".
  String _formatDuration(AppLocalizations localizations, int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    if (s < 60) return localizations.second(s);
    final totalMinutes = s ~/ 60;
    if (totalMinutes < 60) return localizations.minute(totalMinutes);
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (m == 0) return localizations.hour(h);
    return localizations.hoursMinutesShort(h, m);
  }

  /// Countdown label from seconds. Under an hour reads `MM:SS`; an hour or
  /// more collapses to `H:MM` so the tile stays narrow (the phase-name
  /// subtitle disambiguates it from a wall-clock time).
  String _formatCountdown(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    if (s >= 3600) {
      final h = s ~/ 3600;
      final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
      return '$h:$m';
    }
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  Widget _buildTopSectionContent(
    ExerciseEvent event, {
    required bool showHero,
  }) {
    if (!showHero) return _buildScheduleCard(event);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCombinedHeroCard(event),
        const SizedBox(height: 12),
        _buildScheduleCard(event),
      ],
    );
  }

  /// The coordinator's [PlayerStatusCard] — no "Nå" cell (the current
  /// phase is already in the countdown line), so both now/next cells are
  /// forward-looking: "Neste fase" (the next phase and its start time)
  /// and "Neste runde" (the next round and its start time). Both are
  /// omitted once there is no further phase/round to report (the last
  /// phase of the last round).
  Widget _buildCombinedHeroCard(ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    final exercise = _exercise!;
    final (nextPhase, nextRound) = _coordinatorNowNext(event, localizations);
    return PlayerStatusCard(
      event: event,
      preStartSubline: localizations.statusPreStartSubline(
        exercise.startTime.toString(),
        exercise.numberOfRounds,
      ),
      leadingCell: nextPhase,
      trailingCell: nextRound,
    );
  }

  /// Computes the coordinator's two forward-looking cells from
  /// `Exercise.schedule` — the next phase in the current round (or, for
  /// the last phase, the next round's first phase) and the next round
  /// after the current one. Either (or both) falls back to
  /// [finishFallbackCell] once there is nothing further of its own to
  /// report (last phase of the last round / last round already running).
  /// Both are `null` together only when the card isn't showing the running
  /// layout at all (`!event.isRunning`).
  ///
  /// Both cells share the plain "Neste" label with no icon — the phase/
  /// round distinction is carried by the value ("EVAL" vs "Runde 2") and
  /// the inline "· HH:MM" time, not the label, so the two half-card cells
  /// don't overflow the way "Neste fase"/"Neste runde" plus an icon did.
  (PlayerStatusCell?, PlayerStatusCell?) _coordinatorNowNext(
    ExerciseEvent event,
    AppLocalizations localizations,
  ) {
    if (!event.isRunning) return (null, null);
    final exercise = _exercise!;
    final phaseIdx = event.phase.index - 1;
    final roundIdx = event.currentRound;
    final isLastRound = roundIdx >= exercise.numberOfRounds - 1;

    final PlayerStatusCell nextPhaseCell;
    if (phaseIdx < 2 || !isLastRound) {
      final nextPhaseIdx = phaseIdx < 2 ? phaseIdx + 1 : 0;
      final nextPhaseRound = phaseIdx < 2 ? roundIdx : roundIdx + 1;
      final nextPhaseName = switch (nextPhaseIdx) {
        0 => localizations.drill,
        1 => localizations.eval,
        _ => localizations.roll,
      }.toUpperCase();
      nextPhaseCell = PlayerStatusCell(
        label: localizations.nextLabel,
        time: exercise.schedule[nextPhaseRound][nextPhaseIdx].toString(),
        value: nextPhaseName,
      );
    } else {
      nextPhaseCell = finishFallbackCell(localizations, exercise);
    }

    final PlayerStatusCell nextRoundCell;
    if (!isLastRound) {
      nextRoundCell = PlayerStatusCell(
        label: localizations.nextLabel,
        time: exercise.schedule[roundIdx + 1][0].toString(),
        value: '${localizations.round(1)} ${roundIdx + 2}',
      );
    } else {
      nextRoundCell = finishFallbackCell(localizations, exercise);
    }
    return (nextPhaseCell, nextRoundCell);
  }

  /// The coordinator's schedule card — the same [ScheduleCard] the
  /// Post/Lag/Spill players build, full width, replacing the old
  /// shrink-wrapped round table (DESIGN-010 follow-up).
  Widget _buildScheduleCard(ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    // Long-press on the schedule card is kept as a forgiving shortcut
    // that triggers the same copy-exercise action as the floating
    // button in the top-right corner of the screen (see _buildBody).
    // Observers who learned the gesture in the original prototype
    // continue to get it; new users discover the button. Both
    // affordances copy the full exercise (header, meta, station list,
    // rotation block) so there's a single mental model. `behavior:
    // opaque` makes the gesture fire on the card's padded area too, not
    // just on tile pixels.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _copyExerciseToClipboard(localizations),
      child: ScheduleCard(
        sectionId: 'coordinatorSchedule',
        title: localizations.stationTimingCardTitle,
        // "Round", not localizations.schedule ("Schedule"/"Plan") — the
        // card title already says "Tidsplan"/"Schedule", so repeating it
        // as the first column's header is redundant. Every row here is one
        // round, so "Round"/"Runde" describes the column instead.
        headerLabel: localizations.round(1),
        labelWidth: 90,
        event: event,
        exercise: _exercise!,
        rows: [
          for (
            var roundIndex = 0;
            roundIndex < _exercise!.schedule.length;
            roundIndex++
          )
            ScheduleTableRow(
              roundIndex: roundIndex,
              label: '${localizations.round(1)} ${roundIndex + 1}',
            ),
        ],
      ),
    );
  }

  Future<void> _copyExerciseToClipboard(AppLocalizations localizations) async {
    final exercise = _exercise;
    if (exercise == null) return;
    final text = formatExerciseForShare(
      exercise,
      localizations,
      variables: _overridesFor(exercise),
    );
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
    final exercise = _exercise!;
    // Use staged stations (synchronous post-commit display) when available so
    // the new order is shown immediately after Done without snap-back.
    // _stagedStations is cleared when the programRefreshed event arrives.
    final stations = _stagedStations ?? exercise.stations;

    // Resolve the exercise's 1-based number the same way the Stations segment
    // does — by position in the unfiltered exercise list — so the badge label
    // matches what the Stations segment shows (ADR-0036 §"Coordinator station
    // badge").
    final exerciseNumber =
        (_programService.loadExercises().indexWhere(
          (e) => e.uuid == exercise.uuid,
        ) +
        1);

    Widget buildStationRow(
      BuildContext context,
      Station station,
      int position,
      bool reordering,
      Widget dragHandle,
    ) {
      // The station's list position equals its index (rotation math invariant).
      final stationIndex = position;
      // A station is "live" when the current round assigns a team to it.
      final isLive =
          event.isRunning &&
          exercise.teamIndex(stationIndex, event.currentRound) >= 0;
      final accent = LiveAccent.of(context, isLive: isLive);

      final badge = StationNumberBadge(
        label: Numbering.station(
          _programService.activeProgram?.stationNumberFormat ??
              StationNumberFormat.dotted,
          exerciseNumber: exerciseNumber,
          // Use position (list index) so the badge renumbers live during a
          // drag, matching the exercises-list behaviour (ADR-0035, ADR-0036).
          stationIndex: position,
        ),
        highlight: isLive,
      );

      // The rotation schedule shown as a trailing row of team assignments.
      final scheduleRow = Row(
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
              style: TextStyle(
                fontSize: kDrillAccentFontSize,
                color: accent.foreground,
              ),
            ),
          ),
          ...List<Widget>.generate(exercise.schedule.length, (roundIndex) {
            final isCurrent =
                event.isRunning && roundIndex == event.currentRound;
            final teamIndex = exercise.teamIndex(stationIndex, roundIndex) + 1;
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
                  fontSize: kDrillAccentFontSize,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent ? Colors.white : accent.foreground,
                ),
              ),
            );
          }),
        ],
      );

      // In reorder mode: show drag handle, suspend gestures (ADR-0031).
      if (reordering) {
        return ExpandableTile(
          key: ValueKey<String>('coordinator-station-${station.index}'),
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          accent: accent,
          leading: badge,
          title: RingDrillText(
            station.name,
            overrides: _overridesFor(exercise, station: station),
            style: TextStyle(
              fontSize: kDrillAccentFontSize,
              color: accent.foreground,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: dragHandle,
          // No onOpen, onLongPress, onToggle — gestures suspended in reorder mode.
        );
      }

      return Dismissible(
        key: ValueKey<String>('coordinator-station-dismiss-${station.index}'),
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
                style: TextStyle(color: context.colors.onSecondaryContainer),
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
          // expansion bool to double? and crashing at didChangeDependencies.
          key: ValueKey<String>('coordinator-station-${station.index}'),
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          accent: accent,
          leading: badge,
          title: RingDrillText(
            station.name,
            overrides: _overridesFor(exercise, station: station),
            style: TextStyle(
              fontSize: kDrillAccentFontSize,
              color: accent.foreground,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: scheduleRow,
          expanded: _expandedStationIndex == stationIndex,
          // House rule (all ExpandableTiles): tap the row opens the
          // sheet, the chevron is the only expand affordance. Even on
          // CoordinatorScreen — which is itself the exercise view — we
          // route through the station sheet so the surface stays
          // consistent with Poster/Øvelser/Markører/Lag.
          onOpen: () => ContextSheet.of(context).show(
            context,
            StationSheetTarget(
              exerciseUuid: widget.uuid,
              stationIndex: station.index,
            ),
          ),
          onToggle: () => _toggleStation(stationIndex),
          body: _buildStationDetail(stationIndex),
        ),
      );
    }

    // Use shrinkWrap so the section works inside the coordinator's
    // SingleChildScrollView. Reorder is gated by !_isStarted (same guard as
    // _editStation) so the toggle is absent while a session is live.
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ReorderableSection<Station>(
        shrinkWrap: true,
        items: stations,
        keyOf: (s) => ValueKey('coordinator-station-${s.index}'),
        orderLabel: context.l10n.exerciseSortBy,
        enabled: !_isStarted,
        onCommitReorder: (newOrder) {
          // Show the new order immediately (synchronous), then persist async.
          setState(() => _stagedStations = newOrder);
          final orderedOldIndices = newOrder.map((s) => s.index).toList();
          _programService.reorderStations(exercise.uuid, orderedOldIndices);
        },
        itemBuilder: buildStationRow,
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
    // DESIGN-009 prompt 5/4j: the delete-guard, save-block and the Persons
    // section's inline marker row all need to know which roleplays are
    // already linked to this station.
    final roleplays = _programService
        .loadRolePlays()
        .where(
          (r) =>
              r.exerciseUuid == _exercise!.uuid &&
              r.stationIndex == stationIndex,
        )
        .toList();
    final result = await openFormSurface<StationFormResult>(
      context,
      builder: (_) => StationFormScreen(
        station: _exercise!.stations[stationIndex],
        markers: _programService.getLocations().toMarkerSpecs(),
        variables: _programService.activeProgram?.variables ?? const [],
        parentExercise: _exercise,
        roleplays: roleplays,
      ),
    );
    // No mounted gate on the save: openFormSurface disposes this State when
    // it dismisses the hosting context sheet around the form push.
    if (result == null) return;
    await applyVariableAdditionsToActiveProgram(
      _programService,
      result.additions,
    );
    // A marker authored/edited inline from the Persons section's "Legg til
    // markør" / "Spilles av {navn}" row (DESIGN-009 prompt 4j) — held in
    // the post editor's own working copy, written back here alongside the
    // station's own save.
    await applyPendingRolePlayAdditions(
      _programService,
      localizations,
      result.additions,
    );
    final stations = [..._exercise!.stations];
    stations[stationIndex] = result.station;
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
    // Seed this station's own ExerciseScope/StationScope (mirroring
    // station_list_view.dart's per-tile scope) so `{{station.*}}` — e.g.
    // `{{station.position.utm}}` — resolves in the expanded card instead of
    // showing literally.
    return ExerciseScope(
      exercise: _exercise!,
      variableOverrides: _exercise!.variableOverrides,
      child: StationScope(
        locations: station.locations,
        persons: station.persons,
        name: station.name,
        description: station.description,
        variantSuffix: station.variantSuffix,
        positionUtm: formatUtm(station.position),
        child: Padding(
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
                child: RingDrillText(
                  description,
                  overrides: _overridesFor(_exercise!, station: station),
                ),
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
        ),
      ),
    );
  }

  Widget _buildTeamList(ExerciseEvent event) {
    final localizations = context.l10n;
    final format =
        ProgramService().activeProgram?.stationNumberFormat ??
        StationNumberFormat.dotted;
    final exNum =
        ProgramService().loadExercises().indexWhere(
          (e) => e.uuid == _exercise!.uuid,
        ) +
        1;
    final exerciseNumber = exNum < 1 ? 1 : exNum;
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
              ? _exercise!.stations[currentStationIndex].numberAndName(
                  format,
                  exerciseNumber: exerciseNumber,
                )
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
              style: TextStyle(
                fontSize: kDrillAccentFontSize,
                color: accent.foreground,
              ),
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
                    style: TextStyle(
                      fontSize: kDrillAccentFontSize,
                      color: accent.foreground,
                    ),
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
            // House rule (all ExpandableTiles): tap row opens sheet,
            // chevron is the only expand affordance. CoordinatorScreen
            // routes to the team-in-exercise player view so the rule
            // holds across Poster/Øvelser/Markører/Lag/Spill.
            onOpen: () => ContextSheet.of(context).show(
              context,
              TeamSheetTarget(exerciseUuid: widget.uuid, teamIndex: teamIndex),
            ),
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
    // No mounted gate on the save: openFormSurface disposes this State when
    // it dismisses the hosting context sheet around the form push.
    if (updated == null) return;
    await _programService.saveTeam(localizations, updated);
    if (mounted) setState(() {});
  }

  /// Inline detail for a team row in the coordinator team list. Shown when
  /// the user expands the [ExpandableTile] for that team. Lists the station
  /// rotation per round so the coordinator can track where the team is going
  /// without leaving the overview.
  Widget _buildTeamDetail(int teamIndex, ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    final format =
        ProgramService().activeProgram?.stationNumberFormat ??
        StationNumberFormat.dotted;
    final exNum =
        ProgramService().loadExercises().indexWhere(
          (e) => e.uuid == _exercise!.uuid,
        ) +
        1;
    final exerciseNumber = exNum < 1 ? 1 : exNum;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: ScheduleCard(
        sectionId: 'coordinatorTeamDetailSchedule',
        title: localizations.stationTimingCardTitle,
        // "Round", not localizations.schedule — see the coordinator's own
        // round-table ScheduleCard above for why.
        headerLabel: localizations.round(1),
        labelWidth: 78,
        event: event,
        exercise: _exercise!,
        rows: List<ScheduleTableRow>.generate(_exercise!.schedule.length, (
          roundIndex,
        ) {
          final stationIndex = _exercise!.stationIndex(teamIndex, roundIndex);
          final none = stationIndex < 0;
          return ScheduleTableRow(
            roundIndex: roundIndex,
            label: none
                ? '${localizations.station(1)} ×'
                : _exercise!.stations[stationIndex].numberAndName(
                    format,
                    exerciseNumber: exerciseNumber,
                  ),
            muted: none,
            // Mirror the description tap in _buildStationDetail: a round
            // row here represents "team T at station S in round R", so a
            // tap should open the same StationExerciseScreen the
            // station-list path leads to. Rounds where the team has no
            // station (`none`) get no tap handler so the dead cell can't
            // trigger navigation.
            onTap: none
                ? null
                : () => ContextSheet.of(context).show(
                    context,
                    StationSheetTarget(
                      exerciseUuid: widget.uuid,
                      stationIndex: stationIndex,
                    ),
                  ),
          );
        }),
      ),
    );
  }
}
