import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/team_form_screen.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

class TeamsView extends StatefulWidget {
  const TeamsView({super.key});

  @override
  State<TeamsView> createState() => _TeamsViewState();
}

class _TeamsViewState extends State<TeamsView> {
  final _programService = ProgramService();
  StreamSubscription<ProgramEvent>? _programSubscription;

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
          final exerciseCount = exercises
              .where((e) => e.numberOfTeams > t.index)
              .length;
          final parts = <String>[
            if ((t.numberOfMembers ?? 0) > 0)
              '${t.numberOfMembers} '
                  '${localizations.member(t.numberOfMembers!).toLowerCase()}',
            '$exerciseCount '
                '${localizations.exercise(exerciseCount).toLowerCase()}',
          ];
          final isSelected =
              selectedTarget is TeamSheetTarget &&
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
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                selected: isSelected,
                title: Text(
                  t.name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(parts.join(' · ')),
                onLongPress: () => _openTeamForm(t),
                onTap: () {
                  final exercise = _programService
                      .loadExercises()
                      .where((e) => e.numberOfTeams > t.index)
                      .firstOrNull;
                  if (exercise == null) return;
                  ContextSheet.of(context).show(
                    context,
                    TeamSheetTarget(
                      exerciseUuid: exercise.uuid,
                      teamIndex: t.index,
                    ),
                  );
                },
              ),
            ),
          );
        }).toList(),
      );
    }

    return Padding(
      // top: 11 + Card.margin.top (4) = 15 ≈ 16, matching the detail body's
      // `EdgeInsets.all(16)` so the first row of master and detail align in
      // the wide layout. Side/bottom padding stays at 8.
      padding: const EdgeInsets.fromLTRB(8, 11, 8, 8),
      child: targetNotifier == null
          ? buildList(null)
          : ValueListenableBuilder<ContextSheetTarget?>(
              valueListenable: targetNotifier,
              builder: (context, target, _) => buildList(target),
            ),
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
