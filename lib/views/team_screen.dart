import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/phase_headers.dart';
import 'package:ringdrill/views/phase_tile.dart';
import 'package:ringdrill/views/station_screen.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key, required this.teamIndex});

  final int teamIndex;

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final ProgramService _programService = ProgramService();
  int currentIndex = 0;

  @override
  void initState() {
    currentIndex = widget.teamIndex;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final team = _programService.getTeam(widget.teamIndex);

    return Scaffold(
      appBar: AppBar(title: Text(team!.name)),
      body: SafeArea(
        child: StreamBuilder(
          stream: ExerciseService().events,
          initialData: ExerciseService().last,
          builder: (context, asyncSnapshot) {
            final event = asyncSnapshot.data;
            currentIndex = asyncSnapshot.hasData
                ? event!.exercise.stationIndex(
                    widget.teamIndex,
                    event.currentRound,
                  )
                : 0;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team Info
                  _buildTeamStatus(event),
                  const SizedBox(height: 8),
                  // Schedule Details
                  PhaseHeaders(
                    expand: true,
                    titleWidth: 78,
                    title: AppLocalizations.of(context)!.schedule,
                    mainAxisAlignment: MainAxisAlignment.start,
                  ),
                  const SizedBox(height: 4),
                  Expanded(child: _buildStationList(event)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTeamStatus(ExerciseEvent? event) {
    final name =
        '${AppLocalizations.of(context)!.team(1)} ${widget.teamIndex + 1}';
    final localizations = AppLocalizations.of(context)!;
    return ExerciseService().isStarted
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                event == null
                    ? name
                    : '$name (${event.getState(localizations)})',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (event != null)
                Text(
                  event.isPending
                      ? DateTimeX.fromMinutes(
                          event.remainingTime,
                        ).formal(localizations)
                      : localizations.minute(event.remainingTime),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          )
        : Text(
            name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          );
  }

  ListView _buildStationList(ExerciseEvent? event) {
    return ListView.builder(
      itemCount: event?.exercise.schedule.length ?? 0,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: GestureDetector(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: PhaseTile(
                title: event!
                    .exercise
                    .stations[event.exercise.stationIndex(
                      widget.teamIndex,
                      index,
                    )]
                    .name,
                event: event,
                roundIndex: index,
                exercise: event.exercise,
                mainAxisAlignment: MainAxisAlignment.start,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StationExerciseScreen(
                    stationIndex: index,
                    uuid: event.exercise.uuid,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
