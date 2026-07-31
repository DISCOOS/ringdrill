// ADR-0067's token browser: the inventory for one field, with a description and a
// live resolved value per row.
//
// The caret menu is the fast path and stays untested here (see
// token_insertion_menu_test.dart); what this file cares about is the half the caret
// menu could not do — say what a token means, show what it produces, and let an
// author who does not know the name find it by category.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/plan_field_tokens.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';
import 'package:ringdrill/views/widgets/token_browser.dart';

const _room = Location(
  slug: 'room',
  place: 'LSOR kurslokale',
  position: LatLng(58.99, 10.43),
);
const _anne = Person(slug: 'anne', name: 'Anne Glemsk', age: 39);

Exercise _exercise() => Exercise(
  uuid: 'ex-1',
  name: 'Områdesøk',
  startTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 11, minute: 30),
  numberOfTeams: 3,
  numberOfRounds: 2,
  executionTime: 15,
  evaluationTime: 10,
  rotationTime: 5,
  stations: const [],
  schedule: const [
    [
      SimpleTimeOfDay(hour: 9, minute: 0),
      SimpleTimeOfDay(hour: 9, minute: 15),
      SimpleTimeOfDay(hour: 9, minute: 25),
    ],
    [
      SimpleTimeOfDay(hour: 9, minute: 30),
      SimpleTimeOfDay(hour: 9, minute: 45),
      SimpleTimeOfDay(hour: 9, minute: 55),
    ],
  ],
);

/// A station-scope field: plan + exercise + station tokens, a declared variable,
/// and the station's own location and person.
Future<({BuildContext context, AppLocalizations l10n})> _pumpStationField(
  WidgetTester tester, {
  List<DrillVariable> variables = const [
    DrillVariable(name: 'talegruppe', value: 'RK-VFOLD-ØV4 / DMO-ANDRE-1'),
  ],
  List<Location> locations = const [_room],
  List<Person> persons = const [_anne],
}) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('nb'),
      home: PlanScope(
        variables: variables,
        planName: 'LSOR vinterøvelse 2026',
        planDescription: 'Sju øvelser fredag til søndag.',
        planCounts: const (exercises: 7, teams: 3, stations: 25),
        child: ExerciseScope(
          exercise: _exercise(),
          variableOverrides: const {},
          child: StationScope(
            locations: locations,
            persons: persons,
            name: 'Fisker',
            stationCode: '1c',
            position: const LatLng(58.98, 10.42),
            child: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    ),
  );
  return (context: captured, l10n: AppLocalizations.of(captured)!);
}

List<PlanFieldToken> _stationFields(AppLocalizations l) => [
  ...PlanFieldTokens.plan(l),
  ...PlanFieldTokens.exercise(l),
  ...PlanFieldTokens.station(l),
];

