import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/team_screen.dart';

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
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ListView(
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
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(
                t.name,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(parts.join(' · ')),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TeamScreen(teamIndex: t.index),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class TeamsPageController extends ScreenController {
  const TeamsPageController() : super();
  @override
  String title(BuildContext context) {
    return AppLocalizations.of(context)!.teamsOverview;
  }
}
