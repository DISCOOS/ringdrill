// Generates assets/example/onboarding-example.nb.drill and
// assets/example/onboarding-example.en.drill for the DESIGN-007 stage 3
// onboarding flow. Run from the repo root:
//
//   dart run tools/generate_example_drills.dart
//
// The output is deterministic (fixed UUIDs, fixed timestamps) so regenerating
// produces no git churn unless the content or schema changes.
import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';

SimpleTimeOfDay _tod(int totalMin) =>
    SimpleTimeOfDay(hour: (totalMin ~/ 60) % 24, minute: totalMin % 60);

// Station content, coordinates and descriptions are lifted verbatim from the
// real exercise plan in test/fixtures/test-7x.drill — onboarding exercise 2
// from that plan's exercise #2 (Eidene), onboarding exercise 1 from its
// exercise #5 (Lindhøy). Only the "Nx) " label prefix is stripped from the
// station names, since the app now renders that badge itself from the alpha
// numbering format. Helper takes (lng, lat) like the GeoJSON in the fixture;
// LatLng wants (lat, lng). Pass null coords for a station with no position.
Station _st(int index, String name, double? lng, double? lat, String description) =>
    Station(
      index: index,
      name: name,
      position: (lng != null && lat != null) ? LatLng(lat, lng) : null,
      description: description,
    );

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
  required String ex1RpName,
  required String ex1RpBackground,
  String? ex1RpBehavior,
  required String rp1Name,
  required String rp1Background,
  String? rp1Behavior,
  required String rp2Name,
  required String rp2Background,
  String? rp2Behavior,
}) {
  final created = DateTime.utc(2026, 1, 1);
  final ex1Uuid = '$uuid-ex1';
  final ex2Uuid = '$uuid-ex2';

  // Exercise 1: first response, 3 teams, 2 rounds, 09:00, exec=15, eval=5, rot=2.
  // index=0 → exerciseNumber=1 → stations labelled 1a/1b/1c (alpha format).
  const ex1Start = 9 * 60;
  const ex1Exec = 15, ex1Eval = 5, ex1Rot = 2, ex1Rounds = 2;
  final ex1 = Exercise(
    uuid: ex1Uuid,
    index: 0,
    name: ex1Name,
    startTime: _tod(ex1Start),
    numberOfTeams: 3,
    numberOfRounds: ex1Rounds,
    executionTime: ex1Exec,
    evaluationTime: ex1Eval,
    rotationTime: ex1Rot,
    stations: ex1Stations,
    schedule: _schedule(ex1Start, ex1Rounds, ex1Exec, ex1Eval, ex1Rot),
    endTime: _tod(ex1Start + ex1Rounds * (ex1Exec + ex1Eval + ex1Rot)),
  );

  // Exercise 2: three-station rotation, 3 teams, 2 rounds, 09:50, exec=15, eval=5, rot=2
  // index=1 → exerciseNumber=2 → stations labelled 2a/2b/2c (alpha format)
  const ex2Start = 9 * 60 + 50;
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
      uuid: '$uuid-ex1-rp1',
      index: 0,
      exerciseUuid: ex1Uuid,
      name: ex1RpName,
      stationIndex: 0,
      background: ex1RpBackground,
      behavior: ex1RpBehavior,
    ),
    RolePlay(
      uuid: '$uuid-rp1',
      index: 1,
      exerciseUuid: ex2Uuid,
      name: rp1Name,
      stationIndex: 0,
      background: rp1Background,
      behavior: rp1Behavior,
    ),
    RolePlay(
      uuid: '$uuid-rp2',
      index: 2,
      exerciseUuid: ex2Uuid,
      name: rp2Name,
      stationIndex: 2,
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
        'lag roterer gjennom poster én runde om gangen, og rykker videre '
        'samtidig når runden er over.\n\n'
        'Innholdet er hentet fra en reell øvingsplan for søk etter savnet på '
        'land. **Øvelse 1** er et områdesøk ved Lindhøy. **Øvelse 2** er '
        'førsteinnsats ved Eidene, der tre lag roterer mellom postene.\n',
    ex1Name: 'Områdesøk – Lindhøy (ringøvelse)',
    ex1Stations: [
      _st(0, 'Barn 10-12 år', 10.404133, 59.109755, 'Lindhøy. Tiril Thorsen (15) – avsøk areal, savnede unnviker søk. Sist sett 32V 0580410E 6553119N. KO på parkering ved Lindhøy Skole. Markører: Lisa Davidsen, Ingrid Ellingsen.'),
      _st(1, 'Ruspåvirket', null, null, 'Lindhøy. Tone Antonsen (51) – finsøk uten funn, skrive søksrapport. Ingen markør. Avslutt søk 5 min før øving slutt.'),
      _st(2, 'Forlatt kjøretøy', null, null, 'Lindhøy. Tre biler: EK35989 (Nissan Leaf, sølvgrå), SV41219 (VW G..), m.fl. Søk og rapportér posisjon. Ingen markør.'),
    ],
    ex2Name: 'Førsteinnsats søk – Eidene (ringøvelse)',
    ex2Stations: [
      _st(0, 'Fisker', 10.402513, 59.09789, 'Eidene. Kari Fiskeløs – finsøk rundt IPP innenfor R25. Post 32V 0580345E 6551796N.'),
      _st(1, 'Bilcamping', 10.404234, 59.09814, 'Eidene. Hermod Hess (tysk) – finsøk fra bobil ut til R25. Post 32V 0580443E 6551826N.'),
      _st(2, 'Løper', 10.40428, 59.098841, 'Eidene. Ine Vigerdal (42) – søk treningsløype. Post 32V 0580444E 6551904N (start på løpeløype).'),
    ],
    teamNames: ['Lag 1', 'Lag 2', 'Lag 3'],
    ex1RpName: 'Barn 10-12 år',
    ex1RpBackground: 'Tiril Thorsen (15). Avsøk areal; savnede unnviker søk aktivt. KO ved Lindhøy Skole.',
    rp1Name: 'Fisker',
    rp1Background: 'Kari Fiskeløs. Finsøk rundt IPP innenfor R25.',
    rp2Name: 'Løper',
    rp2Background: 'Ine Vigerdal (42). Søk langs treningsløype fra start.',
  );

  final en = _buildPlan(
    uuid: 'onboarding-en-v1',
    name: 'Example plan – RingDrill',
    description: 'A small example with two exercises showing how RingDrill works.',
    briefIntro:
        '# Example plan\n\n'
        'Welcome to RingDrill! This plan shows the core concept: '
        'teams rotate through stations one round at a time, and all advance '
        'together when the round ends.\n\n'
        'The content is taken from a real land-search training plan. '
        '**Exercise 1** is an area search at Lindhøy. **Exercise 2** is the '
        'initial response at Eidene, where three teams rotate between the '
        'stations.\n',
    ex1Name: 'Area search – Lindhøy (ring drill)',
    ex1Stations: [
      _st(0, 'Child 10-12 yrs', 10.404133, 59.109755, 'Lindhøy. Tiril Thorsen (15) – area search; the subject evades searchers. Last seen 32V 0580410E 6553119N. CP at the Lindhøy School car park. Markers: Lisa Davidsen, Ingrid Ellingsen.'),
      _st(1, 'Intoxicated', null, null, 'Lindhøy. Tone Antonsen (51) – fine search with no find; write a search report. No marker. End the search 5 min before the exercise ends.'),
      _st(2, 'Abandoned vehicle', null, null, 'Lindhøy. Three cars: EK35989 (Nissan Leaf, silver-grey), SV41219 (VW G..), and more. Search and report position. No marker.'),
    ],
    ex2Name: 'Initial search response – Eidene (ring drill)',
    ex2Stations: [
      _st(0, 'Angler', 10.402513, 59.09789, 'Eidene. Kari Fiskeløs – fine search around the IPP within the 25% ring. Point 32V 0580345E 6551796N.'),
      _st(1, 'Car camping', 10.404234, 59.09814, 'Eidene. Hermod Hess (German) – fine search from the camper out to the 25% ring. Point 32V 0580443E 6551826N.'),
      _st(2, 'Runner', 10.40428, 59.098841, 'Eidene. Ine Vigerdal (42) – search the running trail. Point 32V 0580444E 6551904N (start of the trail).'),
    ],
    teamNames: ['Team 1', 'Team 2', 'Team 3'],
    ex1RpName: 'Child 10-12 yrs',
    ex1RpBackground: 'Tiril Thorsen (15). Area search; the subject actively evades searchers. CP at the Lindhøy School.',
    rp1Name: 'Angler',
    rp1Background: 'Kari Fiskeløs. Fine search around the IPP within the 25% ring.',
    rp2Name: 'Runner',
    rp2Background: 'Ine Vigerdal (42). Search the running trail from the start.',
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
