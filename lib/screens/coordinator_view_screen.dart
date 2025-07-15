import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/exercise_repository.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'exercise_form_screen.dart';
import 'supervisor_view_screen.dart';

class CoordinatorViewScreen extends StatefulWidget {
  final Exercise exercise;

  const CoordinatorViewScreen({super.key, required this.exercise});

  @override
  State<CoordinatorViewScreen> createState() => _CoordinatorViewScreenState();
}

class _CoordinatorViewScreenState extends State<CoordinatorViewScreen> {
  late Exercise _current;
  bool _isStarted = false;

  @override
  void initState() {
    _current = widget.exercise;

    // Listen to ExerciseService state changes
    ExerciseService().events.listen((event) {
      // Update the state based on the current event phase
      if (mounted) {
        final changed = _isStarted != (event.isRunning || event.isPending);
        setState(() {
          _isStarted = event.isRunning || event.isPending;
        });
        if (changed) {
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
    });

    super.initState();
  }

  /// Converts TimeOfDay to string for display
  String formatTimeOfDay(TimeOfDay time) {
    return ExerciseX.formatTime(time);
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
    return Scaffold(
      appBar: AppBar(
        actionsPadding: const EdgeInsets.all(8.0),
        title: Text(_current.name), // Dynamic title shows the exercise's name
        actions:
            _isStarted
                ? [
                  IconButton(
                    icon: const Icon(Icons.stop),
                    padding: const EdgeInsets.all(8.0),
                    onPressed: () {
                      // Stop the exercise
                      ExerciseService().stop();
                    },
                    tooltip: 'Stop Exercise',
                  ),
                ]
                : [
                  // Edit Exercise Button
                  IconButton(
                    icon: const Icon(Icons.edit),
                    padding: const EdgeInsets.all(8.0),
                    onPressed: () => _editExercise(context),
                    tooltip: 'Edit Exercise',
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    padding: const EdgeInsets.all(8.0),
                    onPressed: () {
                      // Start the exercise
                      ExerciseService().start(_current);
                    },
                    tooltip: 'Start Exercise',
                  ),
                ],
      ),
      body:
          widget.exercise.schedule.isEmpty
              ? const Center(child: Text('No rounds scheduled!'))
              : OrientationBuilder(
                builder: (context, orientation) {
                  final isPortrait = orientation == Orientation.portrait;
                  final mode = (isPortrait ? Column.new : Row.new);
                  return mode(
                    children: [
                      Expanded(
                        flex: isPortrait ? 1 : 2,
                        child: _buildRoundTable(isPortrait),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        flex: isPortrait ? 5 : 4,
                        child: _buildTeamList(),
                      ),
                    ],
                  );
                },
              ),
    );
  }

  ListView _buildTeamList() {
    return ListView.builder(
      itemCount: widget.exercise.teams.length,
      itemBuilder: (context, teamIndex) {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          child: ListTile(
            title: Text('Team ${teamIndex + 1}'),
            subtitle: Text(
              'Stations: ${List<int>.generate(widget.exercise.schedule.length, (roundIndex) {
                return stationIndex(teamIndex, roundIndex) + 1;
              }).join(' ')}',
            ),
            onTap: () {
              // Navigate to SupervisorViewScreen, starting from the selected station
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => SupervisorViewScreen(
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

  Column _buildRoundTable(bool isPortrait) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment:
          isPortrait ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: List<Text>.generate(widget.exercise.schedule.length, (index) {
        final round = widget.exercise.schedule[index];
        return Text(
          style: TextStyle(fontSize: 18),
          'Round ${index + 1}: '
          '${formatTimeOfDay(round[0])} | '
          '${formatTimeOfDay(round[1])} | '
          '${formatTimeOfDay(round[2])}',
        );
      }),
    );
  }
}
