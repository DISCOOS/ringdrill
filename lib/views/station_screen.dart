import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/exercise_repository.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/station_form_screen.dart';
import 'package:ringdrill/views/team_state_widget.dart';
import 'package:ringdrill/views/utm_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StationScreen extends StatefulWidget {
  final int stationIndex;
  final Exercise exercise;

  const StationScreen({
    super.key,
    required this.stationIndex,
    required this.exercise,
  });

  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  late bool _isStarted;
  late Exercise _current;
  final _exerciseService = ExerciseService();
  final _mapKey = GlobalKey<_StationScreenState>();
  late StreamSubscription<ExerciseEvent> _exerciseListener;

  @override
  void initState() {
    _current = widget.exercise;
    _isStarted =
        _exerciseService.exercise == _current && _exerciseService.isStarted;

    // Listen to ExerciseService state changes
    _exerciseListener = _exerciseService.events.listen((event) {
      if (event.exercise == _current) {
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
                content: Text(
                  '${_current.name} ${event.isRunning
                      ? 'is running'
                      : event.isPending
                      ? 'is pending'
                      : 'is done'}!',
                ),
              ),
            );
          }
        }
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _exerciseListener.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_current.name),
        actions: [
          // Edit Exercise Button
          IconButton(
            icon: const Icon(Icons.edit),
            padding: const EdgeInsets.all(8.0),
            onPressed: _isStarted ? null : () => _editStation(context),
            tooltip: _isStarted ? 'Stop exercise first' : 'Edit Exercise',
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
              final station = _current.stations[widget.stationIndex];
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Team Info
                    _buildStationStatus(event),
                    const SizedBox(height: 8),
                    Expanded(
                      child: mode(
                        children: [
                          Expanded(
                            flex: isPortrait ? -1 : 1,
                            child: _buildStationInfo(station, isPortrait),
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

  Widget _buildTeamRotations(ExerciseEvent event) {
    return ListView.builder(
      itemCount: _current.schedule.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: TeamStateWidget(
              event: event,
              roundIndex: index,
              teamIndex: _current.teamIndex(widget.stationIndex, index),
              exercise: _current,
              mainAxisAlignment: MainAxisAlignment.start,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStationInfo(Station station, bool isPortrait) {
    return LayoutBuilder(
      builder: (context, BoxConstraints constraints) {
        return SizedBox(
          height: isPortrait ? 350 : null,
          child: ListView(
            children: [
              Card(
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
                                  ? 'No description'
                                  : station.description!,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
                              'No location',
                              style: Theme.of(context).textTheme.bodyLarge,
                            )
                          else
                            UtmWidget(
                              wrapped: false,
                              position: station.position,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        width: constraints.maxWidth,
                        child: MapView(
                          key: _mapKey,
                          initialZoom: 20,
                          withCross: true,
                          layer: MapConfig.topoLayer,
                          initialCenter:
                              station.position ?? MapConfig.initialCenter,
                        ),
                      ),
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

  Widget _buildStationStatus(ExerciseEvent event) {
    return _exerciseService.isStarted
        ? Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_current.stations[widget.stationIndex].name} (${event.state})',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              event.isPending
                  ? DateTimeX.fromMinutes(event.remainingTime).formal()
                  : '${event.remainingTime} min',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        )
        : Text(
          _current.stations[widget.stationIndex].name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        );
  }

  ExerciseEvent _initialData() {
    final last = _exerciseService.last;
    if (last?.exercise == widget.exercise) return last!;
    return ExerciseEvent.pending(widget.exercise);
  }

  /// Function to handle editing the exercise
  void _editStation(BuildContext context) async {
    final stations = _current.stations.toList();

    // Navigate to the edit exercise screen
    final newStation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                StationFormScreen(station: stations[widget.stationIndex]),
      ),
    );
    if (newStation != _current) {
      stations[widget.stationIndex] = newStation;
      final prefs = await SharedPreferences.getInstance();
      final repo = ExerciseRepository(prefs);
      final newExercise = _current.copyWith(stations: stations);
      await repo.addExercise(newExercise, true);
      setState(() {
        _current = newExercise;
      });
    }
  }
}
