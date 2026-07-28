import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/exercise_form_screen.dart';
import 'package:ringdrill/views/plan_form_screen.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/station_form_screen.dart';

/// DESIGN-009 follow-ups 4b and 4c — the `/`/`{{` picker offers the
/// already-resolvable `plan.*`/`exercise.*`/`station.*`/`roleplay.*`
/// plan fields, built from the single `PlanFieldTokens` source
/// ([lib/views/widgets/plan_field_tokens.dart]), alongside whatever each
/// editor already offered ([test/views/plan_field_tokens_resolution_test.dart]
/// is the renderer-side half of this invariant: every offered token
/// actually resolves).
///
/// Filters use the `{{<name>` form throughout, not `/`: the `/` trigger's
/// filter is `\w*` only (no dot), so it cannot narrow to a dotted path like
/// `exercise.startTime` — matching the same reasoning already applied to
/// `{{station.loc.`/`{{station.person.` filters elsewhere.

Future<void> _pumpAndOpen(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () =>
              Navigator.push(ctx, MaterialPageRoute(builder: (_) => home)),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('PlanFormScreen', () {
    testWidgets('offers only plan.* plan fields, never exercise.*/station.*/'
        'roleplay.*', (tester) async {
      final now = DateTime.utc(2026, 1, 1);
      await _pumpAndOpen(
        tester,
        PlanFormScreen(
          plan: Plan(
            uuid: 'pgm-1',
            name: 'Vinterøvelse',
            description: '',
            metadata: PlanMetadata(created: now, updated: now, version: '1.0'),
            teams: const [],
            sessions: const [],
            exercises: const [],
            briefIntroMd: 'x',
          ),
        ),
      );

      await tester.tap(find.text(l.briefSectionPlanIntro));
      await tester.pumpAndSettle();
      // The section field has no floating label (8d7acf9 dropped it as a
      // dup of the switcher/rail name); only one section is mounted at a
      // time, so its field is the sole TextFormField in the tree.
      await tester.enterText(find.byType(TextFormField), 'x {{');
      await tester.pump();
      await tester.pump();

      expect(find.text(l.planName), findsOneWidget);
      expect(find.text(l.planDescription), findsOneWidget);
      expect(find.text(l.exerciseName), findsNothing);
      expect(find.text(l.startTime), findsNothing);
      expect(find.text(l.stationName), findsNothing);
      expect(find.text(l.roleName), findsNothing);

      await tester.tap(find.text(l.planName));
      await tester.pump();

      expect(find.textContaining('{{plan.name}}'), findsOneWidget);
    });
  });

  group('ExerciseFormScreen', () {
    Exercise exercise() => Exercise(
      uuid: 'ex-1',
      name: 'Original name',
      startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
      numberOfTeams: 1,
      numberOfRounds: 1,
      executionTime: 10,
      evaluationTime: 5,
      rotationTime: 2,
      stations: const [],
      schedule: const [],
      endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
    );

    testWidgets('offers both plan.* and exercise.* plan fields, but never '
        'station.*/roleplay.* (4c is scoped to the station/roleplay editors '
        'only); selecting one inserts the exact token', (tester) async {
      await _pumpAndOpen(
        tester,
        ExerciseFormScreen(exercise: exercise(), variables: const []),
      );

      final nameField = find.widgetWithText(TextFormField, l.exerciseName);

      await tester.enterText(nameField, 'x {{plan.name');
      await tester.pump();
      await tester.pump();
      expect(find.text(l.planName), findsOneWidget);

      await tester.enterText(nameField, 'x {{exercise.startTime');
      await tester.pump();
      await tester.pump();
      final menuEntry = find.descendant(
        of: find.byType(ListView),
        matching: find.text(l.startTime),
      );
      expect(menuEntry, findsOneWidget);

      await tester.tap(menuEntry);
      await tester.pump();

      expect(find.textContaining('{{exercise.startTime}}'), findsOneWidget);

      await tester.enterText(nameField, 'x {{');
      await tester.pump();
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text(l.stationCode),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text(l.roleAge),
        ),
        findsNothing,
      );
    });
  });

  group('StationFormScreen', () {
    Exercise parentExercise() => Exercise(
      uuid: 'ex-1',
      name: 'Exercise',
      startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
      endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
      numberOfTeams: 1,
      numberOfRounds: 1,
      executionTime: 10,
      evaluationTime: 5,
      rotationTime: 5,
      stations: const [],
      schedule: const [],
    );

    testWidgets(
      'the plan/exercise/station plan fields coexist with station.loc/'
      'person entries the linked StationScope already supplies',
      (tester) async {
        final station = Station(
          index: 0,
          name: 'Post 1',
          position: const LatLng(58.99, 10.43),
          locations: const [Location(slug: 'lkp', place: 'Sentrum')],
          persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
        );
        await _pumpAndOpen(
          tester,
          StationFormScreen(
            station: station,
            parentExercise: parentExercise(),
            variables: const <DrillVariable>[],
          ),
        );

        // The description starts empty, so it is collapsed to the
        // "Legg til beskrivelse" affordance (DESIGN-009); reveal it first.
        await tester.tap(find.text(l.stationAddDescriptionAction));
        await tester.pump();

        final descriptionField = find.widgetWithText(
          TextFormField,
          l.stationDescription,
        );

        await tester.enterText(descriptionField, '{{exercise.startTime');
        await tester.pump();
        await tester.pump();
        expect(find.text(l.startTime), findsOneWidget);

        await tester.enterText(descriptionField, '{{station.name');
        await tester.pump();
        await tester.pump();
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.text(l.stationName),
          ),
          findsOneWidget,
        );

        await tester.enterText(
          descriptionField,
          '{{exercise.startTime}}{{station.loc.',
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('Sentrum'), findsOneWidget);
      },
    );

    testWidgets('offers station.* own facets, but never station.description — '
        'inserting one produces the exact token', (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        position: const LatLng(58.99, 10.43),
      );
      await _pumpAndOpen(
        tester,
        StationFormScreen(
          station: station,
          parentExercise: parentExercise(),
          variables: const <DrillVariable>[],
        ),
      );

      // The description starts empty, so it is collapsed to the
      // "Legg til beskrivelse" affordance (DESIGN-009); reveal it first.
      await tester.tap(find.text(l.stationAddDescriptionAction));
      await tester.pump();

      final descriptionField = find.widgetWithText(
        TextFormField,
        l.stationDescription,
      );
      await tester.enterText(descriptionField, '{{station.');
      await tester.pump();
      await tester.pump();

      final menu = find.byType(ListView);
      expect(
        find.descendant(of: menu, matching: find.text(l.stationName)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: menu, matching: find.text(l.stationCode)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: menu, matching: find.text(l.positionUtm)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: menu, matching: find.text(l.variantSuffix)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: menu, matching: find.text(l.stationDescription)),
        findsNothing,
      );

      await tester.tap(
        find.descendant(of: menu, matching: find.text(l.stationCode)),
      );
      await tester.pump();

      expect(find.textContaining('{{station.stationCode}}'), findsOneWidget);
    });
  });

  group('RolePlayFormScreen', () {
    // Portrays a station Person (ADR-0047, amended 2026-07-10 — no
    // auto-created placeholder); the name matches so identity starts
    // inherited and the "Tilpass" panel opens on the disclosure tap.
    RolePlay rolePlay() => const RolePlay(
      uuid: 'role-1',
      index: 0,
      exerciseUuid: 'ex-1',
      name: 'Anna Hansen',
      stationIndex: 0,
      behavior: 'x',
      personRef: 'anne',
    );

    // Ensures the passed station carries the portrayed person (slug 'anne')
    // so `personRef` above resolves — without clobbering a person the test's
    // own station already supplies under that slug.
    Exercise exercise(Station station) => Exercise(
      uuid: 'ex-1',
      name: 'Exercise',
      startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
      endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
      numberOfTeams: 1,
      numberOfRounds: 1,
      executionTime: 10,
      evaluationTime: 5,
      rotationTime: 5,
      stations: [
        station.copyWith(
          persons: [
            ...station.persons,
            if (!station.persons.any((p) => p.slug == 'anne'))
              const Person(slug: 'anne', name: 'Anna Hansen'),
          ],
        ),
      ],
      schedule: const [],
    );

    testWidgets('the behavior field offers plan/exercise/station/roleplay plan '
        'fields, coexisting with station.loc/person entries the linked '
        'station supplies', (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        position: const LatLng(58.99, 10.43),
        locations: const [Location(slug: 'lkp', place: 'Sentrum')],
        persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
      );
      await _pumpAndOpen(
        tester,
        RolePlayFormScreen(
          rolePlay: rolePlay(),
          exercise: exercise(station),
          variables: const <DrillVariable>[],
        ),
      );

      await tester.tap(find.text(l.roleBehavior));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));

      await tester.enterText(find.byType(TextField), 'x {{exercise.startTime');
      await tester.pump();
      await tester.pump();
      expect(find.text(l.startTime), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'x {{station.name');
      await tester.pump();
      await tester.pump();
      expect(find.text(l.stationName), findsOneWidget);

      // roleplay.name is not self-referential here (this is the behavior
      // field, not the name field), so the full roleplay(l) set is on
      // offer, roleplay.name included.
      await tester.enterText(find.byType(TextField), 'x {{roleplay.');
      await tester.pump();
      await tester.pump();
      final behaviorMenu = find.byType(ListView);
      expect(
        find.descendant(of: behaviorMenu, matching: find.text(l.roleName)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: behaviorMenu, matching: find.text(l.roleAge)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: behaviorMenu,
          matching: find.text(l.roleDescription),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: behaviorMenu, matching: find.text(l.positionUtm)),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'x {{station.person.');
      await tester.pump();
      await tester.pump();
      expect(find.text('Anne Glemsk'), findsWidgets);
    });

    // The three cases below each open the form fresh and enter text on the
    // name field exactly once. The name field's RingDrillTextField takes an
    // `onChanged` that calls `setState()` on the whole screen (so the
    // effective-identity preview stays live) — unique to this one field
    // among every token-aware field in the app. A *second* `enterText` while
    // its token menu is still open rebuilds `RingDrillTextField` (and so
    // `TokenInsertionMenu`) from that `setState`, which unconditionally
    // calls the open overlay's `markNeedsBuild()` from `didUpdateWidget`
    // mid-build — a pre-existing bug in `token_insertion_menu.dart`
    // predating this follow-up (it reproduces with plain `plan.*`/
    // `exercise.*` filters too, nothing 4c-specific) that a two-keystroke
    // interaction on this field would already have hit. Flagged separately;
    // each case here stays to a single `enterText` to avoid it.
    testWidgets(
      "the roleplay's own name field offers roleplay's derived facets but "
      'withholds roleplay.name (self-reference)',
      (tester) async {
        final station = Station(
          index: 0,
          name: 'Post 1',
          position: const LatLng(58.99, 10.43),
        );
        await _pumpAndOpen(
          tester,
          RolePlayFormScreen(
            rolePlay: rolePlay(),
            exercise: exercise(station),
            variables: const <DrillVariable>[],
          ),
        );

        await tester.tap(find.byKey(const Key('identity-disclosure')));
        await tester.pumpAndSettle();
        final nameField = find.widgetWithText(TextFormField, 'Anna Hansen');
        await tester.enterText(nameField, 'x {{roleplay.');
        await tester.pump();
        await tester.pump();

        final menu = find.byType(ListView);
        expect(
          find.descendant(of: menu, matching: find.text(l.roleAge)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: menu, matching: find.text(l.roleDescription)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: menu, matching: find.text(l.positionUtm)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: menu, matching: find.text(l.roleName)),
          findsNothing,
        );
      },
    );

    testWidgets("the roleplay's own name field also offers station.* facets", (
      tester,
    ) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        position: const LatLng(58.99, 10.43),
      );
      await _pumpAndOpen(
        tester,
        RolePlayFormScreen(
          rolePlay: rolePlay(),
          exercise: exercise(station),
          variables: const <DrillVariable>[],
        ),
      );

      await tester.tap(find.byKey(const Key('identity-disclosure')));
      await tester.pumpAndSettle();
      final nameField = find.widgetWithText(TextFormField, 'Anna Hansen');
      await tester.enterText(nameField, 'x {{station.name');
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text(l.stationName),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      "selecting roleplay.age from the roleplay's own name field inserts "
      'the exact token',
      (tester) async {
        final station = Station(
          index: 0,
          name: 'Post 1',
          position: const LatLng(58.99, 10.43),
        );
        await _pumpAndOpen(
          tester,
          RolePlayFormScreen(
            rolePlay: rolePlay(),
            exercise: exercise(station),
            variables: const <DrillVariable>[],
          ),
        );

        await tester.tap(find.byKey(const Key('identity-disclosure')));
        await tester.pumpAndSettle();
        final nameField = find.widgetWithText(TextFormField, 'Anna Hansen');
        await tester.enterText(nameField, 'x {{roleplay.age');
        await tester.pump();
        await tester.pump();
        await tester.tap(
          find.descendant(
            of: find.byType(ListView),
            matching: find.text(l.roleAge),
          ),
        );
        await tester.pump();

        expect(find.textContaining('{{roleplay.age}}'), findsOneWidget);
      },
    );
  });
}
