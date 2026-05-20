import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/exercise_control_button.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/shared_file_widget.dart';

import 'exercise_form_screen.dart';

export 'package:ringdrill/web/program_page_controller.dart'
    if (dart.library.io) 'program_page_controller.dart';

class ProgramView extends StatefulWidget {
  const ProgramView({super.key});

  @override
  State<ProgramView> createState() => _ProgramViewState();
}

class _ProgramViewState extends State<ProgramView> {
  final _programService = ProgramService();
  final _exerciseService = ExerciseService();
  final List<StreamSubscription> _subscriptions = [];
  List<Exercise> _exercises = [];

  @override
  void initState() {
    super.initState();
    _initExercises();

    // Listen to exercise changes
    _subscriptions.add(
      _programService.events.listen((event) {
        setState(() {
          _exercises = _programService.loadExercises();
        });
      }),
    );

    // Listen to ExerciseService state changes
    _subscriptions.add(
      _exerciseService.events.listen((event) {
        // Update the state based on the current event phase
        if (mounted) {
          setState(() {});
        }
      }),
    );
  }

  @override
  void dispose() {
    super.dispose();
    for (var e in _subscriptions) {
      e.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final programs = _exercises.isEmpty
        ? Center(child: Text(localizations.noExercisesYet))
        : Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: ListView.builder(
              itemCount: _exercises.length,
              itemBuilder: (context, index) {
                final exercise = _exercises[index];
                final markers = exercise.getLocations(false);

                return GestureDetector(
                  onTap: () async {
                    // Navigate to CoordinatorViewScreen with the selected exercise
                    await context.push('$routeProgram/${exercise.uuid}');
                  },
                  child: Dismissible(
                    key: ValueKey(exercise.name),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) => showDialog(
                      context: context,
                      barrierDismissible:
                          false, // Prevent closing without taking action
                      builder: (context) => AlertDialog(
                        title: Text(localizations.confirm),
                        content: Text(localizations.confirmDeleteExercise),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context, false);
                            },
                            child: Text(localizations.cancel),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () async {
                              Navigator.pop(context, true);
                            },
                            child: Text(
                              localizations.delete,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    onDismissed: (direction) {
                      _deleteExercise(exercise);
                    },
                    child: ExerciseCard(
                      exercise: exercise,
                      localizations: localizations,
                      trailing: ExerciseControlButton(
                        isFAB: false,
                        exercise: exercise,
                        service: _exerciseService,
                        localizations: localizations,
                      ),
                      markers: markers,
                    ),
                  ),
                );
              },
            ),
          );
    return kIsWeb ? programs : SharedFileWidget(child: programs);
  }

  void _initExercises() {
    _exercises = _programService.loadExercises();
  }

  // Delete an exercise and refresh the list
  Future<void> _deleteExercise(Exercise exercise) async {
    if (ExerciseService().exercise == exercise) {
      ExerciseService().stop();
    }
    // Remove the exercise from the repository
    await _programService.deleteExercise(exercise.uuid);
  }
}

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.localizations,
    this.trailing,
    required this.markers,
  });

  final Widget? trailing;
  final Exercise exercise;
  final AppLocalizations localizations;
  final List<StationLocation> markers;

  @override
  Widget build(BuildContext context) {
    final st = exercise.startTime.toMaterial();
    final et = exercise.endTime.toMaterial();
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: Text(
                    exercise.name,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    [
                      '${st.formal()} - ${et.formal()}',
                      et.toDateTime().formal(localizations, st.toDateTime()),
                      '${exercise.numberOfRounds} ${localizations.round(exercise.numberOfRounds).toLowerCase()}',
                      '${exercise.numberOfTeams} ${localizations.team(exercise.numberOfTeams).toLowerCase()}',
                    ].join(' | '),
                  ),
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: trailing,
                ),
            ],
          ),
          if (markers.isNotEmpty)
            SizedBox(
              height: 200,
              child: IgnorePointer(
                child: MapView(
                  layers: MapConfig.layers,
                  withToggle: false,
                  markers: markers,
                  initialFit: markers.fit(),
                  initialCenter: markers.average(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

abstract class ProgramPageControllerBase extends ScreenController {
  ProgramPageControllerBase();

  @protected
  final programService = ProgramService();

  @override
  String title(BuildContext context) =>
      programService.activeProgram?.name ??
      AppLocalizations.of(context)!.exercise(2);

  @override
  Widget? buildFAB(BuildContext context, BoxConstraints constraints) {
    return FloatingActionButton(
      heroTag: 'add',
      onPressed: () => _navigateToCreateExercise(context),
      child: const Icon(Icons.add),
    );
  }

  // Navigate to the CreateExerciseScreen to add a new exercise
  Future<void> _navigateToCreateExercise(BuildContext context) async {
    final newExercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (context) => ExerciseFormScreen()),
    );

    if (context.mounted && newExercise != null) {
      // Add the new exercise and reload the list
      await programService.saveExercise(
        AppLocalizations.of(context)!,
        newExercise,
      );
    }
  }

  @override
  List<Widget>? buildActions(BuildContext context, BoxConstraints constraints) {
    return null;
  }

  static Future<List<String>> selectExercises(
    BuildContext context,
    String title,
    List<Exercise> exercises,
    BoxConstraints constraints,
    AppLocalizations localizations,
    bool extended,
  ) async {
    final List<String> selected = [];

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: extended,
      constraints: extended
          ? constraints
          : constraints.copyWith(
              minHeight: 400,
              maxHeight: max(400, constraints.maxHeight * 0.5),
            ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8.0),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: exercises.length,
                        itemBuilder: (context, index) {
                          final uuid = exercises[index].uuid;
                          final markers = exercises[index].getLocations(false);
                          return extended
                              ? ExerciseCard(
                                  exercise: exercises[index],
                                  localizations: localizations,
                                  markers: markers,
                                  trailing: Switch(
                                    value: selected.contains(uuid),
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          selected.add(uuid);
                                        } else {
                                          selected.remove(uuid);
                                        }
                                      });
                                    },
                                  ),
                                )
                              : SwitchListTile(
                                  title: Text(
                                    exercises[index].name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  value: selected.contains(uuid),
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        selected.add(uuid);
                                      } else {
                                        selected.remove(uuid);
                                      }
                                    });
                                  },
                                );
                        },
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context, null);
                          },
                          child: Text(localizations.cancel),
                        ),
                        const SizedBox(width: 8.0),
                        ElevatedButton(
                          onPressed: selected.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(context, selected);
                                },
                          child: Text(localizations.confirm),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return selected;
  }

  static Future<String?> promptFileName(
    BuildContext context,
    AppLocalizations localizations,
  ) async {
    String? fileName;

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true, // Allows the bottom sheet to resize properly
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) {
        final TextEditingController controller = TextEditingController(
          text: localizations.exercise(2),
        );

        return Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localizations.enterFileName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8.0),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: localizations.fileNameHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, null);
                      },
                      child: Text(localizations.cancel),
                    ),
                    const SizedBox(width: 8.0),
                    ElevatedButton(
                      onPressed: () {
                        fileName = controller.text.trim();
                        Navigator.pop(context, fileName);
                      },
                      child: Text(localizations.confirm),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
              ],
            ),
          ),
        );
      },
    );

    return fileName;
  }
}
