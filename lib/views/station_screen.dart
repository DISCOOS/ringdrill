import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/phase_headers.dart';
import 'package:ringdrill/views/phase_tile.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/widgets/cast_picker_sheet.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';
import 'package:ringdrill/views/widgets/station_position_panel.dart';

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

  @override
  void initState() {
    _exercise = _programService.getExercise(widget.uuid)!;
    _isStarted = _exerciseService.isStartedOn(_exercise.uuid);

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
                    '${_exercise.name} ${event.isRunning
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
          tooltip: localizations.briefClose,
        ),
        toolbarHeight: 72,
        title: SheetTitle(primary: station.name, secondary: _exercise.name),
        actions: [
          // Edit Exercise Button
          IconButton(
            icon: const Icon(Icons.edit),
            padding: const EdgeInsets.all(8.0),
            onPressed: _isStarted ? null : () => _editStation(context),
            tooltip: _isStarted
                ? localizations.stopExerciseFirst(_exercise.name)
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
            return OrientationBuilder(
              builder: (context, orientation) {
                final isPortrait = orientation == Orientation.portrait;
                final event = asyncSnapshot.data!;
                final station = _exercise.stations[widget.stationIndex];
                final stationInfo = _buildStationInfo(station);
                final rolesSection = _buildRolesSection(station);
                final rotations = _buildTeamRotations(event);
                // One outer SingleChildScrollView so the screen has a
                // single scroll context. Sub-sections (station info,
                // team rotations) are non-scrolling Columns sized to
                // their content and laid out side-by-side in landscape,
                // stacked in portrait.
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStationStatus(station, event),
                      const SizedBox(height: 8),
                      if (isPortrait) ...[
                        stationInfo,
                        const SizedBox(height: 8),
                        rolesSection,
                        const SizedBox(height: 8),
                        rotations,
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: stationInfo),
                            const SizedBox(width: 8),
                            Expanded(child: rotations),
                          ],
                        ),
                        const SizedBox(height: 8),
                        rolesSection,
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildStationStatus(Station station, ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    // The station name lives in the sheet's AppBar (`SheetTitle.primary`),
    // so this status row only carries running-state info. When the
    // exercise has not started yet there is nothing to report and the
    // row collapses to `SizedBox.shrink`.
    if (!_exerciseService.isStarted) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          event.getState(localizations),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          event.isPending
              ? DateTimeX.fromMinutes(event.remainingTime).formal(localizations)
              : localizations.minute(event.remainingTime),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  /// Description + position + mini-map. Sized to its content (no
  /// inner scrollable) so the outer SingleChildScrollView in [build]
  /// owns the whole screen's scroll context.
  ///
  /// Uses the shared [StationPositionPanel] so the "Posisjon ... pin
  /// coords" label row and the tap-to-open-bottom-sheet mini-map stay
  /// consistent with the other station surfaces (coordinator screen
  /// and the Stations tab).
  Widget _buildStationInfo(Station station) {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDescription(station, localizations),
        Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StationPositionPanel(
              exercise: _exercise,
              station: station,
              miniMapKey: ValueKey<String>(
                'station-screen-map-${_exercise.uuid}-${station.index}',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Card _buildDescription(Station station, AppLocalizations localizations) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.description,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    station.description == null
                        ? localizations.noDescription
                        : station.description!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Per-round phase tiles. Sized to its content (no inner
  /// scrollable) so the outer SingleChildScrollView in [build] owns
  /// the whole screen's scroll context.
  Widget _buildTeamRotations(ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhaseHeaders(
          expand: true,
          titleWidth: 78,
          title: localizations.schedule,
          mainAxisAlignment: MainAxisAlignment.start,
        ),
        const SizedBox(height: 8),
        ...List.generate(_exercise.schedule.length, (index) {
          final teamIndex = _exercise.teamIndex(widget.stationIndex, index);
          final none = teamIndex == -1;
          final title =
              '${localizations.team(1)} '
              '${none ? '×' : teamIndex + 1}';
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: none
                  ? null
                  : () {
                      ContextSheet.of(context).replace(
                        TeamSheetTarget(
                          exerciseUuid: _exercise.uuid,
                          teamIndex: teamIndex,
                        ),
                      );
                    },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: PhaseTile(
                  event: event,
                  title: title,
                  roundIndex: index,
                  exercise: _exercise,
                  mainAxisAlignment: MainAxisAlignment.start,
                  decoration: none ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  ExerciseEvent _initialData() {
    final last = _exerciseService.last;
    if (last?.exercise.uuid == widget.uuid) return last!;
    return ExerciseEvent.pending(_exercise);
  }

  Widget _buildRolesSection(Station station) {
    final localizations = AppLocalizations.of(context)!;
    final roles = _programService
        .loadRolePlays()
        .where(
          (r) =>
              r.exerciseUuid == _exercise.uuid &&
              r.stationIndex == widget.stationIndex,
        )
        .toList();
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  localizations.stationRolesSection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(localizations.addRolePlay),
                  onPressed: () => _addRolePlay(station),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (roles.isEmpty)
              Text(
                localizations.noRolesAtThisStation,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...roles.map((r) => _buildRoleRow(r)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleRow(RolePlay r) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final actor = r.actorUuid != null
        ? _programService.getActor(r.actorUuid!)
        : null;
    final titleText = r.age != null ? '${r.name}, ${r.age}' : r.name;
    final subtitleText = actor != null
        ? localizations.castedByLine(actor.realName)
        : localizations.noCastLine;
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: actor != null
          ? colorScheme.onSurfaceVariant
          : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      fontStyle: actor != null ? FontStyle.normal : FontStyle.italic,
    );

    return Dismissible(
      key: ValueKey('role-row-${r.uuid}'),
      direction: DismissDirection.startToEnd,
      background: Container(
        color: colorScheme.secondaryContainer,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(Icons.edit, color: colorScheme.onSecondaryContainer),
            const SizedBox(width: 8),
            Text(
              localizations.stationRolesSection,
              style: TextStyle(color: colorScheme.onSecondaryContainer),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        final localizations = AppLocalizations.of(context)!;
        final updated = await Navigator.push<RolePlay>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                RolePlayFormScreen(rolePlay: r, exercise: _exercise),
          ),
        );
        if (updated != null) {
          await _programService.saveRolePlay(localizations, updated);
          if (mounted) setState(() {});
        }
        return false;
      },
      child: InkWell(
        onTap: () => ContextSheet.of(
          context,
        ).replace(RoleSheetTarget(rolePlayUuid: r.uuid)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.theater_comedy,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitleText,
                      style: subtitleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  actor != null ? Icons.person : Icons.person_add_outlined,
                  color: actor != null
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                tooltip: actor != null
                    ? localizations.editCast
                    : localizations.addCast,
                onPressed: () => _openCastPicker(r),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addRolePlay(Station station) async {
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
      name: '',
    );
    final saved = await Navigator.push<RolePlay>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RolePlayFormScreen(rolePlay: draft, exercise: _exercise),
      ),
    );
    if (saved != null) {
      await _programService.saveRolePlay(localizations, saved);
      if (mounted) setState(() {});
    }
  }

  Future<void> _openCastPicker(RolePlay r) async {
    final localizations = AppLocalizations.of(context)!;
    final actorUuid = await showRingdrillActionSheet<String>(
      context: context,
      builder: (context) => CastPickerSheet(rolePlay: r),
    );
    if (actorUuid != null && actorUuid != r.actorUuid) {
      await _programService.saveRolePlay(
        localizations,
        r.copyWith(actorUuid: actorUuid),
      );
      if (mounted) setState(() {});
    }
  }

  /// Function to handle editing the exercise
  void _editStation(BuildContext context) async {
    final stations = _exercise.stations.toList();

    // Navigate to the edit exercise screen
    final newStation = await Navigator.push<Station>(
      context,
      MaterialPageRoute(
        builder: (context) => StationFormScreen(
          station: stations[widget.stationIndex],
          markers: _programService.getLocations().toMarkerSpecs(),
        ),
      ),
    );
    // The previous guard was `newStation != _exercise`, but those are
    // two unrelated types (Station vs Exercise) so the comparison was
    // always true. Backing out of the form (newStation == null) then
    // ran `stations[i] = null` on a non-nullable list and crashed.
    if (!context.mounted || newStation == null) return;
    stations[widget.stationIndex] = newStation;
    final newExercise = _exercise.copyWith(stations: stations);
    await _programService.saveExercise(
      AppLocalizations.of(context)!,
      newExercise,
    );
    if (!mounted) return;
    setState(() {
      _exercise = newExercise;
    });
  }
}
