import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/exercise_repository.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'exercise_form_screen.dart';
import 'supervisor_screen.dart';

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

  int stationIndex(int teamIndex, int roundIndex) {
    return widget.exercise.stationIndex(teamIndex, roundIndex);
  }

  @override
  Widget build(BuildContext context) {
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
                tooltip: 'Show notification',
              ),

              // Edit Exercise Button
              IconButton(
                icon: const Icon(Icons.edit),
                padding: const EdgeInsets.all(8.0),
                onPressed: _isStarted ? null : () => _editExercise(context),
                tooltip: _isStarted ? 'Stop exercise first' : 'Edit Exercise',
              ),
            ],
          ),
          body:
              _current.schedule.isEmpty
                  ? const Center(child: Text('No rounds scheduled!'))
                  : OrientationBuilder(
                    builder: (context, orientation) {
                      final isPortrait = orientation == Orientation.portrait;
                      final mode = (isPortrait ? Column.new : Row.new);
                      return mode(
                        children: [
                          Expanded(
                            flex: isPortrait ? 1 : 2,
                            child: _buildRoundTable(event, isPortrait),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            flex: isPortrait ? 5 : 4,
                            child: _buildTeamList(event),
                          ),
                        ],
                      );
                    },
                  ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              if (!isStartable) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "Stop '${_exerciseService.exercise!.name}' first!",
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

  ExerciseEvent _initialData() {
    final last = ExerciseService().last;
    if (last?.exercise == _current) return last!;
    return ExerciseEvent.pending(widget.exercise);
  }

  bool get isStartable {
    return _exerciseService.exercise == null ||
        _exerciseService.exercise == _current;
  }

  ListView _buildTeamList(ExerciseEvent event) {
    return ListView.builder(
      itemCount: _current.teams.length,
      itemBuilder: (context, teamIndex) {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          child: ListTile(
            title: Text('Team ${teamIndex + 1}'),
            subtitle: Row(
              children: [
                Text('Stations:'),
                ...List<Widget>.generate(_current.schedule.length, (
                  roundIndex,
                ) {
                  final isCurrent =
                      event.isRunning && roundIndex == event.currentRound;
                  return Container(
                    padding: EdgeInsets.all(4),
                    color: isCurrent ? Colors.blueAccent : Colors.transparent,
                    child: Text(
                      '${stationIndex(teamIndex, roundIndex) + 1}',
                      style: TextStyle(
                        fontWeight:
                            isCurrent
                                ? FontWeight.bold
                                : FontWeight.normal, // Emphasize current round
                        color: isCurrent ? Colors.white : Colors.black,
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
                      (context) => SupervisorScreen(
                        teamIndex: teamIndex,
                        exercise: _current,
                      ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRoundTable(ExerciseEvent event, bool isPortrait) {
    return Container(
      padding: EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment:
            isPortrait ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment:
            isPortrait ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: List<Widget>.generate(_current.schedule.length, (roundIndex) {
          // Determine whether this round is completed or current
          final isCurrent = event.isRunning && roundIndex == event.currentRound;
          final textStyle = TextStyle(
            fontSize: 18,
            fontWeight:
                isCurrent
                    ? FontWeight.bold
                    : FontWeight.normal, // Emphasize current round
            color:
                isCurrent
                    ? Colors.white
                    : Colors.black, // Contrast for visibility
          );

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 24,
                padding: EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: isCurrent ? Colors.blueAccent : Colors.transparent,
                  borderRadius:
                      isCurrent
                          ? BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          )
                          : null,
                ),
                child: Text('Round ${roundIndex + 1}: ', style: textStyle),
              ),
              ...List<Widget>.generate(_current.schedule[roundIndex].length, (
                phaseIndex,
              ) {
                return _buildPhaseCell(
                  event,
                  roundIndex,
                  phaseIndex,
                  textStyle,
                  isPortrait,
                  isCurrent,
                );
              }),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPhaseCell(
    ExerciseEvent event,
    int roundIndex,
    int phaseIndex,
    TextStyle style,
    bool isPortrait,
    bool isCurrent,
  ) {
    final cellSize =
        phaseIndex < ExercisePhase.rotation.index - 1 ? 56.0 : 50.0;
    final isCurrentRound = event.isRunning && roundIndex == event.currentRound;
    final isCurrentPhase =
        isCurrentRound && phaseIndex == event.phase.index - 1;
    final isComplete = isCurrentRound && event.phase.index > phaseIndex + 1;
    return SizedBox(
      width: cellSize,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Background progress bar
          SizedBox(
            height: 24,
            child: Container(
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color:
                    isCurrentRound
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.transparent,
                borderRadius:
                    phaseIndex == 2
                        ? BorderRadius.only(
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        )
                        : null,
              ),
            ),
          ),
          SizedBox(
            height: 24,
            child: FractionallySizedBox(
              widthFactor:
                  isComplete
                      ? 1.0
                      : isCurrentPhase
                      ? event.phaseProgress
                      : 0.0,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isCurrentRound ? Colors.blueAccent : Colors.transparent,
                  borderRadius:
                      phaseIndex == 2
                          ? BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          )
                          : null,
                ),
              ),
            ),
          ),

          // Phase info
          Row(
            crossAxisAlignment:
                isPortrait
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
            children: [
              Text(
                _current.schedule[roundIndex][phaseIndex].formal(),
                style: style,
              ),
              if (phaseIndex < 2) Text(' |', style: style),
            ],
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
