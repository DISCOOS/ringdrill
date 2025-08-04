import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/exercise_repository.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/views/phase_headers.dart';
import 'package:ringdrill/views/phase_tile.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'exercise_form_screen.dart';
import 'team_screen.dart';

class CoordinatorScreen extends StatefulWidget {
  final Exercise exercise;

  const CoordinatorScreen({super.key, required this.exercise});

  @override
  State<CoordinatorScreen> createState() => _CoordinatorScreenState();
}

class _CoordinatorScreenState extends State<CoordinatorScreen> {
  late bool _isStarted;
  late Exercise _current;
  bool _promptShowNotification = false;
  final _exerciseService = ExerciseService();
  late StreamSubscription<ExerciseEvent> _exerciseListener;
  late StreamSubscription<NotificationEvent> _notificationListener;

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
    });

    // Listen to Notification Events
    _notificationListener = NotificationService().events
        .where((e) => e.action == NotificationAction.promptReshow)
        .where((e) => e.exercise == _current)
        .listen((event) {
          if (mounted) {
            setState(() {
              _promptShowNotification = true;
            });
          }
        });

    super.initState();
  }

  @override
  void didChangeDependencies() {
    _current = widget.exercise;
    _isStarted =
        _exerciseService.exercise == _current && _exerciseService.isStarted;
    super.didChangeDependencies();
  }

  /// Function to handle editing the exercise
  void _editExercise(BuildContext context) async {
    // Navigate to the edit exercise screen
    final newExercise = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseFormScreen(exercise: _current),
      ),
    );
    if (newExercise != null) {
      final prefs = await SharedPreferences.getInstance();
      final repo = ExerciseRepository(prefs);
      // Replace existing exercise with new
      await repo.addExercise(newExercise, true);
      setState(() {
        _current = newExercise;
      });
    }
  }

  ExerciseEvent _initialData() {
    final last = ExerciseService().last;
    if (last?.exercise == _current) return last!;
    return ExerciseEvent.pending(widget.exercise);
  }

  bool get isStartable {
    return _exerciseService.exercise == null ||
        _exerciseService.exercise == _current;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return StreamBuilder(
      stream: ExerciseService().events,
      initialData: _initialData(),
      builder: (context, asyncSnapshot) {
        final event = asyncSnapshot.data!;
        return Scaffold(
          appBar: AppBar(
            actionsPadding: const EdgeInsets.all(8.0),
            title: Text(
              _current.name,
            ), // Dynamic title shows the exercise's name
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_on),
                padding: const EdgeInsets.all(8.0),
                onPressed:
                    _promptShowNotification
                        ? () {
                          unawaited(NotificationService().initFromPrefs());
                          setState(() {
                            _promptShowNotification = false;
                          });
                        }
                        : null,
                tooltip: localizations.showNotification,
              ),

              // Edit Exercise Button
              IconButton(
                icon: const Icon(Icons.edit),
                padding: const EdgeInsets.all(8.0),
                onPressed: _isStarted ? null : () => _editExercise(context),
                tooltip:
                    _isStarted
                        ? AppLocalizations.of(
                          context,
                        )!.stopExerciseFirst(_exerciseService.exercise!.name)
                        : localizations.editExercise,
              ),
            ],
          ),
          body:
              _current.schedule.isEmpty
                  ? Center(child: Text(localizations.noRoundsScheduled))
                  : _buildBody(event),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              if (!isStartable) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      localizations.stopExerciseFirst(
                        _exerciseService.exercise!.name,
                      ),
                    ),
                  ),
                );
                return;
              }
              if (_isStarted) {
                // Stop the exercise
                _exerciseService.stop();
              } else {
                // Start the exercise
                _exerciseService.start(_current);
              }
            },
            child: Icon(_isStarted ? Icons.stop : Icons.play_arrow),
          ),
        );
      },
    );
  }

  Widget _buildBody(ExerciseEvent event) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: OrientationBuilder(
        builder: (context, orientation) {
          final isPortrait = orientation == Orientation.portrait;
          final mode = (isPortrait ? Column.new : Row.new);
          return mode(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: _buildRoundTable(event, isPortrait),
              ),
              Expanded(
                flex: isPortrait ? 1 : 5,
                child: _buildStationList(event),
              ),
              Expanded(flex: isPortrait ? 1 : 5, child: _buildTeamList(event)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRoundTable(ExerciseEvent event, bool isPortrait) {
    final localizations = AppLocalizations.of(context)!;
    return Container(
      padding: EdgeInsets.all(8.0),
      child: Column(
        children: [
          PhaseHeaders(
            titleWidth: 90,
            title: localizations.schedule,
            mainAxisAlignment: MainAxisAlignment.center,
          ),
          SizedBox(height: 8),
          ...List<Widget>.generate(_current.schedule.length, (roundIndex) {
            // Determine whether this round is completed or current
            return PhaseTile(
              title:
                  "${AppLocalizations.of(context)!.round(1)} "
                  "${roundIndex + 1}",
              event: event,
              exercise: _current,
              roundIndex: roundIndex,
              isPortrait: isPortrait,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStationList(ExerciseEvent event) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 24,
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(AppLocalizations.of(context)!.stationRotations),
              ),
            ),
          ),
          SizedBox(height: 4.0),
          Expanded(
            child: ListView.builder(
              itemCount: _current.stations.length,
              itemBuilder: (context, stationIndex) {
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 2,
                  ),
                  child: ListTile(
                    title: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '${AppLocalizations.of(context)!.station(1)} ${stationIndex + 1}',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text('|'),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(AppLocalizations.of(context)!.team(1)),
                        ),
                        ...List<Widget>.generate(_current.schedule.length, (
                          roundIndex,
                        ) {
                          final isCurrent =
                              event.isRunning &&
                              roundIndex == event.currentRound;
                          final teamIndex =
                              widget.exercise.teamIndex(
                                stationIndex,
                                roundIndex,
                              ) +
                              1;
                          final none = teamIndex == 0;
                          return Container(
                            padding: EdgeInsets.all(4),
                            color:
                                isCurrent
                                    ? none
                                        ? Colors.grey
                                        : Colors.blueAccent
                                    : Colors.transparent,
                            child: Text(
                              '${none ? '×' : teamIndex}',
                              style: TextStyle(
                                fontWeight:
                                    isCurrent
                                        ? FontWeight.bold
                                        : FontWeight
                                            .normal, // Emphasize current round
                                color: isCurrent ? Colors.white : null,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    onTap: () async {
                      // Navigate to SupervisorViewScreen, starting from the selected station
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => StationScreen(
                                stationIndex: stationIndex,
                                exercise: _current,
                              ),
                        ),
                      );
                      if (mounted) {
                        final prefs = await SharedPreferences.getInstance();
                        final repo = ExerciseRepository(prefs);
                        final exercise = await repo.getExercise(_current.uuid);
                        setState(() {
                          _current = exercise!;
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamList(ExerciseEvent event) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 24,
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(AppLocalizations.of(context)!.teamRotations),
              ),
            ),
          ),
          SizedBox(height: 4.0),
          Expanded(
            child: ListView.builder(
              itemCount: _current.teams.length,
              itemBuilder: (context, teamIndex) {
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 2,
                  ),
                  child: ListTile(
                    title: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '${AppLocalizations.of(context)!.team(1)} ${teamIndex + 1}',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text('|'),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(AppLocalizations.of(context)!.station(1)),
                        ),
                        ...List<Widget>.generate(_current.schedule.length, (
                          roundIndex,
                        ) {
                          final isCurrent =
                              event.isRunning &&
                              roundIndex == event.currentRound;
                          return Container(
                            padding: EdgeInsets.all(4),
                            color:
                                isCurrent
                                    ? Colors.blueAccent
                                    : Colors.transparent,
                            child: Text(
                              '${widget.exercise.stationIndex(teamIndex, roundIndex) + 1}',
                              style: TextStyle(
                                fontWeight:
                                    isCurrent
                                        ? FontWeight.bold
                                        : FontWeight
                                            .normal, // Emphasize current round
                                color: isCurrent ? Colors.white : null,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    onTap: () {
                      // Navigate to SupervisorViewScreen, starting from the selected station
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => TeamScreen(
                                teamIndex: teamIndex,
                                exercise: _current,
                              ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _exerciseListener.cancel();
    _notificationListener.cancel();
    super.dispose();
  }
}
