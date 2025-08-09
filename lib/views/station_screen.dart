import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/phase_headers.dart';
import 'package:ringdrill/views/phase_tile.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/team_exercise_screen.dart';

import 'map_screen.dart';

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
  final _mapKey = GlobalKey<_StationExerciseScreenState>();

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
      ),
      body: StreamBuilder(
        stream: _exerciseService.events,
        initialData: _initialData(),
        builder: (context, asyncSnapshot) {
          return OrientationBuilder(
            builder: (context, orientation) {
              final isPortrait = orientation == Orientation.portrait;
              final mode = (isPortrait ? Column.new : Row.new);
              final event = asyncSnapshot.data!;
              final station = _exercise.stations[widget.stationIndex];
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Team Info
                    _buildStationStatus(station, event),
                    const SizedBox(height: 8),
                    Expanded(
                      child: mode(
                        children: [
                          Expanded(
                            flex: isPortrait ? -1 : 1,
                            child: _buildStationInfo(
                              station,
                              event,
                              isPortrait,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: _buildTeamRotations(event)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
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

  Widget _buildStationInfo(
    Station station,
    ExerciseEvent event,
    bool isPortrait,
  ) {
    final localizations = AppLocalizations.of(context)!;
    final station = _exercise.stations[widget.stationIndex];
    return LayoutBuilder(
      builder: (context, BoxConstraints constraints) {
        final size = station.position == null ? 150.0 : 350.0;
        return SizedBox(
          height: isPortrait ? size : null,
          width: isPortrait ? null : size,
          child: ListView(
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
                          if (station.position == null)
                            Text(
                              localizations.noLocation,
                              style: Theme.of(context).textTheme.bodyLarge,
                            )
                          else
                            PositionWidget(
                              wrapped: false,
                              format: PositionFormat.utm,
                              position: station.position,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                        ],
                      ),
                      if (station.position != null) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 200,
                          width: constraints.maxWidth,
                          child: MapView(
                            key: _mapKey,
                            withCross: true,
                            initialZoom: 16,
                            initialCenter:
                                station.position ?? MapConfig.initialCenter,
                            layers: MapConfig.layers,
                            onTap: (_, _) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) {
                                    int i = 0;
                                    return MapScreen<int>(
                                      title: station.name,
                                      withCross: true,
                                      withSearch: true,
                                      initialZoom: 14,
                                      initialCenter:
                                          station.position ??
                                          MapConfig.initialCenter,
                                      interactionFlags: MapConfig.interactive,
                                      markers: _exercise.stations
                                          .where((e) => e.position != null)
                                          .map(
                                            (e) => (i++, e.name, e.position!),
                                          )
                                          .toList(),
                                      onMarkerTap: (on) {
                                        showModalBottomSheet(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return _buildBottomSheet(
                                              event,
                                              _exercise.stations[on.$1],
                                              isPortrait,
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

  Container _buildBottomSheet(
    ExerciseEvent event,
    Station station,
    bool isPortrait,
  ) {
    return Container(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStationStatus(station, event),
          Divider(),
          _buildDescription(station, AppLocalizations.of(context)!),
          Expanded(child: _buildTeamRotations(event)),
        ],
      ),
    );
  }

  Widget _buildTeamRotations(ExerciseEvent event) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhaseHeaders(
          expand: true,
          titleWidth: 78,
          title: AppLocalizations.of(context)!.schedule,
          mainAxisAlignment: MainAxisAlignment.start,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: _exercise.schedule.length,
            itemBuilder: (context, index) {
              final teamIndex = _exercise.teamIndex(widget.stationIndex, index);
              final none = teamIndex == -1;
              final title =
                  '${AppLocalizations.of(context)!.team(1)} '
                  '${none ? '×' : teamIndex + 1}';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: none
                      ? null
                      : () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TeamExerciseScreen(
                                teamIndex: teamIndex,
                                exercise: _exercise,
                              ),
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
            },
          ),
        ),
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
    final newStation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StationFormScreen(
          station: stations[widget.stationIndex],
          markers: _programService.getLocations(),
        ),
      ),
    );
    if (context.mounted && newStation != _exercise) {
      stations[widget.stationIndex] = newStation;
      final newExercise = _exercise.copyWith(stations: stations);
      await _programService.saveExercise(
        AppLocalizations.of(context)!,
        newExercise,
      );
      setState(() {
        _exercise = newExercise;
      });
    }
  }
}
