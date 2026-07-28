import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/brief/field_resolver.dart' show formatUtm;
import 'package:ringdrill/services/edit_permissions.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/subscription_bag.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';
import 'package:ringdrill/views/drill_player/player_mode.dart';
import 'package:ringdrill/views/location_form_screen.dart';
import 'package:ringdrill/views/map_view.dart' show MapConfig;
import 'package:ringdrill/views/person_form_screen.dart';
import 'package:ringdrill/views/plan_additions.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/loader_state.dart';
import 'package:ringdrill/views/shell/closable_surface.dart';
import 'package:ringdrill/views/shell/detail_empty_pane.dart';
import 'package:ringdrill/views/shell/master_detail_leading.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/shell/wide_detail_map_split.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/widgets/cast_picker_sheet.dart';
import 'package:ringdrill/views/widgets/cast_pill.dart';
import 'package:ringdrill/views/widgets/collapsible_section_card.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/edit_affordance.dart';
import 'package:ringdrill/views/widgets/gender_segmented_control.dart';
import 'package:ringdrill/views/widgets/location_kind_style.dart';
import 'package:ringdrill/views/widgets/map_placeholder.dart';
import 'package:ringdrill/views/widgets/player_status_card.dart';
import 'package:ringdrill/views/widgets/schedule_card.dart';
import 'package:ringdrill/views/widgets/schedule_table.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';
import 'package:ringdrill/views/widgets/station_description_card.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:ringdrill/views/widgets/station_scenario_map.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';

class StationScreen extends StatefulWidget {
  final int stationIndex;
  final String uuid;

  const StationScreen({
    super.key,
    required this.stationIndex,
    required this.uuid,
  });

  @override
  State<StationScreen> createState() => _StationScreenState();
}

/// The three segments of the compact/medium detail body: the post brief
/// (`info` — description + schedule), the acted scenario (`script` —
/// persons + locations), and the directly-interactive map (`map`). No
/// coercion guard is needed on resize (unlike CoordinatorScreen's
/// `_viewWithoutMap`): the `SegmentedButton` is rendered only in this body
/// and always carries all three segments, so `_view` is always a valid
/// selection regardless of a resize (the expanded body never reads it).
enum _StationDetailView { info, script, map }

/// What this screen shows: the parent exercise plus the station at
/// [StationScreen.stationIndex]. Both are needed together — and the index can
/// fall out of range when the station is deleted elsewhere — so they are
/// loaded as one unit.
class _StationSubject {
  const _StationSubject(this.exercise, this.station);

  final Exercise exercise;
  final Station station;
}

