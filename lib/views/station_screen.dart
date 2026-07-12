import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';
import 'package:ringdrill/views/location_form_screen.dart';
import 'package:ringdrill/views/person_form_screen.dart';
import 'package:ringdrill/views/plan_additions.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/shell/master_detail_leading.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/widgets/card_section_header.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/gender_segmented_control.dart';
import 'package:ringdrill/views/widgets/location_kind_style.dart';
import 'package:ringdrill/views/widgets/narrative_rollup_card.dart';
import 'package:ringdrill/services/brief/field_resolver.dart' show formatUtm;
import 'package:ringdrill/views/widgets/player_status_card.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';
import 'package:ringdrill/views/widgets/station_scenario_map.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';
import 'package:ringdrill/views/widgets/schedule_card.dart';
import 'package:ringdrill/views/widgets/schedule_table.dart';

class StationExerciseScreen extends StatefulWidget {
  final int stationIndex;
  final String uuid;

  const StationExerciseScreen({
    super.key,
    required this.stationIndex,
    required this.uuid,
  });

  @override
  State<StationExerciseScreen> createState() => _StationExerciseScreenState();
}

class _StationExerciseScreenState extends State<StationExerciseScreen> {
  late bool _isStarted;
  late Exercise _exercise;
  final _programService = ProgramService();
  final _exerciseService = ExerciseService();
  final _subscribers = <StreamSubscription>[];

  // DESIGN-010 stage 3b: the Postbeskrivelse card renders per the settings
  // role (director sees the gated directorNotesMd section too), not an
  // in-sheet toggle. Defaults to director (participants do not use the
  // app) until the async load resolves, mirroring BriefScreen's own
  // `_loadStoredRole` default/override pattern.
  AppUserRole _role = AppUserRole.director;

  Future<void> _loadStoredRole() async {
    final role = await loadStoredAppUserRole();
    if (mounted) setState(() => _role = role);
  }

  /// The effective plan-variable map (ADR-0046) at [exercise]'s scope,
  /// optionally narrowed to [station]'s — the active plan's declared
  /// values overlaid by [exercise]'s overrides, then [station]'s. Empty
  /// when there is no active plan (defense-in-depth; this screen only
  /// ever renders inside one).
  Map<String, String> _overridesFor(Exercise exercise, {Station? station}) {
    final program = _programService.activeProgram;
    if (program == null) return const {};
    return effectivePlanVariables(
      program,
      exercise: exercise,
      station: station,
    );
  }

