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
import 'package:ringdrill/views/widgets/gender_segmented_control.dart';

/// DESIGN-009 prompt 4i — the reworked default section: Post first, then
/// the effective-identity card (collapsed summary, "Tilpass" override
/// panel), then Posisjon. Supersedes 4g's interleaved Navn+Alder/Person+
/// Kjønn rows.

Exercise _exercise() => Exercise(
  uuid: 'ex-1',
  name: 'Exercise',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  endTime: const SimpleTimeOfDay(hour: 9, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 5,
  stations: const [
    Station(
      index: 0,
      name: 'Post 1',
      persons: [Person(slug: 'anne', name: 'Anne Glemsk', gender: 'woman')],
    ),
  ],
  schedule: const [],
);

// gender: 'woman' matches the linked person's own value (see _exercise()),
// so every facet starts inherited — the fixture ADR-0047's sync would have
// produced had this roleplay gone through the normal personRef selection
// flow rather than being constructed directly.
RolePlay _rolePlay() => const RolePlay(
  uuid: 'role-1',
  index: 0,
  exerciseUuid: 'ex-1',
  name: 'Anne Glemsk',
  gender: 'woman',
  stationIndex: 0,
  personRef: 'anne',
);

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RolePlayFormScreen(rolePlay: _rolePlay(), exercise: _exercise()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  testWidgets('Post leads, then the identity card, then Posisjon', (
    tester,
  ) async {
    await _open(tester);

    final postTop = tester
        .getTopLeft(find.byKey(const Key('station-field')))
        .dy;
    final identityTop = tester
        .getTopLeft(find.byKey(const Key('person-field')))
        .dy;
    final positionTop = tester
        .getTopLeft(find.byType(PositionFormField))
        .dy;

    expect(postTop, lessThan(identityTop));
    expect(identityTop, lessThan(positionTop));
  });

  testWidgets(
    'a fully-inherited identity starts collapsed: header shows the person '
    'summary, "Tilpass" disclosure, no override dot',
    (tester) async {
      await _open(tester);

      // Scoped to the identity card header: the section title bar also
      // shows the roleplay's name as plain text.
      expect(
        find.descendant(
          of: find.byKey(const Key('person-field')),
          matching: find.text('Anne Glemsk'),
        ),
        findsOneWidget,
      );
      // No "Følger person(en)" text anywhere (DESIGN-009 prompt 4j) — just
      // the "Tilpass" disclosure.
      expect(find.text(l.rolePlayIdentityCustomizeAction), findsOneWidget);
      expect(find.byType(GenderSegmentedControl), findsNothing);
      expect(find.byKey(const Key('identity-panel')), findsNothing);
    },
  );

  testWidgets(
    'tapping "Customize" expands the panel with Navn+Alder on one row and '
    'Kjønn on its own row',
    (tester) async {
      await _open(tester);

      await tester.tap(find.byKey(const Key('identity-disclosure')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('identity-panel')), findsOneWidget);
      final nameTop = tester
          .getTopLeft(find.widgetWithText(TextFormField, l.roleName))
          .dy;
      final ageTop = tester.getTopLeft(find.byKey(const Key('age-field'))).dy;
      final genderTop = tester.getTopLeft(find.text(l.roleGender)).dy;

      // Navn and Alder share a row.
      expect(nameTop, ageTop);
      // Kjønn sits on its own row, below.
      expect(genderTop, greaterThan(nameTop));
    },
  );

  testWidgets(
    'no "Følger person(en)" text anywhere, in nb — collapsed, panel '
    'expanded, or with an override',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('nb'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RolePlayFormScreen(rolePlay: _rolePlay(), exercise: _exercise()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Følger'), findsNothing);

      await tester.tap(find.byKey(const Key('identity-disclosure')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Følger'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Anne Glemsk'),
        'Kari',
      );
      await tester.pump();
      expect(find.textContaining('Følger'), findsNothing);
    },
  );

  testWidgets(
    'no "Følger personens lokasjon" text on the position card, in nb — the '
    'location name reads as the source instead',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        locations: const [
          Location(slug: 'lkp', label: 'Bosted', position: LatLng(58.99, 10.43)),
        ],
        persons: const [Person(slug: 'anne', name: 'Anne Glemsk', locSlug: 'lkp')],
      );
      final exercise = _exercise().copyWith(stations: [station]);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('nb'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RolePlayFormScreen(rolePlay: _rolePlay(), exercise: exercise),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bosted'), findsOneWidget);
      expect(find.byKey(const Key('position-disclosure')), findsOneWidget);
      expect(find.textContaining('Følger'), findsNothing);
    },
  );
}
