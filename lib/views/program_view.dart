import 'dart:async';
import 'dart:math';

import 'package:external_path/external_path.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/material.dart';
import 'package:nanoid/nanoid.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/exercise_controll_button.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_io/io.dart';

import 'coordinator_screen.dart';
import 'exercise_form_screen.dart';

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

  Future<void> _initExercises() async {
    final exercises = await _programService.init();

    setState(() {
      _exercises = exercises;
    });
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

class ProgramPageController extends ScreenController {
  final _programService = ProgramService();

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
      await _programService.saveExercise(
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
          PopupMenuItem(value: 'open', child: Text(localizations.openProgram)),
          PopupMenuItem(
            value: 'import',
            child: Text(localizations.importProgram),
          ),
          PopupMenuItem(
            value: 'export',
            child: Text(localizations.exportProgram),
          ),
          PopupMenuItem(
            value: 'share', // Add the new option
            child: Text('Share...'),
          ),
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
      case 'share':
        return _share(context, constraints, localizations);
      default:
        throw UnimplementedError('Action [$action] not implemented');
    }
  }

  Future<void> _open(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
  ) async {
    String? filePath = await _pickFileOrDir(
      context,
      constraints,
      localizations.selectFile,
      FilesystemType.file,
    );

    if (filePath != null) {
      final file = File(filePath);

      try {
        final program = await _programService.openFromLocalFile(file);
        if (program == null) return;
        if (context.mounted) {
          _showSnackBar(context, localizations.openSuccess(program.name));
        }
      } catch (e, stackTrace) {
        if (context.mounted) {
          _showSnackBar(context, localizations.openFailure(filePath));
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
    String? filePath = await _pickFileOrDir(
      context,
      constraints,
      localizations.selectFile,
      FilesystemType.file,
    );
    if (!context.mounted) return;

    if (filePath != null) {
      final file = File(filePath);

      try {
        final program = await _programService.importFromLocalFile(
          file,
          onSelect: (items) async {
            final selected = await _selectExercises(
              context,
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
          _showSnackBar(context, localizations.importSuccess(program.name));
        }
      } catch (e, stackTrace) {
        if (context.mounted) {
          _showSnackBar(context, localizations.importFailure(file.path));
        }
        unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      }
    }
  }

  Future<void> _export(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
  ) async {
    final selected = await _selectExercises(
      context,
      _programService.loadExercises(),
      constraints,
      localizations,
      false,
    );
    if (selected.isEmpty || !context.mounted) return;

    final fileName = await _promptFileName(context, localizations);
    if (!context.mounted) return;

    if (fileName != null) {
      String? dirPath = await _pickFileOrDir(
        context,
        constraints,
        localizations.selectDirectory,
        FilesystemType.folder,
      );
      if (!context.mounted) return;
      if (dirPath != null) {
        // Ask the user for the file name
        try {
          final file = await _exportToLocal(
            context,
            localizations,
            fileName,
            dirPath,
            selected,
          );
          if (!context.mounted) return;
          if (file != null) {
            _showSnackBar(context, localizations.exportSuccess(file.path));
          }
        } on Exception catch (e, stackTrace) {
          if (context.mounted) {
            _showSnackBar(
              context,
              localizations.exportFailure(
                path.join(dirPath, '$fileName.drill'),
              ),
            );
          }
          unawaited(Sentry.captureException(e, stackTrace: stackTrace));
        }
      }
    }
  }

  Future<void> _share(
    BuildContext context,
    BoxConstraints constraints,
    AppLocalizations localizations,
  ) async {
    // Create a temp folder for export
    final String tempDirPath = path.join(
      (await getTemporaryDirectory()).path,
      'program_share',
    );
    if (!context.mounted) return;

    final tempDir = Directory(tempDirPath);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    tempDir.createSync(recursive: true);

    final selected = await _selectExercises(
      context,
      _programService.loadExercises(),
      constraints,
      localizations,
      false,
    );
    if (selected.isEmpty || !context.mounted) return;

    final fileName = await _promptFileName(context, localizations);
    if (!context.mounted) return;

    if (fileName != null) {
      try {
        final file = await _exportToLocal(
          context,
          localizations,
          fileName,
          tempDir.path,
          selected,
        );

        if (file != null) {
          final params = ShareParams(
            text: path.basenameWithoutExtension(file.path),
            files: [XFile(file.path, mimeType: drillMimeType)],
          );

          final result = await SharePlus.instance.share(params);
          if (!context.mounted) return;

          if (result.status == ShareResultStatus.success) {
            _showSnackBar(context, localizations.shareSuccess(file.path));
          }
        }
      } on Exception catch (e, stackTrace) {
        if (context.mounted) {
          _showSnackBar(context, localizations.shareFailure(fileName));
        }
        unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      }
    }
    tempDir.deleteSync(recursive: true);
  }

  Future<File?> _exportToLocal(
    BuildContext context,
    AppLocalizations localizations,
    String fileName,
    String dirPath,
    List<String> exercises,
  ) async {
    if (fileName.isNotEmpty) {
      return await _programService.exportToLocalFile(
        nanoid(10),
        fileName,
        Directory(dirPath),
        exercises,
      );
    } else {
      _showSnackBar(context, localizations.invalidFileName);
    }
    return null;
  }

  static Future<String?> _pickFileOrDir(
    BuildContext context,
    BoxConstraints constraints,
    String title,
    FilesystemType type,
  ) async {
    final localizations = AppLocalizations.of(context)!;
    final docsDirPath = await ExternalPath.getExternalStoragePublicDirectory(
      ExternalPath.DIRECTORY_DOCUMENTS,
    );
    final downloadsDirPath =
        await ExternalPath.getExternalStoragePublicDirectory(
          ExternalPath.DIRECTORY_DOWNLOAD,
        );

    final extDirs = Platform.isAndroid
        ? await getExternalStorageDirectories()
        : [];

    if (!context.mounted) return null;

    int i = 1;
    final result = await FilesystemPicker.openBottomSheet(
      context: context,
      title: title,
      fsType: type,
      showGoUp: true,
      constraints: constraints.copyWith(
        minHeight: 400,
        maxHeight: max(400, constraints.maxHeight * 0.6),
      ),
      pickText: localizations.select,
      rootName: localizations.storage,
      fileTileSelectMode: FileTileSelectMode.wholeTile,
      shortcuts: [
        FilesystemPickerShortcut(
          name: localizations.documents,
          path: Directory(docsDirPath),
          icon: Icons.folder,
          isSelectable: false,
        ),
        FilesystemPickerShortcut(
          name: localizations.downloads,
          path: Directory(downloadsDirPath),
          icon: Icons.folder,
          isSelectable: false,
        ),
        if (extDirs != null)
          ...extDirs.map(
            (dir) => FilesystemPickerShortcut(
              name:
                  '${localizations.sdCard} ${i++} '
                  '(${path.basenameWithoutExtension(dir.path)})',
              path: dir,
              icon: Icons.snippet_folder,
              isSelectable: false,
            ),
          ),
      ],
    );
    return result;
  }

  static Future<List<String>> _selectExercises(
    BuildContext context,
    List<Exercise> exercises,
    BoxConstraints constraints,
    AppLocalizations localizations,
    bool extended,
  ) async {
    final List<String> selected = [];

    await showModalBottomSheet(
      context: context,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2.0),
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                  Text(
                    localizations.selectExercises,
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
                                  style: Theme.of(context).textTheme.titleLarge,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2.0),
                    color: Colors.grey[400],
                  ),
                ),
              ),
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
