// Generates assets/example/onboarding-example.nb.drill and
// assets/example/onboarding-example.en.drill for the DESIGN-007 stage 3
// onboarding flow. Run from the repo root:
//
//   dart run tools/generate_example_drills.dart
//
// The output is deterministic (fixed UUIDs, fixed timestamps) so regenerating
// produces no git churn unless the content or schema changes.
import 'dart:io';

import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';

SimpleTimeOfDay _tod(int totalMin) =>
    SimpleTimeOfDay(hour: (totalMin ~/ 60) % 24, minute: totalMin % 60);

List<List<SimpleTimeOfDay>> _schedule(
  int startMin,
  int rounds,
  int exec,
  int eval,
  int rot,
) {
  final cycle = exec + eval + rot;
  return [
    for (var i = 0; i < rounds; i++)
      [
        _tod(startMin + i * cycle),
        _tod(startMin + i * cycle + exec),
        _tod(startMin + i * cycle + exec + eval),
      ],
  ];
}

Program _buildPlan({
  required String uuid,
  required String name,
  required String description,
  required String briefIntro,
  required String ex1Name,
  required List<Station> ex1Stations,
  required String ex2Name,
  required List<Station> ex2Stations,
  required List<String> teamNames,
  required String rp1Name,
  required String rp1Background,
  required String rp1Behavior,
  required String rp2Name,
  required String rp2Background,
  required String rp2Behavior,
}) {
  final created = DateTime.utc(2026, 1, 1);
  final ex1Uuid = '$uuid-ex1';
  final ex2Uuid = '$uuid-ex2';

  // Exercise 1: intro, 2 teams, 1 round, 09:00, exec=20, eval=10, rot=2
  const ex1Start = 9 * 60;
  const ex1Exec = 20, ex1Eval = 10, ex1Rot = 2, ex1Rounds = 1;
  final ex1 = Exercise(
    uuid: ex1Uuid,
    index: 0,
    name: ex1Name,
    startTime: _tod(ex1Start),
    numberOfTeams: 2,
    numberOfRounds: ex1Rounds,
    executionTime: ex1Exec,
    evaluationTime: ex1Eval,
    rotationTime: ex1Rot,
    stations: ex1Stations,
    schedule: _schedule(ex1Start, ex1Rounds, ex1Exec, ex1Eval, ex1Rot),
    endTime: _tod(ex1Start + ex1Rounds * (ex1Exec + ex1Eval + ex1Rot)),
  );

  // Exercise 2: three-station rotation, 3 teams, 2 rounds, 09:35, exec=15, eval=5, rot=2
  // index=1 → exerciseNumber=2 → stations labelled 2a/2b/2c (alpha format)
  const ex2Start = 9 * 60 + 35;
  const ex2Exec = 15, ex2Eval = 5, ex2Rot = 2, ex2Rounds = 2;
  final ex2 = Exercise(
    uuid: ex2Uuid,
    index: 1,
    name: ex2Name,
    startTime: _tod(ex2Start),
    numberOfTeams: 3,
    numberOfRounds: ex2Rounds,
    executionTime: ex2Exec,
    evaluationTime: ex2Eval,
    rotationTime: ex2Rot,
    stations: ex2Stations,
    schedule: _schedule(ex2Start, ex2Rounds, ex2Exec, ex2Eval, ex2Rot),
    endTime: _tod(ex2Start + ex2Rounds * (ex2Exec + ex2Eval + ex2Rot)),
  );

  final teams = [
    for (var i = 0; i < teamNames.length; i++)
      Team(uuid: '$uuid-team-$i', index: i, name: teamNames[i]),
  ];

  final rolePlays = [
    RolePlay(
      uuid: '$uuid-rp1',
      index: 0,
      exerciseUuid: ex2Uuid,
      name: rp1Name,
      stationIndex: 0,
      background: rp1Background,
      behavior: rp1Behavior,
    ),
    RolePlay(
      uuid: '$uuid-rp2',
      index: 1,
      exerciseUuid: ex2Uuid,
      name: rp2Name,
      stationIndex: 1,
      background: rp2Background,
      behavior: rp2Behavior,
    ),
  ];

  return Program(
    uuid: uuid,
    name: name,
    description: description,
    stationNumberFormat: StationNumberFormat.alpha,
    metadata: ProgramMetadata(
      created: created,
      updated: created,
      version: '1.1',
      schema: DrillFile.drillSchemaCurrent,
    ),
    source: const ProgramSource.local(),
    teams: teams,
    sessions: const [],
    exercises: [ex1, ex2],
    rolePlays: rolePlays,
    actors: const [],
    briefIntroMd: briefIntro,
  );
}

