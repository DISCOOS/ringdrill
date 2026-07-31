import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/field_resolver.dart'
    show ActionChipFormatter, formatUtm;
import 'package:ringdrill/services/edit_permissions.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/subscription_bag.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';
import 'package:ringdrill/views/drill_player/player_mode.dart';
import 'package:ringdrill/views/loader_state.dart';
import 'package:ringdrill/views/map_view.dart' show MapConfig;
import 'package:ringdrill/views/plan_additions.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/shell/closable_surface.dart';
import 'package:ringdrill/views/shell/detail_empty_pane.dart';
import 'package:ringdrill/views/shell/master_detail_leading.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/shell/wide_detail_map_split.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';
import 'package:ringdrill/views/widgets/card_section_header.dart';
import 'package:ringdrill/views/widgets/cast_picker_sheet.dart';
import 'package:ringdrill/views/widgets/cast_pill.dart';
import 'package:ringdrill/views/widgets/collapsible_section_card.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/edit_affordance.dart';
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/face_badge_icon.dart';
import 'package:ringdrill/views/widgets/gender_segmented_control.dart';
import 'package:ringdrill/views/widgets/map_legend.dart';
import 'package:ringdrill/views/widgets/player_status_card.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';
import 'package:ringdrill/views/widgets/role_mini_map.dart';
import 'package:ringdrill/views/widgets/role_position_panel.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:ringdrill/views/widgets/position_empty_state.dart';
import 'package:ringdrill/views/widgets/roleplay_scope.dart';
import 'package:ringdrill/views/widgets/schedule_card.dart';
import 'package:ringdrill/views/widgets/schedule_table.dart';
import 'package:ringdrill/views/widgets/section_header.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';

/// Read-only view of a single [RolePlay]. Shows the publishable scenario
/// fields (name, age, description, background, behavior, station, position).
///
/// The Cast section (Staff assignment) is intentionally absent here because
/// this view represents the publishable role, not the local cast record.
/// Casting is managed from the RolePlays list via the cast picker.
///
/// Tap the edit pencil in the AppBar to push [RolePlayFormScreen].
///
/// TODO: When the observer-player shell (DESIGN-001) lands, a Role tab will
/// surface these same fields in the player context via a separate route.
class RolePlayScreen extends StatefulWidget {
  const RolePlayScreen({super.key, required this.uuid});

  final String uuid;

  @override
  State<RolePlayScreen> createState() => _RolePlayScreenState();
}

/// The two segments of the medium-width detail body — everything-but-the-map
/// (`info`) and the directly-interactive map (`map`). Mirrors
/// `_StationDetailView`; no resize coercion needed for the same reason (the
/// selector always carries both segments and only the medium body renders it).
enum _RolePlayDetailView { info, map }

/// What this screen shows: the roleplay plus the parent exercise it is scoped
/// to. Both are needed together — a roleplay whose exercise no longer exists
/// has nothing to render — so they are looked up as one unit.
class _RolePlaySubject {
  const _RolePlaySubject(this.rolePlay, this.exercise);

  final RolePlay rolePlay;
  final Exercise exercise;
}

