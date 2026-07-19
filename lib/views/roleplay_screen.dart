import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/field_resolver.dart'
    show ActionChipFormatter, formatUtm;
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/subscription_bag.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/plan_additions.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/shell/master_detail_leading.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/shell/wide_detail_map_split.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';
import 'package:ringdrill/views/widgets/card_section_header.dart';
import 'package:ringdrill/views/widgets/cast_picker_sheet.dart';
import 'package:ringdrill/views/widgets/collapsible_section_card.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/face_badge_icon.dart';
import 'package:ringdrill/views/widgets/gender_segmented_control.dart';
import 'package:ringdrill/views/widgets/location_kind_style.dart';
import 'package:ringdrill/views/widgets/map_legend.dart';
import 'package:ringdrill/views/widgets/player_status_card.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';
import 'package:ringdrill/views/widgets/role_position_panel.dart';
import 'package:ringdrill/views/widgets/roleplay_scope.dart';
import 'package:ringdrill/views/widgets/schedule_card.dart';
import 'package:ringdrill/views/widgets/schedule_table.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';

/// Read-only view of a single [RolePlay]. Shows the publishable scenario
/// fields (name, age, signalement, background, behavior, station, position).
///
/// The Cast section (Actor assignment) is intentionally absent here because
/// this view represents the publishable role, not the local cast record.
/// Casting is managed from the RolePlays list via the cast picker.
///
/// Tap the edit pencil in the AppBar to push [RolePlayFormScreen].
///
/// TODO: When the observer-player shell (DESIGN-001) lands, a Role tab will
/// surface these same fields in the player context via a separate route.
class RolePlayScreen extends StatefulWidget {
  const RolePlayScreen({super.key, required this.rolePlayUuid});

  final String rolePlayUuid;

  @override
  State<RolePlayScreen> createState() => _RolePlayScreenState();
}

