import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/location_form_screen.dart';
import 'package:ringdrill/views/person_form_screen.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/station_screen.dart';
import 'package:ringdrill/views/widgets/cast_picker_sheet.dart';
import 'package:ringdrill/views/widgets/collapsible_section_card.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fixtures — DESIGN-010 stage 3b: the Post viewer's "roles" list is now the
// Personer card (one row per station-owned Person, the enacting RolePlay
// shown inline via `personRef`), not a flat RolePlay list.
// ---------------------------------------------------------------------------

const _planUuid = 'prog-x';
const _exerciseUuid = 'ex-x';

// Station 0 has two persons: one enacted (Hilde, personRef'd by a RolePlay),
// one not. Station 1 has none — used for the empty-state test.
const _hilde = Person(
  slug: 'hilde',
  name: 'Hilde',
  age: 34,
  gender: 'female',
  description: 'Gul regnjakke',
);
const _kari = Person(slug: 'kari', name: 'Kari Fiskeløs', age: 71);

// Hilde's marker is cast to a staff member; the enacted-by line names the
// cast actor (not the roleplay's person-mirroring name).
const _actorForHilde = Actor(uuid: 'actor-hilde', realName: 'Ola Nordmann');

const _roleForHilde = RolePlay(
  uuid: 'role-hilde',
  index: 0,
  exerciseUuid: _exerciseUuid,
  stationIndex: 0,
  name: 'Hilde',
  personRef: 'hilde',
  actorUuid: 'actor-hilde',
);

const _lkp = Location(slug: 'lkp', label: 'LKP', kind: LocationKind.lkp);

Exercise _exercise() => Exercise(
  uuid: _exerciseUuid,
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
      persons: [_hilde, _kari],
      locations: [_lkp],
    ),
    Station(index: 1, name: 'Post 2'),
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

Map<String, Object> _basePrefs() {
  final ex = _exercise();
  return {
    'app:activePlan:v1': _planUuid,
    'app:librarySchema:v1': '1',
    'p:$_planUuid': jsonEncode({
      'uuid': _planUuid,
      'name': 'Test Plan',
      'description': '',
      'metadata': {
        'created': '2024-01-01T00:00:00.000Z',
        'updated': '2024-01-01T00:00:00.000Z',
        'version': '1.1',
      },
      'exercises': [],
      'teams': [],
      'sessions': [],
      'rolePlays': [],
      'actors': [],
    }),
    'pe:$_planUuid:$_exerciseUuid': jsonEncode(ex.toJson()),
    'pr:$_planUuid:${_roleForHilde.uuid}': jsonEncode(_roleForHilde.toJson()),
    'pa:$_planUuid:${_actorForHilde.uuid}': jsonEncode(_actorForHilde.toJson()),
  };
}

Future<void> _seedAndInit() async {
  SharedPreferences.setMockInitialValues(_basePrefs());
  await PlanService().init();
}