class _RolePlayScreenState extends State<RolePlayScreen>
    with
        SubscriptionBag<RolePlayScreen>,
        ClosableSurface<RolePlayScreen>,
        Loader<RolePlayScreen, _RolePlaySubject, PlanEvent> {
  final _planService = PlanService();
  final _exerciseService = ExerciseService();

  _RolePlayDetailView _view = _RolePlayDetailView.info;

  bool _isStarted = false;

  @override
  void initState() {
    super.initState();

    load();

    // Listen to ExerciseService state changes. Re-read isStartedOn
    // unconditionally so an event from *another* exercise starting correctly
    // flips this viewer's own _isStarted back to false — same reasoning as
    // CoordinatorScreen's listener.
    listen(_exerciseService.events, (_) {
      if (!mounted) return;
      setState(onLoaded);
    });

    // Refresh on any plan mutation (cast/edit from the roster or another
    // pane, not just this viewer's own actions) — mirrors CoordinatorScreen.
    // Refresh on any plan mutation this viewer actually renders — its own
    // actions, but also a cast or edit from the roster or another pane.
    listen(_planService.events, (event) {
      if (_rendersChangesFrom(event)) reload(event);
    });
  }

  /// Whether [event] can change anything this viewer shows.
  ///
  /// Narrower than "any plan event", but deliberately wider than
  /// CoordinatorScreen's exercise-only test: this viewer also renders its own
  /// roleplay and — via the cast footer, which reads the Staff fresh from
  /// PlanService — the actor playing it. `rolePlaySaved` and `actorSaved` carry
  /// no exercise at all, so an exercise-keyed filter would leave a re-cast or a
  /// renamed marker showing stale text.
  ///
  /// While nothing is loaded, everything matches: the roleplay may be about to
  /// reappear (a plan re-activated, an undo), and this is the only way back
  /// from the not-found state.
  bool _rendersChangesFrom(PlanEvent event) {
    if (event.type == PlanEventType.planRefreshed) return true;
    if (loadState case Loaded<_RolePlaySubject>(:final value)) {
      final rolePlay = value.rolePlay;
      return event.exercise?.uuid == rolePlay.exerciseUuid ||
          event.rolePlay?.uuid == rolePlay.uuid ||
          (rolePlay.staffUuid != null &&
              event.actor?.uuid == rolePlay.staffUuid);
    }
    return true;
  }

  /// The parent exercise's uuid while the roleplay loads, else null. Incoming
  /// events are keyed by *exercise*, so this — never `widget.uuid`, which is
  /// this roleplay's own uuid — is what they must be matched against.
  String? get _exerciseUuid => switch (loadState) {
    Loaded<_RolePlaySubject>(:final value) => value.exercise.uuid,
    NotFound<_RolePlaySubject>() => null,
  };

  @override
  void onLoaded() {
    final uuid = _exerciseUuid;
    _isStarted = uuid != null && _exerciseService.isStartedOn(uuid);
  }

  @override
  _RolePlaySubject? onLoad(PlanEvent? event) {
    final rolePlay = _planService.getRolePlay(widget.uuid);
    if (rolePlay == null) return null;
    // The event's exercise is only an optimisation, and only when it is
    // actually *this* roleplay's parent — an event about some other exercise
    // must never be adopted as the subject.
    final carried = event?.exercise;
    final exercise = (carried != null && carried.uuid == rolePlay.exerciseUuid)
        ? carried
        : _planService.getExercise(rolePlay.exerciseUuid);
    if (exercise == null) return null;
    return _RolePlaySubject(rolePlay, exercise);
  }

  /// Opens the marker (cast) picker for [rolePlay] and applies the resulting
  /// select-or-clear choice, then reloads — the identity card's always-on
  /// quick action (Fix 4), mirroring the master tile's cast chip.
  Future<void> _openCastPicker(RolePlay rolePlay) async {
    final localizations = AppLocalizations.of(context)!;
    await openCastPickerAndApply(context, localizations, rolePlay);
    reload();
  }

  /// Opens [RolePlayFormScreen] for editing, optionally jumping straight to
  /// [initialSectionId] — used by the AppBar pencil (no section) and by
  /// tapping a Play-card section (its matching form section). Reloads on save.
  Future<void> _openRolePlayForm(
    _RolePlaySubject subject, {
    String? initialSectionId,
  }) async {
    final localizations = AppLocalizations.of(context)!;
    final result = await openFormSurface<RolePlayFormResult>(
      context,
      builder: (_) => RolePlayFormScreen(
        rolePlay: subject.rolePlay,
        exercise: subject.exercise,
        variables: _planService.activePlan?.variables ?? const [],
        initialSectionId: initialSectionId,
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
        reload();
      case RolePlayFormDelete(:final rolePlay):
        await _planService.deleteRolePlay(rolePlay.uuid);
        close();
    }
  }

  /// Deletes the shown roleplay after confirmation (the viewer's delete icon),
  /// then closes the viewer — the same shared confirm the roleplay form uses.
  Future<void> _confirmDeleteFromViewer(RolePlay rolePlay) async {
    if (!await confirmDeleteRolePlay(context, rolePlay) || !mounted) return;
    await _planService.deleteRolePlay(rolePlay.uuid);
    close();
  }

  /// The effective plan-variable map (ADR-0046) at [exercise]'s scope,
  /// optionally narrowed to [station]'s. Empty when there is no active
  /// plan.
  Map<String, String> _effectiveVariables(
    Exercise exercise, {
    Station? station,
  }) {
    final plan = _planService.activePlan;
    if (plan == null) return const {};
    return effectivePlanVariables(plan, exercise: exercise, station: station);
  }

  /// The scenario [Person] this roleplay portrays, via `personRef`, or
  /// null when unlinked (a legacy/orphaned roleplay with only its own bare
  /// fields, ADR-0047).
  Person? _personFor(Station? station, RolePlay rolePlay) {
    final personRef = rolePlay.personRef;
    if (station == null || personRef == null) return null;
    return station.persons.where((p) => p.slug == personRef).firstOrNull;
  }

  /// The [Location] this roleplay's position was copied from (DESIGN-009:
  /// `roleplay_form_screen.dart`'s `_applyPersonSelection` copies a
  /// "following" position from the linked person's own `locSlug`) — null
  /// when unlinked. Used by the identity card's expanded "Location" section.
  Location? _personLocation(Station? station, RolePlay rolePlay) {
    final person = _personFor(station, rolePlay);
    final locSlug = person?.locSlug;
    if (station == null || locSlug == null) return null;
    return station.locations.where((l) => l.slug == locSlug).firstOrNull;
  }

  /// The event to render for [exercise]: the service's live one when it
  /// belongs to *this* roleplay's parent exercise, else a pending placeholder.
  ///
  /// Matching is against [exercise]'s uuid, never `widget.uuid` — that is the
  /// roleplay's own uuid and can never equal an exercise's, so comparing it
  /// here would silently pin the view to "not started" forever.
  ExerciseEvent _ensureEvent(Exercise exercise, [ExerciseEvent? event]) {
    final last = event ?? _exerciseService.last;

    // Events from a different running exercise must not bleed into this
    // viewer's progress colours and phase display.
    if (last != null && last.exercise.uuid == exercise.uuid) return last;

    // Not started yet
    return ExerciseEvent.pending(exercise);
  }

  /// The roleplay is gone (deleted elsewhere, or a stale deep link).
  ///
  /// Deliberately does *not* dismiss itself: a view that disappears on its own
  /// leaves the reader wondering what happened, and in master/detail it would
  /// silently retract the pane they were just looking at. Explain instead, and
  /// let them close it — via the pane's own action or the AppBar leading.
  @override
  Widget buildNotFound(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: MasterDetailLeading(onClose: close)),
      body: DetailGonePane(
        icon: Icons.theater_comedy,
        message: AppLocalizations.of(context)!.detailGoneRolePlay,
        onClose: close,
      ),
    );
  }

  @override
  Widget buildLoaded(BuildContext context, _RolePlaySubject subject) {
    final l10n = AppLocalizations.of(context)!;
    final rolePlay = subject.rolePlay;
    final exercise = subject.exercise;
    return StreamBuilder(
      initialData: _ensureEvent(exercise),
      stream: _exerciseService.events,
      builder: (context, asyncSnapshot) {
        final event = _ensureEvent(exercise, asyncSnapshot.data);
        // RolePlay resolves at its station scope (ADR-0046, DESIGN-008
        // follow-up 07): the station it's assigned to, or just the exercise
        // when unassigned/out of range. Both are legitimate — an imported or
        // legacy roleplay can carry no stationIndex at all — so `station`
        // stays nullable all the way down rather than being forced here.
        final stations = exercise.stations;
        final stationIndex = rolePlay.stationIndex;
        final station =
            (stationIndex != null &&
                stationIndex >= 0 &&
                stationIndex < stations.length)
            ? stations[stationIndex]
            : null;
        final roleOverrides = _effectiveVariables(exercise, station: station);
        // The role's own number (e.g. "1.1-1"), matching the badge every
        // roleplay list row already shows — so the AppBar title and the map
        // sheet's header (built in _buildPositionPanel) both name "which role
        // this is", not just its (possibly reused) display name.
        final stationNumberFormat =
            _planService.activePlan?.stationNumberFormat ??
            StationNumberFormat.dotted;
        final exerciseNumber = _planService.getExerciseNumber(exercise.uuid);
        final roleNumber = stationIndex == null
            ? 0
            : _planService.roleNumberAtStation(rolePlay, stationIndex);
        final roleLabel = rolePlay.numberLabel(
          stationNumberFormat,
          exerciseNumber: exerciseNumber,
          roleNumber: roleNumber,
        );

        final scaffold = Scaffold(
          appBar: AppBar(
            leading: MasterDetailLeading(onClose: close),
            toolbarHeight: 72,
            title: SheetTitle(
              primary: '$roleLabel ${rolePlay.name}',
              secondary: exercise.name,
              secondaryOverrides: _effectiveVariables(exercise),
            ),
            actions: [
              // A markør's script is the actor's to write (ADR-0057), so this
              // pencil is one of the few edit affordances an actor keeps — and
              // it stays live-editable, which is the whole point of the
              // roleplay exemption.
              IfEditable(
                target: EditTarget.rolePlay,
                child: IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: l10n.roleSection,
                  onPressed: () => _openRolePlayForm(subject),
                ),
              ),
              // The Spill title is short, so — unlike the exercise viewer's
              // cramped compact bar — there is room for a standalone delete icon
              // next to edit instead of an overflow menu.
              //
              // Deleting is *not* the actor's to do, and unlike the pencil above
              // it has no live exemption: removing a markør the running exercise
              // still references is unrecoverable. Hence IfDeletable for the
              // role and the disable for the run.
              IfDeletable(
                target: EditTarget.rolePlay,
                child: IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: _isStarted
                      ? l10n.stopExerciseFirst(exercise.name)
                      : l10n.deleteRolePlay,
                  onPressed: _isStarted
                      ? null
                      : () => _confirmDeleteFromViewer(rolePlay),
                ),
              ),
            ],
            actionsPadding: const EdgeInsets.only(right: 16),
          ),
          body: SafeArea(
            // DESIGN-010 follow-up (expanded-map-right split): drives off the
            // body's own pane width (`WindowSizeClass.fromWidth`, not
            // `.of(context)` — this sheet can sit in a detail pane narrower
            // than the window, ADR-0030), moving the position panel to a fixed
            // full-height right pane beside a capped, independently-scrolling
            // left column once the pane is wide enough — mirroring the
            // coordinator's and Post viewer's own expanded bodies. Compact and
            // medium keep today's single scrolling column.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final windowSize = WindowSizeClass.fromWidth(
                  constraints.maxWidth,
                );
                if (windowSize == WindowSizeClass.expanded) {
                  return _buildExpandedBody(
                    context,
                    l10n: l10n,
                    subject: subject,
                    event: event,
                    station: station,
                    roleOverrides: roleOverrides,
                  );
                }
                // Compact and medium share the segmented Info/Map body; only
                // expanded gets the two-pane WideDetailMapSplit.
                return _buildSegmentedBody(
                  l10n: l10n,
                  subject: subject,
                  event: event,
                  station: station,
                  roleOverrides: roleOverrides,
                );
              },
            ),
          ),
          // Mirror the CoordinatorScreen pattern: dock a DrillMiniPlayer for
          // the parent exercise so the user can start it from the role view
          // (modal context sheet in narrow). In master-detail (wide) the
          // docked bar lives in the master column instead. We require a
          // resolvable parent exercise — orphaned roleplays just get the
          // body, no bar.
          bottomNavigationBar: (MasterDetailScope.maybeOf(context) == null)
              ? DrillMiniPlayer(
                  height: 64,
                  exercise: exercise,
                  applyBottomInset: true,
                  onPlay: () {
                    unawaited(HapticFeedback.mediumImpact());
                    ExerciseService().start(exercise);
                  },
                  mode: RolePlayerMode(rolePlay.uuid),
                  // showOrReplace, not replace: this screen can be a plain
                  // pushed route (a cold deep link) where the shell's
                  // controller exists but was never opened, and replace
                  // asserts on that.
                  onPickTarget: (target) => unawaited(
                    ContextSheet.of(context).showOrReplace(context, target),
                  ),
                )
              : null,
        );

        // DESIGN-010 stage 3 (ADR-0048): wrap in this roleplay's own facets plus
        // the linked station's/parent exercise's resolve-context scopes. The
        // roleplay scope is always present (this is its viewer); station/exercise
        // are optional (an orphaned/unassigned roleplay has neither), so each of
        // those is skipped rather than passed empty/fake data.
        Widget scoped = RoleplayScope.forRoleplay(rolePlay, child: scaffold);
        if (station != null) {
          scoped = StationScope(
            locations: station.locations,
            persons: station.persons,
            name: station.name,
            description: station.description,
            variantSuffix: station.variantSuffix,
            position: station.position,
            child: scoped,
          );
        }
        return ExerciseScope(
          exercise: exercise,
          variableOverrides: exercise.variableOverrides,
          child: scoped,
        );
      },
    );
  }

  /// The cards shared by both bodies, in their common order, everything
  /// but the position panel and the Når aktiv card (the stacked body
  /// inlines the position panel between this list and Når aktiv; the
  /// expanded body moves it to the right pane instead, so it is built
  /// separately by both).
  List<Widget> _buildInfoSections({
    required _RolePlaySubject subject,
    required Station? station,
    required ExerciseEvent event,
    required Map<String, String> roleOverrides,
    required AppLocalizations localizations,
  }) {
    final rolePlay = subject.rolePlay;
    final exercise = subject.exercise;
    return [
      // Omitted for an unassigned/orphaned roleplay (no station to report a
      // rotation for) and while the exercise is not running — mirrors
      // station_screen.dart's own `if (_isStarted)` gating.
      if (station != null && _isStarted)
        _RoleplayStatusCard(
          event: event,
          exercise: exercise,
          stationIndex: station.index,
        ),

      // Station context card — parent post, chevron through.
      _StationContextCard(
        station: station,
        exercise: exercise,
        overrides: roleOverrides,
      ),

      // Spill card — the whole play in one card: the effective identity
      // (person fields overridden by this roleplay's non-empty ones,
      // ADR-0047), the script sections (behavior/background/props) and the
      // cast footer. Replaces the former separate identity + Markørordre
      // cards.
      _RolePlayCard(
        rolePlay: rolePlay,
        person: _personFor(station, rolePlay),
        location: _personLocation(station, rolePlay),
        actor: rolePlay.staffUuid == null
            ? null
            : _planService.getStaff(rolePlay.staffUuid!),
        overrides: roleOverrides,
        onEditCast: () => _openCastPicker(rolePlay),
        onEditSection: (id) => _openRolePlayForm(subject, initialSectionId: id),
      ),
      _ActiveScheduleCard(exercise: exercise, rolePlay: rolePlay),
    ];
  }

  /// The role map panel. Null only when the exercise cannot be resolved — a
  /// missing *position* is no longer an absence to route around, because the panel
  /// renders the teaching card for it (ADR-0057 gating included). That is why
  /// `_buildMapPlaceholder` is gone: the card is the placeholder now, and it says
  /// something.
  ///
  /// [fillHeight] makes the map flex to fill the expanded body's right pane instead
  /// of the panel's own fixed default height; left `false` for the stacked body's
  /// inline card.
  Widget? _buildPositionPanel({
    required RolePlay rolePlay,
    required Station? station,
    required AppLocalizations l10n,
    required Map<String, String> roleOverrides,
    bool fillHeight = false,
    bool interactive = false,
  }) {
    final exercise = _planService.getExercise(rolePlay.exerciseUuid);
    if (exercise == null) return null;

    // A Builder, not the outer `build` context: the resolve-context scopes
    // are wrapped around the whole Scaffold in `build`, which sits *above*
    // `build`'s own context in the tree, so `resolveScopedField` needs a
    // context from inside it.
    return Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final resolvedRoleName =
            resolveScopedField(
              context,
              rolePlay.name,
              overrides: roleOverrides,
            ) ??
            rolePlay.name;

        // Del B: read-only context pins beside the central marker, via the
        // shared roleContextMarkers helper (role_mini_map.dart) so the
        // compact list tile shows the same map content as this detail
        // panel. The legend mirrors whichever pins are actually shown, led
        // by the marker's own central position (the `RoleMarker`'s
        // tertiary accent), the same dot + label strip the Post viewer's
        // map card uses.
        final contextPins = roleContextMarkers(
          context,
          rolePlay,
          station,
          overrides: roleOverrides,
        );
        final extra = contextPins.markers;
        final legendEntries = <MapLegendEntry>[
          MapLegendEntry(color: scheme.tertiary, label: resolvedRoleName),
          ...contextPins.legend,
        ];

        return RolePositionPanel(
          exercise: exercise,
          rolePlay: rolePlay,
          station: station,
          label: l10n.placement,
          overrides: roleOverrides,
          asCard: true,
          fillHeight: fillHeight,
          interactive: interactive,
          sectionId: 'position',
          extraMarkers: extra,
          legend: MapLegend(entries: legendEntries),
          emptyStyle: PositionEmptyStyle.card,
          emptyState: _buildRolePositionEmptyState(
            subject: _RolePlaySubject(rolePlay, exercise),
            l10n: l10n,
          ),
        );
      },
    );
  }

  /// The teaching state for a markør with no central position, gated like the
  /// AppBar pencil (ADR-0057).
  ///
  /// `roleCentralPosition` is null only when neither the markør nor its station has
  /// a position, so the copy names both routes out. The action sets the markør's
  /// *own* position, which is the one this screen can do something about.
  Widget _buildRolePositionEmptyState({
    required _RolePlaySubject subject,
    required AppLocalizations l10n,
  }) {
    return IfEditable(
      target: EditTarget.rolePlay,
      // Without a replacement IfEditable collapses to a zero-size box, which would
      // leave the card's thumbnail slot empty for a viewer.
      replacement: PositionEmptyState(
        title: l10n.noPositionTitle,
        body: l10n.noPositionRolePlayBody,
        icon: Icons.mood,
      ),
      child: PositionEmptyState(
        title: l10n.noPositionTitle,
        body: l10n.noPositionRolePlayBody,
        icon: Icons.mood,
        actionLabel: l10n.setOwnPosition,
        onAction: () =>
            _openRolePlayForm(subject, initialSectionId: 'position'),
      ),
    );
  }

  /// Expanded body (pane ≥ 840): the same cards the stacked body shows,
  /// split via the shared [WideDetailMapSplit] — the status/context/
  /// identity/Markørordre cards and Når aktiv in a capped, self-scrolling
  /// left column, the role's position panel as a fixed full-height right
  /// pane, mirroring the coordinator's and Post viewer's own expanded
  /// bodies.
  Widget _buildExpandedBody(
    BuildContext context, {
    required _RolePlaySubject subject,
    required Station? station,
    required ExerciseEvent event,
    required Map<String, String> roleOverrides,
    required AppLocalizations l10n,
  }) {
    return Padding(
      padding: const EdgeInsets.all(kPlayerSurfaceHorizontalPadding),
      child: WideDetailMapSplit(
        left: _buildInfoSections(
          subject: subject,
          event: event,
          station: station,
          roleOverrides: roleOverrides,
          localizations: l10n,
        ),
        mapPane:
            _buildPositionPanel(
              l10n: l10n,
              station: station,
              rolePlay: subject.rolePlay,
              roleOverrides: roleOverrides,
              fillHeight: true,
              interactive: true,
            ) ??
            const SizedBox.shrink(),
      ),
    );
  }

  /// Compact and medium body: a pinned Info/Map segmented selector, then the
  /// selected segment filling the rest. Info (status/context/play cards +
  /// schedule) scrolls within its area; Map fills it to the bottom with the
  /// directly-interactive position panel — which now teaches its own empty state
  /// when there is no central position, rather than being swapped for a
  /// placeholder. Only the `expanded` window size uses the two-pane
  /// `WideDetailMapSplit` instead.
  Widget _buildSegmentedBody({
    required _RolePlaySubject subject,
    required Station? station,
    required ExerciseEvent event,
    required Map<String, String> roleOverrides,
    required AppLocalizations l10n,
  }) {
    return Column(
      spacing: 8.0,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildViewSelector(l10n),
        Expanded(
          child: switch (_view) {
            _RolePlayDetailView.info => _segmentScroll(
              _buildInfoSections(
                subject: subject,
                event: event,
                station: station,
                roleOverrides: roleOverrides,
                localizations: l10n,
              ),
            ),
            _RolePlayDetailView.map => _fillOrScrollMap(
              _buildPositionPanel(
                    l10n: l10n,
                    station: station,
                    rolePlay: subject.rolePlay,
                    roleOverrides: roleOverrides,
                    fillHeight: true,
                    interactive: true,
                  ) ??
                  const SizedBox.shrink(),
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

  /// The Info/Map segmented control. Wrapped in a horizontal scroll view
  /// forced to at least the viewport width (like CoordinatorScreen's) so it
  /// centres when it fits and scrolls rather than overflows on a very
  /// narrow phone.
  Widget _buildViewSelector(AppLocalizations l10n) {
    final button = SegmentedButton<_RolePlayDetailView>(
      segments: [
        ButtonSegment<_RolePlayDetailView>(
          value: _RolePlayDetailView.info,
          label: Text(l10n.infoTab),
          icon: const Icon(Icons.info_outline),
        ),
        ButtonSegment<_RolePlayDetailView>(
          value: _RolePlayDetailView.map,
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

  /// Sizes the Map segment's [map] to fill the space the segmented body
  /// gives it — reaching the bottom with no dead gap — but never below a
  /// floor, since a shorter map can't fit its own FAB command stack (a very
  /// short landscape-phone viewport would otherwise overflow). When the
  /// available height is below the floor the map takes the floor and the
  /// area scrolls; otherwise it fills exactly. The floor is
  /// [MapConfig.minInteractiveHeight] (the *map's* own FAB-stack minimum)
  /// plus ~80px for the position panel's coordinate bar and legend below
  /// the map, so the map portion itself still clears the minimum.
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
}

/// Station context card (DESIGN-010's Spill viewer, harmonized into the
/// shared collapsible card family — mockup
/// `docs/design/mockups/spill-viewer-consistency.html`): a "Post" header
/// (flag icon + collapse chevron, like every other titled section card)
/// over a body that is itself a tappable region — the parent post's name and
/// its full description, navigating to the Post sheet. No bespoke "open"
/// affordance (no trailing chevron on the row): as with any
/// [CollapsibleSectionCard], the card must be expanded first, and tapping
/// the body is what navigates.
/// Falls back to [AppLocalizations.noStationAssigned] (still inside the
/// same collapsible card, just not tappable) for an unassigned/
/// out-of-range roleplay (ADR-0046, DESIGN-008 follow-up 07's
/// scope-resolution note).
class _StationContextCard extends StatelessWidget {
  const _StationContextCard({
    required this.station,
    required this.exercise,
    this.overrides = const {},
  });

  final Station? station;
  final Exercise? exercise;
  final Map<String, String> overrides;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final briefTheme = BriefTheme.of(context);
    final station = this.station;
    final exercise = this.exercise;
    // Post label: the formatted station number + name (Station.numberAndName),
    // or just the name when there is no resolvable post. Shown in both the
    // collapsed header and the body's title line.
    final postLabel = (station != null && exercise != null)
        ? station.numberAndName(
            PlanService().activePlan?.stationNumberFormat ??
                StationNumberFormat.dotted,
            exerciseNumber: PlanService().getExerciseNumber(exercise.uuid),
          )
        : station?.name;
    return CollapsibleSectionCard(
      sectionId: 'stationContext',
      // Collapsed appends which post this marker plays at — the formatted
      // station number + name — so the reader sees it without expanding.
      headerBuilder: (collapsed) {
        final title = StringBuffer(l10n.stationLabel.toUpperCase());
        if (collapsed && postLabel != null) {
          title.write(' · ${substitutePlanVariables(postLabel, overrides)}');
        }
        return kickerHeaderContent(
          context,
          icon: Icons.flag,
          title: title.toString(),
        );
      },
      body: station == null || exercise == null
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.noStationAssigned,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          : InkWell(
              onTap: () => ContextSheet.of(context).replace(
                StationSheetTarget(
                  exerciseUuid: exercise.uuid,
                  stationIndex: station.index,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Post name, prefixed with the formatted number and bold —
                    // the body's own title line.
                    RingDrillText.plain(
                      postLabel ?? station.name,
                      overrides: overrides,
                      style: briefTheme.typography.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: briefTheme.text.heading,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if ((station.description ?? '').isNotEmpty)
                      RingDrillText.rich(
                        station.description!,
                        overrides: overrides,
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// The "Spill" card — the whole play in one section card: the effective
/// identity (age · gender, description), the script sections
/// (behavior/background/props, kept as markdown), the person's notes and
/// linked [Location], and a muted "Spilles av …" footer naming the cast
/// actor. Replaces the former separate identity + Markørordre cards.
///
/// Identity/description each use the linked [Person]'s own value unless
/// [rolePlay] overrides it non-empty (ADR-0047's effective-identity rule —
/// the same rule `resolvePersonFacet` applies for `{{station.person.*}}`
/// tokens and the brief itself). Notes/location are not subject to that rule
/// — [RolePlay] has no fields of its own for either, so they come straight
/// from [person]/[location].
///
/// Built on [CollapsibleSectionCard] via its `headerBuilder` slot, so it
/// shares the card chrome, header divider and collapse machinery with the
/// Post/Når aktiv cards. The header is an uppercase "SPILL" kicker, which
/// while collapsed becomes "SPILLES AV {markør}" when a cast marker exists
/// (else stays "SPILL"); the cast quick action rides the wrapper's `trailing`
/// slot and the body aligns at the shared 12px padding.
class _RolePlayCard extends StatelessWidget {
  const _RolePlayCard({
    required this.rolePlay,
    required this.person,
    required this.actor,
    required this.onEditCast,
    required this.onEditSection,
    this.location,
    this.overrides = const {},
  });

  final RolePlay rolePlay;
  final Person? person;
  final Staff? actor;

  /// Opens the marker (cast) picker — the always-visible quick action in the
  /// card header, wired by [RolePlayScreen] to `_openCastPicker`.
  final VoidCallback onEditCast;

  /// Opens the roleplay form at the given form section id (roleplay-owned
  /// sections: description/behavior/background/props) — wired by
  /// [RolePlayScreen] to `_openRolePlayForm`.
  final void Function(String sectionId) onEditSection;

  final Location? location;
  final Map<String, String> overrides;

  /// ADR-0047's effective-identity rule: the roleplay's own non-empty
  /// value wins over the linked person's, mirroring
  /// `station_scenario_tokens.dart`'s private `_effectiveField` (not
  /// reusable here — that helper is private to its own file).
  static String? _effective(String? roleplayValue, String? personValue) =>
      (roleplayValue != null && roleplayValue.isNotEmpty)
      ? roleplayValue
      : personValue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final briefTheme = BriefTheme.of(context);
    final person = this.person;
    final actor = this.actor;
    final location = this.location;
    final age = rolePlay.age ?? person?.age;
    final gender = _effective(rolePlay.gender, person?.gender);
    final description = _effective(rolePlay.description, person?.description);
    final genderLabel = genderLabelFor(gender, l10n);
    final notes = person?.notes ?? '';
    final locationLabel = location == null
        ? null
        : (location.label.isEmpty ? location.slug : location.label);
    final locationPosition = location?.position;

    // The card body, in the agreed order: who (age · gender, then
    // description), what the marker does (the script sections
    // behavior/background/props, kept as markdown), person context (notes,
    // location), then the cast footer. Every labelled block uses the same
    // uppercase kicker; the name is not repeated here since it already heads
    // the viewer.
    final sections = <Widget>[];
    // [onTap] makes a block tappable to open its editor (parity around
    // editing): roleplay-owned blocks route to the roleplay form, person-/
    // post-owned blocks (PERSON/NOTATER/LOKASJON) to the parent post's form.
    void addSection(Widget child, {VoidCallback? onTap}) {
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 12));
      if (onTap != null) {
        child = InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: child,
          ),
        );
      }
      sections.add(child);
    }

    // [markdown] content (BriefMarkdownBlock) carries its own top spacing, so
    // plain-text content needs a larger label→body gap to line up with the
    // markdown script sections' airier spacing.
    Widget labeled(String label, Widget content, {bool markdown = false}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(label),
            // ~16px label→body gap; markdown content adds ~6px of its own top
            // spacing, so it gets a smaller SizedBox to land at the same gap.
            SizedBox(height: markdown ? 10 : 16),
            content,
          ],
        );

    // Non-markdown body text (description, notes, location) uses the same
    // style as the markdown script sections (BriefMarkdownBlock's paragraph:
    // briefTheme body typography + colour), so the whole card reads at one
    // size/colour with more air, not three.
    final bodyTextStyle = briefTheme.typography.body.copyWith(
      color: briefTheme.text.body,
    );

    Widget resolvedText(String text) =>
        RingDrillText.plain(text, overrides: overrides, style: bodyTextStyle);

    // PERSON section — the effective identity (name + age · gender), each the
    // linked person's own value unless this roleplay overrides it non-empty
    // (ADR-0047). A small accent dot marks any override; "Tilpasset fra
    // {person}" marks the overridden *name* specifically, so the reader knows
    // who is actually portrayed (mirrors the form's identity header). The
    // scenario Person is owned by the post, so a tap opens the post form.
    final name = _effective(rolePlay.name, person?.name) ?? rolePlay.name;
    final personName = person?.name;
    bool overridesValue(String? own, String? personValue) =>
        own != null && own.isNotEmpty && own != (personValue ?? '');
    final nameOverridden =
        personName != null && overridesValue(rolePlay.name, personName);
    final overrideCount = person == null
        ? 0
        : [
            overridesValue(rolePlay.name, person.name),
            rolePlay.age != null && rolePlay.age != person.age,
            overridesValue(rolePlay.gender, person.gender),
            overridesValue(rolePlay.description, person.description),
          ].where((overridden) => overridden).length;
    final metaParts = [
      if (age != null) l10n.rolePlayAgeYears(age),
      ?genderLabel,
    ];
    addSection(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row: the "PERSON" kicker, then the accent dot (any identity
          // facet overridden) with "Tilpasset fra {person}" as its label when
          // it is the name specifically that is overridden. A Wrap so the
          // label falls to the next line on a narrow card instead of
          // overflowing; the name below stays clean.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              SectionHeader(l10n.rolePlayPersonLabel),
              if (overrideCount > 0)
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                ),
              if (nameOverridden)
                Text(
                  l10n.rolePlayCustomizedFrom(personName),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          // ~16px label→body gap, matching the other blocks.
          const SizedBox(height: 16),
          // Effective name with age · gender appended inline (small-dot
          // separator); same body style as the rest of the card.
          RingDrillText.plain(
            metaParts.isEmpty ? name : '$name · ${metaParts.join(' · ')}',
            overrides: overrides,
          ),
          // The person's own notes, folded in and read together with the
          // identity (no "Notater" kicker of its own).
          if (notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: resolvedText(notes),
            ),
          // The person's location, read together with the identity (no
          // "Lokasjon" kicker of its own). Plain strings by convention —
          // no token resolution.
          if (locationLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: RingDrillText.rich(
                [
                  locationLabel,
                  if (locationPosition != null)
                    const ActionChipFormatter().position(
                      formatUtm(locationPosition),
                      locationPosition,
                    ),
                ].join(' · '),
              ),
            ),
        ],
      ),
      // The identity is edited on the roleplay's own "Rolle" section (person
      // selection + per-marker overrides), not the scenario Person directly.
      onTap: () => onEditSection('roleplay'),
    );

    if ((description ?? '').isNotEmpty) {
      addSection(
        labeled(l10n.roleDescription, resolvedText(description!)),
        onTap: () => onEditSection('roleplay'),
      );
    }

    // Script sections (markdown), resolved via the scope cascade (ADR-0048)
    // and skipped when they resolve to nothing. [sectionId] matches the
    // form's own `_MdSection` id so a tap opens the form at that section.
    void addScript(String sectionId, String label, String? raw) {
      if (raw == null || raw.isEmpty) return;
      final resolved =
          resolveScopedField(context, raw, overrides: overrides) ?? '';
      if (resolved.trim().isEmpty) return;
      addSection(
        labeled(
          label,
          BriefMarkdownBlock(data: resolved, theme: briefTheme, gutter: 0),
          markdown: true,
        ),
        onTap: () => onEditSection(sectionId),
      );
    }

    addScript('behavior', l10n.roleBehavior, rolePlay.behavior);
    addScript('background', l10n.roleBackground, rolePlay.background);
    addScript('props', l10n.roleProps, rolePlay.propsMd);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sections.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sections,
            ),
          ),
        // "Spilles av …" footer, separated from the sections above by a top
        // border only when there are sections (the header divider already
        // separates it otherwise).
        if (actor != null)
          // The footer names the cast actor and is itself tappable — opening
          // the same cast picker as the header quick action — via the same
          // CastPill chip as the collapsed tile's face chip and
          // roleplays_view's cast row.
          InkWell(
            onTap: onEditCast,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                border: sections.isNotEmpty
                    ? Border(
                        top: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      )
                    : null,
              ),
              child: Column(
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
                        onTap: () => _openCastPicker(context, rolePlay),
                      ),
                      // A full chip (copy icon and all), not plain tappable text — tap
                      // dials, the icon copies (ADR-0050, DESIGN-013).
                      if (actor.phone != null && actor.phone!.isNotEmpty)
                        RingDrillText.rich(
                          const ActionChipFormatter().phone(
                            actor.phone!,
                            actor.phone!,
                          ),
                        ),
                    ],
                  ),

                  if (actor.notes != null && actor.notes!.isNotEmpty)
                    RingDrillText.rich(actor.notes!),
                ],
              ),
            ),
          ),
      ],
    );

    return CollapsibleSectionCard(
      sectionId: 'spill',
      // Custom header: an uppercase "SPILL" kicker, built with the current
      // collapsed state so the marker's first name shows in parentheses only
      // while collapsed. The wrapper supplies the shared card chrome, the
      // header divider and the collapse chevron, so the card reads as one
      // family with Post/Når aktiv.
      headerBuilder: (collapsed) {
        // Collapsed with a cast marker → "SPILLES AV {markør}" (the
        // `castedByLine` string, uppercased); otherwise just "SPILL". A single
        // concrete marker → the face icon (masks = the markers list, face =
        // one marker, person = a person).
        final title = collapsed && actor != null
            ? l10n.castedByLine(actor.realName)
            : l10n.playSection;
        return kickerHeaderContent(
          context,
          icon: Icons.theater_comedy_outlined,
          title: title.toUpperCase(),
        );
      },
      // Add/change-marker quick action — always visible regardless of
      // collapse state (the one hurtigaksjon this card needs), mirroring the
      // master tile's cast chip. Sized down to the collapse chevron's footprint
      // so it does not make the header taller than the other section cards.
      trailing: IconButton(
        tooltip: actor != null ? l10n.editCast : l10n.addCast,
        visualDensity: VisualDensity.compact,
        // Cast → plain face; uncast → face + plus "assign an actor". person/
        // add-person is reserved for the character, not who enacts it.
        icon: actor != null
            ? Icon(Icons.face, color: theme.colorScheme.primary)
            : AddFaceIcon(color: theme.colorScheme.onSurfaceVariant),
        onPressed: onEditCast,
      ),
      body: body,
    );
  }

  // Select/clear/edit/add all live in the marker sheet itself now
  // (CastPickerSheet, DESIGN-010 browser tile polish) — this just opens it
  // and applies the resulting select-or-clear choice via the shared helper.
  Future<void> _openCastPicker(BuildContext context, RolePlay rolePlay) async {
    final localizations = AppLocalizations.of(context)!;
    await openCastPickerAndApply(context, localizations, rolePlay);
  }
}