  @override
  void initState() {
    _exercise = _programService.getExercise(widget.uuid)!;
    _isStarted = _exerciseService.isStartedOn(_exercise.uuid);
    _loadStoredRole();

    // Listen to ExerciseService state changes
    _subscribers.add(
      _exerciseService.events.listen((event) {
        if (event.exercise.uuid == widget.uuid) {
          // Update the state based on the current event phase
          if (mounted) {
            final changed = _isStarted != (event.isRunning || event.isPending);
            setState(() {
              _isStarted = event.isRunning || event.isPending;
            });
            if (changed || event.isDone) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  showCloseIcon: true,
                  dismissDirection: DismissDirection.endToStart,
                  content: Text(
                    '${substitutePlanVariables(_exercise.name, _overridesFor(_exercise))} ${event.isRunning
                        ? AppLocalizations.of(context)!.isRunning
                        : event.isPending
                        ? AppLocalizations.of(context)!.isPending
                        : AppLocalizations.of(context)!.isDone}',
                  ),
                ),
              );
            }
          }
        }
      }),
    );
    super.initState();
  }

  @override
  void dispose() {
    for (final it in _subscribers) {
      it.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    // Station identity in the AppBar so the sheet's header names the
    // thing the sheet is about, with the parent exercise on the
    // secondary line. We render `station.name` verbatim — the active
    // data convention already embeds a code prefix in the name
    // ("1a) Turgåer"), and the body's own heading uses the same
    // string, so any synthetic prefix here would double up.
    final station = _exercise.stations[widget.stationIndex];
    // DESIGN-010 stage 3: this station/exercise are already loaded here, so
    // wrap the sheet in the same resolve-context scopes an editor provides
    // (ADR-0048). Every widget built *below* this point (`SheetTitle`,
    // `RingDrillText`, the `Builder` in `_buildDescription`) then resolves
    // the full `{{station.*}}`/`{{exercise.*}}` cascade, not just
    // `{{var.*}}` — `context` captured here in `build` stays above the
    // scope (it is `State.context`, an ancestor of whatever `build`
    // returns), so it cannot see these two itself.
    return ExerciseScope(
      exercise: _exercise,
      variableOverrides: _exercise.variableOverrides,
      child: StationScope(
        locations: station.locations,
        persons: station.persons,
        name: station.name,
        description: station.description,
        variantSuffix: station.variantSuffix,
        positionUtm: formatUtm(station.position),
        child: Scaffold(
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
              primary: station.name,
              secondary: _exercise.name,
              primaryOverrides: _overridesFor(_exercise, station: station),
              secondaryOverrides: _overridesFor(_exercise),
            ),
            actions: [
              // Edit Exercise Button
              IconButton(
                icon: const Icon(Icons.edit),
                padding: const EdgeInsets.all(8.0),
                onPressed: _isStarted ? null : () => _editStation(context),
                tooltip: _isStarted
                    ? localizations.stopExerciseFirst(
                        substitutePlanVariables(
                          _exercise.name,
                          _overridesFor(_exercise),
                        ),
                      )
                    : localizations.editExercise,
              ),
            ],
            actionsPadding: EdgeInsets.only(right: 16.0),
          ),
          body: SafeArea(
            child: StreamBuilder(
              stream: _exerciseService.events,
              initialData: _initialData(),
              builder: (context, asyncSnapshot) {
                final event = asyncSnapshot.data!;
                final station = _exercise.stations[widget.stationIndex];
                // DESIGN-010 stage 3b: the rebuilt Post viewer is a single
                // linear stack of cards (Postbeskrivelse, map, Personer,
                // Lokasjoner, Tidsplan), matching the mockup — the old
                // side-by-side landscape split had no natural place for the
                // new persons/locations/schedule cards, and the sheet
                // already gets wide-screen room from the master-detail
                // shell (ADR-0030), not an in-body Row.
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(
                    kPlayerSurfaceHorizontalPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStationStatus(station, event),
                      const SizedBox(height: 8),
                      _buildStationInfo(station),
                      _buildPersonsCard(station),
                      _buildLocationsCard(station),
                      _buildTimingCard(station, event),
                    ],
                  ),
                );
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
                  exercise: _exercise,
                  height: 64,
                  applyBottomInset: true,
                  // We are already inside the station sheet; tapping the bar
                  // body should not try to re-open something.
                  onOpen: () {},
                  onPlay: () {
                    unawaited(HapticFeedback.mediumImpact());
                    _exerciseService.start(_exercise);
                  },
                  onPickExercise: (picked) => ContextSheet.of(
                    context,
                  ).replace(ExerciseSheetTarget(exerciseUuid: picked.uuid)),
                )
              : null,
        ),
      ),
    );
  }

  /// The shared [PlayerStatusCard] (DESIGN-010 follow-up: player-status-
  /// card). The station name lives in the sheet's AppBar
  /// (`SheetTitle.primary`), so this card only carries running-state info.
  /// Gated on [_isStarted] (scoped to this exercise, not the global
  /// `ExerciseService().isStarted`) so a different exercise running
  /// elsewhere never renders this station's card with foreign data.
  Widget _buildStationStatus(Station station, ExerciseEvent event) {
    if (!_isStarted) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return PlayerStatusCard(
      event: event,
      preStartSubline: l10n.statusPreStartSubline(
        _exercise.startTime.toString(),
        _exercise.numberOfRounds,
      ),
      leadingCell: _teamAtPostCell(
        l10n,
        roundIndex: event.currentRound,
        isNow: true,
      ),
      trailingCell: _nextTeamAtPostCell(l10n, event),
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
    final teamIndex = _exercise.teamIndex(widget.stationIndex, roundIndex);
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
      roundIndex < _exercise.schedule.length;
      roundIndex++
    ) {
      final teamIndex = _exercise.teamIndex(widget.stationIndex, roundIndex);
      if (teamIndex == -1) continue;
      return PlayerStatusCell(
        icon: Icons.arrow_forward,
        label: l10n.nextLabel,
        time: _exercise.schedule[roundIndex][0].toString(),
        value: '${l10n.team(1)} ${teamIndex + 1}',
      );
    }
    return finishFallbackCell(l10n, _exercise, icon: Icons.arrow_forward);
  }

  /// Postbeskrivelse (rollup) + map cards. Sized to its content (no inner
  /// scrollable) so the outer SingleChildScrollView in [build] owns the
  /// whole screen's scroll context.
  Widget _buildStationInfo(Station station) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPostDescriptionCard(station),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildMapCard(station),
        ),
      ],
    );
  }

  /// The rollup made concrete (DESIGN-010): the lead description then every
  /// active labeled section, resolved and markdown-rendered, closing the
  /// literal `{{station.position.utm}}` bug this stage started from.
  /// `directorNotesMd` is the mockup's "Notat til øvelsesleder" — gated on
  /// the settings role being director (a stricter gate than the brief's own
  /// `BriefAudience.includesDirectorNotes`, which also includes instructor:
  /// this is the author's own live planning note, not the printed brief).
  /// Tapping a section opens the station editor scrolled straight to it.
  Widget _buildPostDescriptionCard(Station station) {
    final l10n = AppLocalizations.of(context)!;
    final overrides = _overridesFor(_exercise, station: station);
    return NarrativeRollupCard(
      icon: Icons.description,
      title: l10n.postDescriptionCardTitle,
      leadText: station.description,
      leadOverrides: overrides,
      leadId: 'station',
      sections: [
        NarrativeSection(
          id: 'equipment',
          label: l10n.briefSectionStationEquipment,
          text: station.equipmentMd,
          overrides: overrides,
        ),
        NarrativeSection(
          id: 'situation',
          label: l10n.briefSectionStationSituation,
          text: station.situationMd,
          overrides: overrides,
        ),
        NarrativeSection(
          id: 'mission',
          label: l10n.briefSectionStationMission,
          text: station.missionMd,
          overrides: overrides,
        ),
        NarrativeSection(
          id: 'logistics',
          label: l10n.briefSectionStationLogistics,
          text: station.logisticsMd,
          overrides: overrides,
        ),
        NarrativeSection(
          id: 'criticalQuestions',
          label: l10n.briefSectionStationCriticalQuestions,
          text: station.criticalQuestionsMd,
          overrides: overrides,
        ),
        NarrativeSection(
          id: 'leaderAnswers',
          label: l10n.briefSectionStationLeaderAnswers,
          text: station.leaderAnswersMd,
          overrides: overrides,
        ),
        if (_role == AppUserRole.director)
          NarrativeSection(
            id: 'directorNotes',
            label: l10n.briefSectionStationDirectorNotes,
            text: station.directorNotesMd,
            overrides: overrides,
            gated: true,
          ),
      ],
      onTapSection: (id) => _editStation(context, initialSectionId: id),
      showHint: true,
    );
  }

  /// The scenario map card: the station's own position plus its DESIGN-009
  /// `Location`s, styled by `LocationKind` (ADR-0020), with the legend slot
  /// — richer than `StationPositionPanel`'s administrative-only default,
  /// which every other station surface keeps.
  Widget _buildMapCard(Station station) {
    return StationPositionPanel(
      exercise: _exercise,
      station: station,
      asCard: true,
      miniMapKey: ValueKey<String>(
        'station-screen-map-${_exercise.uuid}-${station.index}',
      ),
      markers: stationScenarioMarkers(context, station),
      legend: StationScenarioLegend(station: station),
    );
  }

  /// Tidsplan card (DESIGN-010): the per-team drill/eval/roll clock times
  /// for this station across every round, from the same `Exercise.schedule`
  /// + `teamIndex`/`stationIndex` data the live rotation tables read — via
  /// the shared `ScheduleTable`, so the current round (while `event` is
  /// running) gets the same house progress-fill highlight the coordinator
  /// and team tables show, not a bespoke static rendering.
  Widget _buildTimingCard(Station station, ExerciseEvent event) {
    final l10n = AppLocalizations.of(context)!;
    final rows = List.generate(_exercise.schedule.length, (roundIndex) {
      final teamIndex = _exercise.teamIndex(widget.stationIndex, roundIndex);
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
                  exerciseUuid: _exercise.uuid,
                  teamIndex: teamIndex,
                ),
              ),
      );
    });
    return ScheduleCard(
      title: l10n.stationTimingCardTitle,
      headerLabel: l10n.team(1),
      rows: rows,
      event: event,
      exercise: _exercise,
    );
  }

  ExerciseEvent _initialData() {
    final last = _exerciseService.last;
    if (last?.exercise.uuid == widget.uuid) return last!;
    return ExerciseEvent.pending(_exercise);
  }

  /// Personer card (DESIGN-009/010): one row per station-owned [Person] —
  /// the row *is* the person, with the marker portraying them (if any)
  /// shown inline via `personsSectionEnactedByAction` (the same label
  /// `PersonsSection`'s own editor row uses) rather than a separate marker
  /// list. Omitted entirely when the station has none.
  Widget _buildPersonsCard(Station station) {
    if (station.persons.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardSectionHeader(
            icon: Icons.people,
            title: l10n.personsSectionTitle,
            trailing: _HeaderAddAction(
              label: l10n.personsSectionAddAction,
              onTap: () => _addPerson(station),
            ),
          ),
          for (final person in station.persons)
            _buildPersonRow(station, person),
        ],
      ),
    );
  }

  Widget _buildPersonRow(Station station, Person person) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final rolePlay = _programService
        .loadRolePlays()
        .where(
          (r) =>
              r.exerciseUuid == _exercise.uuid &&
              r.stationIndex == widget.stationIndex &&
              r.personRef == person.slug,
        )
        .firstOrNull;
    final displayName = person.name.isEmpty ? person.slug : person.name;
    final genderLabel = genderLabelFor(person.gender, l10n);
    final metaParts = [
      displayName,
      if (person.age != null) '${person.age}',
      ?genderLabel,
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(metaParts.join(' · '), overflow: TextOverflow.ellipsis),
                if ((person.signalement ?? '').isNotEmpty)
                  Text(
                    person.signalement!,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: rolePlay == null
                      ? () => _addRolePlayForPerson(station, person)
                      : () => _openRolePlay(rolePlay),
                  child: rolePlay == null
                      ? _AddMarkerPill(
                          label: l10n.personsSectionAddMarkerAction,
                        )
                      : _EnactedByPill(
                          label: l10n.personsSectionEnactedByAction(
                            rolePlay.name,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Lokasjoner card (DESIGN-009/010): one row per station-owned [Location],
  /// styled by [LocationKind] (ADR-0020) — the same kind icon/color the map
  /// card's markers and legend use. Omitted entirely when the station has
  /// none.
  Widget _buildLocationsCard(Station station) {
    if (station.locations.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardSectionHeader(
            icon: Icons.map,
            title: l10n.locationsSectionTitle,
            trailing: _HeaderAddAction(
              label: l10n.locationsSectionAddAction,
              onTap: () => _addLocation(station),
            ),
          ),
          for (final location in station.locations) _buildLocationRow(location),
        ],
      ),
    );
  }

  Widget _buildLocationRow(Location location) {
    final theme = Theme.of(context);
    final displayName = location.label.isEmpty ? location.slug : location.label;
    final subtitle = location.place.isNotEmpty
        ? location.place
        : (location.position == null ? '' : formatUtm(location.position));
    return Container(
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
    );
  }

  Future<void> _addPerson(Station station) async {
    final localizations = AppLocalizations.of(context)!;
    final result = await openFormSurface<PersonFormResult>(
      context,
      builder: (_) => PersonFormScreen(
        existingSlugs: station.persons.map((p) => p.slug).toSet(),
        locations: station.locations,
      ),
    );
    if (result == null) return;
    final updated = station.copyWith(
      persons: [...station.persons, result.person],
      locations: result.newLocation == null
          ? station.locations
          : [...station.locations, result.newLocation!],
    );
    await _saveStation(localizations, updated);
  }

  Future<void> _addLocation(Station station) async {
    final localizations = AppLocalizations.of(context)!;
    final saved = await openFormSurface<Location>(
      context,
      builder: (_) => LocationFormScreen(
        existingSlugs: station.locations.map((l) => l.slug).toSet(),
      ),
    );
    if (saved == null) return;
    final updated = station.copyWith(locations: [...station.locations, saved]);
    await _saveStation(localizations, updated);
  }

  /// Opens the RolePlay editor pre-set with [person]'s own identity and
  /// `personRef` (mirroring `PersonsSection.onAddRolePlay`'s editor
  /// counterpart) — a new marker for a person nobody plays yet.
  Future<void> _addRolePlayForPerson(Station station, Person person) async {
    final localizations = AppLocalizations.of(context)!;
    final existing = _programService
        .loadRolePlays()
        .where((r) => r.exerciseUuid == _exercise.uuid)
        .length;
    final draft = RolePlay(
      uuid: nanoid(10),
      index: existing,
      exerciseUuid: _exercise.uuid,
      stationIndex: station.index,
      name: person.name,
      age: person.age,
      gender: person.gender,
      signalement: person.signalement,
      personRef: person.slug,
    );
    final result = await openFormSurface<RolePlayFormResult>(
      context,
      builder: (_) => RolePlayFormScreen(
        rolePlay: draft,
        exercise: _exercise,
        variables: _programService.activeProgram?.variables ?? const [],
      ),
    );
    if (result != null) {
      await applyRolePlayAdditions(
        _programService,
        localizations,
        result.rolePlay,
        result.additions,
      );
      await _programService.saveRolePlay(localizations, result.rolePlay);
      if (mounted) setState(() {});
    }
  }

  void _openRolePlay(RolePlay rolePlay) {
    ContextSheet.of(
      context,
    ).replace(RoleSheetTarget(rolePlayUuid: rolePlay.uuid));
  }

  Future<void> _saveStation(
    AppLocalizations localizations,
    Station updated,
  ) async {
    final stations = _exercise.stations.toList()
      ..[widget.stationIndex] = updated;
    final newExercise = _exercise.copyWith(stations: stations);
    await _programService.saveExercise(localizations, newExercise);
    if (!mounted) return;
    setState(() => _exercise = newExercise);
  }

  /// Function to handle editing the exercise. [initialSectionId] jumps the
  /// editor straight to that section (DESIGN-010's rollup card tap-to-edit)
  /// instead of always opening on the base section.
  void _editStation(BuildContext context, {String? initialSectionId}) async {
    // Captured before the await: in compact layout openFormSurface dismisses
    // the hosting context sheet around the form push, which disposes this
    // State — the context is gone by the time the form pops. The save must
    // still run (ProgramService needs no context); only UI work below is
    // gated on mounted.
    final localizations = AppLocalizations.of(context)!;
    final stations = _exercise.stations.toList();

    // DESIGN-009 prompt 5: the delete-guard and save-block need to know
    // whether a roleplay linked to this station references a Location/
    // Person before letting the author remove or leave one dangling.
    final roleplays = _programService
        .loadRolePlays()
        .where(
          (r) =>
              r.exerciseUuid == _exercise.uuid &&
              r.stationIndex == widget.stationIndex,
        )
        .toList();

    // Navigate to the edit exercise screen
    final result = await openFormSurface<StationFormResult>(
      context,
      builder: (context) => StationFormScreen(
        station: stations[widget.stationIndex],
        markers: _programService.getLocations().toMarkerSpecs(),
        variables: _programService.activeProgram?.variables ?? const [],
        parentExercise: _exercise,
        roleplays: roleplays,
        initialSectionId: initialSectionId,
      ),
    );
    // The previous guard was `newStation != _exercise`, but those are
    // two unrelated types (Station vs Exercise) so the comparison was
    // always true. Backing out of the form (result == null) then
    // ran `stations[i] = null` on a non-nullable list and crashed.
    if (result == null) return;
    await applyVariableAdditionsToActiveProgram(
      _programService,
      result.additions,
    );
    stations[widget.stationIndex] = result.station;
    final newExercise = _exercise.copyWith(stations: stations);
    await _programService.saveExercise(localizations, newExercise);
    if (!mounted) return;
    setState(() {
      _exercise = newExercise;
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

/// A person row's "Spilles av {navn}" pill (mockup's `.mkline`) — mirrors
/// `PersonsSection`'s own `_EnactedByRow` visual (that one is private to
/// `persons_section.dart`).
class _EnactedByPill extends StatelessWidget {
  const _EnactedByPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.theater_comedy_outlined,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A person row's "+ Legg til markør" affordance (mockup's `.addinline`) —
/// mirrors `PersonsSection`'s own `_AddMarkerRow` visual.
class _AddMarkerPill extends StatelessWidget {
  const _AddMarkerPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.add, size: 15, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