class _StationScreenState extends State<StationScreen>
    with
        SubscriptionBag<StationScreen>,
        ClosableSurface<StationScreen>,
        Loader<StationScreen, _StationSubject, PlanEvent> {
  _StationDetailView _view = _StationDetailView.info;
  final _planService = PlanService();
  final _exerciseService = ExerciseService();

  bool _isStarted = false;

  // DESIGN-010 stage 3b: the Station description card renders per the settings
  // role (director sees the gated directorNotesMd section too), not an
  // in-sheet toggle. Defaults to director (participants do not use the
  // app) until [_bindRole] seeds the stored value, which is synchronous.
  StaffRole _role = StaffRole.director;

  /// Seeded synchronously and kept current: the role decides what this surface
  /// offers (ADR-0057), so it has to be right on the first frame *and* follow a
  /// change made from the drawer while this screen is open. It used to be awaited
  /// once, which was both a frame late and permanently stale.
  void _bindRole() {
    _role = currentAppUserRole();
    appUserRole.addListener(_onRoleChanged);
  }

  void _onRoleChanged() {
    if (mounted) setState(() => _role = appUserRole.value);
  }

  @override
  void dispose() {
    appUserRole.removeListener(_onRoleChanged);
    super.dispose();
  }

  /// The effective plan-variable map (ADR-0046) at [exercise]'s scope,
  /// optionally narrowed to [station]'s — the active plan's declared
  /// values overlaid by [exercise]'s overrides, then [station]'s. Empty
  /// when there is no active plan (defense-in-depth; this screen only
  /// ever renders inside one).
  Map<String, String> _overridesFor(Exercise exercise, {Station? station}) {
    final plan = _planService.activePlan;
    if (plan == null) return const {};
    return effectivePlanVariables(plan, exercise: exercise, station: station);
  }

  @override
  void initState() {
    super.initState();

    load();
    _bindRole();

    // Listen to ExerciseService state changes
    listen(_exerciseService.events, (event) {
      if (!mounted) return;
      if (event.exercise.uuid == widget.uuid) {
        setState(onLoaded);
      }
    });

    // Rebuild on any plan mutation (roleplay/actor/person/station edits
    // elsewhere), not just this screen's own actions — mirrors
    // CoordinatorScreen. Re-read the cached exercise; ignore a delete of the
    // exercise itself (the hosting sheet closes that case).
    listen(_planService.events, (event) {
      if (_rendersChangesFrom(event)) reload(event);
    });
  }

  /// Whether [event] can change anything this screen shows.
  ///
  /// Wider than CoordinatorScreen's exercise-only test, because the person rows
  /// render each person's roleplay and the actor cast in it — and neither
  /// `rolePlaySaved` nor `actorSaved` carries an exercise to match on. Which
  /// specific roleplays and actors are on screen changes with the station's
  /// contents, so any of those events counts rather than trying to track the
  /// current set.
  bool _rendersChangesFrom(PlanEvent event) =>
      event.type == PlanEventType.planRefreshed ||
      event.exercise?.uuid == widget.uuid ||
      event.rolePlay != null ||
      event.actor != null;

  @override
  void onLoaded() {
    _isStarted = _exerciseService.isStartedOn(widget.uuid);
  }

  @override
  _StationSubject? onLoad(PlanEvent? event) {
    // Prefer the event's exercise object when available (avoids an extra
    // service lookup for the common case). Fall back to a fresh load when the
    // event carries no exercise (e.g. planRefreshed).
    final exercise = event?.exercise ?? _planService.getExercise(widget.uuid);
    if (exercise == null) return null;
    // The index can outlive the station it pointed at — a delete elsewhere
    // shortens the list — so range-check rather than indexing blind.
    if (widget.stationIndex < 0 ||
        widget.stationIndex >= exercise.stations.length) {
      return null;
    }
    return _StationSubject(exercise, exercise.stations[widget.stationIndex]);
  }

  /// The event to render for [exercise]: the service's live one when it belongs
  /// to this exercise, else a pending placeholder.
  ExerciseEvent _ensureEvent(Exercise exercise, [ExerciseEvent? event]) {
    final last = event ?? _exerciseService.last;

    // Events from a different running exercise must not bleed into this
    // viewer's progress colours and phase display.
    if (last != null && last.exercise.uuid == exercise.uuid) return last;

    // Not started yet
    return ExerciseEvent.pending(exercise);
  }

  /// The station, or its exercise, is gone (deleted elsewhere, a stale deep
  /// link, or a station index that no longer exists).
  ///
  /// Explains itself and leaves closing to the reader rather than dismissing
  /// the surface out from under them — see [DetailGonePane].
  @override
  Widget buildNotFound(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: MasterDetailLeading(onClose: close)),
      body: DetailGonePane(
        icon: Icons.place,
        message: AppLocalizations.of(context)!.detailGoneStation,
        onClose: close,
      ),
    );
  }

  @override
  Widget buildLoaded(BuildContext context, _StationSubject subject) {
    final localizations = AppLocalizations.of(context)!;
    final exercise = subject.exercise;
    return StreamBuilder(
      initialData: _ensureEvent(exercise),
      stream: _exerciseService.events,
      builder: (context, asyncSnapshot) {
        final event = _ensureEvent(exercise, asyncSnapshot.data);
        // Station identity in the AppBar so the sheet's header names the thing
        // the sheet is about, with the parent exercise on the secondary line.
        // Prefixed with the formatted post number (Station.numberAndName), like
        // everywhere else a post is named as text. A manual code the author
        // typed into the name (e.g. "1a) Turgåer") is their own to clean up
        // (doubling is not handled here).
        final station = subject.station;
        final stationNumberFormat =
            _planService.activePlan?.stationNumberFormat ??
            StationNumberFormat.dotted;
        final exerciseNumber = _planService.getExerciseNumber(exercise.uuid);

        // DESIGN-010 stage 3: this station/exercise are already loaded here, so
        // wrap the sheet in the same resolve-context scopes an editor provides
        // (ADR-0048). Every widget built *below* this point (`SheetTitle`,
        // `RingDrillText`, the `Builder` in `_buildDescription`) then resolves
        // the full `{{station.*}}`/`{{exercise.*}}` cascade, not just
        // `{{var.*}}` — `context` captured here in `build` stays above the
        // scope (it is `State.context`, an ancestor of whatever `build`
        // returns), so it cannot see these two itself.
        return StationScope.forStation(
          exercise: exercise,
          station: station,
          child: Scaffold(
            appBar: AppBar(
              leading: MasterDetailLeading(onClose: close),
              toolbarHeight: 72,
              title: SheetTitle(
                primary: station.numberAndName(
                  stationNumberFormat,
                  exerciseNumber: exerciseNumber < 1 ? 1 : exerciseNumber,
                ),
                secondary: exercise.name,
                primaryOverrides: _overridesFor(exercise, station: station),
                secondaryOverrides: _overridesFor(exercise),
              ),
              actions: [
                // Edit Station Button — director-only (ADR-0057); the run
                // disables rather than hides it, so the tooltip can say why.
                IfEditable(
                  target: EditTarget.station,
                  child: IconButton(
                    icon: const Icon(Icons.edit),
                    padding: const EdgeInsets.all(8.0),
                    onPressed: _isStarted
                        ? null
                        : () => _editStation(context, exercise),
                    tooltip: _isStarted
                        ? localizations.stopExerciseFirst(
                            substitutePlanVariables(
                              exercise.name,
                              _overridesFor(exercise),
                            ),
                          )
                        : localizations.editStation,
                  ),
                ),
              ],
              actionsPadding: EdgeInsets.only(right: 16.0),
            ),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final windowSize = WindowSizeClass.fromWidth(
                    constraints.maxWidth,
                  );
                  if (windowSize == WindowSizeClass.expanded) {
                    return _buildExpandedBody(exercise, station, event);
                  }
                  // Compact and medium share the segmented Info/Script/Map
                  // body; only expanded gets the two-pane WideDetailMapSplit.
                  return _buildSegmentedBody(exercise, station, event);
                },
              ),
            ),
            // Mirror the CoordinatorScreen pattern: dock a DrillMiniPlayer for
            // the parent exercise so the user can start it directly from the
            // station view (modal context sheet in narrow). In master-detail
            // (wide) the docked bar lives in the master column instead, so we
            // skip it here. The bar self-hides when an unrelated exercise is
            // already running.
            bottomNavigationBar: MasterDetailScope.maybeOf(context) == null
                ? DrillMiniPlayer(
                    exercise: exercise,
                    height: 64,
                    applyBottomInset: true,
                    onPlay: () {
                      unawaited(HapticFeedback.mediumImpact());
                      _exerciseService.start(exercise);
                    },
                    mode: StationPlayerMode(widget.stationIndex),
                    // showOrReplace, not replace: this screen can be a plain pushed
                    // route (a cold deep link) where the shell's controller exists but
                    // was never opened, and replace asserts on that.
                    onPickTarget: (target) => unawaited(
                      ContextSheet.of(context).showOrReplace(context, target),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  /// The rollup made concrete (DESIGN-010): the lead description then every
  /// active labeled section, resolved and markdown-rendered, closing the
  /// literal `{{station.position}}` bug this stage started from.
  /// `directorNotesMd` is the mockup's "Notat til øvelsesleder" — gated on
  /// the settings role being director (a stricter gate than the brief's own
  /// `BriefAudience.includesDirectorNotes`, which also includes instructor:
  /// this is the author's own live planning note, not the printed brief).
  /// Tapping a section opens the station editor scrolled straight to it.
  Widget _buildStationDescriptionCard(Exercise exercise, Station station) {
    return StationDescriptionCard(
      exercise: exercise,
      station: station,
      role: _role,
      onTapSection: (id) =>
          _editStation(context, exercise, initialSectionId: id),
    );
  }

  /// The scenario map card: the station's own position plus its DESIGN-009
  /// `Location`s, styled by `LocationKind` (ADR-0020), with the legend slot
  /// — richer than `StationPositionPanel`'s administrative-only default,
  /// which every other station surface keeps. Both the expanded pane and
  /// the compact/medium Map segment pass `fillHeight: true, interactive:
  /// true` so the map flexes to fill its bounded parent and is directly
  /// interactive.
  Widget _buildMapCard(
    Exercise exercise,
    Station station, {
    bool fillHeight = false,
    bool interactive = false,
  }) {
    return StationPositionPanel(
      exercise: exercise,
      station: station,
      label: AppLocalizations.of(context)!.placement,
      asCard: true,
      withTitle: false,
      fillHeight: fillHeight,
      interactive: interactive,
      sectionId: 'position',
      miniMapKey: ValueKey<String>(
        'station-screen-map-${exercise.uuid}-${station.index}',
      ),
      markers: stationScenarioMarkers(context, exercise, station),
      legend: StationScenarioLegend(exercise: exercise, station: station),
      onTap: () => _editStation(context, exercise, initialSectionId: 'id'),
    );
  }

  /// Expanded body (pane ≥ 840): the same cards the stacked body shows,
  /// split via the shared [WideDetailMapSplit] — Postbeskrivelse/Personer/
  /// Lokasjoner/Tidsplan in a capped, self-scrolling left column, the map
  /// panel (with its coordinate row) filling the right pane's full height
  /// (`fillHeight: true`), mirroring the coordinator's own expanded body.
  Widget _buildExpandedBody(
    Exercise exercise,
    Station station,
    ExerciseEvent event,
  ) {
    return Padding(
      padding: const EdgeInsets.all(kPlayerSurfaceHorizontalPadding),
      child: WideDetailMapSplit(
        left: [
          _StationStatusCard(
            exercise: exercise,
            stationIndex: station.index,
            event: event,
          ),
          _buildStationDescriptionCard(exercise, station),
          _buildPersonsCard(exercise, station),
          _buildLocationsCard(exercise, station),
          _buildTimingCard(exercise, station, event),
        ],
        mapPane: _buildMapCard(
          exercise,
          station,
          fillHeight: true,
          interactive: true,
        ),
      ),
    );
  }

  /// Compact and medium body: a pinned status card + Info/Script/Map
  /// segmented selector, then the selected segment filling the rest. Info
  /// (description + schedule) and Script (persons + locations) scroll within
  /// their area; Map fills it to the bottom with a directly-interactive map
  /// (or, with no position, a [MapPlaceholder]) — no bottom-sheet detour,
  /// and a fullscreen command for going bigger. Mirrors CoordinatorScreen's
  /// own segmented body. Only the `expanded` window size uses the two-pane
  /// `WideDetailMapSplit` instead.
  Widget _buildSegmentedBody(
    Exercise exercise,
    Station station,
    ExerciseEvent event,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      spacing: 8.0,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            kPlayerSurfaceHorizontalPadding,
            kPlayerSurfaceHorizontalPadding,
            kPlayerSurfaceHorizontalPadding,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StationStatusCard(
                event: event,
                exercise: exercise,
                stationIndex: widget.stationIndex,
              ),
              _buildViewSelector(l10n),
            ],
          ),
        ),
        Expanded(
          child: switch (_view) {
            _StationDetailView.info => _segmentScroll([
              _buildStationDescriptionCard(exercise, station),
              _buildTimingCard(exercise, station, event),
            ]),
            _StationDetailView.script => _segmentScroll([
              _buildPersonsCard(exercise, station),
              _buildLocationsCard(exercise, station),
            ]),
            _StationDetailView.map => _fillOrScrollMap(
              station.position == null
                  ? MapPlaceholder(message: l10n.noLocation)
                  : _buildMapCard(
                      exercise,
                      station,
                      fillHeight: true,
                      interactive: true,
                    ),
            ),
          },
        ),
      ],
    );
  }

  /// A segment's cards in their own scroll view, filling the [Expanded] the
  /// segmented body gives them (so the pinned selector above stays put while
  /// this content scrolls).
  Widget _segmentScroll(List<Widget> cards) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        kPlayerSurfaceHorizontalPadding,
        0,
        kPlayerSurfaceHorizontalPadding,
        kPlayerSurfaceHorizontalPadding,
      ),
      child: Column(
        spacing: 8.0,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cards,
      ),
    );
  }

  /// Sizes the Map segment's [map] to fill the space the segmented body
  /// gives it — reaching the bottom with no dead gap — but never below a
  /// floor, since a shorter map can't fit its own FAB command stack (a very
  /// short landscape-phone viewport would otherwise overflow). When the
  /// available height is below the floor the map takes the floor and the
  /// area scrolls; otherwise it fills exactly (content == viewport, so no
  /// scroll). The floor is [MapConfig.minInteractiveHeight] (the *map's* own
  /// FAB-stack minimum) plus ~80px for the position panel's coordinate bar
  /// and legend below the map, so the map portion itself still clears the
  /// minimum.
  Widget _fillOrScrollMap(Widget map) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight.clamp(
          MapConfig.minInteractiveHeight + 80,
          double.infinity,
        );
        return SingleChildScrollView(
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kPlayerSurfaceHorizontalPadding,
              ),
              child: map,
            ),
          ),
        );
      },
    );
  }

  /// The Info/Script/Map segmented control. Wrapped in a horizontal scroll
  /// view forced to at least the viewport width (like CoordinatorScreen's
  /// own selector) so three segments centre when they fit and scroll rather
  /// than overflow on a very narrow phone.
  Widget _buildViewSelector(AppLocalizations l10n) {
    final button = SegmentedButton<_StationDetailView>(
      segments: [
        ButtonSegment<_StationDetailView>(
          value: _StationDetailView.info,
          label: Text(l10n.infoTab),
          icon: const Icon(Icons.info_outline),
        ),
        ButtonSegment<_StationDetailView>(
          value: _StationDetailView.script,
          label: Text(l10n.scriptTab),
          icon: const Icon(Icons.theater_comedy),
        ),
        ButtonSegment<_StationDetailView>(
          value: _StationDetailView.map,
          label: Text(l10n.mapTab),
          icon: const Icon(Icons.map),
        ),
      ],
      selected: {_view},
      showSelectedIcon: false,
      onSelectionChanged: (selection) {
        setState(() => _view = selection.first);
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Center(child: button),
        ),
      ),
    );
  }

  /// Tidsplan card (DESIGN-010): the per-team drill/eval/roll clock times
  /// for this station across every round, from the same `Exercise.schedule`
  /// + `teamIndex`/`stationIndex` data the live rotation tables read — via
  /// the shared `ScheduleTable`, so the current round (while `event` is
  /// running) gets the same house progress-fill highlight the coordinator
  /// and team tables show, not a bespoke static rendering.
  Widget _buildTimingCard(
    Exercise exercise,
    Station station,
    ExerciseEvent event,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final rows = List.generate(exercise.schedule.length, (roundIndex) {
      final teamIndex = exercise.teamIndex(widget.stationIndex, roundIndex);
      return ScheduleTableRow(
        roundIndex: roundIndex,
        label: teamIndex == -1
            ? '${l10n.team(1)} ×'
            : '${l10n.team(1)} ${teamIndex + 1}',
        muted: teamIndex == -1,
        onTap: teamIndex == -1
            ? null
            : () => ContextSheet.of(context).replace(
                TeamSheetTarget(
                  exerciseUuid: exercise.uuid,
                  teamIndex: teamIndex,
                ),
              ),
      );
    });
    return ScheduleCard(
      sectionId: 'schedule',
      title: l10n.stationTimingCardTitle,
      headerLabel: l10n.team(1),
      rows: rows,
      event: event,
      exercise: exercise,
      // Collapsed-header summary: the whole exercise window and its duration,
      // via the same helper the Spill viewer's Når aktiv card uses.
      collapsedSummary: scheduleWindowSummary(
        l10n,
        exercise.startTime,
        exercise.endTime,
      ),
    );
  }

  /// Personer card (DESIGN-009/010): one row per station-owned [Person] —
  /// the row *is* the person, with the marker portraying them (if any)
  /// shown inline via `personsSectionEnactedByAction` (the same label
  /// `PersonsSection`'s own editor row uses) rather than a separate marker
  /// list. Omitted entirely when the station has none.
  Widget _buildPersonsCard(Exercise exercise, Station station) {
    if (station.persons.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return CollapsibleSectionCard(
      sectionId: 'persons',
      icon: Icons.people,
      title: l10n.personsSectionTitle,
      collapsedTitleSuffix: '${station.persons.length}',
      trailing: _HeaderAddAction(
        label: l10n.personsSectionAddAction,
        onTap: () => _addPerson(exercise, station),
      ),
      // Each row already draws its own leading (top) divider.
      dividedBody: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final person in station.persons)
            _buildPersonRow(exercise, station, person),
        ],
      ),
    );
  }

  Widget _buildPersonRow(Exercise exercise, Station station, Person person) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final rolePlay = _planService
        .loadRolePlays()
        .where(
          (r) =>
              r.exerciseUuid == exercise.uuid &&
              r.stationIndex == widget.stationIndex &&
              r.personRef == person.slug,
        )
        .firstOrNull;
    final castActor = rolePlay?.staffUuid == null
        ? null
        : _planService.getStaff(rolePlay!.staffUuid!);

    // Effective identity (DESIGN-012): the actor's own non-empty
    // override wins over the linked person's planned value, so the post's own
    // context shows what is actually played — not just the plan.
    final effName = _effective(rolePlay?.name, person.name);
    final displayName = (effName == null || effName.isEmpty)
        ? person.slug
        : effName;
    final effAge = rolePlay?.age ?? person.age;
    final effGender = _effective(rolePlay?.gender, person.gender);
    final effDescription = _effective(
      rolePlay?.description,
      person.description,
    );
    final genderLabel = genderLabelFor(effGender, l10n);
    final metaParts = [
      displayName,
      if (effAge != null) '$effAge',
      ?genderLabel,
    ];
    final overridden =
        rolePlay != null &&
        (_isOverride(rolePlay.name, person.name) ||
            (rolePlay.age != null && rolePlay.age != person.age) ||
            _isOverride(rolePlay.gender, person.gender) ||
            _isOverride(rolePlay.description, person.description));

    // Trailing cast pill: create the RolePlay (no marker yet), or assign/edit
    // the actor (RolePlay present) via the shared cast picker — not the Spill
    // viewer.
    final CastPill pill;
    if (rolePlay == null) {
      pill = CastPill(
        variant: CastPillVariant.add,
        label: l10n.personsSectionAddMarkerAction,
        onTap: () => _addRolePlayForPerson(exercise, station, person),
      );
    } else if (castActor == null) {
      pill = CastPill(
        variant: CastPillVariant.uncast,
        label: l10n.noCastLine,
        onTap: () => _castRolePlay(rolePlay),
      );
    } else {
      pill = CastPill(
        variant: CastPillVariant.cast,
        // Just the actor name — the face icon already reads "enacted by".
        label: castActor.realName,
        onTap: () => _castRolePlay(rolePlay),
      );
    }

    // Once a spill (RolePlay) exists, the row opens the spill editor — the
    // spill is the richer entity and would otherwise be unreachable from the
    // person list (DESIGN-012 follow-up); without one, it opens the person
    // editor. The trailing cast pill is its own inner tap target.
    return InkWell(
      onTap: rolePlay == null
          ? () => _editPerson(exercise, station, person)
          : () => _editRolePlay(exercise, rolePlay),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Person rows carry a person icon (the row *is* the character);
            // the accent-dot badge marks a row the actor has overridden.
            _personLeadingIcon(theme, overridden: overridden),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(metaParts.join(' · '), overflow: TextOverflow.ellipsis),
                  if ((effDescription ?? '').isNotEmpty)
                    Text(
                      effDescription!,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: pill,
            ),
          ],
        ),
      ),
    );
  }

  /// ADR-0047 effective-identity rule: the roleplay's own non-empty value
  /// wins over the linked person's.
  static String? _effective(String? roleValue, String? personValue) =>
      (roleValue != null && roleValue.isNotEmpty) ? roleValue : personValue;

  /// Whether [roleValue] overrides [personValue] (non-empty and different).
  static bool _isOverride(String? roleValue, String? personValue) =>
      roleValue != null &&
      roleValue.isNotEmpty &&
      roleValue != (personValue ?? '');

  /// The person row's 30×30 leading icon, with an accent-dot corner badge
  /// (costing no inline width) when the actor has overridden the person's
  /// planned identity.
  Widget _personLeadingIcon(ThemeData theme, {required bool overridden}) {
    final box = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(
        Icons.person,
        size: 16,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    if (!overridden) return box;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        box,
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: theme.cardColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  /// Opens the shared cast picker for [rolePlay] (assign/clear its actor),
  /// the same sheet the Spill card and browser tiles use.
  Future<void> _castRolePlay(RolePlay rolePlay) async {
    final localizations = AppLocalizations.of(context)!;
    await openCastPickerAndApply(context, localizations, rolePlay);
    if (mounted) setState(() {});
  }

  /// Opens the spill (roleplay) editor for an existing [rolePlay] — the person
  /// row's tap target once the person has a spill (DESIGN-012 follow-up), so
  /// the spill is reachable and editable from the person list.
  Future<void> _editRolePlay(Exercise exercise, RolePlay rolePlay) async {
    final localizations = AppLocalizations.of(context)!;
    final result = await openFormSurface<RolePlayFormResult>(
      context,
      builder: (_) => RolePlayFormScreen(
        rolePlay: rolePlay,
        exercise: exercise,
        variables: _planService.activePlan?.variables ?? const [],
        isExisting: true,
      ),
    );
    switch (result) {
      case null:
        return;
      case RolePlayFormSave(:final rolePlay, :final additions):
        await applyRolePlayAdditions(
          _planService,
          localizations,
          rolePlay,
          additions,
        );
        await _planService.saveRolePlay(localizations, rolePlay);
      case RolePlayFormDelete(:final rolePlay):
        await _planService.deleteRolePlay(rolePlay.uuid);
    }
    if (mounted) setState(() {});
  }

  /// Lokasjoner card (DESIGN-009/010): one row per station-owned [Location],
  /// styled by [LocationKind] (ADR-0020) — the same kind icon/color the map
  /// card's markers and legend use. Omitted entirely when the station has
  /// none.
  Widget _buildLocationsCard(Exercise exercise, Station station) {
    if (station.locations.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return CollapsibleSectionCard(
      sectionId: 'locations',
      icon: Icons.location_pin,
      title: l10n.locationsSectionTitle,
      collapsedTitleSuffix: '${station.locations.length}',
      trailing: _HeaderAddAction(
        label: l10n.locationsSectionAddAction,
        onTap: () => _addLocation(exercise, station),
      ),
      // Each row already draws its own leading (top) divider.
      dividedBody: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final location in station.locations)
            _buildLocationRow(exercise, station, location),
        ],
      ),
    );
  }

  Widget _buildLocationRow(
    Exercise exercise,
    Station station,
    Location location,
  ) {
    final theme = Theme.of(context);
    final displayName = location.label.isEmpty ? location.slug : location.label;
    final subtitle = location.place.isNotEmpty
        ? location.place
        : (location.position == null ? '' : formatUtm(location.position));
    return InkWell(
      onTap: () => _editLocation(exercise, station, location),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                location.kind.icon,
                size: 16,
                color: location.kind.color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, overflow: TextOverflow.ellipsis),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPerson(Exercise exercise, Station station) async {
    final localizations = AppLocalizations.of(context)!;
    final result = await openFormSurface<PersonFormResult>(
      context,
      builder: (_) => PersonFormScreen(
        existingSlugs: station.persons.map((p) => p.slug).toSet(),
        locations: station.locations,
      ),
    );
    if (result == null) return;
    // Write-back (ADR-0047, DESIGN-009 "Inline creation and write-back"):
    // a var.* created inline from this person's own fields reaches the
    // active Plan; a sibling station.loc/person.* joins this same
    // station, alongside the person itself.
    await applyVariableAdditionsToActivePlan(_planService, result.additions);
    final withAdditions = applyStationAdditions(station, result.additions);
    final updated = withAdditions.copyWith(
      persons: [...withAdditions.persons, result.person],
    );
    await _saveStation(localizations, exercise, updated);
  }

  Future<void> _addLocation(Exercise exercise, Station station) async {
    final localizations = AppLocalizations.of(context)!;
    final result = await openFormSurface<LocationFormResult>(
      context,
      builder: (_) => LocationFormScreen(
        existingSlugs: station.locations.map((l) => l.slug).toSet(),
      ),
    );
    if (result == null) return;
    // Write-back, mirroring _addPerson above.
    await applyVariableAdditionsToActivePlan(_planService, result.additions);
    final withAdditions = applyStationAdditions(station, result.additions);
    final updated = withAdditions.copyWith(
      locations: [...withAdditions.locations, result.location],
    );
    await _saveStation(localizations, exercise, updated);
  }

  /// Opens the person editor for an existing [person] (row tap), writing the
  /// edited person back in place by its (stable) slug. Mirrors [_addPerson]'s
  /// write-back of any sibling entities created inline.
  Future<void> _editPerson(
    Exercise exercise,
    Station station,
    Person person,
  ) async {
    final localizations = AppLocalizations.of(context)!;
    final result = await openFormSurface<PersonFormResult>(
      context,
      builder: (_) => PersonFormScreen(
        existingSlugs: station.persons
            .where((p) => p.slug != person.slug)
            .map((p) => p.slug)
            .toSet(),
        locations: station.locations,
        initial: person,
      ),
    );
    if (result == null) return;
    await applyVariableAdditionsToActivePlan(_planService, result.additions);
    final withAdditions = applyStationAdditions(station, result.additions);
    final updated = withAdditions.copyWith(
      persons: [
        for (final p in withAdditions.persons)
          if (p.slug == person.slug) result.person else p,
      ],
    );
    await _saveStation(localizations, exercise, updated);
  }

  /// [_editPerson]'s [Location] counterpart (row tap on the Lokasjoner card).
  Future<void> _editLocation(
    Exercise exercise,
    Station station,
    Location location,
  ) async {
    final localizations = AppLocalizations.of(context)!;
    final result = await openFormSurface<LocationFormResult>(
      context,
      builder: (_) => LocationFormScreen(
        existingSlugs: station.locations
            .where((l) => l.slug != location.slug)
            .map((l) => l.slug)
            .toSet(),
        initial: location,
      ),
    );
    if (result == null) return;
    await applyVariableAdditionsToActivePlan(_planService, result.additions);
    final withAdditions = applyStationAdditions(station, result.additions);
    final updated = withAdditions.copyWith(
      locations: [
        for (final l in withAdditions.locations)
          if (l.slug == location.slug) result.location else l,
      ],
    );
    await _saveStation(localizations, exercise, updated);
  }

  /// Opens the RolePlay editor pre-set with [person]'s own identity and
  /// `personRef` (mirroring `PersonsSection.onAddRolePlay`'s editor
  /// counterpart) — a new marker for a person nobody plays yet.
  Future<void> _addRolePlayForPerson(
    Exercise exercise,
    Station station,
    Person person,
  ) async {
    final localizations = AppLocalizations.of(context)!;
    final existing = _planService
        .loadRolePlays()
        .where((r) => r.exerciseUuid == exercise.uuid)
        .length;
    final draft = RolePlay(
      uuid: nanoid(10),
      index: existing,
      exerciseUuid: exercise.uuid,
      stationIndex: station.index,
      name: person.name,
      age: person.age,
      gender: person.gender,
      description: person.description,
      personRef: person.slug,
    );
    final result = await openFormSurface<RolePlayFormResult>(
      context,
      builder: (_) => RolePlayFormScreen(
        rolePlay: draft,
        exercise: exercise,
        variables: _planService.activePlan?.variables ?? const [],
      ),
    );
    // A fresh draft has no delete affordance, so only a save (or cancel) is
    // possible here.
    if (result is RolePlayFormSave) {
      await applyRolePlayAdditions(
        _planService,
        localizations,
        result.rolePlay,
        result.additions,
      );
      await _planService.saveRolePlay(localizations, result.rolePlay);
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveStation(
    AppLocalizations localizations,
    Exercise exercise,
    Station updated,
  ) async {
    final stations = exercise.stations.toList()
      ..[widget.stationIndex] = updated;
    final newExercise = exercise.copyWith(stations: stations);
    await _planService.saveExercise(localizations, newExercise);
    if (!mounted) return;
    // Optimistic local update: we already hold the saved object, so swap it in
    // rather than re-reading it back out of the repository.
    updateLoaded(_StationSubject(newExercise, stations[widget.stationIndex]));
  }

  /// Function to handle editing the exercise. [initialSectionId] jumps the
  /// editor straight to that section (DESIGN-010's rollup card tap-to-edit)
  /// instead of always opening on the base section.
  void _editStation(
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
    final stations = exercise.stations.toList();

    // DESIGN-009 prompt 5: the delete-guard and save-block need to know
    // whether a roleplay linked to this station references a Location/
    // Person before letting the author remove or leave one dangling.
    final roleplays = _planService
        .loadRolePlays()
        .where(
          (r) =>
              r.exerciseUuid == exercise.uuid &&
              r.stationIndex == widget.stationIndex,
        )
        .toList();

    // Navigate to the edit exercise screen
    final result = await openFormSurface<StationFormResult>(
      context,
      builder: (context) => StationFormScreen(
        station: stations[widget.stationIndex],
        markers: _planService.getLocations().toMarkerSpecs(),
        variables: _planService.activePlan?.variables ?? const [],
        parentExercise: exercise,
        roleplays: roleplays,
        initialSectionId: initialSectionId,
      ),
    );
    // The previous guard was `newStation != exercise`, but those are
    // two unrelated types (Station vs Exercise) so the comparison was
    // always true. Backing out of the form (result == null) then
    // ran `stations[i] = null` on a non-nullable list and crashed.
    if (result == null) return;
    await applyVariableAdditionsToActivePlan(_planService, result.additions);
    stations[widget.stationIndex] = result.station;
    final newExercise = exercise.copyWith(stations: stations);
    await _planService.saveExercise(localizations, newExercise);
    if (!mounted) return;
    setState(() {
      exercise = newExercise;
    });
  }
}

/// A card header's compact "+ Action" affordance (mockup's `.addrow`) —
/// smaller than a `TextButton.icon`'s default tap target, matching the
/// mockup's inline link style rather than a full button.
class _HeaderAddAction extends StatelessWidget {
  const _HeaderAddAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 15, color: theme.colorScheme.primary),
            const SizedBox(width: 3),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StationStatusCard extends StatelessWidget {
  _StationStatusCard({
    required this.event,
    required this.exercise,
    required this.stationIndex,
  });

  final int stationIndex;
  final Exercise exercise;
  final ExerciseEvent event;
  final exerciseService = ExerciseService();

  @override
  Widget build(BuildContext context) {
    if (!exerciseService.isStartedOn(exercise.uuid)) {
      return const SizedBox.shrink();
    }
    final lastEvent = exerciseService.last;
    return StreamBuilder<ExerciseEvent>(
      stream: exerciseService.events,
      initialData: lastEvent?.exercise.uuid == exercise.uuid
          ? lastEvent
          : ExerciseEvent.pending(exercise),
      builder: (context, snapshot) {
        final event = snapshot.data!;
        final l10n = AppLocalizations.of(context)!;
        return PlayerStatusCard(
          event: event,
          preStartSubline: l10n.statusPreStartSubline(
            exercise.startTime.toString(),
            exercise.numberOfRounds,
          ),
          leadingCell: _teamAtPostCell(
            l10n,
            roundIndex: event.currentRound,
            isNow: true,
          ),
          trailingCell: _nextTeamAtPostCell(l10n, event),
        );
      },
    );
  }

  /// "Nå"/"Neste" team-at-post cell for [roundIndex], from
  /// `Exercise.teamIndex` — the same rotation math `_buildTimingCard`'s
  /// schedule rows read. `null` team ("Ikke aktiv nå") for [isNow]; a
  /// missing round for "Neste" is handled by [_nextTeamAtPostCell]
  /// returning `null` instead.
  PlayerStatusCell _teamAtPostCell(
    AppLocalizations l10n, {
    required int roundIndex,
    required bool isNow,
  }) {
    final teamIndex = exercise.teamIndex(stationIndex, roundIndex);
    return PlayerStatusCell(
      icon: Icons.groups,
      label: isNow ? l10n.statusNow : l10n.nextLabel,
      value: teamIndex == -1
          ? l10n.statusNotActiveNow
          : '${l10n.team(1)} ${teamIndex + 1}',
      isNow: isNow,
    );
  }

  /// The next round (after [event.currentRound]) that assigns a team to
  /// this station, falling back to [finishFallbackCell] once no later
  /// round does (last active round already running).
  PlayerStatusCell? _nextTeamAtPostCell(
    AppLocalizations l10n,
    ExerciseEvent event,
  ) {
    for (
      var roundIndex = event.currentRound + 1;
      roundIndex < exercise.schedule.length;
      roundIndex++
    ) {
      final teamIndex = exercise.teamIndex(stationIndex, roundIndex);
      if (teamIndex == -1) continue;
      return PlayerStatusCell(
        icon: Icons.arrow_forward,
        label: l10n.nextLabel,
        time: exercise.schedule[roundIndex][0].toString(),
        value: '${l10n.team(1)} ${teamIndex + 1}',
      );
    }
    return finishFallbackCell(l10n, exercise, icon: Icons.arrow_forward);
  }
}
