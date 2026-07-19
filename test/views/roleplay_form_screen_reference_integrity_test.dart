import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';

/// DESIGN-009 prompt 5, commit 1 — `RolePlayFormScreen`'s save-block on an
/// unresolved `station.loc.<slug>`/`station.person.<slug>` reference,
/// resolved against the linked station's own `locations`/`persons`.

Exercise _exercise({List<Station> stations = const []}) => Exercise(
  uuid: 'ex-1',
  name: 'Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 5,
  stations: stations,
  schedule: const [],
);

class _Captured {
  RolePlayFormSave? value;
}

Future<void> _openForm(
  WidgetTester tester,
  RolePlay rolePlay,
  Exercise exercise,
  _Captured captured,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async {
            captured.value = await Navigator.push<RolePlayFormSave>(
              ctx,
              MaterialPageRoute(
                builder: (_) =>
                    RolePlayFormScreen(rolePlay: rolePlay, exercise: exercise),
              ),
            );
          },
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

  testWidgets(
    'a behavior field with an unresolved station.loc reference blocks '
    'save and names the field and the broken reference',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
      );
      final captured = _Captured();
      await _openForm(
        tester,
        RolePlay(
          uuid: 'role-1',
          index: 0,
          exerciseUuid: 'ex-1',
          name: 'Anne Glemsk',
          stationIndex: 0,
          personRef: 'anne',
          behavior: 'Sier hei ved {{station.loc.ghost}}.',
        ),
        _exercise(stations: [station]),
        captured,
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNull);
      expect(
        find.text(
          l.saveBlockedUnresolvedReference(l.roleBehavior, 'station.loc.ghost'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('removing the broken token unblocks save', (tester) async {
    final station = Station(
      index: 0,
      name: 'Post 1',
      persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
    );
    final captured = _Captured();
    await _openForm(
      tester,
      RolePlay(
        uuid: 'role-1',
        index: 0,
        exerciseUuid: 'ex-1',
        name: 'Anne Glemsk',
        stationIndex: 0,
        personRef: 'anne',
        behavior: 'Sier hei ved {{station.loc.ghost}}.',
      ),
      _exercise(stations: [station]),
      captured,
    );

    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();
    expect(captured.value, isNull);

    // The failed save now also shows a broken-reference warning chip
    // labeled "Behaviour" (ADR-0049 follow-up), so `find.text(l.roleBehavior)`
    // alone is ambiguous — it also matches the chip. Scope to the section
    // rail's own ListTile (the chip has no ListTile ancestor), same
    // disambiguation `roleplay_form_screen_relink_test.dart` already uses.
    await tester.tap(
      find.ancestor(
        of: find.text(l.roleBehavior),
        matching: find.byType(ListTile),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, l.roleBehavior),
      'Sier hei.',
    );
    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();

    expect(captured.value, isNotNull);
    expect(captured.value!.rolePlay.behavior, 'Sier hei.');
  });

  testWidgets('a valid station.loc reference saves', (tester) async {
    final station = Station(
      index: 0,
      name: 'Post 1',
      locations: const [Location(slug: 'lkp', label: 'Sist kjent')],
      persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
    );
    final captured = _Captured();
    await _openForm(
      tester,
      RolePlay(
        uuid: 'role-1',
        index: 0,
        exerciseUuid: 'ex-1',
        name: 'Anne Glemsk',
        stationIndex: 0,
        personRef: 'anne',
        behavior: 'Sier hei ved {{station.loc.lkp}}.',
      ),
      _exercise(stations: [station]),
      captured,
    );

    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();

    expect(captured.value, isNotNull);
    expect(captured.value!.rolePlay.behavior, 'Sier hei ved {{station.loc.lkp}}.');
  });

  testWidgets(
    'a faceted token keys on the same slug as the bare token',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
      );
      final captured = _Captured();
      await _openForm(
        tester,
        RolePlay(
          uuid: 'role-1',
          index: 0,
          exerciseUuid: 'ex-1',
          name: 'Anne Glemsk',
          stationIndex: 0,
          personRef: 'anne',
          behavior: 'Sier hei ved {{station.loc.ghost.place}}.',
        ),
        _exercise(stations: [station]),
        captured,
      );

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNull);
      expect(
        find.text(
          l.saveBlockedUnresolvedReference(l.roleBehavior, 'station.loc.ghost'),
        ),
        findsOneWidget,
      );
    },
  );
}
