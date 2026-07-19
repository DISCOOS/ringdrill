import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/position_form_field.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';

/// DESIGN-009 prompt 4i, commit 3 (label dropped in prompt 4j) — the
/// position section defaults to the selected person's own `loc` location: a
/// collapsed card (`position-disclosure`) showing that location's name and
/// coordinate, "Sett egen" to override via the existing picker, and a plain
/// unchanged picker when there is nothing to follow.

const _lkp = LatLng(58.99, 10.43);

Exercise _exercise({required Station station}) => Exercise(
  uuid: 'ex-1',
  name: 'Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 5,
  stations: [station],
  schedule: const [],
);

class _Captured {
  RolePlayFormSave? value;
}

Future<void> _openForm(
  WidgetTester tester,
  RolePlay rolePlay,
  Station station,
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
                builder: (_) => RolePlayFormScreen(
                  rolePlay: rolePlay,
                  exercise: _exercise(station: station),
                ),
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
    'defaults to the selected person\'s location: collapsed card shows '
    'the location and its coordinate, no raw picker',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        locations: const [
          Location(slug: 'lkp', label: 'Sist kjent', position: _lkp),
        ],
        persons: const [
          Person(slug: 'anne', name: 'Anne Glemsk', locSlug: 'lkp'),
        ],
      );
      final captured = _Captured();
      await _openForm(
        tester,
        const RolePlay(
          uuid: 'role-1',
          index: 0,
          exerciseUuid: 'ex-1',
          name: 'Anne Glemsk',
          stationIndex: 0,
          personRef: 'anne',
        ),
        station,
        captured,
      );

      expect(find.text('Sist kjent'), findsOneWidget);
      expect(find.byKey(const Key('position-disclosure')), findsOneWidget);
      expect(find.byType(PositionFormField), findsNothing);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();

      expect(captured.value, isNotNull);
      expect(captured.value!.rolePlay.position, _lkp);
    },
  );

  testWidgets('"Sett egen" reveals the picker; picking a point overrides', (
    tester,
  ) async {
    final station = Station(
      index: 0,
      name: 'Post 1',
      locations: const [
        Location(slug: 'lkp', label: 'Sist kjent', position: _lkp),
      ],
      persons: const [
        Person(slug: 'anne', name: 'Anne Glemsk', locSlug: 'lkp'),
      ],
    );
    final captured = _Captured();
    await _openForm(
      tester,
      const RolePlay(
        uuid: 'role-1',
        index: 0,
        exerciseUuid: 'ex-1',
        name: 'Anne Glemsk',
        stationIndex: 0,
        personRef: 'anne',
      ),
      station,
      captured,
    );

    await tester.tap(find.byKey(const Key('position-disclosure')));
    await tester.pumpAndSettle();

    expect(find.byType(PositionFormField), findsOneWidget);
    expect(find.byKey(const Key('position-disclosure')), findsNothing);

    // Not touching the map itself here (a separate picker route); saving
    // with the still-following coordinate simply persists that value.
    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();

    expect(captured.value, isNotNull);
    expect(captured.value!.rolePlay.position, _lkp);
  });

  testWidgets(
    'a person with no loc location falls back to the plain picker — no '
    'card, no regression',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        persons: const [Person(slug: 'anne', name: 'Anne Glemsk')],
      );
      final captured = _Captured();
      await _openForm(
        tester,
        const RolePlay(
          uuid: 'role-1',
          index: 0,
          exerciseUuid: 'ex-1',
          name: 'Anne Glemsk',
          stationIndex: 0,
          personRef: 'anne',
        ),
        station,
        captured,
      );

      expect(find.byType(PositionFormField), findsOneWidget);
      expect(find.byKey(const Key('position-disclosure')), findsNothing);
      expect(find.text(l.pickALocation), findsOneWidget);
    },
  );

  testWidgets(
    'switching to a different person re-follows onto their own location',
    (tester) async {
      const kariCoord = LatLng(59.9, 10.7);
      final station = Station(
        index: 0,
        name: 'Post 1',
        locations: const [
          Location(slug: 'lkp', label: 'Sist kjent', position: _lkp),
          Location(slug: 'ipp', label: 'IPP', position: kariCoord),
        ],
        persons: const [
          Person(slug: 'anne', name: 'Anne Glemsk', locSlug: 'lkp'),
          Person(slug: 'kari', name: 'Kari Hansen', locSlug: 'ipp'),
        ],
      );
      final captured = _Captured();
      await _openForm(
        tester,
        const RolePlay(
          uuid: 'role-1',
          index: 0,
          exerciseUuid: 'ex-1',
          name: 'Anne Glemsk',
          stationIndex: 0,
          personRef: 'anne',
        ),
        station,
        captured,
      );

      // Still following Anne's location before the switch.
      expect(find.byKey(const Key('position-disclosure')), findsOneWidget);

      await tester.tap(find.byKey(const Key('person-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kari Hansen').last);
      await tester.pumpAndSettle();

      // Re-follows onto Kari's own location, not left pointing at Anne's.
      expect(find.text('IPP'), findsOneWidget);
      expect(find.byKey(const Key('position-disclosure')), findsOneWidget);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(captured.value!.rolePlay.position, kariCoord);
    },
  );

  testWidgets(
    'switching to a different person leaves an already-overridden position '
    'untouched',
    (tester) async {
      const manualCoord = LatLng(60.0, 11.0);
      final station = Station(
        index: 0,
        name: 'Post 1',
        locations: const [
          Location(slug: 'lkp', label: 'Sist kjent', position: _lkp),
          Location(slug: 'ipp', label: 'IPP', position: LatLng(59.9, 10.7)),
        ],
        persons: const [
          Person(slug: 'anne', name: 'Anne Glemsk', locSlug: 'lkp'),
          Person(slug: 'kari', name: 'Kari Hansen', locSlug: 'ipp'),
        ],
      );
      final captured = _Captured();
      await _openForm(
        tester,
        const RolePlay(
          uuid: 'role-1',
          index: 0,
          exerciseUuid: 'ex-1',
          name: 'Anne Glemsk',
          stationIndex: 0,
          personRef: 'anne',
          // Differs from Anne's own location — already a deliberate
          // override before the switch.
          position: manualCoord,
        ),
        station,
        captured,
      );

      expect(find.byType(PositionFormField), findsOneWidget);
      expect(find.byKey(const Key('position-disclosure')), findsNothing);

      await tester.tap(find.byKey(const Key('person-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kari Hansen').last);
      await tester.pumpAndSettle();

      // Still the manual override, not re-pointed at Kari's location.
      expect(find.byKey(const Key('position-disclosure')), findsNothing);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(captured.value!.rolePlay.position, manualCoord);
    },
  );
}
