import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/field_resolver.dart' show formatUtm;
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';
import 'package:ringdrill/views/plan_additions.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/shell/master_detail_leading.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/wide_detail_map_split.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/player_status_card.dart';
import 'package:ringdrill/views/widgets/schedule_card.dart';
import 'package:ringdrill/views/widgets/collapse_chevron.dart';
import 'package:ringdrill/views/widgets/collapsible_section_card.dart';
import 'package:ringdrill/views/widgets/collapsible_section_store.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/gender_segmented_control.dart';
import 'package:ringdrill/views/widgets/narrative_rollup_card.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';
import 'package:ringdrill/views/widgets/role_position_panel.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';
import 'package:ringdrill/views/widgets/schedule_table.dart';

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

class _RolePlayScreenState extends State<RolePlayScreen> {
  final _programService = ProgramService();

  RolePlay? _rolePlay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _rolePlay = _programService.getRolePlay(widget.rolePlayUuid);
    });
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

  /// This roleplay's own `roleplay.*` facets (DESIGN-010's resolve-context
  /// cascade — the same shape `RolePlayFormScreen._roleplayFacets` builds
  /// for its live preview), passed to `resolveScopedField`'s
  /// `roleplayFacets` rather than a scope (DESIGN-010: "small enough...
  /// than a separate scope").
  Map<String, dynamic> _roleplayFacets(RolePlay rolePlay) => {
    'name': rolePlay.name,
    'age': rolePlay.age,
    'signalement': rolePlay.signalement ?? '',
    'position': {
      'utm': rolePlay.position == null ? '' : formatUtm(rolePlay.position),
    },
  };

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
          leading: MasterDetailLeading(
            onClose: () => Navigator.pop(context),
          ),
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
            onPressed: () async {
              final result = await openFormSurface<RolePlayFormResult>(
                context,
                builder: (_) => RolePlayFormScreen(
                  rolePlay: rolePlay,
                  exercise: exercise,
                  variables:
                      _programService.activeProgram?.variables ?? const [],
                ),
              );
              if (result != null) {
                await applyRolePlayAdditions(
                  _programService,
                  localizations,
                  result.rolePlay,
                  result.additions,
                );
                await _programService.saveRolePlay(
                  localizations,
                  result.rolePlay,
                );
                if (context.mounted) _load();
              }
            },
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

                  // Position card — follows the portrayed person's
                  // location (copied onto rolePlay.position at selection
                  // time). Omitted entirely (not even a placeholder) when
                  // there is no position, matching this body's pre-
                  // expanded-split behaviour.
                  if (rolePlay.position != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildPositionPanel(
                        rolePlay: rolePlay,
                        station: station,
                        roleOverrides: roleOverrides,
                      ),
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

    // DESIGN-010 stage 3 (ADR-0048): wrap in the linked station's/parent
    // exercise's resolve-context scopes, mirroring station_screen.dart —
    // both are optional here (an orphaned or unassigned roleplay has
    // neither), so each wrap is skipped rather than passed empty/fake data.
    Widget scoped = scaffold;
    if (station != null) {
      scoped = StationScope(
        locations: station.locations,
        persons: station.persons,
        name: station.name,
        description: station.description,
        variantSuffix: station.variantSuffix,
        positionUtm: formatUtm(station.position),
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
        _MarkerStatusCard(exercise: exercise, stationIndex: stationIndex),

      // Station context card — parent post, chevron through.
      _StationContextCard(
        station: station,
        exercise: exercise,
        overrides: roleOverrides,
      ),

      // Effective identity card — the person's own fields, overridden by
      // this roleplay's non-empty ones (ADR-0047): the same rule the
      // brief and the editor's chip resolution already apply, computed
      // here for display instead of assuming `rolePlay`'s own fields are
      // already effective.
      _EffectiveIdentityCard(
        rolePlay: rolePlay,
        person: _personFor(station, rolePlay),
        location: _personLocation(station, rolePlay),
        actor: rolePlay.actorUuid == null
            ? null
            : _programService.getActor(rolePlay.actorUuid!),
        overrides: roleOverrides,
        roleplayFacets: _roleplayFacets(rolePlay),
      ),

      // Markørordre card — the play itself (behavior/background/props),
      // resolved. Signalement moved to the identity card above (DESIGN-
      // 010 mockup) since it's part of *who*, not *what the marker does*.
      if (rolePlay.background?.isNotEmpty == true ||
          rolePlay.behavior?.isNotEmpty == true ||
          rolePlay.propsMd?.isNotEmpty == true)
        NarrativeRollupCard(
          sectionId: 'markorordre',
          icon: Icons.theater_comedy,
          title: localizations.roleSection,
          sections: [
            NarrativeSection(
              id: 'behavior',
              label: localizations.roleBehavior,
              text: rolePlay.behavior,
              overrides: roleOverrides,
              roleplayFacets: _roleplayFacets(rolePlay),
            ),
            NarrativeSection(
              id: 'background',
              label: localizations.roleBackground,
              text: rolePlay.background,
              overrides: roleOverrides,
              roleplayFacets: _roleplayFacets(rolePlay),
            ),
            NarrativeSection(
              id: 'props',
              label: localizations.roleProps,
              text: rolePlay.propsMd,
              overrides: roleOverrides,
              roleplayFacets: _roleplayFacets(rolePlay),
            ),
          ],
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
  Widget? _buildPositionPanel({
    required RolePlay rolePlay,
    required Station? station,
    required Map<String, String> roleOverrides,
    bool fillHeight = false,
  }) {
    final position = rolePlay.position;
    if (position == null) return null;
    // A Builder, not the outer `build` context: the resolve-context scopes
    // are wrapped around the whole Scaffold in `build`, which sits *above*
    // `build`'s own context in the tree, so `resolveScopedField` needs a
    // context from inside it.
    return Builder(
      builder: (context) => RolePositionPanel(
        position: position,
        label:
            resolveScopedField(
              context,
              rolePlay.name,
              overrides: roleOverrides,
              roleplayFacets: _roleplayFacets(rolePlay),
            ) ??
            rolePlay.name,
        sourceLabel: _positionSourceLabel(station, rolePlay),
        asCard: true,
        fillHeight: fillHeight,
        sectionId: 'position',
      ),
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

/// Station context card (DESIGN-010's Spill viewer, harmonized into the
/// shared collapsible card family — mockup
/// `docs/design/mockups/spill-viewer-consistency.html`): a "Post" header
/// (flag icon + collapse chevron, like every other titled section card)
/// over a body that is itself a tappable row — the parent post's name and
/// a one-line description excerpt, navigating to the Post sheet. No
/// bespoke header "open" affordance: as with any [CollapsibleSectionCard],
/// the card must be expanded first, and the body row is what navigates.
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
    final station = this.station;
    final exercise = this.exercise;
    return CollapsibleSectionCard(
      sectionId: 'stationContext',
      icon: Icons.flag,
      title: l10n.stationLabel,
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RingDrillText(station.name, overrides: overrides),
                          if ((station.description ?? '').isNotEmpty)
                            RingDrillText(
                              station.description!,
                              overrides: overrides,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Effective identity card (DESIGN-010's Spill viewer, harmonized +
/// expandable — mockup `docs/design/mockups/spill-viewer-consistency.html`):
/// the marker's name/age/gender/signalement, each the linked [Person]'s own
/// value unless [rolePlay] overrides it non-empty (ADR-0047's
/// effective-identity rule — the same rule `resolvePersonFacet` applies for
/// `{{station.person.*}}` tokens and the brief itself), a muted "Spilles
/// av" footer naming the cast actor, and — once expanded — the rest of the
/// linked person: the full (untruncated) signalement, [Person.notes], and
/// the linked [Location] (name + coordinate). Notes/location are not
/// subject to the effective-identity rule — [RolePlay] has no fields of
/// its own for either, so they come straight from [person]/[location].
///
/// Not built on [CollapsibleSectionCard]: it keeps its own avatar + name
/// identity layout rather than a generic uppercase [CardSectionHeader], so
/// the [CollapseChevron] is wired directly into that layout instead of a
/// forced header.
class _EffectiveIdentityCard extends StatefulWidget {
  const _EffectiveIdentityCard({
    required this.rolePlay,
    required this.person,
    required this.actor,
    this.location,
    this.overrides = const {},
    this.roleplayFacets,
  });

  final RolePlay rolePlay;
  final Person? person;
  final Actor? actor;
  final Location? location;
  final Map<String, String> overrides;
  final Map<String, dynamic>? roleplayFacets;

  /// ADR-0047's effective-identity rule: the roleplay's own non-empty
  /// value wins over the linked person's, mirroring
  /// `station_scenario_tokens.dart`'s private `_effectiveField` (not
  /// reusable here — that helper is private to its own file).
  static String? _effective(String? roleplayValue, String? personValue) =>
      (roleplayValue != null && roleplayValue.isNotEmpty)
      ? roleplayValue
      : personValue;

  @override
  State<_EffectiveIdentityCard> createState() =>
      _EffectiveIdentityCardState();
}

class _EffectiveIdentityCardState extends State<_EffectiveIdentityCard> {
  static const _sectionId = 'identity';
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCollapsed());
  }

  Future<void> _loadCollapsed() async {
    final stored = await CollapsibleSectionStore.isCollapsed(_sectionId);
    if (!mounted || stored == _collapsed) return;
    setState(() => _collapsed = stored);
  }

  void _toggle() {
    final next = !_collapsed;
    setState(() => _collapsed = next);
    unawaited(CollapsibleSectionStore.setCollapsed(_sectionId, next));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final rolePlay = widget.rolePlay;
    final person = widget.person;
    final overrides = widget.overrides;
    final roleplayFacets = widget.roleplayFacets;
    final actor = widget.actor;
    final location = widget.location;
    final name =
        _EffectiveIdentityCard._effective(rolePlay.name, person?.name) ??
        rolePlay.name;
    final age = rolePlay.age ?? person?.age;
    final gender = _EffectiveIdentityCard._effective(
      rolePlay.gender,
      person?.gender,
    );
    final signalement = _EffectiveIdentityCard._effective(
      rolePlay.signalement,
      person?.signalement,
    );
    final genderLabel = genderLabelFor(gender, l10n);
    final metaParts = [
      if (age != null) l10n.rolePlayAgeYears(age),
      ?genderLabel,
    ];
    final notes = person?.notes ?? '';
    final locationLabel = location == null
        ? null
        : (location.label.isEmpty ? location.slug : location.label);
    final locationPosition = location?.position;
    final hasMore = notes.isNotEmpty || locationLabel != null;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RingDrillText(
                          name,
                          overrides: overrides,
                          roleplayFacets: roleplayFacets,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (metaParts.isNotEmpty)
                          Text(
                            metaParts.join(' · '),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if ((signalement ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          // Collapsed: a short/one-line excerpt (mockup's
                          // summary row). Expanded: the full signalement,
                          // no truncation — this is the "reveal the full
                          // signalement" half of the expand (Fix 2).
                          RingDrillText(
                            signalement!,
                            overrides: overrides,
                            roleplayFacets: roleplayFacets,
                            maxLines: _collapsed ? 1 : null,
                            overflow: _collapsed
                                ? TextOverflow.ellipsis
                                : null,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  CollapseChevron(collapsed: _collapsed, onTap: _toggle),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _collapsed || !hasMore
                ? const SizedBox.shrink()
                : Padding(
                    // Left-indents under the name column, not the avatar:
                    // avatar diameter (38) + the gap beside it (11) + the
                    // row's own padding (12) = 61, matching the mockup.
                    padding: const EdgeInsets.fromLTRB(61, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (notes.isNotEmpty) ...[
                          _IdentityMoreLabel(l10n.personsSectionNotesLabel),
                          RingDrillText(
                            notes,
                            overrides: overrides,
                            roleplayFacets: roleplayFacets,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (locationLabel != null) ...[
                          if (notes.isNotEmpty) const SizedBox(height: 8),
                          _IdentityMoreLabel(
                            l10n.personsSectionLocationLabel,
                          ),
                          // The location's own label/place are plain
                          // strings by convention (station_screen.dart's
                          // `_buildLocationRow` and friends render them the
                          // same way) — no token resolution, unlike notes.
                          Text(
                            [
                              locationLabel,
                              if (locationPosition != null)
                                formatUtm(locationPosition),
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
          if (actor != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.theater_comedy_outlined,
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
            ),
        ],
      ),
    );
  }
}

/// The small uppercase kicker label above a value in the identity card's
/// expanded "more" section (mockup's `.pmore .k`) — "NOTATER"/"LOKASJON".
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

/// The shared [PlayerStatusCard] for the Spill (marker) player (DESIGN-010
/// follow-up: player-status-card): "Nå"/"Neste" is the team [stationIndex]'s
/// post meets now/next, from `Exercise.teamIndex` — the same rotation math
/// [_ActiveScheduleCard] reads below — falling back to "Ikke aktiv nå" when
/// the post has no team assigned this round. Wrapped in its own
/// `StreamBuilder`, like [_ActiveScheduleCard], since [RolePlayScreen] has
/// no single event stream of its own.
class _MarkerStatusCard extends StatelessWidget {
  const _MarkerStatusCard({required this.exercise, required this.stationIndex});

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
          ),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
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
        );
      },
    );
  }
}
