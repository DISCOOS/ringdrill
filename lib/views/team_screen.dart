import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/station_state_widget.dart'
    show StationStateWidget;

class TeamScreen extends StatefulWidget {
  final int teamIndex;
  final Exercise exercise;

  const TeamScreen({
    super.key,
    required this.teamIndex,
    required this.exercise,
  });

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  int currentIndex = 0;

  @override
  void initState() {
    currentIndex = widget.teamIndex;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${AppLocalizations.of(context)!.team(1)} ${widget.teamIndex + 1}',
        ),
      ),
      body: StreamBuilder(
        stream: ExerciseService().events,
        initialData: _initialData(),
        builder: (context, asyncSnapshot) {
          final event = asyncSnapshot.data!;
          currentIndex = widget.exercise.stationIndex(
            widget.teamIndex,
            event.currentRound,
          );
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team Info
                _buildTeamStatus(event),
                const SizedBox(height: 8),

                // Schedule Details
                Expanded(child: _buildStationList(event)),
              ],
            ),
          );
        },
      ),
    );
  }

  ListView _buildStationList(ExerciseEvent event) {
    return ListView.builder(
      itemCount: widget.exercise.schedule.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: StationStateWidget(
              event: event,
              stationIndex: widget.exercise.stationIndex(
                widget.teamIndex,
                index,
              ),
              exercise: widget.exercise,
              roundIndex: index,
              mainAxisAlignment: MainAxisAlignment.start,
            ),
            onTap: () {
              // Navigate to SupervisorViewScreen, starting from the selected station
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => StationScreen(
                        stationIndex: index,
                        exercise: widget.exercise,
                      ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTeamStatus(ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    return ExerciseService().isStarted
        ? Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${widget.exercise.name} (${event.getState(localizations)})',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              event.isPending
                  ? DateTimeX.fromMinutes(
                    event.remainingTime,
                  ).formal(localizations)
                  : localizations.minute(event.remainingTime),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        )
        : Text(widget.exercise.name);
  }

  ExerciseEvent _initialData() {
    final last = ExerciseService().last;
    if (last?.exercise == widget.exercise) return last!;
    return ExerciseEvent.pending(widget.exercise);
  }
}
