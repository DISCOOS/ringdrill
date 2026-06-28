import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/drill_player/drill_mini_player.dart';
import 'package:ringdrill/views/phase_headers.dart';
import 'package:ringdrill/views/phase_tile.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/team_form_screen.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';

class TeamExerciseScreen extends StatefulWidget {
  const TeamExerciseScreen({
    super.key,
    required this.teamIndex,
    required this.exercise,
  });

  final int teamIndex;
  final Exercise exercise;

  @override
  State<TeamExerciseScreen> createState() => _TeamExerciseScreenState();
}

class _TeamExerciseScreenState extends State<TeamExerciseScreen> {
  final _exerciseService = ExerciseService();
  final _programService = ProgramService();

  int currentIndex = 0;

  @override
  void initState() {
    currentIndex = widget.teamIndex;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final team = _programService.getTeam(widget.teamIndex);
    final teamLabel =
        team?.name ?? '${localizations.team(1)} ${widget.teamIndex + 1}';
    return Scaffold(
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
        title: SheetTitle(primary: teamLabel, secondary: widget.exercise.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            padding: const EdgeInsets.all(8),
            onPressed: _exerciseService.isStarted ? null : _editTeam,
            tooltip: _exerciseService.isStarted
                ? localizations.stopExerciseFirst(widget.exercise.name)
                : localizations.editTeam,
          ),
        ],
        actionsPadding: const EdgeInsets.only(right: 16),
      ),
      body: SafeArea(
        child: StreamBuilder(
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
      // Mirror the CoordinatorScreen pattern: dock a DrillMiniPlayer for
      // the parent exercise so the user can start it from the team view
      // (modal context sheet in narrow). In master-detail (wide) the
      // docked bar lives in the master column instead.
      bottomNavigationBar: MasterDetailScope.maybeOf(context) == null
          ? DrillMiniPlayer(
              exercise: widget.exercise,
              height: 64,
              applyBottomInset: true,
              onOpen: () {},
              onPlay: () {
                unawaited(HapticFeedback.mediumImpact());
                _exerciseService.start(widget.exercise);
              },
            )
          : null,
    );
  }

  Widget _buildTeamStatus(ExerciseEvent event) {
    final localizations = AppLocalizations.of(context)!;
    // The team label lives in the sheet's AppBar (`SheetTitle.primary`),
    // so this status row only carries running-state info. When the
    // exercise has not started yet there is nothing to report and the
    // row collapses to `SizedBox.shrink`.
    if (!ExerciseService().isStarted) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          event.getState(localizations),
          // ADR-0037: themed titleLarge (20) instead of a hardcoded 24.
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          event.isPending
              ? DateTimeX.fromMinutes(event.remainingTime).formal(localizations)
              : localizations.minute(event.remainingTime),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  ListView _buildStationList(ExerciseEvent event) {
    return ListView.builder(
      itemCount: widget.exercise.schedule.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: GestureDetector(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: PhaseTile(
                title: widget
                    .exercise
                    .stations[widget.exercise.stationIndex(
                      widget.teamIndex,
                      index,
                    )]
                    .name,
                event: event,
                roundIndex: index,
                exercise: widget.exercise,
                mainAxisAlignment: MainAxisAlignment.start,
              ),
            ),
            onTap: () {
              ContextSheet.of(context).replace(
                StationSheetTarget(
                  exerciseUuid: widget.exercise.uuid,
                  stationIndex: widget.exercise.stationIndex(
                    widget.teamIndex,
                    index,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  ExerciseEvent _initialData() {
    final last = ExerciseService().last;
    // Match the live exercise by `uuid`, not by full-object equality.
    // The `Exercise` held by the service is captured at `start()` time
    // and can differ field-for-field from the freshly-loaded instance
    // passed to this screen, so value equality misses the live event and
    // the status only corrects itself once the next stream event lands.
    // A `done` event is treated as "not live" so a stopped exercise
    // starts from `pending`, matching `TeamScreen`.
    if (last != null &&
        last.exercise.uuid == widget.exercise.uuid &&
        !last.isDone) {
      return last;
    }
    return ExerciseEvent.pending(widget.exercise);
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
