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
import 'package:ringdrill/views/roleplay_list_view.dart';
import 'package:ringdrill/views/widgets/cast_pill.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/role_position_panel.dart';
import 'package:ringdrill/views/widgets/roleplay_description_rollup.dart';

import 'support/save_roundtrip_harness.dart';

// ---------------------------------------------------------------------------
// DESIGN-010 "browser tile polish" — Spill tile (roleplay_list_view.dart).
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
  signalement: 'UTM: {{station.position}} STED: {{station.loc.entry.place}}',
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
      _harness(RolePlayListView(controller: RolePlaysController())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Fix 1: scenario/position/cast sections share the same symmetric '
    'spacing (Column.spacing, no separate divider widget)',
    (tester) async {
      await expandFirstRole(tester);

      // Signalement, position and cast are all present, one gap between
      // each pair of adjacent sections.
      final descriptionRect = tester.getRect(
        find.byType(RolePlayDescriptionRollup),
      );
      final positionRect = tester.getRect(find.byType(RolePositionPanel));
      // The cast section's own Row (holding the CastPill + phone chip) is
      // the section's top edge — the CastPill itself is vertically centred
      // within that Row (default CrossAxisAlignment.center) and sits lower
      // than the row's top whenever the phone chip is taller than the pill.
      final castRowRect = tester.getRect(
        find
            .ancestor(of: find.byType(CastPill).first, matching: find.byType(Row))
            .first,
      );

      expect(positionRect.top - descriptionRect.bottom, 8.0);
      expect(castRowRect.top - positionRect.bottom, 8.0);
    },
  );

  testWidgets(
    'Fix 3: Cast tile shows the actor name, the phone number, and never '
    'castPrivateHint',
    (tester) async {
      await expandFirstRole(tester);

      // The cast pill reads "Enacted by {realName}".
      expect(find.text(l10n.castedByLine(_actor.realName)), findsOneWidget);
      expect(find.text(_actor.phone!), findsOneWidget);
      // The deprecated hint's literal wording must never render.
      expect(find.text('Stays on this device'), findsNothing);
      expect(find.text('Lagres lokalt'), findsNothing);
    },
  );

  testWidgets('Fix 4: no marker context menu remains; the cast chip (the one '
      'person-icon) opens the shared marker sheet', (tester) async {
    await expandFirstRole(tester);

    // No `⋮` menu anywhere in the tile.
    expect(find.byWidgetPredicate((w) => w is PopupMenuButton), findsNothing);

    // The cast chip (Icons.face, this role is cast) opens the shared marker
    // sheet — the one consistent affordance, unified with Poster.
    await tester.tap(find.byIcon(Icons.face).first);
    await tester.pumpAndSettle();

    expect(find.text(l10n.pickerSelectRolePlayTitle), findsOneWidget);
    expect(find.text(l10n.clearCast), findsOneWidget);
  });

  testWidgets('Fix 5: {{station.position}} and {{station.loc.*}} resolve per '
      'tile via its own StationScope instead of showing literally', (
    tester,
  ) async {
    await expandFirstRole(tester);

    expect(find.textContaining('{{station.'), findsNothing);
    // The signalement renders via RingDrillText.rich, so the resolved
    // position/address render as their own action/copy chips rather than
    // flat text — the "UTM:"/"STED:" labels stay in the surrounding prose
    // (only found via `findRichText`) while each resolved value is its own
    // chip widget's plain Text.
    expect(find.textContaining('UTM:', findRichText: true), findsOneWidget);
    expect(find.textContaining(formatUtm(_stationPosition)), findsWidgets);
    expect(find.textContaining('STED:', findRichText: true), findsOneWidget);
    expect(find.textContaining('Innkjøring'), findsWidgets);
  });
}
