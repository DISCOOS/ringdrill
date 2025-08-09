import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/notification_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/phase_headers.dart';
import 'package:ringdrill/views/phase_tile.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/team_exercise_screen.dart';
import 'package:ringdrill/views/team_station_widget.dart';
import 'package:ringdrill/views/vertical_divider_widget.dart';

import 'exercise_controll_button.dart';
import 'exercise_form_screen.dart';

class CoordinatorScreen extends StatefulWidget {
  final String uuid;

  const CoordinatorScreen({super.key, required this.uuid});

  @override
  State<CoordinatorScreen> createState() => _CoordinatorScreenState();
}

class _CoordinatorScreenState extends State<CoordinatorScreen> {
  late bool _isStarted;

  final _programService = ProgramService();
  final _exerciseService = ExerciseService();
  final _subscriptions = <StreamSubscription>[];

  Exercise? _exercise;
  bool _promptShowNotification = false;

  @override
  void initState() {
    _isStarted = _exerciseService.isStartedOn(widget.uuid);

    // Listen to ProgramService state changes
    _subscriptions.add(
      _programService.events.listen((event) {
        if (event.exercise?.uuid == widget.uuid) {
          if (mounted) {
            setState(() {
              _exercise = event.exercise;
            });
          }
        }
      }),
    );

    // Listen to ExerciseService state changes
    _subscriptions.add(
      _exerciseService.events
          .where((e) => _exerciseService.isStartedOn(_exercise!.uuid))
          .listen((event) {
            // Update the state based on the current event phase
            if (mounted) {
              final changed =
                  _isStarted != (event.isRunning || event.isPending);
              setState(() {
                _isStarted = event.isRunning || event.isPending;
              });
              if (changed || event.isDone) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    showCloseIcon: true,
                    dismissDirection: DismissDirection.endToStart,
                    content: Text(
                      '${_exercise!.name} ${event.isRunning
                          ? AppLocalizations.of(context)!.isRunning
                          : event.isPending
                          ? AppLocalizations.of(context)!.isPending
                          : AppLocalizations.of(context)!.isDone}',
                    ),
                  ),
                );
              }
            }
          }),
    );

    // Listen to Notification Events
    _subscriptions.add(
      NotificationService().events
          .where((_) => _exercise != null)
          .where((e) => e.action == NotificationAction.promptReshow)
          .where((e) => e.exercise?.uuid == _exercise?.uuid)
          .listen((event) {
            if (mounted) {
              setState(() {
                _promptShowNotification = true;
              });
            }
          }),
    );

    super.initState();
  }

  @override
  void didChangeDependencies() {
    _exercise = _programService.getExercise(widget.uuid);
    assert(_exercise != null, 'Exercise with uuid [${widget.uuid}] not found');
    _isStarted = _exerciseService.isStartedOn(widget.uuid);
    super.didChangeDependencies();
  }

  /// Function to handle editing the exercise
  void _deleteExercise(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.confirm),
        content: Text(localizations.confirmDeleteExercise),
        actions: [
          // Cancel Button
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: Text(localizations.cancel),
          ),
          // Delete Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop(true);
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
    );

    if (context.mounted && confirmed) {
      await _programService.deleteExercise(_exercise!.uuid);
      if (context.mounted) {
        Navigator.of(context).pop(false);
      }
    }
  }

  /// Function to handle editing the exercise
  void _editExercise(BuildContext context) async {
    final numberOfTeams = _programService.loadTeams().length;
    // Navigate to the edit exercise screen
    final newExercise = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExerciseFormScreen(
          exercise: _exercise,
          numberOfTeams: numberOfTeams == 0 ? null : numberOfTeams,
        ),
      ),
    );
    if (context.mounted && newExercise != null) {
      await _programService.saveExercise(
        AppLocalizations.of(context)!,
        newExercise,
      );
      setState(() {
        _exercise = newExercise;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return StreamBuilder(
      stream: _exerciseService.events,
      initialData: _exerciseService.last,
      builder: (context, asyncSnapshot) {
        final event =
            asyncSnapshot.data ??
            ExerciseEvent.pending(_programService.getExercise(widget.uuid)!);
        return Scaffold(
          appBar: AppBar(
            actionsPadding: const EdgeInsets.all(8.0),
            title: Text(
              _exercise!.name,
            ), // Dynamic title shows the exercise's name
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_on),
                padding: const EdgeInsets.all(8.0),
                onPressed: _promptShowNotification
                    ? () {
                        unawaited(NotificationService().initFromPrefs());
                        setState(() {
                          _promptShowNotification = false;
                        });
                      }
                    : null,
                tooltip: localizations.showNotification,
              ),

              // Delete Exercise Button
              IconButton(
                icon: const Icon(Icons.delete),
                padding: const EdgeInsets.all(8.0),
                onPressed: _isStarted ? null : () => _deleteExercise(context),
              ),

              // Edit Exercise Button
              IconButton(
                icon: const Icon(Icons.edit),
                padding: const EdgeInsets.all(8.0),
                onPressed: _isStarted ? null : () => _editExercise(context),
              ),
            ],
          ),
          body: _exercise!.schedule.isEmpty
              ? Center(child: Text(localizations.noRoundsScheduled))
              : _buildBody(event),
          floatingActionButton: ExerciseControlButton(
            exercise: _exercise!,
            service: _exerciseService,
            localizations: localizations,
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
          ...List<Widget>.generate(_exercise!.schedule.length, (roundIndex) {
            // Determine whether this round is completed or current
            return PhaseTile(
              title:
                  "${AppLocalizations.of(context)!.round(1)} "
                  "${roundIndex + 1}",
              event: event,
              exercise: _exercise!,
              roundIndex: roundIndex,
              isPortrait: isPortrait,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStationList(ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(localizations.stationRotations),
                    Text(
                      '${event.exercise.stations.length} '
                      '${localizations.station(event.exercise.stations.length).toLowerCase()}',
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 4.0),
          Expanded(
            child: ListView.builder(
              itemCount: _exercise!.stations.length,
              itemBuilder: (context, stationIndex) {
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 2,
                  ),
                  child: GestureDetector(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0).copyWith(left: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              '${localizations.station(1)} ${stationIndex + 1}',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: VerticalDividerWidget(),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              localizations.team(1),
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          ...List<Widget>.generate(_exercise!.schedule.length, (
                            roundIndex,
                          ) {
                            final isCurrent =
                                event.isRunning &&
                                roundIndex == event.currentRound;
                            final teamIndex =
                                _exercise!.teamIndex(stationIndex, roundIndex) +
                                1;
                            final none = teamIndex == 0;
                            return Container(
                              padding: EdgeInsets.all(4),
                              color: isCurrent
                                  ? none
                                        ? Colors.grey
                                        : Colors.blueAccent
                                  : Colors.transparent,
                              child: Text(
                                '${none ? '×' : teamIndex}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: isCurrent
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
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StationExerciseScreen(
                            stationIndex: stationIndex,
                            uuid: _exercise!.uuid,
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

  Widget _buildTeamList(ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(localizations.teamRotations),
                    Text(
                      '${event.exercise.numberOfTeams} '
                      '${localizations.team(event.exercise.numberOfTeams).toLowerCase()}',
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 4.0),
          Expanded(
            child: ListView.builder(
              // Limit teams to number of teams
              itemCount: event.exercise.numberOfTeams,
              itemBuilder: (context, teamIndex) {
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 2,
                  ),
                  child: GestureDetector(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0).copyWith(left: 16),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              '${localizations.team(1)} ${teamIndex + 1}',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: VerticalDividerWidget(),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              localizations.station(1),
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          ...List<Widget>.generate(_exercise!.schedule.length, (
                            roundIndex,
                          ) {
                            final isCurrent =
                                event.isRunning &&
                                roundIndex == event.currentRound;
                            return TeamStationWidget(
                              isCurrent: isCurrent,
                              exercise: _exercise!,
                              teamIndex: teamIndex,
                              roundIndex: roundIndex,
                            );
                          }),
                        ],
                      ),
                    ),
                    onTap: () {
                      // Navigate to SupervisorViewScreen, starting from the selected station
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TeamExerciseScreen(
                            teamIndex: teamIndex,
                            exercise: _exercise!,
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
    for (final it in _subscriptions) {
      it.cancel();
    }
    super.dispose();
  }
}
