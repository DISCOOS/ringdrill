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

// Station content and coordinates are lifted from the screenshot demo
// generator (tools/screenshots/make_demo_drills.py): real search methods and
// terminology from the HRS guide "Søk etter savnet på land", clustered around
// Tjøme/Eidene so the Map tab is populated. Helper takes (lng, lat) like the
// demo's GeoJSON; LatLng wants (lat, lng).
Station _st(int index, String name, double lng, double lat, String description) =>
    Station(index: index, name: name, position: LatLng(lat, lng), description: description);

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
  required String ex1RpBehavior,
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
      stationIndex: 1,
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
        'Innholdet bygger på Hovedredningssentralens veileder «Søk etter '
        'savnet på land». **Øvelse 1 – Førsteinnsats søk** øver søksmetodene '
        'etter sykkelhjulmodellen. **Øvelse 2 – Søk langs linjer** er '
        'ringøvelsen der tre lag roterer mellom tre poster i to runder.\n',
    ex1Name: 'Førsteinnsats søk (ringøvelse)',
    ex1Stations: [
      _st(0, 'Sporutgang fra IPP', 10.4019, 59.0999, 'Hundeekvipasje tar sporutgang fra IPP. Grovsøk langs ferskeste spor.'),
      _st(1, 'Nærområdesøk', 10.4043, 59.0981, 'Raskt nærområdesøk rundt IPP innenfor R25. Grovsøk, prioriter hurtighet.'),
      _st(2, 'Søk langs ledelinje', 10.4043, 59.0988, '1–3 personer langs sti mot R50. Høy POD. Meld funn og POI på samband.'),
      _st(3, 'Sperrepost ved knutepunkt', 10.4038, 59.0998, 'Områdebegrensning: hindre at savnede passerer veikrysset.'),
    ],
    ex2Name: 'Søk langs linjer (ringøvelse)',
    ex2Stations: [
      _st(0, 'Ledelinjesøk langs sti', 10.4012, 59.0995, '1–2 personer langs sti mot R50. Svært høy POD. Meld funn på samband.'),
      _st(1, 'Ledelinjesøk langs vei', 10.4031, 59.0972, 'Følg skogsbilvei ut fra IPP. Jevn fart, dekk begge sider.'),
      _st(2, 'Punktsøk POI', 10.4156, 59.0724, 'Sjekk POI langs ledelinjene – refleksene i sykkelhjulmodellen.'),
    ],
    teamNames: ['Lag 1', 'Lag 2', 'Lag 3'],
    ex1RpName: 'Savnet person',
    ex1RpBackground: 'Borte fra hytta siden i går kveld. Funnet under nærområdesøk innenfor R25.',
    ex1RpBehavior: 'Bevisst, forvirret, lett nedkjølt. Svarer på tiltale, men orienterer seg ikke.',
    rp1Name: 'Vitne',
    rp1Background: 'Turgåer som så den savnede langs stien tidligere på dagen.',
    rp1Behavior: 'Samarbeidsvillig. Peker ut retning og beskriver bekledning.',
    rp2Name: 'Savnet person',
    rp2Background: 'Sett sist langs stien mot R50. Ligger i tilknytning til en POI.',
    rp2Behavior: 'Sittende, utmattet. Vinker når søkslaget nærmer seg.',
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
        'The content is based on the Norwegian HRS guide for searching for '
        'missing persons on land. **Exercise 1 – Initial search response** '
        'drills the search methods of the spokes-and-hub model. '
        '**Exercise 2 – Linear search** is the ring drill where three teams '
        'rotate between three stations across two rounds.\n',
    ex1Name: 'Initial search response (ring drill)',
    ex1Stations: [
      _st(0, 'Track start from IPP', 10.4019, 59.0999, 'Dog team takes the track start from the IPP. Hasty search along the freshest track.'),
      _st(1, 'Hasty area search', 10.4043, 59.0981, 'Quick hasty search around the IPP within the 25% ring. Prioritize speed.'),
      _st(2, 'Linear feature search', 10.4043, 59.0988, '1–3 searchers along the trail toward the 50% ring. High detection probability; report finds and POIs by radio.'),
      _st(3, 'Containment point', 10.4038, 59.0998, 'Area containment: stop the missing person from passing the road junction.'),
    ],
    ex2Name: 'Linear search (ring drill)',
    ex2Stations: [
      _st(0, 'Leading-line search (trail)', 10.4012, 59.0995, '1–2 searchers along the trail toward the 50% ring. Very high detection probability.'),
      _st(1, 'Leading-line search (road)', 10.4031, 59.0972, 'Follow the forest road out from the IPP, covering both sides.'),
      _st(2, 'Point search (POI)', 10.4156, 59.0724, "Check the POIs along the leading lines – the spokes-and-hub model's points of interest."),
    ],
    teamNames: ['Team 1', 'Team 2', 'Team 3'],
    ex1RpName: 'Missing person',
    ex1RpBackground: 'Missing from the cabin since yesterday evening. Found during the hasty area search within the 25% ring.',
    ex1RpBehavior: 'Conscious but confused, mildly hypothermic. Responds to voice but cannot self-orient.',
    rp1Name: 'Witness',
    rp1Background: 'A hiker who saw the missing person along the trail earlier in the day.',
    rp1Behavior: 'Cooperative. Points out the direction and describes the clothing.',
    rp2Name: 'Missing person',
    rp2Background: 'Last seen along the trail toward the 50% ring. Lying near a POI.',
    rp2Behavior: 'Seated, exhausted. Waves when the search team approaches.',
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
