import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/exercise_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coordinator_view_screen.dart';
import 'exercise_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ExerciseRepository _repository;
  List<Exercise> _exercises = [];

  @override
  void initState() {
    super.initState();
    _initRepository();
  }

  Future<void> _initRepository() async {
    final prefs = await SharedPreferences.getInstance();
    _repository = ExerciseRepository(prefs);
    _fetchExercises();
  }

  void _fetchExercises() {
    setState(() {
      _exercises = _repository.loadExercises();
    });
  }

  // Navigate to the CreateExerciseScreen to add a new exercise
  Future<void> _navigateToCreateExercise() async {
    final newExercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (context) => ExerciseFormScreen()),
    );

    if (newExercise != null) {
      // Add the new exercise and reload the list
      await _repository.addExercise(newExercise);
      _fetchExercises();
    }
  }

  // Delete an exercise and refresh the list
  Future<void> _deleteExercise(Exercise exercise) async {
    // Remove the exercise from the repository
    await _repository.deleteExercise(exercise.uuid);
    _fetchExercises();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      body:
          _exercises.isEmpty
              ? const Center(child: Text('No exercises yet!'))
              : ListView.builder(
                itemCount: _exercises.length,
                itemBuilder: (context, index) {
                  final exercise = _exercises[index];

                  return Dismissible(
                    key: ValueKey(exercise.name),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      _deleteExercise(exercise);
                    },
                    child: Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(
                        vertical: 5,
                        horizontal: 10,
                      ),
                      child: ListTile(
                        title: Text(exercise.name),
                        subtitle: Text(
                          'Start: ${ExerciseX.formatTime(exercise.startTime)} - '
                          'End: ${ExerciseX.formatTime(exercise.endTime)}',
                        ),
                        onTap: () async {
                          // Navigate to CoordinatorViewScreen with the selected exercise
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      CoordinatorViewScreen(exercise: exercise),
                            ),
                          );
                          _fetchExercises();
                        },
                        trailing: Icon(
                          Icons.swipe_left,
                          color: Theme.of(context).colorScheme.secondary,
                        ), // An additional swipe icon
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateExercise,
        child: const Icon(Icons.add),
      ),
    );
  }
}
