import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/field_resolver.dart' show formatUtm;
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/roleplays_view.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/tile_section_divider.dart';

import 'support/save_roundtrip_harness.dart';

// ---------------------------------------------------------------------------
// DESIGN-010 "browser tile polish" — Spill tile (roleplays_view.dart).
// Covers: uniform section dividers (Fix 1), the "Spilles av {realName}"
// Cast line with no castPrivateHint (Fix 3), unified marker management on
// the shared bottom sheet with no context menu (Fix 4), and per-tile
// StationScope token resolution (Fix 5).
// ---------------------------------------------------------------------------

const _exerciseUuid = 'ex-role-tile-polish';
const _stationPosition = LatLng(59.91, 10.75);
const _entryLoc = Location(
  slug: 'entry',
  place: 'Innkjøring',
  position: LatLng(59.9, 10.7),
);
const _rolePosition = LatLng(59.92, 10.76);

const _actor = Actor(
  uuid: 'actor-role-tile-polish',
  realName: 'Kari Nordmann',
  phone: '99887766',
);

Exercise _exercise() =>
    makeExercise(uuid: _exerciseUuid, name: 'Exercise A').copyWith(
      stations: [
        Station(
          index: 0,
          name: 'Post 1',
          position: _stationPosition,
          locations: const [_entryLoc],
        ),
      ],
    );

RolePlay _rolePlay() => const RolePlay(
  uuid: 'role-tile-polish',
  index: 0,
  exerciseUuid: _exerciseUuid,
  name: 'Vitne',
  stationIndex: 0,
  position: _rolePosition,
  actorUuid: 'actor-role-tile-polish',
  signalement:
      'UTM: {{station.position.utm}} STED: {{station.loc.entry.place}}',
);

Widget _harness(Widget sliver) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: PlanScope(
    variables: const [],
    child: Scaffold(body: CustomScrollView(slivers: [sliver])),
  ),
);

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() async {
    await initActivePlan('Role tile polish plan');
    await ProgramService().saveExercise(l10n, _exercise());
    await ProgramService().saveActor(l10n, _actor);
    await ProgramService().saveRolePlay(l10n, _rolePlay());
  });

  tearDown(() => ProgramService().clearAllForTest());

  Future<void> expandFirstRole(WidgetTester tester) async {
    await tester.pumpWidget(
      _harness(RolePlaysView(controller: RolePlaysController())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Fix 1: TileSectionDivider separates scenario/position/cast with the '
    'shared, symmetric spacing',
    (tester) async {
      await expandFirstRole(tester);

      // Signalement, position and cast are all present, so exactly 2
      // dividers separate the 3 sections.
      final dividers = find.byType(TileSectionDivider);
      expect(dividers, findsNWidgets(2));

      for (var i = 0; i < dividers.evaluate().length; i++) {
        final descendantPaddings = tester.widgetList<Padding>(
          find.descendant(of: dividers.at(i), matching: find.byType(Padding)),
        );
        expect(
          descendantPaddings.map((p) => p.padding),
          contains(const EdgeInsets.symmetric(vertical: kTileSectionSpacing)),
        );
      }
    },
  );

  testWidgets(
    'Fix 3: Cast tile shows the actor name, the phone number, and never '
    'castPrivateHint',
    (tester) async {
      await expandFirstRole(tester);

      // The cast pill shows just the actor name (no "Played by").
      expect(find.text(_actor.realName), findsOneWidget);
      expect(find.text(_actor.phone!), findsOneWidget);
      // The deprecated hint's literal wording must never render.
      expect(find.text('Stays on this device'), findsNothing);
      expect(find.text('Lagres lokalt'), findsNothing);
    },
  );

  testWidgets(
    'Fix 4: no marker context menu remains; the cast chip (the one '
    'person-icon) opens the shared marker sheet',
    (tester) async {
      await expandFirstRole(tester);

      // No `⋮` menu anywhere in the tile.
      expect(
        find.byWidgetPredicate((w) => w is PopupMenuButton),
        findsNothing,
      );

      // The cast chip (Icons.face, this role is cast) opens the shared marker
      // sheet — the one consistent affordance, unified with Poster.
      await tester.tap(find.byIcon(Icons.face).first);
      await tester.pumpAndSettle();

      expect(find.text(l10n.pickerSelectRolePlayTitle), findsOneWidget);
      expect(find.text(l10n.clearCast), findsOneWidget);
    },
  );

  testWidgets(
    'Fix 5: {{station.position.utm}} and {{station.loc.*}} resolve per '
    'tile via its own StationScope instead of showing literally',
    (tester) async {
      await expandFirstRole(tester);

      expect(find.textContaining('{{station.'), findsNothing);
      // Tiles render via RingDrillText (plain text), so the resolved
      // position/address read as plain text — the copy chip only appears on
      // the markdown surfaces (the detail card / brief).
      expect(
        find.textContaining('UTM: ${formatUtm(_stationPosition)}'),
        findsOneWidget,
      );
      expect(find.textContaining('STED: Innkjøring'), findsOneWidget);
    },
  );
}