/// The shared [PlayerStatusCard] for the Spill (Play) player (DESIGN-010
/// follow-up: player-status-card): "Nå"/"Neste" is the team [stationIndex]'s
/// post meets now/next, from `Exercise.teamIndex` — the same rotation math
/// [_ActiveScheduleCard] reads below — falling back to "Ikke aktiv nå" when
/// the post has no team assigned this round. Wrapped in its own
/// `StreamBuilder`, like [_ActiveScheduleCard], since [RolePlayScreen] has
/// no single event stream of its own.
class _RoleplayStatusCard extends StatelessWidget {
  const _RoleplayStatusCard({
    required this.event,
    required this.exercise,
    required this.stationIndex,
  });

  final int stationIndex;
  final Exercise exercise;
  final ExerciseEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PlayerStatusCard(
      event: event,
      preStartSubline: l10n.statusPreStartSublineMarker(
        _activeFrom().toString(),
        Numbering.station(
          PlanService().activePlan?.stationNumberFormat ??
              StationNumberFormat.dotted,
          exerciseNumber: _exerciseNumber(),
          stationIndex: stationIndex,
        ),
      ),
      leadingCell: _teamAtPostCell(l10n, event.currentRound, isNow: true),
      trailingCell: _nextTeamAtPostCell(l10n, event),
    );
  }

  /// Start time of the first round this post is staffed by a team, for the
  /// pre-start subline's "aktiv fra HH:MM" — falls back to the exercise's
  /// own start time when the post is never staffed (a marker with no active
  /// round at all).
  SimpleTimeOfDay _activeFrom() {
    for (
      var roundIndex = 0;
      roundIndex < exercise.schedule.length;
      roundIndex++
    ) {
      if (exercise.teamIndex(stationIndex, roundIndex) != -1) {
        return exercise.schedule[roundIndex][0];
      }
    }
    return exercise.startTime;
  }

  int _exerciseNumber() => PlanService().getExerciseNumber(exercise.uuid);

  PlayerStatusCell _teamAtPostCell(
    AppLocalizations l10n,
    int roundIndex, {
    required bool isNow,
  }) {
    final teamIndex = exercise.teamIndex(stationIndex, roundIndex);
    return PlayerStatusCell(
      icon: Icons.theater_comedy,
      label: isNow ? l10n.statusNow : l10n.nextLabel,
      value: teamIndex == -1
          ? l10n.statusNotActiveNow
          : '${l10n.team(1)} ${teamIndex + 1}',
      isNow: isNow,
    );
  }

  /// The next round (after [event.currentRound]) this post is staffed by a
  /// team, falling back to [finishFallbackCell] once no later round is
  /// (last active round already running).
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

