import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/exercise_repository.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/sentry_config.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/about_page.dart';
import 'package:ringdrill/views/settings_page.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coordinator_screen.dart';
import 'exercise_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.isFirstLaunch});

  final bool isFirstLaunch;

  static void showSettings(BuildContext context, [bool pop = false]) {
    if (pop) Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

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
    if (widget.isFirstLaunch) _showConsentDialog();
    NotificationService().events.listen((event) {
      if (event.action == NotificationAction.showSettings) {
        if (mounted) {
          HomeScreen.showSettings(context);
        }
      }
    });
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
                  builder:
                      (context) => AlertDialog(
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
    if (ExerciseService().exercise == exercise) {
      ExerciseService().stop();
    }
    // Remove the exercise from the repository
    await _repository.deleteExercise(exercise.uuid);
    _fetchExercises();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(localizations.exercise(10))),
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
                  HomeScreen.showSettings(context, true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: Text(localizations.about),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AboutPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body:
          _exercises.isEmpty
              ? Center(child: Text(localizations.noExercisesYet))
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
                    confirmDismiss:
                        (direction) => showDialog(
                          context: context,
                          barrierDismissible:
                              false, // Prevent closing without taking action
                          builder:
                              (context) => AlertDialog(
                                title: Text(localizations.confirm),
                                content: Text(
                                  localizations.confirmDeleteExercise,
                                ),
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
                        title: Text(exercise.name),
                        subtitle: Text(
                          [
                            '${exercise.startTime.formal()} - ${exercise.endTime.formal()}',
                            exercise.endTime.toDateTime().formal(
                              localizations,
                              exercise.startTime.toDateTime(),
                            ),
                            '${exercise.numberOfRounds} ${localizations.round(exercise.numberOfRounds)}',
                            '${exercise.numberOfTeams} ${localizations.team(exercise.numberOfTeams)}',
                          ].join(' | '),
                        ),
                        onTap: () async {
                          // Navigate to CoordinatorViewScreen with the selected exercise
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
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
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateExercise,
        child: const Icon(Icons.add),
      ),
    );
  }
}
