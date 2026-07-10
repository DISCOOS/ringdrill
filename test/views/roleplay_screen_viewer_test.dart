import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/data/program_repository.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/roleplay_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DESIGN-010 stage 3b commit 4 — the Spill viewer's effective-identity
/// card (person values inherited, roleplay values overriding non-empty
/// ones), Markørordre card (behavior/background/props, all resolved), and
/// position card (labeled with the source location the position follows).
///
/// RolePlay.background/behavior/propsMd are excluded from JSON (like
/// Station's *Md fields) — persisting them for `ProgramService.init()` to
/// pick up needs `ProgramRepository.saveRolePlay`'s sidecar-key path.
const _programUuid = 'prog-role-viewer';
const _exerciseUuid = 'ex-role-viewer';
const _roleUuid = 'role-viewer';
const _actorUuid = 'actor-viewer';

const _homeLocation = Location(
  slug: 'home',
  label: 'Bosted',
  kind: LocationKind.home,
  position: LatLng(59.92, 10.76),
);

const _hilde = Person(
  slug: 'hilde',
  name: 'Hilde',
  age: 34,
  gender: 'woman',
  signalement: 'Gul regnjakke, hjemme',
  locSlug: 'home',
);

Program _shell() {
  final now = DateTime.utc(2026, 1, 1);
  return Program(
    uuid: _programUuid,
    name: 'Test Program',
    description: '',
    metadata: ProgramMetadata(created: now, updated: now, version: '1.0'),
    teams: const [],
    sessions: const [],
    exercises: const [],
    actors: const [Actor(uuid: _actorUuid, realName: 'Nina Actor')],
  );
}

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
  index: 0,
  name: 'Test Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [
    Station(
      index: 0,
      name: 'Post 1',
      persons: [_hilde],
      locations: [_homeLocation],
    ),
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

/// Age/signalement are left null (inherited from `_hilde`); gender is set
/// to 'man' (overrides `_hilde`'s 'woman' — ADR-0047's effective-identity
/// rule: the roleplay's own non-empty value wins).
RolePlay _rolePlay() => const RolePlay(
  uuid: _roleUuid,
  index: 0,
  exerciseUuid: _exerciseUuid,
  stationIndex: 0,
  name: 'Hilde',
  gender: 'man',
  personRef: 'hilde',
  actorUuid: _actorUuid,
  position: LatLng(59.92, 10.76),
  // `{{roleplay.age}}` deliberately not used here: roleplayFacets exposes
  // the roleplay's own bare fields (ADR-0048), not the effective/merged
  // value the identity card computes — age is null on this roleplay
  // itself (only the linked person has it), so that token would resolve
  // empty. `{{roleplay.name}}` is always set directly on the roleplay.
  behavior: 'Rolig, følger {{roleplay.name}}.',
  background: 'Sett ved {{station.name}}.',
  propsMd: 'Fiskestang.',
);

Future<void> _seedAndInit() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = ProgramRepository(prefs);
  await repo.saveProgramShell(_shell());
  await repo.setActiveProgramUuid(_programUuid);
  await repo.saveExercise(_exercise());
  // Actor storage is a separate sidecar keyspace (`pa:<program>:<actor>`) —
  // Program.actors on the shell alone is not what ProgramService.getActor
  // reads.
  await repo.saveActor(const Actor(uuid: _actorUuid, realName: 'Nina Actor'));
  await repo.saveRolePlay(_rolePlay());
  await ProgramService().init();
}

Widget _buildScreen() {
  return const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: RolePlayScreen(rolePlayUuid: _roleUuid),
  );
}

void main() {
  setUp(() async {
    await _seedAndInit();
  });

  testWidgets(
    'effective identity shows the person\'s inherited age/signalement and '
    'the roleplay\'s overridden gender',
    (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Age: inherited from the person (roleplay.age is null).
      expect(find.textContaining(l10n.rolePlayAgeYears(34)), findsOneWidget);
      // Gender: the roleplay's own 'male' wins over the person's 'female'.
      expect(find.textContaining('Man'), findsOneWidget);
      expect(find.textContaining('Woman'), findsNothing);
      // Signalement: inherited from the person (roleplay.signalement null).
      expect(
        find.text('Gul regnjakke, hjemme', findRichText: true),
        findsOneWidget,
      );
      // Cast actor footer.
      expect(find.text(l10n.castedByLine('Nina Actor')), findsOneWidget);
    },
  );

  testWidgets(
    'Markørordre resolves tokens in behavior/background and shows props',
    (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(
        find.text('Rolig, følger Hilde.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Sett ved Post 1.', findRichText: true), findsOneWidget);
      expect(find.text('Fiskestang.', findRichText: true), findsOneWidget);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.roleProps), findsOneWidget);
    },
  );

  testWidgets(
    'the position card is labeled with the source location the position follows',
    (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Bosted'), findsOneWidget);
    },
  );
}
