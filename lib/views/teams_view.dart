import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/theme.dart' show kDrillAccentFontSize;
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/team_form_screen.dart';
import 'package:ringdrill/views/team_station_widget.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';

class TeamsView extends StatefulWidget {
  const TeamsView({super.key});

  @override
  State<TeamsView> createState() => _TeamsViewState();
}

class _TeamsViewState extends State<TeamsView> {
  final _programService = ProgramService();
  StreamSubscription<ProgramEvent>? _programSubscription;

  /// Which team row is currently expanded to its rotation peek. Single-open
  /// (mirrors the exercise list's expand mutex).
  int? _expandedTeamIndex;

  @override
  void initState() {
    super.initState();
    // Rebuild when the active program or its teams change. The parent
    // MainScreen keeps tabs alive in an IndexedStack with identical widget
    // instances, so its own setState does not propagate here. See
    // active_plan_actions.dart and ProgramService.setActive/installFromFile.
    _programSubscription = _programService.events.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _programSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final teams = _programService.loadTeams();
    final exercises = _programService.loadExercises();
    final targetNotifier = MasterDetailScope.maybeOf(context)?.target;

    Widget buildList(ContextSheetTarget? selectedTarget) {
      return ListView(
        children: teams.map((t) {
          final teamExercises = exercises
              .where((e) => e.numberOfTeams > t.index)
              .toList();
          final exerciseCount = teamExercises.length;
          final parts = <String>[
            if ((t.numberOfMembers ?? 0) > 0)
              '${t.numberOfMembers} '
                  '${localizations.member(t.numberOfMembers!).toLowerCase()}',
            '$exerciseCount '
                '${localizations.exercise(exerciseCount).toLowerCase()}',
          ];
          final isSelected =
              selectedTarget is TeamOverviewSheetTarget &&
              selectedTarget.teamIndex == t.index;
          final colorScheme = Theme.of(context).colorScheme;
          return Dismissible(
            key: ValueKey('team-row-${t.uuid}'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: colorScheme.secondaryContainer,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    localizations.editTeam,
                    style: TextStyle(color: colorScheme.onSecondaryContainer),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.edit, color: colorScheme.onSecondaryContainer),
                ],
              ),
            ),
            confirmDismiss: (_) async {
              await _openTeamForm(t);
              return false;
            },
            // Parity with Øvelser/Poster/Spill (DESIGN-006): the same
            // ExpandableTile shell instead of a taller Card+ListTile, so
            // height, padding and subtitle size match across all four
            // segments. Expands to a rotation peek; tap opens the overview.
            child: ExpandableTile(
              selected: isSelected,
              title: Text(
                t.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(parts.join(' · ')),
              onLongPress: () => _openTeamForm(t),
              // Expand shows a static rotation peek (which post per round, per
              // exercise). No body/chevron when the team is in no exercises.
              expanded: _expandedTeamIndex == t.index,
              onToggle: teamExercises.isEmpty
                  ? null
                  : () => setState(() {
                      _expandedTeamIndex = _expandedTeamIndex == t.index
                          ? null
                          : t.index;
                    }),
              body: teamExercises.isEmpty
                  ? null
                  : _buildTeamRotation(context, t, teamExercises, localizations),
              // Tap opens the cross-exercise team overview (TeamScreen). The
              // rotation is a per-exercise/player concept, so planning context
              // does not guess an exercise; TeamScreen highlights the live one
              // itself when an exercise is running.
              onOpen: () => ContextSheet.of(
                context,
              ).show(context, TeamOverviewSheetTarget(teamIndex: t.index)),
            ),
          );
        }).toList(),
      );
    }

    return Padding(
      // top: 11 + ExpandableTile.margin.top (5) = 16, matching the detail
      // body's `EdgeInsets.all(16)` so the first row of master and detail
      // align in the wide layout. Side/bottom padding stays at 8.
      padding: const EdgeInsets.fromLTRB(8, 11, 8, 8),
      child: targetNotifier == null
          ? buildList(null)
          : ValueListenableBuilder<ContextSheetTarget?>(
              valueListenable: targetNotifier,
              builder: (context, target, _) => buildList(target),
            ),
    );
  }

  /// Static rotation peek for the expanded Lag tile: one block per exercise
  /// the team is in, each showing which post the team visits per round
  /// (reusing [TeamStationWidget]). No live highlighting here — that belongs
  /// to the player; tapping the row opens the full [TeamScreen] overview.
  Widget _buildTeamRotation(
    BuildContext context,
    Team team,
    List<Exercise> teamExercises,
    AppLocalizations localizations,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    // Cards use the master-view (page) background so they read as recessed
    // panels: quiet when the tile is unselected, and popping against the bright
    // selected-tile background when a team is selected. ExpandableTile already
    // pads the body 16px and stretches it full width, so no extra horizontal
    // padding here — stretch makes each card span the full row.
    final blockColor = Theme.of(context).scaffoldBackgroundColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in teamExercises)
          Card(
            margin: const EdgeInsets.only(top: 8),
            color: blockColor,
            // antiAlias so the InkWell ripple/hover honours the rounded
            // corners, matching the exercise expandable tiles.
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              // Tapping a specific exercise is unambiguous, so open the team in
              // that exercise (the per-exercise player view) — unlike the row
              // tap, which opens the cross-exercise overview.
              onTap: () => ContextSheet.of(context).show(
                context,
                TeamSheetTarget(exerciseUuid: e.uuid, teamIndex: team.index),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Text(
                    e.name,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          localizations.station(1),
                          style: TextStyle(
                            fontSize: kDrillAccentFontSize,
                            color: muted,
                          ),
                        ),
                      ),
                      for (int r = 0; r < e.schedule.length; r++)
                        TeamStationWidget(
                          isCurrent: false,
                          exercise: e,
                          teamIndex: team.index,
                          roundIndex: r,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openTeamForm(Team team) async {
    final localizations = AppLocalizations.of(context)!;
    final exerciseService = ExerciseService();
    if (exerciseService.isStarted) {
      final exerciseName = exerciseService.last?.exercise.name;
      if (exerciseName != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.stopExerciseFirst(exerciseName)),
          ),
        );
      }
      return;
    }
    final updated = await openFormSurface<Team>(
      context,
      builder: (_) => TeamFormScreen(team: team),
    );
    if (!mounted || updated == null) return;
    await _programService.saveTeam(localizations, updated);
  }
}

class TeamsPageController extends ScreenController {
  const TeamsPageController() : super();
  @override
  String title(BuildContext context) {
    return AppLocalizations.of(context)!.teamsOverview;
  }
}
