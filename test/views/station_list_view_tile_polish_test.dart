import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/brief/field_resolver.dart' show formatUtm;
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/station_list_view.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/tile_section_divider.dart';

import 'support/save_roundtrip_harness.dart';

// ---------------------------------------------------------------------------
// DESIGN-010 "browser tile polish" — Poster tile (station_list_view.dart).
// Covers: uniform section dividers (Fix 1), distinct marker header/row
// icons (Fix 2), unified marker management on the shared bottom sheet
// (Fix 4), and per-tile StationScope token resolution (Fix 5).
// ---------------------------------------------------------------------------

const _stationPosition = LatLng(59.91, 10.75);
const _entryLoc = Location(
  slug: 'entry',
  place: 'Innkjøring',
  position: LatLng(59.9, 10.7),
);

Exercise _exercise() =>
    makeExercise(uuid: 'ex-tile-polish', name: 'Exercise A').copyWith(
      stations: [
        Station(
          index: 0,
          name: 'Post 1',
          description:
              'Beskrivelse. UTM: {{station.position}} '
              'STED: {{station.loc.entry.place}}',
          position: _stationPosition,
          locations: const [_entryLoc],
        ),
        const Station(index: 1, name: 'Post 2'),
      ],
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
    await initActivePlan('Tile polish plan');
    await ProgramService().saveExercise(l10n, _exercise());
    await ProgramService().saveRolePlay(
      l10n,
      const RolePlay(
        uuid: 'role-tile-polish',
        index: 0,
        exerciseUuid: 'ex-tile-polish',
        name: 'Vitne',
        stationIndex: 0,
      ),
    );
  });

  tearDown(() => ProgramService().clearAllForTest());

  Future<void> expandFirstStation(WidgetTester tester) async {
    await tester.pumpWidget(
      _harness(StationListView(controller: StationListController())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Fix 1: TileSectionDivider separates description/position/markers with '
    'the shared, symmetric spacing',
    (tester) async {
      await expandFirstStation(tester);

      // Description, position and markers (a role is attached to station 0)
      // are all present, so exactly 2 dividers separate the 3 sections.
      final dividers = find.byType(TileSectionDivider);
      expect(dividers, findsNWidgets(2));

      // Every divider gets the same, symmetric top/bottom padding from the
      // one shared constant — not an ad-hoc SizedBox stacked next to it.
      // `dividers.at(i)` (positional), not `find.byWidget` — the const
      // TileSectionDivider instances at different tree locations canonicalize
      // to the same object, so byWidget would match every occurrence at once.
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

  testWidgets('Fix 2: the section header and person row use different icons', (
    tester,
  ) async {
    await expandFirstStation(tester);

    // Header keeps the masks-theater icon (the play/actors group)...
    expect(find.byIcon(Icons.theater_comedy), findsOneWidget);
    // ...the row is the person (character) → person icon; the actor shows in
    // the trailing cast pill instead.
    expect(find.byIcon(Icons.person), findsWidgets);
  });

  testWidgets(
    'Fix 4: the marker row\'s cast-state icon opens the shared marker '
    'sheet instead of the Spill viewer',
    (tester) async {
      await expandFirstStation(tester);

      // No `⋮` menu anywhere in this tile either.
      expect(find.byWidgetPredicate((w) => w is PopupMenuButton), findsNothing);

      // The role seeded in setUp() is uncast, so the trailing cast pill reads
      // "No actor" — tapping it opens the shared marker sheet (not
      // RoleSheetTarget/the Spill viewer).
      await tester.tap(find.text(l10n.noCastLine));
      await tester.pumpAndSettle();

      expect(find.text(l10n.pickerSelectRolePlayTitle), findsOneWidget);
      expect(find.text(l10n.newActor), findsOneWidget);
    },
  );

  testWidgets(
    'Fix 5: {{station.position}} and {{station.loc.*}} resolve per tile '
    'via its own StationScope instead of showing literally',
    (tester) async {
      await expandFirstStation(tester);

      expect(find.textContaining('{{station.'), findsNothing);
      // The description renders via RingDrillText.rich. The app resolvers
      // pass ActionChipFormatter (ADR-0050), so the position resolves as an
      // rdchip: link (rendered as plain link text until DESIGN-013 Commit 4
      // wires up the pill renderer) while the address stays a copy chip
      // (its own Text widget inside a WidgetSpan).
      expect(find.textContaining(formatUtm(_stationPosition)), findsWidgets);
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == 'Innkjøring'),
        findsWidgets,
      );
    },
  );
}
