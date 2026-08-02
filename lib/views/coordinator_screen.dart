import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/views/round_occupancy.dart';
import 'package:ringdrill/views/widgets/exercise_mode_field.dart';
import 'package:ringdrill/views/widgets/app_brief_labels.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/edit_permissions.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/theme.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/context_extensions.dart';
import 'package:ringdrill/utils/exercise_share_format.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/prefs.dart';
import 'package:ringdrill/utils/subscription_bag.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';
import 'package:ringdrill/views/loader_state.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/shell/closable_surface.dart';
import 'package:ringdrill/views/shell/detail_empty_pane.dart';
import 'package:ringdrill/views/shell/master_detail_leading.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/team_form_screen.dart';
import 'package:ringdrill/views/team_station_widget.dart';
import 'package:ringdrill/views/vertical_divider_widget.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/edit_affordance.dart';
import 'package:ringdrill/views/widgets/exercise_description_card.dart';
import 'package:ringdrill/views/widgets/exercise_mini_map.dart'
    show exerciseStationMarkers, ExerciseMapSheetHeader;
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';
import 'package:ringdrill/views/widgets/map_placeholder.dart';
import 'package:ringdrill/views/widgets/notification_permission_help.dart';
import 'package:ringdrill/views/widgets/plan_text.dart';
import 'package:ringdrill/views/widgets/player_status_card.dart';
import 'package:ringdrill/views/widgets/reorderable_section.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';
import 'package:ringdrill/views/widgets/schedule_card.dart';
import 'package:ringdrill/views/widgets/schedule_table.dart';
import 'package:ringdrill/views/widgets/view_segments.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';
import 'package:ringdrill/views/widgets/station_number_badge.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:ringdrill/views/widgets/station_role_summary.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';

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
enum _CoordinatorView { info, stations, teams, map }

/// Entries in the appbar overflow menu. Edit and delete used to live as
/// standalone icon buttons next to brief and the notification bell, but
/// the four-icon row crowded the title out of the appbar on narrow
/// devices. These two actions are structural or destructive and rarely
/// used during an active exercise, so they're grouped behind a single
/// three-dot trigger. See [_CoordinatorScreenState.build] for the wiring.
enum _AppBarMenuAction { edit, delete }

