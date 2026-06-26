import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/theme.dart'
    show kDrillAccentFontSize, RingDrillColors;
import 'package:ringdrill/views/phase_headers.dart';
import 'package:ringdrill/views/phase_tile.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/team_form_screen.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/live_accent.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';

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
    final teamLabel =
        team?.name ?? '${localizations.team(1)} ${widget.teamIndex + 1}';
    final exercises = _programService
        .loadExercises()
        .where((e) => e.numberOfTeams > widget.teamIndex)
        .toList();

    return Scaffold(
      // Sheet-body AppBar (matches TeamExerciseScreen/StationExerciseScreen):
      // close affordance + SheetTitle + edit, so TeamScreen renders cleanly as
      // a ContextSheet body, not just a standalone route.
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (MasterDetailScope.maybeOf(context) != null) {
              ContextSheet.of(context).close();
            } else {
              Navigator.pop(context);
            }
          },
          tooltip: localizations.briefClose,
        ),
        toolbarHeight: 72,
        title: SheetTitle(primary: teamLabel),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            padding: const EdgeInsets.all(8),
            onPressed: _editTeam,
            tooltip: localizations.editTeam,
          ),
        ],
        actionsPadding: const EdgeInsets.only(right: 16),
      ),
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
                        // A `done` event is treated as "not live" so a
                        // stopped exercise stops being painted with the
                        // blue accent. `ExerciseService.stop()` keeps
                        // `_last` around for diagnostics; views drop
                        // it here.
                        final isLive =
                            live?.exercise.uuid == exercise.uuid &&
                            live?.isDone != true;
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
                            ContextSheet.of(context).replace(
                              StationSheetTarget(
                                exerciseUuid: exercise.uuid,
                                stationIndex: stationIndex,
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

  Future<void> _editTeam() async {
    final localizations = AppLocalizations.of(context)!;
    final team = _programService.getTeam(widget.teamIndex);
    if (team == null) return;
    final updated = await openFormSurface<Team>(
      context,
      builder: (_) => TeamFormScreen(team: team),
    );
    if (!mounted || updated == null) return;
    await _programService.saveTeam(localizations, updated);
    if (mounted) setState(() {});
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
        // ADR-0037 drillAccent: match the player's accent tiles instead of 18.
        style: TextStyle(
          fontSize: kDrillAccentFontSize,
          fontWeight: FontWeight.bold,
          color: accent.foreground,
        ),
      ),
      subtitle: Text(subtitle, style: accent.textStyle),
      expanded: _expanded,
      // House rule (all ExpandableTiles): tap row opens sheet, chevron
      // is the only expand affordance. From the cross-exercise team
      // overview we drill into the team-in-this-exercise player view.
      onOpen: () => ContextSheet.of(context).show(
        context,
        TeamSheetTarget(exerciseUuid: exercise.uuid, teamIndex: teamIndex),
      ),
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
              // Match the exercise card's expanded station tiles: the darker
              // brandDeep surface in dark mode (surfaceContainerHigh in light)
              // rather than the default card colour.
              color: Theme.of(context).brightness == Brightness.dark
                  ? RingDrillColors.brandDeep
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
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
