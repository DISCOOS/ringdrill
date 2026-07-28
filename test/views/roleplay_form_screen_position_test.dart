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

/// DESIGN-009 prompt 4i/4j (since simplified) — the marker position is one
/// [PositionFormField] card, thumbnail always shown. It follows the selected
/// person's own `loc` location by default and shows that name — or
/// "Modified" for an override — as the bar's label above the coordinate. An
/// override shows a `position-reset` link; a person with no location falls
/// back to the plain picker.

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

Station _stationWith(List<Location> locations, List<Person> persons) =>
    Station(index: 0, name: 'Post 1', locations: locations, persons: persons);

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('defaults to the selected person\'s location: the bar shows the '
      'location name as its label, no reset', (tester) async {
    final station = _stationWith(
      const [Location(slug: 'lkp', label: 'Sist kjent', position: _lkp)],
      const [Person(slug: 'anne', name: 'Anne Glemsk', locSlug: 'lkp')],
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

    // Following: the location name is the bar's label, no reset link.
    expect(find.byType(PositionFormField), findsOneWidget);
    expect(find.text('Sist kjent'), findsWidgets);
    expect(find.byKey(const Key('position-reset')), findsNothing);

    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();

    expect(captured.value, isNotNull);
    expect(captured.value!.rolePlay.position, _lkp);
  });

  testWidgets(
    'a person with no loc location falls back to the plain picker — no '
    'reset',
    (tester) async {
      final station = _stationWith(const [], const [
        Person(slug: 'anne', name: 'Anne Glemsk'),
      ]);
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
      expect(find.byKey(const Key('position-reset')), findsNothing);
      expect(find.text(l.pickAPlacement), findsOneWidget);
    },
  );

  testWidgets(
    'switching to a different person re-follows onto their own location',
    (tester) async {
      const kariCoord = LatLng(59.9, 10.7);
      final station = _stationWith(
        const [
          Location(slug: 'lkp', label: 'Sist kjent', position: _lkp),
          Location(slug: 'ipp', label: 'IPP', position: kariCoord),
        ],
        const [
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

      // Following Anne's location before the switch.
      expect(find.byKey(const Key('position-reset')), findsNothing);

      await tester.tap(find.byKey(const Key('person-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kari Hansen').last);
      await tester.pumpAndSettle();

      // Re-follows onto Kari's own location.
      expect(find.text('IPP'), findsWidgets);
      expect(find.byKey(const Key('position-reset')), findsNothing);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(captured.value!.rolePlay.position, kariCoord);
    },
  );

  testWidgets(
    'an override shows a reset link and survives a person switch untouched',
    (tester) async {
      const manualCoord = LatLng(60.0, 11.0);
      final station = _stationWith(
        const [
          Location(slug: 'lkp', label: 'Sist kjent', position: _lkp),
          Location(slug: 'ipp', label: 'IPP', position: LatLng(59.9, 10.7)),
        ],
        const [
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
          // Differs from Anne's own location — a deliberate override.
          position: manualCoord,
        ),
        station,
        captured,
      );

      // Override: the reset link is present (the bar's label reads "Modified").
      expect(find.byKey(const Key('position-reset')), findsOneWidget);

      await tester.tap(find.byKey(const Key('person-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kari Hansen').last);
      await tester.pumpAndSettle();

      // Still the manual override, reset still offered.
      expect(find.byKey(const Key('position-reset')), findsOneWidget);

      await tester.tap(find.text(l.save));
      await tester.pumpAndSettle();
      expect(captured.value!.rolePlay.position, manualCoord);
    },
  );

  testWidgets('the reset link reverts an override to the location', (
    tester,
  ) async {
    const manualCoord = LatLng(60.0, 11.0);
    final station = _stationWith(
      const [Location(slug: 'lkp', label: 'Sist kjent', position: _lkp)],
      const [Person(slug: 'anne', name: 'Anne Glemsk', locSlug: 'lkp')],
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
        position: manualCoord,
      ),
      station,
      captured,
    );

    await tester.ensureVisible(find.byKey(const Key('position-reset')));
    await tester.tap(find.byKey(const Key('position-reset')));
    await tester.pumpAndSettle();

    // Back to following the location: the reset is gone, and saving
    // persists the location's coordinate.
    expect(find.byKey(const Key('position-reset')), findsNothing);

    await tester.tap(find.text(l.save));
    await tester.pumpAndSettle();
    expect(captured.value!.rolePlay.position, _lkp);
  });
}
