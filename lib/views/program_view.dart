import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/exercise_control_button.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:universal_io/io.dart';

import 'coordinator_screen.dart';
import 'exercise_form_screen.dart';
import 'feedback.dart';

export '../web/program_page_controller.dart'
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
    return _exercises.isEmpty
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
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CoordinatorScreen(uuid: exercise.uuid),
                      ),
                    );
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
                      '${exercise.startTime.formal()} - ${exercise.endTime.formal()}',
                      exercise.endTime.toDateTime().formal(
                        localizations,
                        exercise.startTime.toDateTime(),
                      ),
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
  @protected
  final programService = ProgramService();

  @protected
  final exerciseService = ExerciseService();

  @override
  String title(BuildContext context) =>
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
    final localizations = AppLocalizations.of(context)!;
    return [
      PopupMenuButton<String>(
        onSelected: (value) => _handleMenuAction(context, constraints, value),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'open',
            enabled: !exerciseService.isStarted,
            child: Text(localizations.openProgram),
          ),
          PopupMenuItem(
            value: 'import',
            enabled: !exerciseService.isStarted,
            child: Text(localizations.importProgram),
          ),

          if (!Platform.isAndroid)
            // On Android 10+ export (save as) does not make that much sense.
            // Access to the file system is highly limited, in practice
            // only “scoped storage” is available to this application for
            // write operations, which is hard to find again. Most modern apps
            // use SEND actions (share) instead, allowing the user decide which
            // app on the mobile os that should receive it (could be Dropbox, SMS etc).
            PopupMenuItem(
              value: 'export',
              enabled: !exerciseService.isStarted,
              child: Text(localizations.exportProgram),
            ),
          PopupMenuItem(
            value: 'share',
            enabled: !exerciseService.isStarted,
            child: Text(localizations.shareProgram),
          ),
          PopupMenuItem(
            value: 'send_to',
            enabled: !exerciseService.isStarted,
            child: Text(localizations.sendToProgram),
          ),
          PopupMenuItem(value: 'feedback', child: Text(localizations.feedback)),
        ],
      ),
    ];
  }

  void _handleMenuAction(
    BuildContext context,
    BoxConstraints constraints,
    String action,
  ) async {
    final localizations = AppLocalizations.of(context)!;

    switch (action) {
      case 'open':
        return _open(context, constraints, localizations);
      case 'import':
        return _import(context, constraints, localizations);
      case 'export':
        return _export(context, constraints, localizations);
      case 'send_to':
        return _sendTo(context, constraints, localizations);
      case 'share':
        return _share(context, constraints, localizations);
      case 'feedback':
        return showFeedbackSheet(
          context,
          appState: {
            '_exerciseService': {'lastEvent': exerciseService.last?.toJson()},
          },
        );
      default:
        throw UnimplementedError('Action [$action] not implemented');
    }
  }

  @protected
  Future<DrillFile?> open(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
  );

  Future<void> _open(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
  ) async {
    final drillFile = await open(context, constraints, localizations);
    if (!context.mounted) return;

    if (drillFile != null) {
      try {
        final program = await programService.openProgram(
          localizations,
          drillFile,
        );
        if (program == null) return;
        if (context.mounted) {
          _showSnackBar(context, localizations.openSuccess(drillFile.fileName));
        }
      } catch (e, stackTrace) {
        if (context.mounted) {
          _showSnackBar(context, localizations.openFailure(drillFile.fileName));
        }
        unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      }
    }
  }

  Future<void> _import(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
  ) async {
    final drillFile = await open(context, constraints, localizations);
    if (!context.mounted) return;

    if (drillFile != null) {
      try {
        final program = await programService.importProgram(
          localizations,
          drillFile,
          onSelect: (items) async {
            final selected = await _selectExercises(
              context,
              localizations.importProgram,
              items.toList(),
              constraints,
              localizations,
              true,
            );
            return selected.isEmpty
                ? null
                : items.where((e) => selected.contains(e.uuid));
          },
        );
        if (program == null) return;

        if (context.mounted) {
          _showSnackBar(
            context,
            localizations.importSuccess(drillFile.fileName),
          );
        }
      } catch (e, stackTrace) {
        if (context.mounted) {
          _showSnackBar(
            context,
            localizations.importFailure(drillFile.fileName),
          );
        }
        unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      }
    }
  }

  @protected
  Future<bool> save(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
    DrillFile drillFile,
  );

  Future<void> _export(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
  ) async {
    final selected = await _selectExercises(
      context,
      localizations.exportProgram,
      programService.loadExercises(),
      constraints,
      localizations,
      false,
    );
    if (selected.isEmpty || !context.mounted) return;

    // Ask the user for the file name
    final fileName = await _promptFileName(context, localizations);
    if (!context.mounted) return;

    if (fileName != null) {
      final drillFile = await programService.exportProgram(
        nanoid(10),
        fileName,
        selected,
      );
      try {
        if (!context.mounted) return;

        final result = await save(
          context,
          constraints,
          localizations,
          drillFile,
        );
        if (!context.mounted) return;
        if (result) {
          _showSnackBar(
            context,
            localizations.exportSuccess(drillFile.fileName),
          );
        }
      } on Exception catch (e, stackTrace) {
        if (context.mounted) {
          _showSnackBar(
            context,
            localizations.exportFailure(drillFile.fileName),
          );
        }
        unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      }
    }
  }

  @protected
  Future<bool> sendTo(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
    DrillFile drillFile,
  );

  Future<void> _sendTo(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
  ) async {
    final selected = await _selectExercises(
      context,
      localizations.sendToProgram,
      programService.loadExercises(),
      constraints,
      localizations,
      false,
    );
    if (selected.isEmpty || !context.mounted) return;

    // Ask the user for the file name
    final fileName = await _promptFileName(context, localizations);
    if (!context.mounted) return;

    if (fileName != null) {
      final drillFile = await programService.exportProgram(
        nanoid(10),
        fileName,
        selected,
      );
      try {
        if (!context.mounted) return;

        final result = await sendTo(
          context,
          constraints,
          localizations,
          drillFile,
        );

        if (!context.mounted) return;
        if (result) {
          _showSnackBar(
            context,
            localizations.sendToSuccess(drillFile.fileName),
          );
        }
      } on Exception catch (e, stackTrace) {
        if (context.mounted) {
          _showSnackBar(
            context,
            localizations.sendToFailure(drillFile.fileName),
          );
        }
        unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      }
    }
  }

  @protected
  Future<bool> share(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
    DrillFile drillFile,
  );

  Future<void> _share(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
  ) async {
    final selected = await _selectExercises(
      context,
      localizations.shareProgram,
      programService.loadExercises(),
      constraints,
      localizations,
      false,
    );
    if (selected.isEmpty || !context.mounted) return;

    // Ask the user for the file name
    final fileName = await _promptFileName(context, localizations);
    if (!context.mounted) return;

    if (fileName != null) {
      final drillFile = await programService.exportProgram(
        nanoid(10),
        fileName,
        selected,
      );
      try {
        if (!context.mounted) return;

        final result = await share(
          context,
          constraints,
          localizations,
          drillFile,
        );

        if (!context.mounted) return;
        if (result) {
          _showSnackBar(
            context,
            localizations.shareSuccess(drillFile.fileName),
          );
        }
      } on Exception catch (e, stackTrace) {
        if (context.mounted) {
          _showSnackBar(
            context,
            localizations.shareFailure(drillFile.fileName),
          );
        }
        unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      }
    }
  }

  static Future<List<String>> _selectExercises(
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

  static Future<String?> _promptFileName(
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

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        showCloseIcon: true,
        dismissDirection: DismissDirection.endToStart,
        content: Text(message),
      ),
    );
  }
}