class _CoordinatorScreenState extends State<CoordinatorScreen>
    with
        SubscriptionBag<CoordinatorScreen>,
        ClosableSurface<CoordinatorScreen>,
        Loader<CoordinatorScreen, Exercise, PlanEvent> {
  final _planService = PlanService();
  final _exerciseService = ExerciseService();

  bool _isStarted = false;
  bool _promptShowNotification = false;
  _CoordinatorView _view = _CoordinatorView.stations;

  /// The effective plan-variable map (ADR-0046) at [exercise]'s scope,
  /// optionally narrowed to [station]'s — mirrors `StationScreen`.
  /// Empty when there is no active plan.
  Map<String, String> _overridesFor(Exercise exercise, {Station? station}) {
    final plan = _planService.activePlan;
    if (plan == null) return const {};
    return effectivePlanVariables(plan, exercise: exercise, station: station);
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
  // without waiting for the async save round-trip. Cleared when the plan
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
    super.initState();

    load();

    // Listen to ExerciseService state changes. The phase transition snackbar
    // that used to live here has been removed because the persistent
    // status-bar at the bottom of the screen already shows the same info
    // (round, phase, remaining time) more prominently and without dismissing
    // itself after a few seconds.
    // Re-read isStartedOn so that events from other exercises (e.g. a
    // different exercise starting) correctly flip _isStarted to false for
    // this coordinator without having to filter by UUID here.
    listen(_exerciseService.events, (_) {
      if (!mounted) return;
      setState(onLoaded);
    });

    // Listen to PlanService state changes. React to direct exercise events
    // (exerciseAdded, etc.) and to planRefreshed events (emitted by
    // reorderStations and reorderExercises which carry no exercise reference).
    listen(_planService.events, (event) {
      if (!mounted) return;
      if (_rendersChangesFrom(event)) reload(event);
    });

    // Listen to Notification Events
    listen(
      NotificationService().events
          .where((_) => loadState is Loaded<Exercise>)
          .where((e) => e.action == NotificationAction.promptReshow)
          .where((e) => e.exercise?.uuid == widget.uuid),
      (event) {
        if (mounted) {
          setState(() {
            _promptShowNotification = true;
          });
        }
      },
    );
  }

  /// Whether [event] can change anything this screen shows.
  ///
  /// Its own exercise, plus any team mutation: the team list and team detail
  /// read names through `PlanService.getTeam`, and `teamSaved` carries only a
  /// team — so an exercise-only test would leave a team renamed elsewhere
  /// showing its old name. Actors are not rendered here, unlike the station and
  /// roleplay viewers, so actor events are ignored.
  bool _rendersChangesFrom(PlanEvent event) =>
      event.type == PlanEventType.planRefreshed ||
      event.exercise?.uuid == widget.uuid ||
      event.team != null;

  @override
  void onLoaded() {
    _isStarted = _exerciseService.isStartedOn(widget.uuid);
    // A fresh load supersedes any staged (drag-in-progress) station order.
    _stagedStations = null;
  }

  @override
  Exercise? onLoad(PlanEvent? event) {
    // Prefer the event's exercise object when available (avoids an
    // extra service lookup for the common case). Fall back to a fresh
    // load when the event carries no exercise (e.g. planRefreshed).
    return event?.exercise ?? _planService.getExercise(widget.uuid);
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
    await Prefs.setBool(AppConfig.keyNotificationConsentAsked, true);
    await service.initFromPrefs(Prefs.instance);
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
  void _deleteExercise(BuildContext context, Exercise exercise) async {
    final localizations = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: localizations.confirm,
      message: localizations.confirmDeleteExercise,
      confirmLabel: localizations.delete,
    );

    if (context.mounted && confirmed) {
      await _planService.deleteExercise(exercise.uuid);
      close();
    }
  }

  /// Function to handle editing the exercise
  void _editExercise(
    BuildContext context,
    Exercise exercise, {
    String? initialSectionId,
  }) async {
    // Captured before the await: in compact layout openFormSurface dismisses
    // the hosting context sheet around the form push, which disposes this
    // State — the context is gone by the time the form pops. The save must
    // still run (PlanService needs no context); only UI work below is
    // gated on mounted.
    final localizations = AppLocalizations.of(context)!;
    final numberOfTeams = _planService.loadTeams().length;
    // Navigate to the edit exercise screen
    final result = await openFormSurface<ExerciseFormResult>(
      context,
      builder: (context) => ExerciseFormScreen(
        exercise: exercise,
        numberOfTeams: numberOfTeams == 0 ? null : numberOfTeams,
        variables: _planService.activePlan?.variables ?? const [],
        initialSectionId: initialSectionId,
      ),
    );
    switch (result) {
      case null:
        return;
      case ExerciseFormSave(:final exercise, :final additions):
        // Apply the write-back (any variable created inline, ADR-0047) before
        // the exercise itself, so a chip the exercise's own save might
        // validate against is already declared.
        await applyVariableAdditionsToActivePlan(_planService, additions);
        await _planService.saveExercise(localizations, exercise);
        if (!mounted) return;
        // Optimistic local update: we already hold the saved object.
        updateLoaded(exercise);
      case ExerciseFormDelete(:final exercise):
        await _planService.deleteExercise(exercise.uuid);
        close();
    }
  }

  ExerciseEvent _ensureEvent(Exercise exercise, [ExerciseEvent? event]) {
    final last = event ?? _exerciseService.last;

    // Only use the service event if it belongs to this exercise.
    // Events from a different running exercise must not bleed into
    // this coordinator's progress colours and phase display.
    if (last?.exercise.uuid == widget.uuid) return last!;

    // Not started yet
    return ExerciseEvent.pending(exercise);
  }

  /// The exercise is gone (deleted elsewhere, or a stale deep link).
  ///
  /// Explains itself and leaves closing to the reader rather than dismissing
  /// the surface out from under them — see [DetailGonePane].
  @override
  Widget buildNotFound(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: MasterDetailLeading(onClose: close)),
      body: DetailGonePane(
        icon: Icons.update,
        message: AppLocalizations.of(context)!.detailGoneExercise,
        onClose: close,
      ),
    );
  }

  @override
  Widget buildLoaded(BuildContext context, Exercise exercise) {
    final localizations = AppLocalizations.of(context)!;
    return StreamBuilder(
      initialData: _ensureEvent(exercise),
      stream: _exerciseService.events,
      builder: (context, asyncSnapshot) {
        final event = _ensureEvent(exercise, asyncSnapshot.data);
        // Provide the resolve-context scopes this screen's own content needs
        // (ADR-0048, DESIGN-010's cascade), the way StationScreen wraps its
        // sheet — the Info segment's exercise-description card renders
        // markdown that may carry `{{exercise.*}}`, `{{plan.*}}` and
        // `{{var.*}}`, and Rollup resolves those from the scopes above it, not
        // from the overrides map alone (which can only override an *already
        // declared* variable's value).
        //
        // PlanScope is seeded here rather than assumed from an ancestor: in
        // compact layout this screen lives in a context sheet, pushed on the
        // Navigator's Overlay as a sibling of MainScreen, so MainScreen's own
        // PlanScope never reaches it (DESIGN-008 follow-up 11). Only
        // `{{exercise.*}}` needs ExerciseScope; station tokens are deliberately
        // *not* provided — an exercise-scope field has no single station, so
        // per docs/variables.md those legitimately stay literal here.
        //
        // The *plan* level is not seeded here. It belongs to whichever route
        // mounts this screen — see PlanScope.fromActivePlan — so that one owner
        // covers every modal body, not just the four the player hosts. This
        // screen briefly seeded its own, which made it the only one of the four
        // that resolved tokens on a bare route and hid the same gap in the other
        // three until the player started hosting them.
        return ExerciseScope(
          exercise: exercise,
          variableOverrides: exercise.variableOverrides,
          child: _buildScaffold(exercise, event, localizations),
        );
      },
    );
  }

  Widget _buildScaffold(
    Exercise exercise,
    ExerciseEvent event,
    AppLocalizations localizations,
  ) {
    return Scaffold(
      appBar: AppBar(
        // Matches the other detail screens (`StationScreen`,
        // `TeamExerciseScreen`, `RolePlayScreen`) and the master
        // AppBar so the first content row aligns across master and
        // detail in the wide layout.
        toolbarHeight: kRingdrillHeaderHeight,
        leading: MasterDetailLeading(onClose: close),
        title: SheetTitle(
          primary: exercise.name,
          primaryOverrides: _overridesFor(exercise),
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
          if (_promptShowNotification && _isStarted)
            IconButton(
              icon: const Icon(Icons.notifications_on),
              padding: const EdgeInsets.all(8.0),
              onPressed: _promptShowNotification
                  ? () => unawaited(_onShowNotificationPressed())
                  : null,
              tooltip: localizations.showNotification,
            ),

          // Edit + delete admin actions, director-only (ADR-0057) and both
          // disabled during a run. On a medium/expanded window there is room to
          // show them as standalone icons; on a compact window a long exercise
          // title would ellipsize, so they collapse into an overflow menu
          // instead.
          //
          // Both forms are gated, and the overflow menu needs it *per entry* —
          // gating only the icons would have left the compact layout wide open,
          // which is exactly the shape of hole this pass exists to close. Two
          // nested gates rather than one because edit and delete are different
          // questions (canEdit vs canDelete); that they currently answer alike
          // for an exercise is a coincidence of the matrix, not something to
          // build on.
          EditGate(
            target: EditTarget.exercise,
            builder: (context, mayEdit) => EditGate(
              target: EditTarget.exercise,
              permission: EditPermission.delete,
              builder: (context, mayDelete) {
                if (!mayEdit && !mayDelete) return const SizedBox.shrink();
                if (WindowSizeClass.of(context).hasMasterDetail) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (mayEdit)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          padding: const EdgeInsets.all(8.0),
                          tooltip: localizations.editExercise,
                          onPressed: _isStarted
                              ? null
                              : () => _editExercise(context, exercise),
                        ),
                      if (mayDelete)
                        IconButton(
                          icon: const Icon(Icons.delete),
                          padding: const EdgeInsets.all(8.0),
                          tooltip: localizations.deleteExercise,
                          onPressed: _isStarted
                              ? null
                              : () => _deleteExercise(context, exercise),
                        ),
                    ],
                  );
                }
                return PopupMenuButton<_AppBarMenuAction>(
                  tooltip: localizations.moreActions,
                  enabled: !_isStarted,
                  position: PopupMenuPosition.under,
                  onSelected: (action) {
                    switch (action) {
                      case _AppBarMenuAction.edit:
                        _editExercise(context, exercise);
                        break;
                      case _AppBarMenuAction.delete:
                        _deleteExercise(context, exercise);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (mayEdit)
                      PopupMenuItem<_AppBarMenuAction>(
                        value: _AppBarMenuAction.edit,
                        child: ListTile(
                          leading: const Icon(Icons.edit),
                          title: Text(localizations.editExercise),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    if (mayDelete)
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
                );
              },
            ),
          ),
        ]),
        actionsPadding: EdgeInsets.only(right: 16.0),
      ),
      body: SafeArea(
        child: exercise.schedule.isEmpty
            ? Center(child: Text(localizations.noRoundsScheduled))
            : _buildBody(exercise, event),
      ),
      // Standalone / modal player surface: the docked mini-player owns
      // play, stop and progress, so the floating control button is
      // dropped here. In master-detail the play control lives in the
      // master column and the mini-player is anchored there, so the
      // detail pane keeps the lightweight status strip instead.
      bottomNavigationBar: MasterDetailScope.maybeOf(context) == null
          ? DrillMiniPlayer(
              key: const ValueKey('coordinator-mini-player'),
              exercise: exercise,
              height: 64,
              // Paint the accent background through the bottom safe-area
              // inset so the home-indicator strip matches the bar instead
              // of reading as a dark band below it.
              applyBottomInset: true,
              // The tile row owns the phase/countdown, so the trailing
              // cluster collapses to just the stop button here.
              showInlineStatus: false,
              onPlay: () {
                unawaited(HapticFeedback.mediumImpact());
                _exerciseService.start(exercise);
              },
              // showOrReplace, not replace: this screen can be a plain pushed
              // route (a cold deep link) where the shell's controller exists but
              // was never opened, and replace asserts on that.
              onPickTarget: (target) => unawaited(
                ContextSheet.of(context).showOrReplace(context, target),
              ),
              bodyBuilder: _buildMiniPlayerBody,
            )
          : _buildExerciseStatus(event),
    );
  }

  Widget _buildBody(Exercise exercise, ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    // Hero row only makes sense once the coordinator has started (or is
    // about to start) the exercise. The StreamBuilder above falls back to
    // a synthetic `ExerciseEvent.pending` whenever no service event has
    // arrived yet, so `event.isPending` is `true` even before the user
    // presses play. Reading the service directly avoids that false
    // positive and matches the gate used for `_buildExerciseStatus`.
    final showHero = _exerciseService.isStartedOn(widget.uuid);
    // No Stack here any more: it existed solely to float the copy action over
    // the body, which now sits in the description card's header
    // (_buildCopyAction).
    return LayoutBuilder(
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
            exercise,
            event,
            showHero: showHero,
            localizations: localizations,
          );
        }
        // The Map segment pins the top section + selector and lets the
        // map fill the rest to the bottom (no scroll, no fixed-height
        // gap, and the bottom-right FABs anchor to the true bottom). The
        // stations/teams segments keep scrolling the whole column.
        if (_view == _CoordinatorView.map) {
          return _buildMapBody(
            exercise,
            event,
            showHero: showHero,
            localizations: localizations,
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(_kCoordinatorBodyPadding),
          child: _buildStackedBody(
            exercise,
            event,
            showHero: showHero,
            localizations: localizations,
          ),
        );
      },
    );
  }

  /// The copy-exercise action, as the description card's header action.
  ///
  /// It used to be a `Positioned(top: -4, right: 0)` overlay floating above
  /// every segment, which put it outside the AppBar *and* outside the card it
  /// visually belonged to — clipping into the segment selector on narrow
  /// windows, and sitting over the map on the Kart segment where there was no
  /// description to copy from at all. `CollapsibleSectionCard` already reserves a
  /// trailing slot before the collapse chevron, so the action can live in the
  /// header of the card whose content it copies.
  ///
  /// Consequence worth knowing: it is now reachable from the Info segment only,
  /// where the description is. The payload is still the whole exercise
  /// (`formatExerciseForShare` — schedule and stations included), not just the
  /// description text.
  Widget _buildCopyAction(AppLocalizations localizations, Exercise exercise) {
    final theme = Theme.of(context);
    // Geometry copied from StationScreen's _HeaderAddAction, the other header
    // action in the app: a compact InkWell with a small icon rather than an
    // IconButton, whose 48px minimum tap target would make this card's header
    // taller than every other card's. Icon-only, so the tooltip carries the
    // label.
    return Tooltip(
      message: localizations.exerciseCopyTooltip,
      child: InkWell(
        onTap: () => _copyExerciseToClipboard(localizations, exercise),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Icon(
            Icons.copy_all_outlined,
            size: 17,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  /// Compact and medium body (B2): one scrolling column — top section,
  /// segment (with the `Kart` option), then the selected segment.
  Widget _buildStackedBody(
    Exercise exercise,
    ExerciseEvent event, {
    required bool showHero,
    required AppLocalizations localizations,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHero) ...[
          _buildTopSection(exercise, event, showHero: showHero),
          const SizedBox(height: 16),
        ],
        _buildViewSelector(localizations, exercise, includeMap: true),
        const SizedBox(height: 8),
        switch (_view) {
          _CoordinatorView.info => _buildInfoSegment(exercise, event),
          _CoordinatorView.stations => _buildStationList(exercise, event),
          _CoordinatorView.teams => _buildTeamList(exercise, event),
          // The map segment never reaches here — `_buildBody` routes it to
          // `_buildMapBody` (a filling, non-scrolling layout) before calling
          // this scrolling stacked body.
          _CoordinatorView.map => const SizedBox.shrink(),
        },
      ],
    );
  }

  /// The Info segment: the exercise's own description sections, then the
  /// rotation timetable.
  ///
  /// Both used to be out of reach here — the timetable was pinned to the top of
  /// every segment, and the description was only in the brief or the editor.
  /// Mirrors StationScreen's Info segment (description card, then timing).
  Widget _buildInfoSegment(Exercise exercise, ExerciseEvent event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExerciseDescriptionCard(
          exercise: exercise,
          onTapSection: (id) =>
              _editExercise(context, exercise, initialSectionId: id),
          trailing: _buildCopyAction(AppLocalizations.of(context)!, exercise),
        ),
        const SizedBox(height: 12),
        _buildScheduleCard(exercise, event),
      ],
    );
  }

  /// The `Kart` segment's body (compact/medium): the same top section +
  /// selector as [_buildStackedBody], with the map sized to fill the space
  /// below the selector — reaching the bottom with no dead gap — but never
  /// below [MapConfig.minInteractiveHeight] (a shorter map can't fit its own
  /// FAB command stack). The whole body scrolls, so a tall top section (e.g.
  /// an expanded schedule card on a short landscape phone) pushes content
  /// into the scroll rather than overflowing — an earlier `Expanded`-based
  /// version overflowed there, because the non-flex top section alone
  /// exceeded the viewport before `Expanded` got any room.
  Widget _buildMapBody(
    Exercise exercise,
    ExerciseEvent event, {
    required bool showHero,
    required AppLocalizations localizations,
  }) {
    final map = _buildExercisePositionMap(exercise, event);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve only the selector + gaps (~96), not the variable top
        // section — so the map fills when the top is short and the body
        // scrolls (no overflow) when it is tall.
        final mapHeight = (constraints.maxHeight - 96).clamp(
          MapConfig.minInteractiveHeight,
          double.infinity,
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(_kCoordinatorBodyPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHero) ...[
                _buildTopSection(exercise, event, showHero: showHero),
                const SizedBox(height: 16),
              ],
              _buildViewSelector(localizations, exercise, includeMap: true),
              const SizedBox(height: 8),
              SizedBox(
                height: mapHeight,
                child: map ?? _buildMapPlaceholder(localizations, exercise),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Expanded body (B2): a capped-width left column (status → schedule →
  /// segment → list, scrolling independently) beside a map pane that fills
  /// the remaining width and the full height. The segment drops `Kart`
  /// (`includeMap: false`) since the map is always visible here.
  Widget _buildExpandedBody(
    Exercise exercise,
    ExerciseEvent event, {
    required bool showHero,
    required AppLocalizations localizations,
  }) {
    final map = _buildExercisePositionMap(exercise, event);
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
                  if (showHero) ...[
                    _buildTopSection(exercise, event, showHero: showHero),
                    const SizedBox(height: 16),
                  ],
                  _buildViewSelector(
                    localizations,
                    exercise,
                    includeMap: false,
                  ),
                  const SizedBox(height: 8),
                  switch (_viewWithoutMap) {
                    _CoordinatorView.info => _buildInfoSegment(exercise, event),
                    _CoordinatorView.teams => _buildTeamList(exercise, event),
                    // `_viewWithoutMap` never yields `map` here.
                    _ => _buildStationList(exercise, event),
                  },
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: map ?? _buildMapPlaceholder(localizations, exercise)),
        ],
      ),
    );
  }

  /// Stations/teams switch shown at the top of the list. Shared by every
  /// body so all three window sizes keep the same way to reach the team
  /// rotations — without it the expanded body could only ever show
  /// stations.
  Widget _buildViewSelector(
    AppLocalizations localizations,
    Exercise exercise, {
    required bool includeMap,
  }) {
    // The map segment is only offered in the compact/medium bodies; the
    // expanded body always shows the map beside the lists instead.
    // `selected` is coerced via [_viewWithoutMap] so a stale `map` selection
    // does not feed SegmentedButton a value missing from its segments after
    // a resize.
    final selectedView = includeMap ? _view : _viewWithoutMap;
    final display = segmentDisplayFor(context, segments: includeMap ? 4 : 3);
    final button = SegmentedButton<_CoordinatorView>(
      segments: [
        viewSegment(
          value: _CoordinatorView.info,
          label: localizations.infoTab,
          icon: Icons.info_outline,
          display: display,
        ),
        viewSegment(
          value: _CoordinatorView.stations,
          label: localizations.stationsTab,
          icon: Icons.location_on,
          display: display,
        ),
        viewSegment(
          // Plural-aware label, but no parenthetical count: with four segments
          // the row has to stay narrow enough for a compact phone.
          value: _CoordinatorView.teams,
          label: localizations.team(exercise.numberOfTeams),
          icon: Icons.group,
          display: display,
        ),
        if (includeMap)
          viewSegment(
            value: _CoordinatorView.map,
            label: localizations.mapTab,
            icon: Icons.map,
            display: display,
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

  /// Placeholder shown in place of the all-stations map when no station has
  /// a position yet — shared by the compact/medium `Kart` segment and the
  /// expanded body's permanent map pane. [height] is the clamped map height
  /// in the single-column body (a fixed slot in a scrolling column) and
  /// null in the expanded pane (it fills the pane).
  Widget _buildMapPlaceholder(
    AppLocalizations localizations,
    Exercise exercise, {
    double? height,
  }) {
    return MapPlaceholder(
      height: height,
      icon: exercise.stations.isEmpty
          ? Icons.wrong_location
          : Icons.location_off,
      message: exercise.stations.isEmpty
          ? localizations.notStationsCreated
          : localizations.noLocation,
    );
  }

  /// All-stations map for this exercise. Returns null when no station has a
  /// position so callers can omit the block (expanded body) or show a
  /// placeholder (compact/medium `Kart` segment). [height] fixes the map
  /// box's height inside the scrolling compact/medium body; left `null` for
  /// the expanded body's pane, which fills whatever height its `Expanded`
  /// ancestor gives it instead.
  Widget? _buildExercisePositionMap(
    Exercise exercise,
    ExerciseEvent event, {
    double? height,
  }) {
    final markers = exerciseStationMarkers(context, exercise, liveEvent: event);
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
          // No initialZoom/initialFit: MapView computes its own defaults
          // from `markers`, using its own real render size within this
          // card (including the single-marker full-label zoom).
          initialCenter: points.average(MapConfig.initialCenter),
          markers: markers,
          // Built-in expand-to-fullscreen command — sized from the same
          // local commandSize every other internal MapView command uses
          // (unlike the ad-hoc topRightCommands FAB this replaced, which
          // resolved its size from the full window and could visibly
          // mismatch the rest of the stack in a narrower embedding).
          withFullscreen: true,
          fullscreenHeader: ExerciseMapSheetHeader(exercise: exercise),
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
        // A span, formatted as one. This used to build a DateTime whose *hour and
        // minute fields* were the remaining hours and minutes — today 01:30 for 90
        // minutes — and then take its difference from now, so the countdown read
        // whatever the wall clock happened to make of it: "0 sec" for anything under
        // an hour, "47 min" for 90 minutes, "9 hours" for 10.
        ? Duration(minutes: event.remainingTime).formal(localizations)
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

  /// Top of the body: the live status card, pinned above the segment selector
  /// the way StationScreen pins its own — so "now / next" stays visible
  /// whichever segment the coordinator is looking at.
  ///
  /// `showHero` is only true once the exercise has started; before that there
  /// is nothing to report and this collapses away entirely, leaving the
  /// selector at the top. The rotation timetable used to live here too, always
  /// occupying the top of the screen — it is now a card in the Info segment
  /// instead, which is what freed this space for the lists.
  Widget _buildTopSection(
    Exercise exercise,
    ExerciseEvent event, {
    required bool showHero,
  }) {
    // Play and stop live in the docked mini-player (or, in master-detail, in
    // the master column), so the top section is purely informational.
    if (!showHero) return const SizedBox.shrink();
    return _buildCombinedHeroCard(exercise, event);
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
            spacing: 24.0,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (remainingSeconds > 0)
                _buildMiniTile(
                  context,
                  value: _formatCountdown(phaseRemaining),
                  subtitle: event.getState(localizations),
                  fg: fg,
                ),
              _buildMiniTile(
                context,
                value: exercise.startTime.toString(),
                subtitle: localizations.startTime,
                fg: fg,
              ),
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
          spacing: 24.0,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMiniTile(
              context,
              value: _formatDuration(localizations, clampedElapsed),
              subtitle: localizations.elapsedLabel,
              fg: fg,
            ),
            _buildMiniTile(
              context,
              value: _formatDuration(localizations, totalSeconds),
              subtitle: localizations.totalLabel,
              fg: fg,
            ),
            _buildMiniTile(
              context,
              value: localizations.roundOfTotal(
                event.currentRound + 1,
                exercise.numberOfRounds,
              ),
              subtitle: localizations.round(1),
              fg: fg,
            ),
            _buildMiniTile(
              context,
              value: _formatCountdown(phaseRemaining),
              subtitle: event.getState(localizations),
              fg: fg,
            ),
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

  /// The coordinator's [PlayerStatusCard] — no "Nå" cell (the current
  /// phase is already in the countdown line), so both now/next cells are
  /// forward-looking: "Neste fase" (the next phase and its start time)
  /// and "Neste runde" (the next round and its start time). Both are
  /// omitted once there is no further phase/round to report (the last
  /// phase of the last round).
  Widget _buildCombinedHeroCard(Exercise exercise, ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    final (nextPhase, nextRound) = _coordinatorNowNext(
      exercise,
      event,
      localizations,
    );
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
    Exercise exercise,
    ExerciseEvent event,
    AppLocalizations localizations,
  ) {
    if (!event.isRunning) return (null, null);
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
  Widget _buildScheduleCard(Exercise exercise, ExerciseEvent event) {
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
      onLongPress: () => _copyExerciseToClipboard(localizations, exercise),
      child: ScheduleCard(
        sectionId: 'coordinatorSchedule',
        title: localizations.stationTimingCardTitle,
        // "Round", not localizations.schedule ("Schedule"/"Plan") — the
        // card title already says "Tidsplan"/"Schedule", so repeating it
        // as the first column's header is redundant. Every row here is one
        // round, so "Round"/"Runde" describes the column instead.
        headerLabel: localizations.round(1),
        // How the exercise is run (ADR-0062). Until this the only way to tell a
        // `split` exercise from a ring route was to notice that its rows named
        // several teams, which is inference rather than information. The mode name
        // alone in the header — "Gjennomføring:" was a label for a value that needs
        // no label beside a schedule.
        badge: exerciseModeLabel(localizations, exercise.mode),
        labelWidth: 90,
        event: event,
        exercise: exercise,
        rows: [
          for (
            var roundIndex = 0;
            roundIndex < exercise.schedule.length;
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

  Future<void> _copyExerciseToClipboard(
    AppLocalizations localizations,
    Exercise exercise,
  ) async {
    final text = formatExerciseForShare(
      exercise,
      localizations.brief,
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

  Widget _buildStationList(Exercise exercise, ExerciseEvent event) {
    final localizations = context.l10n;
    // Use staged stations (synchronous post-commit display) when available so
    // the new order is shown immediately after Done without snap-back.
    // _stagedStations is cleared when the planRefreshed event arrives.
    final stations = _stagedStations ?? exercise.stations;

    // Resolve the exercise's 1-based number the same way the Stations segment
    // does — by position in the unfiltered exercise list — so the badge label
    // matches what the Stations segment shows (ADR-0036 §"Coordinator station
    // badge").
    final exerciseNumber = _planService.getExerciseNumber(exercise.uuid);

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
          RoundOccupancy.isActive(exercise, stationIndex, event.currentRound);
      final accent = LiveAccent.of(context, isLive: isLive);

      final badge = StationNumberBadge(
        label: Numbering.station(
          _planService.activePlan?.stationNumberFormat ??
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
            // Every team at this station this round, not the first of them
            // (ADR-0062): "1", "1,2" or "1–4", and "×" for nobody. The numeric form
            // is what fits a cell this narrow — "Lag 1, Lag 2" does not, and in
            // `together` the cell would have to hold every team the plan has.
            final teams = exercise.teamsAt(stationIndex, roundIndex);
            final none = teams.isEmpty;
            final label = RoundOccupancy.numbers(teams);
            return Container(
              padding: const EdgeInsets.all(4),
              color: isCurrent
                  ? none
                        ? Colors.grey
                        : Colors.blueAccent
                  : Colors.transparent,
              child: Text(
                label,
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
          title: RingDrillText.plain(
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

      // Gated on the role (ADR-0057). Inside the player this is also where the
      // live lock bites hardest: the exercise on screen is usually the running
      // one, so its posts are frozen.
      return EditableRow(
        target: EditTarget.station,
        exerciseUuid: exercise.uuid,
        dismissKey: ValueKey<String>(
          'coordinator-station-dismiss-${station.index}',
        ),
        label: localizations.editStation,
        onEdit: () => _editStation(exercise, stationIndex),
        builder: (context, onLongPress) => ExpandableTile(
          onLongPress: onLongPress,
          // Do NOT use a PageStorageKey here: any SelectableText below
          // (e.g. UtmWidget inside the station detail) reads from the
          // same bucket-path for its scroll offset, casting an
          // expansion bool to double? and crashing at didChangeDependencies.
          key: ValueKey<String>('coordinator-station-${station.index}'),
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          accent: accent,
          leading: badge,
          title: RingDrillText.plain(
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
          body: _buildStationDetail(exercise, stationIndex),
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
        target: EditTarget.station,
        exerciseUuid: exercise.uuid,
        enabled: !_isStarted,
        onCommitReorder: (newOrder) {
          // Show the new order immediately (synchronous), then persist async.
          setState(() => _stagedStations = newOrder);
          final orderedOldIndices = newOrder.map((s) => s.index).toList();
          _planService.reorderStations(exercise.uuid, orderedOldIndices);
        },
        itemBuilder: buildStationRow,
      ),
    );
  }

  Future<void> _editStation(Exercise exercise, int stationIndex) async {
    final localizations = context.l10n;
    if (_isStarted) {
      showRingdrillSnackBar(
        context,
        localizations.stopExerciseFirst(exercise.name),
        exercise: exercise,
      );
      return;
    }
    // DESIGN-009 prompt 5/4j: the delete-guard, save-block and the Persons
    // section's inline marker row all need to know which roleplays are
    // already linked to this station.
    final roleplays = _planService
        .loadRolePlays()
        .where(
          (r) =>
              r.exerciseUuid == exercise.uuid && r.stationIndex == stationIndex,
        )
        .toList();
    final result = await openFormSurface<StationFormResult>(
      context,
      builder: (_) => StationFormScreen(
        station: exercise.stations[stationIndex],
        markers: _planService.getLocations().toMarkerSpecs(),
        variables: _planService.activePlan?.variables ?? const [],
        parentExercise: exercise,
        roleplays: roleplays,
      ),
    );
    // No mounted gate on the save: openFormSurface disposes this State when
    // it dismisses the hosting context sheet around the form push.
    if (result == null) return;
    await applyVariableAdditionsToActivePlan(_planService, result.additions);
    // A marker authored/edited inline from the Persons section's "Legg til
    // markør" / "Spilles av {navn}" row (DESIGN-009 prompt 4j) — held in
    // the post editor's own working copy, written back here alongside the
    // station's own save.
    await applyPendingRolePlayAdditions(
      _planService,
      localizations,
      result.additions,
    );
    final stations = [...exercise.stations];
    stations[stationIndex] = result.station;
    await _planService.saveExercise(
      localizations,
      exercise.copyWith(stations: stations),
    );
  }

  /// Inline detail for a station row in the coordinator station list. Shown
  /// when the user expands the [ExpandableTile] for that station. Shows
  /// description and a [StationPositionPanel] (label row + mini-map that
  /// opens the interactive bottom sheet). The round-by-round time table
  /// is intentionally NOT repeated here — that information already lives
  /// in the round table above the SegmentedButton.
  Widget _buildStationDetail(Exercise exercise, int stationIndex) {
    final station = exercise.stations[stationIndex];
    final description = station.description;
    // Seed this station's own scope so `{{station.*}}` resolves in the
    // expanded card instead of showing literally (StationScope.forStation is
    // the single source of the field list + UTM formatting).
    return StationScope.forStation(
      exercise: exercise,
      station: station,
      // No horizontal padding of its own, and none on the children either.
      // `ExpandableTile` already insets its body to 16 — the same 16 its header
      // uses — so a wrapper here and another per child put the content 32 in while
      // the header's badge stayed at 16. Only vertical rhythm belongs at this level.
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
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: RingDrillText.rich(
                  description,
                  overrides: _overridesFor(exercise, station: station),
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
          StationPositionPanel(
            exercise: exercise,
            station: station,
            miniMapKey: ValueKey<String>(
              'coordinator-station-map-$stationIndex',
            ),
          ),
          const SizedBox(height: 8),
          StationRoleSummary(exercise: exercise, stationIndex: stationIndex),
        ],
      ),
    );
  }

  Widget _buildTeamList(Exercise exercise, ExerciseEvent event) {
    final localizations = context.l10n;
    final format =
        PlanService().activePlan?.stationNumberFormat ??
        StationNumberFormat.dotted;
    final exNum = PlanService().getExerciseNumber(exercise.uuid);
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
              ? exercise.stationIndex(teamIndex, event.currentRound)
              : -1;
          final currentStationName =
              (currentStationIndex >= 0 &&
                  currentStationIndex < exercise.stations.length)
              ? exercise.stations[currentStationIndex].numberAndName(
                  format,
                  exerciseNumber: exerciseNumber,
                )
              : null;
          // A team is "live" when the exercise is live.
          // Mirrors the live styling used in TeamScreen._ExerciseSection.
          final isLive = event.isRunning;
          final accent = LiveAccent.of(context, isLive: isLive);
          final teamName =
              _planService.getTeam(teamIndex)?.name ??
              '${localizations.team(1)} ${teamIndex + 1}';
          return EditableRow(
            target: EditTarget.team,
            exerciseUuid: exercise.uuid,
            dismissKey: ValueKey<String>('coordinator-team-dismiss-$teamIndex'),
            label: localizations.editTeam,
            onEdit: () => _editTeam(exercise, teamIndex),
            builder: (context, onLongPress) => ExpandableTile(
              onLongPress: onLongPress,
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
                  ...List<Widget>.generate(exercise.schedule.length, (
                    roundIndex,
                  ) {
                    final isCurrent =
                        event.isRunning && roundIndex == event.currentRound;
                    return TeamStationWidget(
                      isCurrent: isCurrent,
                      exercise: exercise,
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
                TeamSheetTarget(
                  exerciseUuid: widget.uuid,
                  teamIndex: teamIndex,
                ),
              ),
              onToggle: () => _toggleTeam(teamIndex),
              body: _buildTeamDetail(exercise, teamIndex, event),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _editTeam(Exercise exercise, int teamIndex) async {
    final localizations = context.l10n;
    if (_isStarted) {
      showRingdrillSnackBar(
        context,
        localizations.stopExerciseFirst(exercise.name),
        exercise: exercise,
      );
      return;
    }
    final team = _planService.getTeam(teamIndex);
    if (team == null) return;
    final updated = await openFormSurface<Team>(
      context,
      builder: (_) => TeamFormScreen(team: team),
    );
    // No mounted gate on the save: openFormSurface disposes this State when
    // it dismisses the hosting context sheet around the form push.
    if (updated == null) return;
    await _planService.saveTeam(localizations, updated);
    if (mounted) setState(() {});
  }

  /// Inline detail for a team row in the coordinator team list. Shown when
  /// the user expands the [ExpandableTile] for that team. Lists the station
  /// rotation per round so the coordinator can track where the team is going
  /// without leaving the overview.
  Widget _buildTeamDetail(
    Exercise exercise,
    int teamIndex,
    ExerciseEvent event,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final format =
        PlanService().activePlan?.stationNumberFormat ??
        StationNumberFormat.dotted;
    final exNum = PlanService().getExerciseNumber(exercise.uuid);
    final exerciseNumber = exNum < 1 ? 1 : exNum;
    // Flush with the tile's own body inset, so the nested card's edge lines up with
    // the team name in the header above it rather than stepping in again.
    return ScheduleCard(
      sectionId: 'coordinatorTeamDetailSchedule',
      title: localizations.stationTimingCardTitle,
      // "Round", not localizations.schedule — see the coordinator's own
      // round-table ScheduleCard above for why.
      headerLabel: localizations.round(1),
      labelWidth: 78,
      event: event,
      exercise: exercise,
      rows: List<ScheduleTableRow>.generate(exercise.schedule.length, (
        roundIndex,
      ) {
        final stationIndex = exercise.stationIndex(teamIndex, roundIndex);
        final none = stationIndex < 0;
        return ScheduleTableRow(
          roundIndex: roundIndex,
          label: none
              ? '${localizations.station(1)} ×'
              : exercise.stations[stationIndex].numberAndName(
                  format,
                  exerciseNumber: exerciseNumber,
                ),
          muted: none,
          // Mirror the description tap in _buildStationDetail: a round
          // row here represents "team T at station S in round R", so a
          // tap should open the same StationScreen the
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
    );
  }
}