/// When active card (DESIGN-010's Play viewer): the round(s) this roleplay's
/// station is staffed by a team, from `Exercise.schedule` +
/// `teamIndex`/`stationIndex` — filtered to only the active round(s)
/// (unlike the Post viewer's Tidsplan card, which shows every round). Reads
/// the same `ExerciseService` event stream the Post viewer does, via its own
/// `StreamBuilder`, so the currently running round gets the shared house
/// highlight + progress fill (only while running — otherwise the rows are
/// the plain "when" list they always were).
class _ActiveScheduleCard extends StatelessWidget {
  const _ActiveScheduleCard({required this.exercise, required this.rolePlay});

  final Exercise? exercise;
  final RolePlay rolePlay;

  @override
  Widget build(BuildContext context) {
    final exercise = this.exercise;
    final stationIndex = rolePlay.stationIndex;
    if (exercise == null || stationIndex == null) {
      return const SizedBox.shrink();
    }
    final rows = <ScheduleTableRow>[
      for (
        var roundIndex = 0;
        roundIndex < exercise.schedule.length;
        roundIndex++
      )
        if (exercise.teamIndex(stationIndex, roundIndex) != -1)
          ScheduleTableRow(
            roundIndex: roundIndex,
            label:
                '${AppLocalizations.of(context)!.team(1)} '
                '${exercise.teamIndex(stationIndex, roundIndex) + 1}',
            // The team staffing this post this round is tappable, mirroring
            // the Post viewer's Tidsplan card (station_screen._buildTimingCard):
            // every row here is an active round, so no muted/non-tappable case.
            onTap: () => ContextSheet.of(context).replace(
              TeamSheetTarget(
                exerciseUuid: exercise.uuid,
                teamIndex: exercise.teamIndex(stationIndex, roundIndex),
              ),
            ),
          ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    // Collapsed-header summary: the marker's active window — the first active
    // round's start to the last active round's end (its last phase start plus
    // the rotation it lasts) — and its total duration, via the shared
    // `scheduleWindowSummary` the Post viewer's Tidsplan card also uses.
    final startTime = exercise.schedule[rows.first.roundIndex].first;
    final endTime = SimpleTimeOfDay.fromMinutes(
      exercise.schedule[rows.last.roundIndex].last.inMinutes +
          exercise.rotationTime,
    );
    final activeSummary = scheduleWindowSummary(l10n, startTime, endTime);

    final exerciseService = ExerciseService();
    final lastEvent = exerciseService.last;
    return StreamBuilder<ExerciseEvent>(
      stream: exerciseService.events,
      initialData: lastEvent?.exercise.uuid == exercise.uuid
          ? lastEvent
          : ExerciseEvent.pending(exercise),
      builder: (context, snapshot) {
        final event = snapshot.data!;
        return ScheduleCard(
          sectionId: 'activeSchedule',
          title: l10n.roleActiveScheduleCardTitle,
          headerLabel: l10n.team(1),
          rows: rows,
          event: event,
          exercise: exercise,
          collapsedSummary: activeSummary,
        );
      },
    );
  }
}
