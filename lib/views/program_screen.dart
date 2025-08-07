import 'dart:async';

import 'package:external_path/external_path.dart';
import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/material.dart';
import 'package:nanoid/nanoid.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/sentry_config.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/about_page.dart';
import 'package:ringdrill/views/settings_page.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_io/io.dart';

import 'coordinator_screen.dart';
import 'exercise_form_screen.dart';

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key, required this.isFirstLaunch});

  final bool isFirstLaunch;

  static void showSettings(BuildContext context, [bool pop = false]) {
    if (pop) Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  final _programService = ProgramService();
  final List<StreamSubscription> _subscriptions = [];
  List<Exercise> _exercises = [];

  @override
  void initState() {
    super.initState();
    _initExercises();
    if (widget.isFirstLaunch) _showConsentDialog();
    _subscriptions.add(
      NotificationService().events.listen((event) {
        if (event.action == NotificationAction.showSettings) {
          if (mounted) {
            ProgramScreen.showSettings(context);
          }
        }
      }),
    );
    _subscriptions.add(
      _programService.events.listen((event) {
        _exercises.clear();
        _fetchExercises();
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
    return LayoutBuilder(
      builder: (context, constraints) => Scaffold(
        appBar: AppBar(
          title: Text(localizations.exercise(10)),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(value, constraints),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'open',
                  child: Text(localizations.openProgram),
                ),
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
          ],
        ),
        drawer: Drawer(
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  color: Theme.of(context).appBarTheme.backgroundColor,
                  padding: const EdgeInsets.symmetric(
                    vertical: 15.0,
                    horizontal: 16.0,
                  ),
                  child: Row(
                    children: [
                      Text(
                        localizations.appName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.0, // Smaller font size than DrawerHeader
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16.0),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: Text(localizations.settings),
                  onTap: () {
                    ProgramScreen.showSettings(context, true);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info),
                  title: Text(localizations.about),
                  onTap: () {
                    Navigator.pop(context); // Close the drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AboutPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        body: _buildBody(localizations),
        floatingActionButton: FloatingActionButton(
          onPressed: _navigateToCreateExercise,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  SingleChildRenderObjectWidget _buildBody(AppLocalizations localizations) {
    return _exercises.isEmpty
        ? Center(child: Text(localizations.noExercisesYet))
        : Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: ListView.builder(
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
                          child: Text(localizations.no),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context, true);
                          },
                          child: Text(localizations.yes),
                        ),
                      ],
                    ),
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
                      onTap: () async {
                        // Navigate to CoordinatorViewScreen with the selected exercise
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CoordinatorScreen(exercise: exercise),
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
          );
  }

  void _showConsentDialog() {
    Future.microtask(() async {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        // Show a dialog asking the user to provide consent
        final consent =
            await showDialog(
                  context: context,
                  barrierDismissible:
                      false, // Prevent closing without taking action
                  builder: (context) => AlertDialog(
                    title: Text(localizations.appAnalyticsConsent),
                    content: Text(
                      [
                        localizations.appAnalyticsConsentMessage,
                        localizations.appAnalyticsConsentOptIn,
                      ].join('. '),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context, false);
                        },
                        child: Text(localizations.decline),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context, true);
                        },
                        child: Text(localizations.allow),
                      ),
                    ],
                  ),
                )
                as bool;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(AppConfig.keyAnalyticsConsent, consent);

        if (consent) {
          await SentryFlutter.init(SentryConfig.apply);
        }
      }
    });
  }

  Future<void> _initExercises() async {
    final exercises = await _programService.init();

    setState(() {
      _exercises = exercises;
    });
  }

  void _fetchExercises() {
    setState(() {
      _exercises = _programService.repo.loadExercises();
    });
  }

  // Navigate to the CreateExerciseScreen to add a new exercise
  Future<void> _navigateToCreateExercise() async {
    final newExercise = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (context) => ExerciseFormScreen()),
    );

    if (newExercise != null) {
      // Add the new exercise and reload the list
      await _programService.repo.addExercise(newExercise);
      _fetchExercises();
    }
  }

  // Delete an exercise and refresh the list
  Future<void> _deleteExercise(Exercise exercise) async {
    if (ExerciseService().exercise == exercise) {
      ExerciseService().stop();
    }
    // Remove the exercise from the repository
    await _programService.repo.deleteExercise(exercise.uuid);
    _fetchExercises();
  }

  void _handleMenuAction(String action, BoxConstraints constraints) async {
    final localizations = AppLocalizations.of(context)!;

    switch (action) {
      case 'open':
        return _open(localizations, constraints);
      case 'import':
        return _import(localizations, constraints);
      case 'export':
        return _export(localizations, constraints);
      case 'share':
        return _share(localizations);
      default:
        throw UnimplementedError('Action [$action] not implemented');
    }
  }

  Future<void> _open(
    AppLocalizations localizations,
    BoxConstraints constraints,
  ) async {
    String? filePath = await _pickFileOrDir(
      localizations.selectFile,
      FilesystemType.file,
      constraints,
    );

    if (mounted) {
      if (filePath != null) {
        final file = File(filePath);

        try {
          final program = await _programService.openFromLocalFile(file);
          _showSnackBar(localizations.openSuccess(program.name));
        } catch (e, stackTrace) {
          _showSnackBar(localizations.openFailure(filePath));
          unawaited(Sentry.captureException(e, stackTrace: stackTrace));
        }
      }
    }
  }

  Future<void> _import(
    AppLocalizations localizations,
    BoxConstraints constraints,
  ) async {
    String? filePath = await _pickFileOrDir(
      localizations.selectFile,
      FilesystemType.file,
      constraints,
    );

    if (mounted) {
      if (filePath != null) {
        final file = File(filePath);

        try {
          final program = await _programService.importFromLocalFile(file);
          _showSnackBar(localizations.importSuccess(program.name));
        } catch (e, stackTrace) {
          _showSnackBar(localizations.importFailure(file.path));
          unawaited(Sentry.captureException(e, stackTrace: stackTrace));
        }
      }
    }
  }

  Future<void> _export(
    AppLocalizations localizations,
    BoxConstraints constraints,
  ) async {
    String? dirPath = await _pickFileOrDir(
      localizations.selectDirectory,
      FilesystemType.folder,
      constraints,
    );

    if (dirPath != null) {
      final fileName = await _promptFileName(localizations);
      if (fileName != null) {
        // Ask the user for the file name
        try {
          final file = await _exportToLocal(localizations, fileName, dirPath);
          if (file != null) {
            _showSnackBar(localizations.exportSuccess(file.path));
          }
        } on Exception catch (e, stackTrace) {
          _showSnackBar(
            localizations.exportFailure(path.join(dirPath, fileName, '.drill')),
          );
          unawaited(Sentry.captureException(e, stackTrace: stackTrace));
        }
      }
    }
  }

  Future<void> _share(AppLocalizations localizations) async {
    // Create a temp folder for export
    final String tempDirPath = path.join(
      (await getTemporaryDirectory()).path,
      'program_share',
    );
    final tempDir = Directory(tempDirPath);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    tempDir.createSync(recursive: true);

    final fileName = await _promptFileName(localizations);
    if (fileName != null) {
      try {
        final file = await _exportToLocal(
          localizations,
          fileName,
          tempDir.path,
        );

        if (file != null) {
          final params = ShareParams(
            text: path.basenameWithoutExtension(file.path),
            files: [XFile(file.path, mimeType: drillMimeType)],
          );

          final result = await SharePlus.instance.share(params);

          if (result.status == ShareResultStatus.success) {
            _showSnackBar(localizations.shareSuccess(file.path));
          }
        }
      } on Exception catch (e, stackTrace) {
        _showSnackBar(localizations.shareFailure(fileName));
        unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      }
    }
    tempDir.deleteSync(recursive: true);
  }

  Future<File?> _exportToLocal(
    AppLocalizations localizations,
    String fileName,
    String dirPath,
  ) async {
    if (fileName.isNotEmpty) {
      final program = Program(
        uuid: nanoid(10),
        name: fileName,
        description: '',
        metadata: ProgramMetadata(
          created: DateTime.now(),
          updated: DateTime.now(),
          version: '1.0',
        ),
        exercises: _exercises,
        // Using the current list of exercises.
        sessions: [], // Add session details if applicable.
      );

      // Use ProgramManager or other logic to export the program
      return await _programService.exportToLocalFile(
        program,
        Directory(dirPath),
      );
    } else {
      _showSnackBar(localizations.invalidFileName);
    }

    return null;
  }

  Future<String?> _pickFileOrDir(
    String title,
    FilesystemType type,
    BoxConstraints constraints,
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

    if (!mounted) return null;

    int i = 1;
    final result = await FilesystemPicker.openBottomSheet(
      context: context,
      title: title,
      constraints: constraints,
      fsType: type,
      pickText: localizations.select,
      rootName: localizations.storage,
      fileTileSelectMode: FileTileSelectMode.checkButton,
      shortcuts: [
        FilesystemPickerShortcut(
          name: localizations.documents,
          path: Directory(docsDirPath),
          icon: Icons.folder,
        ),
        FilesystemPickerShortcut(
          name: localizations.downloads,
          path: Directory(downloadsDirPath),
          icon: Icons.folder,
        ),
        if (extDirs != null)
          ...extDirs.map(
            (dir) => FilesystemPickerShortcut(
              name:
                  '${localizations.sdCard} ${i++} (${path.basenameWithoutExtension(dir.path)})',
              path: dir,
              icon: Icons.snippet_folder,
            ),
          ),
      ],
    );
    return result;
  }

  Future<String?> _promptFileName(AppLocalizations localizations) async {
    String? fileName;

    await showDialog(
      context: context,
      builder: (context) {
        final TextEditingController controller = TextEditingController();

        return AlertDialog(
          title: Text(localizations.enterFileName),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: localizations.fileNameHint),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, null);
              },
              child: Text(localizations.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                fileName = controller.text.trim();
                Navigator.pop(context, fileName);
              },
              child: Text(localizations.confirm),
            ),
          ],
        );
      },
    );

    return fileName;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
