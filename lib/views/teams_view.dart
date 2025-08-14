import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/team_screen.dart';
import 'package:ringdrill/views/vertical_divider_widget.dart';

class TeamsView extends StatefulWidget {
  const TeamsView({super.key});

  @override
  State<TeamsView> createState() => _TeamsViewState();
}

class _TeamsViewState extends State<TeamsView> {
  final _programService = ProgramService();

  @override
  Widget build(BuildContext context) {
    final teams = _programService.loadTeams();
    final exercises = _programService.loadExercises();
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ListView(
        children: teams.map((t) {
          final actual = exercises
              .where((e) => e.numberOfTeams > t.index)
              .toList();
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              title: Text(
                t.name,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: Row(
                children: List.generate(actual.length, (index) {
                  return Row(
                    children: [
                      Text(actual[index].name),
                      if (index < actual.length - 1)
                        VerticalDividerWidget(width: 16),
                    ],
                  );
                }),
              ),
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
    return AppLocalizations.of(context)!.team(2);
  }
}
