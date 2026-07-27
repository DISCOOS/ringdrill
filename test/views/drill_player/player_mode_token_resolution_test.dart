import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/data/plan_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/models/team.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/drill_player/drill_player_coordinator.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every player mode must resolve the token cascade, not print it.
///
/// Reported against station mode: the Postbeskrivelse card rendered
/// `{{station.position}}`, `{{exercise.phaseBreakdown}}` and `{{var.tidspunkt}}`
/// verbatim. The cause was not a missing station or exercise scope — those
/// screens seed their own — but a missing **PlanScope**: `RingDrillText` returns
/// its text untouched when there is no scope at all, so one absent scope
/// silences the whole cascade. The player renders its body on a modal route, a
/// sibling of `MainScreen` rather than a descendant, and unlike
/// `showRingdrillViewerSheet` it never seeded one. It looked fine only while the
/// player's sole body was `CoordinatorScreen`, which happens to seed a scope
/// itself.
///
/// So each mode is asserted twice over: no literal `{{` anywhere, *and* the
/// resolved values are present. The first alone would pass on a screen that
/// dropped the text entirely.
const _planUuid = 'prog-token-modes';
const _exerciseUuid = 'ex-token-modes';
const _roleUuid = 'role-token-modes';

const _hjem = Location(
  slug: 'hjem',
  label: 'Bosted',
  kind: LocationKind.home,
  position: LatLng(59.92, 10.76),
);

const _hanne = Person(
  slug: 'hanne',
  name: 'Hanne Hovden',
  age: 34,
  gender: 'woman',
  locSlug: 'hjem',
);

/// Tokens spanning all four levels a station surface can reach: its own facets,
/// its scenario data, the parent exercise, the plan, and a declared variable.
const _stationDescription =
    'Post {{station.name}} i {{plan.name}}. '
    'Runder: {{exercise.numberOfRounds}}. '
    '{{station.person.hanne}} sist sett på {{station.loc.hjem}} '
    'kl {{var.tidspunkt}}.';

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  index: 0,
  // Tokenised on purpose: the exercise *name* is the only token-aware field a
  // team surface renders (SheetTitle.secondary), so without this the team-mode
  // assertion below would be vacuous — it would pass with the fix reverted.
  name: 'Øvelse kl {{var.tidspunkt}}',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 2,
  numberOfRounds: 6,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [
    Station(
      index: 0,
      name: 'Fisker',
      description: _stationDescription,
      persons: [_hanne],
      locations: [_hjem],
      position: LatLng(59.92, 10.76),
    ),
    Station(index: 1, name: 'Turgåer'),
  ],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 8, minute: 0),
      SimpleTimeOfDay(hour: 8, minute: 10),
      SimpleTimeOfDay(hour: 8, minute: 15),
    ],
  ],
  endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
);

/// Roleplay copy reaching its own facets, the linked station's, the exercise's,
/// the plan's and a variable — the deepest cascade in the app.
RolePlay _rolePlay() => const RolePlay(
  uuid: _roleUuid,
  index: 0,
  exerciseUuid: _exerciseUuid,
  stationIndex: 0,
  name: 'Kari',
  behavior:
      'Rolig. {{roleplay.name}} ved {{station.name}} i {{plan.name}}, '
      '{{exercise.numberOfRounds}} runder, kl {{var.tidspunkt}}.',
);

Plan _shell() {
  final now = DateTime.utc(2026, 1, 1);
  return Plan(
    uuid: _planUuid,
    name: 'Ringøvelse',
    description: '',
    metadata: PlanMetadata(created: now, updated: now, version: '1.1'),
    variables: const [DrillVariable(name: 'tidspunkt', value: '14:30')],
    teams: const [
      Team(uuid: 'team-a', index: 0, name: 'Lag 1'),
      Team(uuid: 'team-b', index: 1, name: 'Lag 2'),
    ],
    sessions: const [],
    exercises: const [],
    rolePlays: const [],
    actors: const [],
  );
}

Future<void> _seedAndInit() async {
  SharedPreferences.setMockInitialValues({});
  PlanService().reset();
  final prefs = await SharedPreferences.getInstance();
  final repo = PlanRepository(prefs);
  await repo.savePlanShell(_shell());
  await repo.setActivePlanUuid(_planUuid);
  await repo.saveExercise(_exercise());
  await repo.saveRolePlay(_rolePlay());
  for (final team in _shell().teams) {
    await repo.saveTeam(team);
  }
  await PlanService().init();
}

/// Opens the player at [target] through the real entry point — the modal route
/// is the whole point, so a bare screen harness would not reproduce this.
Future<void> _openPlayer(WidgetTester tester, ContextSheetTarget target) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => DrillPlayerCoordinator().openDrillPlayer(
                context,
                target: target,
              ),
              child: const Text('open player'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open player'));
  await tester.pumpAndSettle();
}

/// No token may survive unresolved anywhere on screen.
void _expectNoLiteralTokens() {
  expect(
    find.textContaining('{{'),
    findsNothing,
    reason: 'a literal token means a scope is missing from the cascade',
  );
}

void main() {
  setUp(_seedAndInit);

  testWidgets('station mode resolves station, scenario, exercise, plan and '
      'variable tokens', (tester) async {
    await _openPlayer(
      tester,
      const StationSheetTarget(exerciseUuid: _exerciseUuid, stationIndex: 0),
    );

    _expectNoLiteralTokens();
    // Each level of the cascade, named explicitly: "no literals" alone would
    // also pass if the card rendered nothing at all.
    expect(find.textContaining('Post Fisker'), findsWidgets);
    expect(find.textContaining('Ringøvelse'), findsWidgets);
    expect(find.textContaining('Runder: 6'), findsWidgets);
    expect(find.textContaining('Hanne Hovden'), findsWidgets);
    expect(find.textContaining('14:30'), findsWidgets);
  });

  testWidgets('roleplay mode resolves roleplay, station, exercise, plan and '
      'variable tokens', (tester) async {
    await _openPlayer(tester, const RoleSheetTarget(rolePlayUuid: _roleUuid));

    _expectNoLiteralTokens();
    expect(find.textContaining('Kari ved Fisker'), findsWidgets);
    expect(find.textContaining('Ringøvelse'), findsWidgets);
    expect(find.textContaining('6 runder'), findsWidgets);
    expect(find.textContaining('14:30'), findsWidgets);
  });

  testWidgets('exercise mode resolves its tokens', (tester) async {
    await _openPlayer(
      tester,
      const ExerciseSheetTarget(exerciseUuid: _exerciseUuid),
    );

    _expectNoLiteralTokens();
    expect(find.textContaining('Øvelse kl 14:30'), findsWidgets);
  });

  // A team rotates through every post, so it has no single station — station
  // tokens legitimately stay literal there and are deliberately not seeded.
  // Everything above that level must still resolve.
  testWidgets('team mode resolves its tokens', (tester) async {
    await _openPlayer(
      tester,
      const TeamSheetTarget(exerciseUuid: _exerciseUuid, teamIndex: 0),
    );

    _expectNoLiteralTokens();
    expect(find.textContaining('Øvelse kl 14:30'), findsWidgets);
  });
}