class _RolePlayScreenState extends State<RolePlayScreen>
    with SubscriptionBag<RolePlayScreen> {
  final _programService = ProgramService();

  RolePlay? _rolePlay;

  @override
  void initState() {
    super.initState();
    _load();
    // Refresh on any program mutation (cast/edit from the roster or another
    // pane, not just this viewer's own actions) — mirrors CoordinatorScreen.
    listen(_programService.events, (_) {
      if (mounted) _load();
    });
  }

  void _load() {
    setState(() {
      _rolePlay = _programService.getRolePlay(widget.rolePlayUuid);
    });
  }

  /// Opens the marker (cast) picker for [rolePlay] and applies the resulting
  /// select-or-clear choice, then reloads — the identity card's always-on
  /// quick action (Fix 4), mirroring the master tile's cast chip.
  Future<void> _openCastPicker(RolePlay rolePlay) async {
    final localizations = AppLocalizations.of(context)!;
    await openCastPickerAndApply(context, localizations, rolePlay);
    if (mounted) _load();
  }

  /// Opens [RolePlayFormScreen] for editing, optionally jumping straight to
  /// [initialSectionId] — used by the AppBar pencil (no section) and by
  /// tapping a Play-card section (its matching form section). Reloads on
  /// save. No-op when the roleplay is not resolvable.
  Future<void> _openRolePlayForm({String? initialSectionId}) async {
    final localizations = AppLocalizations.of(context)!;
    final rolePlay = _rolePlay;
    if (rolePlay == null) return;
    final exercise = _programService.getExercise(rolePlay.exerciseUuid);
    final result = await openFormSurface<RolePlayFormResult>(
      context,
      builder: (_) => RolePlayFormScreen(
        rolePlay: rolePlay,
        exercise: exercise,
        variables: _programService.activeProgram?.variables ?? const [],
        initialSectionId: initialSectionId,
        isExisting: true,
      ),
    );
    switch (result) {
      case null:
        return;
      case RolePlayFormSave(:final rolePlay, :final additions):
        await applyRolePlayAdditions(
          _programService,
          localizations,
          rolePlay,
          additions,
        );
        await _programService.saveRolePlay(localizations, rolePlay);
        if (mounted) _load();
      case RolePlayFormDelete(:final rolePlay):
        await _programService.deleteRolePlay(rolePlay.uuid);
        if (!mounted) return;
        // The roleplay this viewer showed is gone — close the viewer.
        if (MasterDetailScope.maybeOf(context) != null) {
          ContextSheet.of(context).close();
        } else {
          Navigator.pop(context);
        }
    }
  }

  /// Deletes the shown roleplay after confirmation (the viewer's delete icon),
  /// then closes the viewer — the same shared confirm the roleplay form uses.
  Future<void> _confirmDeleteFromViewer() async {
    final rolePlay = _rolePlay;
    if (rolePlay == null) return;
    if (!await confirmDeleteRolePlay(context, rolePlay) || !mounted) return;
    await _programService.deleteRolePlay(rolePlay.uuid);
    if (!mounted) return;
    if (MasterDetailScope.maybeOf(context) != null) {
      ContextSheet.of(context).close();
    } else {
      Navigator.pop(context);
    }
  }

  /// The effective plan-variable map (ADR-0046) at [exercise]'s scope,
  /// optionally narrowed to [station]'s. Empty when there is no active
  /// plan.
  Map<String, String> _effectiveVariables(
    Exercise? exercise, {
    Station? station,
  }) {
    final program = _programService.activeProgram;
    if (program == null) return const {};
    return effectivePlanVariables(
      program,
      exercise: exercise,
      station: station,
    );
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
  /// when unlinked. Shared by [_positionSourceLabel] (the position card's
  /// bar, pre-DESIGN-010-consistency) and the identity card's expanded
  /// "Location" section.
  Location? _personLocation(Station? station, RolePlay rolePlay) {
    final person = _personFor(station, rolePlay);
    final locSlug = person?.locSlug;
    if (station == null || locSlug == null) return null;
    return station.locations.where((l) => l.slug == locSlug).firstOrNull;
  }

  /// The label of [_personLocation] — null when unlinked, so the position
  /// card's bar falls back to a single-line "Posisjon" label.
  String? _positionSourceLabel(Station? station, RolePlay rolePlay) {
    final location = _personLocation(station, rolePlay);
    if (location == null) return null;
    return location.label.isEmpty ? location.slug : location.label;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final rolePlay = _rolePlay;

    if (rolePlay == null) {
      return Scaffold(
        appBar: AppBar(
          leading: MasterDetailLeading(onClose: () => Navigator.pop(context)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final exercise = _programService.getExercise(rolePlay.exerciseUuid);
    // RolePlay resolves at its station scope (ADR-0046, DESIGN-008
    // follow-up 07): the station it's assigned to, or just the exercise
    // when unassigned/out of range.
    final stations = exercise?.stations;
    final stationIndex = rolePlay.stationIndex;
    final station =
        (stations != null &&
            stationIndex != null &&
            stationIndex >= 0 &&
            stationIndex < stations.length)
        ? stations[stationIndex]
        : null;
    final roleOverrides = _effectiveVariables(exercise, station: station);

    final scaffold = Scaffold(
      appBar: AppBar(
        leading: MasterDetailLeading(
          onClose: () {
            if (MasterDetailScope.maybeOf(context) != null) {
              ContextSheet.of(context).close();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        toolbarHeight: 72,
        title: SheetTitle(
          primary: rolePlay.name,
          secondary: exercise?.name,
          secondaryOverrides: _effectiveVariables(exercise),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: localizations.roleSection,
            onPressed: () => _openRolePlayForm(),
          ),
          // The Spill title is short, so — unlike the exercise viewer's
          // cramped compact bar — there is room for a standalone delete icon
          // next to edit instead of an overflow menu.
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: localizations.deleteRolePlay,
            onPressed: _confirmDeleteFromViewer,
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
            final windowSize = WindowSizeClass.fromWidth(constraints.maxWidth);
            if (windowSize == WindowSizeClass.expanded) {
              return _buildExpandedBody(
                context,
                rolePlay: rolePlay,
                station: station,
                exercise: exercise,
                stationIndex: stationIndex,
                roleOverrides: roleOverrides,
                localizations: localizations,
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(kPlayerSurfaceHorizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Identity (name + parent exercise) lives in the sheet's
                  // AppBar via `SheetTitle`. The body starts directly at
                  // the first content card.
                  ..._buildTopSections(
                    rolePlay: rolePlay,
                    station: station,
                    exercise: exercise,
                    stationIndex: stationIndex,
                    roleOverrides: roleOverrides,
                    localizations: localizations,
                  ),

                  // Position card — the marker's own position (or, failing
                  // that, the portrayed person's location), plus read-only
                  // post/person context pins (Del B). Omitted entirely (not
                  // even a placeholder) when there is no central position.
                  if (_markerMapCentral(rolePlay, station) != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildPositionPanel(
                        rolePlay: rolePlay,
                        station: station,
                        roleOverrides: roleOverrides,
                      )!,
                    ),

                  // Når aktiv card — the round(s) this station is staffed
                  // by a team, from the same Exercise.schedule +
                  // teamIndex data the Post viewer's Tidsplan card reads.
                  _ActiveScheduleCard(exercise: exercise, rolePlay: rolePlay),
                ],
              ),
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
      bottomNavigationBar:
          (MasterDetailScope.maybeOf(context) == null && exercise != null)
          ? DrillMiniPlayer(
              exercise: exercise,
              height: 64,
              applyBottomInset: true,
              onOpen: () {},
              onPlay: () {
                unawaited(HapticFeedback.mediumImpact());
                ExerciseService().start(exercise);
              },
              onPickExercise: (picked) => ContextSheet.of(
                context,
              ).replace(ExerciseSheetTarget(exerciseUuid: picked.uuid)),
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
    if (exercise != null) {
      scoped = ExerciseScope(
        exercise: exercise,
        variableOverrides: exercise.variableOverrides,
        child: scoped,
      );
    }
    return scoped;
  }

  /// The cards shared by both bodies, in their common order, everything
  /// but the position panel and the Når aktiv card (the stacked body
  /// inlines the position panel between this list and Når aktiv; the
  /// expanded body moves it to the right pane instead, so it is built
  /// separately by both).
  List<Widget> _buildTopSections({
    required RolePlay rolePlay,
    required Station? station,
    required Exercise? exercise,
    required int? stationIndex,
    required Map<String, String> roleOverrides,
    required AppLocalizations localizations,
  }) {
    return [
      // Shared status card (DESIGN-010 follow-up: player-status-card):
      // "Nå"/"Neste" is the team this marker's post meets, from the same
      // rotation math the "Når aktiv" card reads. Omitted for an
      // unassigned/orphaned roleplay.
      if (station != null && exercise != null && stationIndex != null)
        _PlayStatusCard(exercise: exercise, stationIndex: stationIndex),

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
      _PlayCard(
        rolePlay: rolePlay,
        person: _personFor(station, rolePlay),
        location: _personLocation(station, rolePlay),
        actor: rolePlay.actorUuid == null
            ? null
            : _programService.getActor(rolePlay.actorUuid!),
        overrides: roleOverrides,
        onEditCast: () => _openCastPicker(rolePlay),
        onEditSection: (id) => _openRolePlayForm(initialSectionId: id),
      ),
    ];
  }

  /// The role map panel — null when [rolePlay] has no position, matching
  /// the stacked body's own "omit entirely" behaviour; the expanded body's
  /// right pane falls back to [_buildMapPlaceholder] instead, since it
  /// always needs something to show there. [fillHeight] makes the map flex
  /// to fill the expanded body's right pane instead of the panel's own
  /// fixed default height; left `false` for the stacked body's inline
  /// card.
  /// The role map's central position (Del B): the marker's own position if
  /// set, else the portrayed person's location. Null when the marker has
  /// neither — the map is omitted entirely.
  LatLng? _markerMapCentral(RolePlay rolePlay, Station? station) =>
      rolePlay.position ?? _personLocation(station, rolePlay)?.position;

  Widget? _buildPositionPanel({
    required RolePlay rolePlay,
    required Station? station,
    required Map<String, String> roleOverrides,
    bool fillHeight = false,
  }) {
    final central = _markerMapCentral(rolePlay, station);
    if (central == null) return null;
    final personLocation = _personLocation(station, rolePlay);
    final exercise = _programService.getExercise(rolePlay.exerciseUuid);
    final stationNumberFormat =
        _programService.activeProgram?.stationNumberFormat ??
        StationNumberFormat.dotted;
    final exNum = exercise == null
        ? 1
        : _programService.loadExercises().indexWhere(
                (e) => e.uuid == exercise.uuid,
              ) +
              1;
    final exerciseNumber = exNum < 1 ? 1 : exNum;

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

        // Del B: read-only context pins beside the central marker — the parent
        // post's position (green place pin) and the portrayed person's
        // location (kind-styled pin) — each only when it sits at a distinct
        // spot (within a small tolerance) from the central marker and from
        // each other. The legend mirrors whichever pins are actually shown,
        // led by the marker's own central position (the `RoleMarker`'s
        // tertiary accent), the same dot + label strip the Post viewer's map
        // card uses.
        final extra = <MapMarkerSpec<int>>[];
        final legendEntries = <MapLegendEntry>[
          MapLegendEntry(color: scheme.tertiary, label: resolvedRoleName),
        ];
        bool distinct(LatLng p) =>
            !_samePlace(p, central) &&
            extra.every((m) => !_samePlace(p, m.point));

        final postPosition = station?.position;
        if (station != null && postPosition != null && distinct(postPosition)) {
          final rawLabel = station.numberAndName(
            stationNumberFormat,
            exerciseNumber: exerciseNumber,
          );
          final postLabel =
              resolveScopedField(context, rawLabel, overrides: roleOverrides) ??
              rawLabel;
          extra.add(
            MapMarkerSpec<int>(
              id: 1,
              label: postLabel,
              point: postPosition,
              child: const Icon(Icons.place, color: Colors.green, size: 32),
            ),
          );
          legendEntries.add(
            MapLegendEntry(color: Colors.green, label: postLabel),
          );
        }
        final locPosition = personLocation?.position;
        if (personLocation != null &&
            locPosition != null &&
            distinct(locPosition)) {
          final locLabel = personLocation.label.isEmpty
              ? personLocation.slug
              : personLocation.label;
          extra.add(
            MapMarkerSpec<int>(
              id: 2,
              label: locLabel,
              point: locPosition,
              child: Icon(
                personLocation.kind.icon,
                color: personLocation.kind.color,
                size: 30,
              ),
            ),
          );
          legendEntries.add(
            MapLegendEntry(color: personLocation.kind.color, label: locLabel),
          );
        }

        return RolePositionPanel(
          position: central,
          label: resolvedRoleName,
          sourceLabel: _positionSourceLabel(station, rolePlay),
          asCard: true,
          fillHeight: fillHeight,
          sectionId: 'position',
          extraMarkers: extra,
          legend: MapLegend(entries: legendEntries),
        );
      },
    );
  }

  /// Placeholder shown in the expanded body's map pane for an unassigned
  /// roleplay with no position — mirrors the coordinator's own
  /// `_buildMapPlaceholder`.
  Widget _buildMapPlaceholder(AppLocalizations localizations) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(child: Text(localizations.noLocation)),
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
    required RolePlay rolePlay,
    required Station? station,
    required Exercise? exercise,
    required int? stationIndex,
    required Map<String, String> roleOverrides,
    required AppLocalizations localizations,
  }) {
    return Padding(
      padding: const EdgeInsets.all(kPlayerSurfaceHorizontalPadding),
      child: WideDetailMapSplit(
        left: [
          ..._buildTopSections(
            rolePlay: rolePlay,
            station: station,
            exercise: exercise,
            stationIndex: stationIndex,
            roleOverrides: roleOverrides,
            localizations: localizations,
          ),
          _ActiveScheduleCard(exercise: exercise, rolePlay: rolePlay),
        ],
        mapPane:
            _buildPositionPanel(
              rolePlay: rolePlay,
              station: station,
              roleOverrides: roleOverrides,
              fillHeight: true,
            ) ??
            _buildMapPlaceholder(localizations),
      ),
    );
  }
}

/// Two positions count as the same spot when within ~5 m — used to drop the
/// Spill map's post/person context pins when they coincide with the marker's
/// own central position (Del B). A coarse degree epsilon is enough here (the
/// pins are just deduplicated, not measured); longitude runs tighter at high
/// latitudes, which only makes the test slightly stricter there.
bool _samePlace(LatLng a, LatLng b) {
  const eps = 0.00005; // ~5.5 m of latitude
  return (a.latitude - b.latitude).abs() < eps &&
      (a.longitude - b.longitude).abs() < eps;
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
            ProgramService().activeProgram?.stationNumberFormat ??
                StationNumberFormat.dotted,
            exerciseNumber:
                ProgramService().loadExercises().indexWhere(
                  (e) => e.uuid == exercise.uuid,
                ) +
                1,
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
/// identity (age · gender, signalement), the script sections
/// (behavior/background/props, kept as markdown), the person's notes and
/// linked [Location], and a muted "Spilles av …" footer naming the cast
/// actor. Replaces the former separate identity + Markørordre cards.
///
/// Identity/signalement each use the linked [Person]'s own value unless
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
class _PlayCard extends StatelessWidget {
  const _PlayCard({
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
  final Actor? actor;

  /// Opens the marker (cast) picker — the always-visible quick action in the
  /// card header, wired by [RolePlayScreen] to `_openCastPicker`.
  final VoidCallback onEditCast;

  /// Opens the roleplay form at the given form section id (roleplay-owned
  /// sections: signalement/behavior/background/props) — wired by
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
    final signalement = _effective(rolePlay.signalement, person?.signalement);
    final genderLabel = genderLabelFor(gender, l10n);
    final notes = person?.notes ?? '';
    final locationLabel = location == null
        ? null
        : (location.label.isEmpty ? location.slug : location.label);
    final locationPosition = location?.position;

    // The card body, in the agreed order: who (age · gender, then
    // signalement), what the marker does (the script sections
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
            _IdentityMoreLabel(label),
            // ~16px label→body gap; markdown content adds ~6px of its own top
            // spacing, so it gets a smaller SizedBox to land at the same gap.
            SizedBox(height: markdown ? 10 : 16),
            content,
          ],
        );

    // Non-markdown body text (signalement, notes, location) uses the same
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
            overridesValue(rolePlay.signalement, person.signalement),
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
              _IdentityMoreLabel(l10n.rolePlayPersonLabel),
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
            style: bodyTextStyle,
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
              child: Text(
                [
                  locationLabel,
                  if (locationPosition != null) formatUtm(locationPosition),
                ].join(' · '),
                style: bodyTextStyle,
              ),
            ),
        ],
      ),
      // The identity is edited on the roleplay's own "Rolle" section (person
      // selection + per-marker overrides), not the scenario Person directly.
      onTap: () => onEditSection('roleplay'),
    );

    if ((signalement ?? '').isNotEmpty) {
      addSection(
        labeled(l10n.roleSignalement, resolvedText(signalement!)),
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
        // "Spilles av …" footer — a muted row (no dark band), separated from
        // the sections above by a top border only when there are sections
        // (the header divider already separates it otherwise).
        if (actor != null)
          // The footer names the cast actor and is itself tappable — opening
          // the same cast picker as the header quick action — kept a plain
          // muted row (no chip background).
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // "Spilles av …" names the actor → face icon (person ≠
                      // actor; person is reserved for the character).
                      Icon(
                        Icons.face,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.castedByLine(actor.realName),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  // The cast footer is the only surface with room for the
                  // actor's phone (ADR-0050, DESIGN-013) — a full chip (copy
                  // icon and all), indented under the name to align with it.
                  if (actor.phone != null && actor.phone!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 24),
                      child: RingDrillText.rich(
                        const ActionChipFormatter().phone(
                          actor.phone!,
                          actor.phone!,
                        ),
                      ),
                    ),
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
          icon: Icons.face,
          title: title.toUpperCase(),
        );
      },
      // Add/change-marker quick action — always visible regardless of
      // collapse state (the one hurtigaksjon this card needs), mirroring the
      // master tile's cast chip. Sized down to the collapse chevron's footprint
      // so it does not make the header taller than the other section cards.
      trailing: IconButton(
        tooltip: actor != null ? l10n.editCast : l10n.addCast,
        iconSize: 20,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
        // Cast → plain face; uncast → face + plus "assign an actor". person/
        // add-person is reserved for the character, not who enacts it.
        icon: actor != null
            ? Icon(Icons.face, color: theme.colorScheme.primary)
            : AddFaceIcon(size: 20, color: theme.colorScheme.onSurfaceVariant),
        onPressed: onEditCast,
      ),
      body: body,
    );
  }
}

/// The small uppercase kicker label above each labelled block in the Spill
/// card body (mockup's `.pmore .k`) — "SIGNALEMENT", "OPPFØRSEL",
/// "NOTATER", "LOKASJON", …
class _IdentityMoreLabel extends StatelessWidget {
  const _IdentityMoreLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 0.4,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// The shared [PlayerStatusCard] for the Spill (Play) player (DESIGN-010
/// follow-up: player-status-card): "Nå"/"Neste" is the team [stationIndex]'s
/// post meets now/next, from `Exercise.teamIndex` — the same rotation math
/// [_ActiveScheduleCard] reads below — falling back to "Ikke aktiv nå" when
/// the post has no team assigned this round. Wrapped in its own
/// `StreamBuilder`, like [_ActiveScheduleCard], since [RolePlayScreen] has
/// no single event stream of its own.
class _PlayStatusCard extends StatelessWidget {
  const _PlayStatusCard({required this.exercise, required this.stationIndex});

  final Exercise exercise;
  final int stationIndex;

  @override
  Widget build(BuildContext context) {
    final exerciseService = ExerciseService();
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
          preStartSubline: l10n.statusPreStartSublineMarker(
            _activeFrom().toString(),
            Numbering.station(
              ProgramService().activeProgram?.stationNumberFormat ??
                  StationNumberFormat.dotted,
              exerciseNumber: _exerciseNumber(),
              stationIndex: stationIndex,
            ),
          ),
          leadingCell: _teamAtPostCell(l10n, event.currentRound, isNow: true),
          trailingCell: _nextTeamAtPostCell(l10n, event),
        );
      },
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

  int _exerciseNumber() =>
      ProgramService().loadExercises().indexWhere(
        (e) => e.uuid == exercise.uuid,
      ) +
      1;

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

/// Når aktiv card (DESIGN-010's Spill viewer): the round(s) this roleplay's
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
