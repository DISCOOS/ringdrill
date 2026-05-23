import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/phase_headers.dart';
import 'package:ringdrill/views/phase_tile.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/widgets/station_mini_map.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(_exercise.name),
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
                        rotations,
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: stationInfo),
                            const SizedBox(width: 8),
                            Expanded(child: rotations),
                          ],
                        ),
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
    return _exerciseService.isStarted
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${station.name} '
                '(${event.getState(localizations)})',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                event.isPending
                    ? DateTimeX.fromMinutes(
                        event.remainingTime,
                      ).formal(localizations)
                    : localizations.minute(event.remainingTime),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )
        : Text(
            station.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          );
  }

  /// Description + position + mini-map. Sized to its content (no
  /// inner scrollable) so the outer SingleChildScrollView in [build]
  /// owns the whole screen's scroll context.
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.place,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: station.position == null
                          ? Text(
                              localizations.noLocation,
                              style: Theme.of(context).textTheme.bodyLarge,
                            )
                          : PositionWidget(
                              wrapped: false,
                              format: PositionFormat.utm,
                              position: station.position,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                    ),
                  ],
                ),
                if (station.position != null) ...[
                  const SizedBox(height: 12),
                  // Uses the shared StationMiniMap so tap opens
                  // the same bottom-sheet view as the Stations
                  // tab. Single-station focus is intentional —
                  // for plan-wide context the user switches to
                  // the Map tab.
                  StationMiniMap(
                    exercise: _exercise,
                    station: station,
                    height: 200,
                  ),
                ],
              ],
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
                      context.push(
                        '$routeProgram/${_exercise.uuid}/team/$teamIndex',
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

  /// Function to handle editing the exercise
  void _editStation(BuildContext context) async {
    final stations = _exercise.stations.toList();

    // Navigate to the edit exercise screen
    final newStation = await Navigator.push<Station>(
      context,
      MaterialPageRoute(
        builder: (context) => StationFormScreen(
          station: stations[widget.stationIndex],
          markers: _programService.getLocations(),
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
