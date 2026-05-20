import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final team = _programService.getTeam(widget.teamIndex);
    final exercises = _programService
        .loadExercises()
        .where((e) => e.numberOfTeams > widget.teamIndex)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(team?.name ?? '')),
      body: SafeArea(
        child: exercises.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    localizations.teamNoExercises,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : StreamBuilder<ExerciseEvent>(
                stream: ExerciseService().events,
                initialData: ExerciseService().last,
                builder: (context, asyncSnapshot) {
                  final live = asyncSnapshot.data;
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ListView.builder(
                      itemCount: exercises.length,
                      itemBuilder: (context, index) {
                        final exercise = exercises[index];
                        final isLive = live?.exercise.uuid == exercise.uuid;
                        final event = isLive
                            ? live!
                            : ExerciseEvent.pending(exercise);
                        return _ExerciseSection(
                          exercise: exercise,
                          event: event,
                          teamIndex: widget.teamIndex,
                          initiallyExpanded: isLive,
                          isLive: isLive,
                          onStationTap: (stationIndex) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StationExerciseScreen(
                                  stationIndex: stationIndex,
                                  uuid: exercise.uuid,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ExerciseSection extends StatelessWidget {
  const _ExerciseSection({
    required this.exercise,
    required this.event,
    required this.teamIndex,
    required this.initiallyExpanded,
    required this.isLive,
    required this.onStationTap,
  });

  final Exercise exercise;
  final ExerciseEvent event;
  final int teamIndex;
  final bool initiallyExpanded;
  final bool isLive;
  final ValueChanged<int> onStationTap;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final roundCount = exercise.schedule.length;
    final subtitle = [
      if (isLive) event.getState(localizations),
      '$roundCount ${localizations.round(roundCount).toLowerCase()}',
      '${exercise.startTime}–${exercise.endTime}',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      color: isLive ? colorScheme.primaryContainer : null,
      shape: isLive
          ? RoundedRectangleBorder(
              side: BorderSide(color: colorScheme.primary, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: isLive
            ? Icon(Icons.play_circle_fill, color: colorScheme.primary)
            : null,
        title: Text(
          exercise.name,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isLive ? colorScheme.onPrimaryContainer : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: isLive
              ? TextStyle(color: colorScheme.onPrimaryContainer)
              : null,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        children: [
          PhaseHeaders(
            expand: true,
            titleWidth: 78,
            title: localizations.schedule,
            mainAxisAlignment: MainAxisAlignment.start,
          ),
          const SizedBox(height: 4),
          ...List.generate(roundCount, (roundIndex) {
            final stationIndex = exercise.stationIndex(teamIndex, roundIndex);
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                onTap: () => onStationTap(stationIndex),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: PhaseTile(
                    title: exercise.stations[stationIndex].name,
                    event: event,
                    roundIndex: roundIndex,
                    exercise: exercise,
                    mainAxisAlignment: MainAxisAlignment.start,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