void main() {
  final nb = _buildPlan(
    uuid: 'onboarding-nb-v1',
    name: 'Eksempelplan – RingDrill',
    description: 'Et lite eksempel med to øvelser for å vise hvordan RingDrill fungerer.',
    briefIntro:
        '# Eksempelplan\n\n'
        'Velkommen til RingDrill! Denne planen viser det grunnleggende: '
        'lag roterer gjennom poster én runde om gangen.\n\n'
        '**Øvelse 1** er en kort oppstart. '
        '**Øvelse 2** er en ringøvelse der tre lag roterer mellom tre poster.\n',
    ex1Name: 'Oppstart og brief',
    ex1Stations: const [
      Station(index: 0, name: 'IPP', description: 'Innsatsleders kommandoplass.'),
      Station(index: 1, name: 'Kommandoplass', description: 'Ressurskoordinator holder oversikten over søkslagene.'),
    ],
    ex2Name: 'Søk og rotasjon (ringøvelse)',
    ex2Stations: const [
      Station(index: 0, name: 'Sporutgang fra IPP', description: 'Hundeekvipasje tar sporutgang fra siste kjente posisjon.'),
      Station(index: 1, name: 'Nærområdesøk', description: 'Raskt grovsøk i nærområdet innenfor R25.'),
      Station(index: 2, name: 'Søk langs ledelinje', description: 'To mann langs sti mot R50. Meld funn og POI på samband.'),
    ],
    teamNames: ['Lag 1', 'Lag 2', 'Lag 3'],
    rp1Name: 'Savnet person',
    rp1Background: 'Borte fra hytte siden i går kveld. Spor funnet ved elv.',
    rp1Behavior: 'Bevisst, forvirret, hypotermisk. Svarer på tiltale men orienterer seg ikke.',
    rp2Name: 'Vitne',
    rp2Background: 'Siste person som så den savnede. Kan peke ut retning.',
    rp2Behavior: 'Samarbeidsvillig og bekymret. Gi retningsanvisning og beskriv bekledning.',
  );

  final en = _buildPlan(
    uuid: 'onboarding-en-v1',
    name: 'Example plan – RingDrill',
    description: 'A small example with two exercises showing how RingDrill works.',
    briefIntro:
        '# Example plan\n\n'
        'Welcome to RingDrill! This plan shows the core concept: '
        'teams rotate through stations, one round at a time.\n\n'
        '**Exercise 1** is a short opening brief. '
        '**Exercise 2** is a ring drill where three teams rotate between three stations.\n',
    ex1Name: 'Opening and brief',
    ex1Stations: const [
      Station(index: 0, name: 'IPP', description: 'Incident command point.'),
      Station(index: 1, name: 'Command post', description: 'Resource coordinator keeps overview of search teams.'),
    ],
    ex2Name: 'Search and rotation (ring drill)',
    ex2Stations: const [
      Station(index: 0, name: 'Track start from IPP', description: 'Dog team takes the track start from last known position.'),
      Station(index: 1, name: 'Hasty area search', description: 'Quick hasty search of the immediate area within the 25% ring.'),
      Station(index: 2, name: 'Linear feature search', description: 'Two searchers along the trail toward the 50% ring. Report finds by radio.'),
    ],
    teamNames: ['Team 1', 'Team 2', 'Team 3'],
    rp1Name: 'Missing person',
    rp1Background: 'Missing from cabin since yesterday evening. Tracks found near the river.',
    rp1Behavior: 'Conscious but confused, hypothermic. Responds to voice but cannot self-orient.',
    rp2Name: 'Witness',
    rp2Background: 'Last person to see the missing person. Can indicate direction of travel.',
    rp2Behavior: 'Cooperative and concerned. Give direction and describe clothing.',
  );

  final outDir = Directory('assets/example');
  outDir.createSync(recursive: true);

  final nbDrill = DrillFile.fromProgram(nb, 'onboarding-example.nb');
  File('assets/example/onboarding-example.nb.drill')
      .writeAsBytesSync(nbDrill.content);

  final enDrill = DrillFile.fromProgram(en, 'onboarding-example.en');
  File('assets/example/onboarding-example.en.drill')
      .writeAsBytesSync(enDrill.content);

  stdout.writeln('Wrote assets/example/onboarding-example.nb.drill');
  stdout.writeln('Wrote assets/example/onboarding-example.en.drill');
}