void main() {
  group('buildTokenBrowserEntries', () {
    testWidgets('every facet the field offers becomes a row, in cascade order', (
      tester,
    ) async {
      final (context: context, l10n: l10n) = await _pumpStationField(tester);
      final entries = buildTokenBrowserEntries(
        context,
        planFields: _stationFields(l10n),
        variables: const [
          VariableToken(name: 'talegruppe', effectiveValue: 'RK-VFOLD-ØV4'),
        ],
        stationLocations: const [
          StationLocationToken(
            slug: 'room',
            label: 'LSOR kurslokale',
            preview: 'LSOR kurslokale',
          ),
        ],
        stationPersons: const [
          StationPersonToken(
            slug: 'anne',
            label: 'Anne Glemsk',
            preview: 'Anne Glemsk, 39',
          ),
        ],
      );

      // Cascade order, then the registries — the same order the sections and the
      // filter use, so those two cannot disagree with the list.
      expect(
        entries.map((e) => e.category).toSet().toList(),
        [
          TokenCategory.plan,
          TokenCategory.exercise,
          TokenCategory.station,
          TokenCategory.variable,
          TokenCategory.location,
          TokenCategory.person,
        ],
        reason: 'a station-scope field has no roleplay in scope, so no Script',
      );

      final tokens = entries
          .whereType<TokenBrowserToken>()
          .map((e) => e.token)
          .toList();
      // Nothing the field offers may be missing, and nothing may be invented.
      for (final field in _stationFields(l10n)) {
        expect(tokens, contains('{{${field.name}}}'));
      }
      expect(tokens, contains('{{var.talegruppe}}'));
      expect(tokens, contains('{{station.loc.room}}'));
      expect(tokens, contains('{{station.person.anne}}'));
    });

    testWidgets('every row carries a description', (tester) async {
      // The whole point of the surface. A row that explains nothing is the caret
      // menu with more whitespace.
      final (context: context, l10n: l10n) = await _pumpStationField(tester);
      final entries = buildTokenBrowserEntries(
        context,
        planFields: _stationFields(l10n),
        variables: const [],
        stationLocations: const [],
        stationPersons: const [],
      );
      for (final entry in entries.whereType<TokenBrowserToken>()) {
        expect(
          entry.description,
          isNotEmpty,
          reason: '${entry.token} has no description',
        );
      }
    });

    testWidgets('values resolve against the field scopes, as plain text', (
      tester,
    ) async {
      final (context: context, l10n: l10n) = await _pumpStationField(tester);
      final entries = buildTokenBrowserEntries(
        context,
        planFields: _stationFields(l10n),
        variables: const [],
        stationLocations: const [],
        stationPersons: const [],
      );
      String? valueOf(String token) => entries
          .whereType<TokenBrowserToken>()
          .firstWhere((e) => e.token == token)
          .value;

      expect(valueOf('{{plan.name}}'), 'LSOR vinterøvelse 2026');
      expect(valueOf('{{plan.stationCount}}'), '25');
      expect(valueOf('{{station.stationCode}}'), '1c');
      expect(valueOf('{{station.duration}}'), '30 min (15 | 10 | 5)');
      // A position resolves as a tappable chip (ADR-0050). The value line is read,
      // not rendered, so the link syntax must not leak into it.
      expect(valueOf('{{station.position}}'), isNot(contains('](')));
      expect(valueOf('{{station.position}}'), contains('32V'));
    });

    testWidgets('a facet the editor cannot resolve falls back to its example', (
      tester,
    ) async {
      // `roundTable` is the case that forced examples to exist: the editor never
      // holds that value, it is assembled when the brief renders. An empty box
      // would answer nothing about what the token produces.
      final (context: context, l10n: l10n) = await _pumpStationField(tester);
      final entries = buildTokenBrowserEntries(
        context,
        planFields: _stationFields(l10n),
        variables: const [],
        stationLocations: const [],
        stationPersons: const [],
      );
      final variant = entries.whereType<TokenBrowserToken>().firstWhere(
        (e) => e.token == '{{station.variantSuffix}}',
      );
      // The fixture's station has no variant suffix, so there is nothing to show.
      expect(variant.value, isNull);
      expect(variant.example, isNotNull);
    });

    testWidgets('an empty registry becomes a note, not a missing section', (
      tester,
    ) async {
      final (context: context, l10n: l10n) = await _pumpStationField(
        tester,
        variables: const [],
        locations: const [],
        persons: const [],
      );
      final entries = buildTokenBrowserEntries(
        context,
        planFields: _stationFields(l10n),
        variables: const [],
        stationLocations: const [],
        stationPersons: const [],
      );

      for (final category in [
        TokenCategory.variable,
        TokenCategory.location,
        TokenCategory.person,
      ]) {
        final section = entries.where((e) => e.category == category);
        expect(section, hasLength(1), reason: '$category should be one note');
        expect(section.single, isA<TokenBrowserNote>());
      }
    });

    testWidgets('a plan-scope field gets no station registries at all', (
      tester,
    ) async {
      // Locations and persons belong to a station. "This does not apply here" is
      // not worth a row; "you could add one" is, which is why the two cases differ.
      final (context: context, l10n: l10n) = await _pumpStationField(tester);
      final entries = buildTokenBrowserEntries(
        context,
        planFields: PlanFieldTokens.plan(l10n),
        variables: const [],
        stationLocations: const [],
        stationPersons: const [],
      );
      expect(entries.map((e) => e.category).toSet(), {
        TokenCategory.plan,
        TokenCategory.variable,
      });
    });

    testWidgets('a note is not searchable', (tester) async {
      // Matching it would leave a section header over a row that cannot be chosen.
      final (context: context, l10n: l10n) = await _pumpStationField(tester);
      final entries = buildTokenBrowserEntries(
        context,
        planFields: PlanFieldTokens.plan(l10n),
        variables: const [],
        stationLocations: const [],
        stationPersons: const [],
      );
      expect(entries.whereType<TokenBrowserNote>().single.searchText, isEmpty);
    });

    testWidgets('search text covers the name, the token and the description', (
      tester,
    ) async {
      final (context: context, l10n: l10n) = await _pumpStationField(tester);
      final entries = buildTokenBrowserEntries(
        context,
        planFields: PlanFieldTokens.exercise(l10n),
        variables: const [],
        stationLocations: const [],
        stationPersons: const [],
      );
      final table = entries.whereType<TokenBrowserToken>().firstWhere(
        (e) => e.token == '{{exercise.roundTable}}',
      );
      expect(table.searchText, contains(table.label));
      expect(table.searchText, contains('roundTable'));
      expect(table.searchText, contains(table.description));
    });
  });

  group('the browser sheet', () {
    /// [fields] defaults to the whole station-scope cascade. A test that asserts a
    /// row is *visible* passes a shorter set: `ListView.builder` does not build
    /// what is below the fold, so "not found" would otherwise mean "scrolled off"
    /// rather than "filtered out".
    Future<void> open(
      WidgetTester tester, {
      Size size = const Size(400, 900),
      List<PlanFieldToken> Function(AppLocalizations l)? fields,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final (context: context, l10n: l10n) = await _pumpStationField(tester);
      final entries = buildTokenBrowserEntries(
        context,
        planFields: (fields ?? _stationFields)(l10n),
        variables: const [
          VariableToken(name: 'talegruppe', effectiveValue: 'RK-VFOLD-ØV4'),
        ],
        stationLocations: const [],
        stationPersons: const [],
      );
      // Not awaited: the sheet stays open for the test to look at.
      showTokenBrowser(context: context, entries: entries);
      await tester.pumpAndSettle();
    }

    testWidgets('shows a filter per category present, plus "all"', (
      tester,
    ) async {
      await open(tester);
      // plan, exercise, station, variable, location, person + all.
      expect(find.byKey(const Key('ringdrill-picker-filter-all')), findsOne);
      for (var i = 0; i < 6; i++) {
        expect(
          find.byKey(Key('ringdrill-picker-filter-$i')),
          findsOne,
          reason: 'category $i should have a filter',
        );
      }
      expect(find.byKey(const Key('ringdrill-picker-filter-6')), findsNothing);
    });

    testWidgets('a filter narrows the list to its own category', (
      tester,
    ) async {
      // Plan (5 rows) and station (5) only, on a tall viewport, so every row is on
      // screen and "gone" cannot be confused with "scrolled out of view" —
      // `ListView.builder` does not build what is below the fold, and a
      // three-line row is tall.
      await open(
        tester,
        size: const Size(400, 2000),
        fields: (l) => [
          ...PlanFieldTokens.plan(l),
          ...PlanFieldTokens.station(l),
        ],
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('nb'));

      expect(find.text(l10n.planName), findsOne);
      expect(find.text(l10n.stationCode), findsOne);

      // Category 0 is plan — the first in cascade order.
      await tester.tap(find.byKey(const Key('ringdrill-picker-filter-0')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.planName), findsOne);
      expect(
        find.text(l10n.stationCode),
        findsNothing,
        reason: 'a station facet is not a plan facet',
      );
    });

    testWidgets('search matches a description, not only a name', (
      tester,
    ) async {
      await open(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('nb'));

      // "loddrette" appears only in the phase-breakdown description.
      await tester.enterText(
        find.byKey(const Key('ringdrill-picker-search')),
        'loddrette',
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.phaseBreakdown), findsOne);
      expect(find.text(l10n.planName), findsNothing);
    });

    testWidgets('tapping a row resolves with the token to insert', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final (context: context, l10n: l10n) = await _pumpStationField(tester);
      final entries = buildTokenBrowserEntries(
        context,
        planFields: PlanFieldTokens.plan(l10n),
        variables: const [],
        stationLocations: const [],
        stationPersons: const [],
      );
      String? chosen;
      showTokenBrowser(
        context: context,
        entries: entries,
      ).then((value) => chosen = value);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.planName));
      await tester.pumpAndSettle();

      expect(chosen, '{{plan.name}}');
    });

    testWidgets('the wide layout puts the categories in a rail', (
      tester,
    ) async {
      // ADR-0030's idiom rather than a dialog that happens to be wide.
      await open(tester, size: const Size(1000, 900));

      final l10n = await AppLocalizations.delegate.load(const Locale('nb'));
      expect(find.text(l10n.tokenBrowserFilterAll), findsOne);
      // With "all" selected the section headers are what tells the categories
      // apart, so they are present.
      expect(find.text(l10n.plan(1)), findsWidgets);

      // Selecting one drops the header — the rail entry is the header then.
      await tester.tap(find.byKey(const Key('ringdrill-picker-filter-0')));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.plan(1)),
        findsOne,
        reason: 'only the rail entry, no section header repeating it',
      );
    });
  });
}