/// Wraps [StationScreen] in a GoRouter so [context.push] works
/// while still allowing the PlanService to be ready before rendering.
Widget _buildScreen({int stationIndex = 0}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            StationScreen(stationIndex: stationIndex, uuid: _exerciseUuid),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

/// Hosts [StationScreen] inside an open [ContextSheet] so the
/// enacted-person tap that calls `ContextSheet.of(context).replace(...)`
/// resolves and updates the sheet body.
class _StationSheetHarness extends StatefulWidget {
  const _StationSheetHarness({required this.stationIndex});

  final int stationIndex;

  @override
  State<_StationSheetHarness> createState() => _StationSheetHarnessState();
}

class _StationSheetHarnessState extends State<_StationSheetHarness> {
  final _controller = ContextSheetController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.show(
        context,
        StationSheetTarget(
          exerciseUuid: _exerciseUuid,
          stationIndex: widget.stationIndex,
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContextSheet(
      controller: _controller,
      bodyBuilder: (ctx, target) => switch (target) {
        StationSheetTarget(:final exerciseUuid, :final stationIndex) =>
          StationScreen(uuid: exerciseUuid, stationIndex: stationIndex),
        RoleSheetTarget(:final rolePlayUuid) => Scaffold(
          body: Center(child: Text('RolePlay $rolePlayUuid')),
        ),
        _ => const SizedBox.shrink(),
      },
      child: const Scaffold(body: SizedBox.shrink()),
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// Persons and Locations now live under the Station detail view's "Script"
/// (Spill) segment (Icons.theater_comedy) at the default ~800px test width,
/// which reads as WindowSizeClass.medium — the segmented body. Select it
/// before asserting on those cards.
Future<void> _selectScript(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.theater_comedy));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    await _seedAndInit();
  });

  testWidgets('Personer card lists the station\'s persons', (tester) async {
    await tester.pumpWidget(_buildScreen(stationIndex: 0));
    await tester.pumpAndSettle();
    await _selectScript(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.personsSectionTitle.toUpperCase()), findsOneWidget);
    expect(find.textContaining('Hilde'), findsWidgets);
    expect(find.textContaining('Kari Fiskeløs'), findsWidgets);
  });

  testWidgets(
    'Personer/Lokasjoner cards are omitted when the station has none',
    (tester) async {
      await tester.pumpWidget(_buildScreen(stationIndex: 1));
      await tester.pumpAndSettle();
      await _selectScript(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.personsSectionTitle.toUpperCase()), findsNothing);
      expect(find.text(l10n.locationsSectionTitle.toUpperCase()), findsNothing);
    },
  );

  testWidgets(
    'an enacted person shows the cast pill and tapping it opens the cast '
    'picker',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const _StationSheetHarness(stationIndex: 0),
        ),
      );
      await tester.pump(); // post-frame callback fires → show()
      await tester.pump(); // showModalBottomSheet starts
      await tester.pumpAndSettle();
      await _selectScript(tester);

      // Hilde is enacted by the cast actor — the pill shows just the actor
      // name (no "Played by").
      final castPill = find.text(_actorForHilde.realName);
      expect(castPill, findsOneWidget);

      // Tapping the pill opens the shared cast picker (assign/change/clear the
      // actor), not the Spill viewer.
      await tester.tap(castPill);
      await tester.pumpAndSettle();
      expect(find.byType(CastPickerSheet), findsOneWidget);
    },
  );

  testWidgets(
    'an unenacted person shows "Add role" and opens a pre-filled RolePlayFormScreen',
    (tester) async {
      await tester.pumpWidget(_buildScreen(stationIndex: 0));
      await tester.pumpAndSettle();
      await _selectScript(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.personsSectionAddMarkerAction), findsOneWidget);

      await tester.tap(find.text(l10n.personsSectionAddMarkerAction));
      await tester.pumpAndSettle();

      expect(find.byType(RolePlayFormScreen), findsOneWidget);
      // The draft is pre-filled from Kari (the unenacted person), including
      // her age — the name field shows it as part of the identity text.
      expect(find.textContaining('Kari Fiskeløs'), findsWidgets);
    },
  );

  testWidgets(
    'tapping a person row that has a spill opens the spill editor, not the '
    'person editor',
    (tester) async {
      await tester.pumpWidget(_buildScreen(stationIndex: 0));
      await tester.pumpAndSettle();
      await _selectScript(tester);

      // Hilde is enacted (has a RolePlay) — tapping her row (not the pill)
      // opens the spill editor so the spill is reachable from the person list.
      await tester.tap(find.textContaining('Hilde'));
      await tester.pumpAndSettle();

      expect(find.byType(RolePlayFormScreen), findsOneWidget);
      expect(find.byType(PersonFormScreen), findsNothing);
    },
  );

  testWidgets(
    '"+ Ny person" (Post viewer) opens PersonFormScreen reading Lagre/Save '
    '— this caller applies and saves the result immediately, unlike the '
    'station editor\'s own deferred Personer section '
    '(persons_section_commit_label_test.dart)',
    (tester) async {
      await tester.pumpWidget(_buildScreen(stationIndex: 0));
      await tester.pumpAndSettle();
      await _selectScript(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.personsSectionAddAction));
      await tester.pumpAndSettle();

      expect(find.byType(PersonFormScreen), findsOneWidget);
      expect(find.text(l10n.save), findsOneWidget);
      expect(find.text(l10n.formDoneAction), findsNothing);
      // The × close affordance is unaffected by the label. Scoped to the
      // pushed form — the underlying station screen has its own back/close
      // action too.
      expect(
        find.descendant(
          of: find.byType(PersonFormScreen),
          matching: find.byIcon(Icons.close),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Lokasjoner card lists the station\'s locations', (tester) async {
    await tester.pumpWidget(_buildScreen(stationIndex: 0));
    await tester.pumpAndSettle();
    await _selectScript(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.locationsSectionTitle.toUpperCase()), findsOneWidget);
    expect(find.text('LKP'), findsWidgets);
  });

  testWidgets(
    'tapping a person row (not the marker pill) opens PersonFormScreen for '
    'that person',
    (tester) async {
      await tester.pumpWidget(_buildScreen(stationIndex: 0));
      await tester.pumpAndSettle();
      await _selectScript(tester);

      // Kari's row reads "Kari Fiskeløs · 71" — tap the name (left of the
      // trailing "+ Legg til spill" pill) to edit the person, not add a marker.
      final row = find.text('Kari Fiskeløs · 71');
      expect(row, findsOneWidget);
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.byType(PersonFormScreen), findsOneWidget);
      // Pre-filled with Kari's own identity.
      expect(find.textContaining('Kari Fiskeløs'), findsWidgets);
    },
  );

  testWidgets('tapping a location row opens LocationFormScreen for that '
      'location', (tester) async {
    await tester.pumpWidget(_buildScreen(stationIndex: 0));
    await tester.pumpAndSettle();
    await _selectScript(tester);

    // The "LKP" text inside the Lokasjoner card (a CollapsibleSectionCard) —
    // scoped so it never matches the same label on the map marker/legend.
    final row = find.descendant(
      of: find.byType(CollapsibleSectionCard),
      matching: find.text('LKP'),
    );
    expect(row, findsOneWidget);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.byType(LocationFormScreen), findsOneWidget);
  });

  testWidgets('Tidsplan card shows the team schedule table', (tester) async {
    await tester.pumpWidget(_buildScreen(stationIndex: 0));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      find.text(l10n.stationTimingCardTitle.toUpperCase()),
      findsOneWidget,
    );
    expect(find.textContaining('Team 1'), findsWidgets);
  });
}
