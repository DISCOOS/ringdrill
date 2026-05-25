import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/phase_headers.dart';
import 'package:ringdrill/views/phase_tile.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';

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
                            // Pure Navigator.push on purpose: routing the
                            // station detail through `context.push` from
                            // here crosses GoRouter branches (`/teams/...`
                            // → `/program/<uuid>/station/...`), which in
                            // go_router 17 builds the new IRM with pages
                            // `[Shell, CoordinatorScreen, StationScreen]`
                            // and drops TeamScreen from the stack. Popping
                            // back across that branch boundary crashed the
                            // app on /teams/<i> — see "bak > bak" splash
                            // regression report. The detail screen does
                            // not need its own bookmarkable URL when
                            // reached from the team view; `/teams/<i>`
                            // itself remains a deep link.
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

class _ExerciseSection extends StatefulWidget {
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
  State<_ExerciseSection> createState() => _ExerciseSectionState();
}

class _ExerciseSectionState extends State<_ExerciseSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final exercise = widget.exercise;
    final event = widget.event;
    final isLive = widget.isLive;
    final teamIndex = widget.teamIndex;
    final onStationTap = widget.onStationTap;
    final roundCount = exercise.schedule.length;
    final accent = LiveAccent.of(context, isLive: isLive);
    final subtitle = [
      if (isLive) event.getState(localizations),
      '$roundCount ${localizations.round(roundCount).toLowerCase()}',
      '${exercise.startTime}–${exercise.endTime}',
    ].join(' · ');

    return ExpandableTile(
      accent: accent,
      leading: accent.indicator,
      title: Text(
        exercise.name,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: accent.foreground,
        ),
      ),
      subtitle: Text(subtitle, style: accent.textStyle),
      expanded: _expanded,
      // No onOpen: tapping the row toggles, matching the previous
      // ExpansionTile behaviour where the row itself was the expand
      // affordance.
      onToggle: _toggleExpanded,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
