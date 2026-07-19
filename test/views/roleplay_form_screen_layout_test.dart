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
    final positionTop = tester.getTopLeft(find.byType(PositionFormField)).dy;

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
      // Matched by its current value, not by a label — the Navn field's
      // own floating label is suppressed in this panel (DESIGN-009 prompt
      // 4j follow-up: the outer "Navn" caption above already labels it,
      // so the field itself no longer duplicates it).
      final nameTop = tester
          .getTopLeft(find.widgetWithText(TextFormField, 'Anne Glemsk'))
          .dy;
      final ageTop = tester.getTopLeft(find.byKey(const Key('age-field'))).dy;
      final genderTop = tester.getTopLeft(find.text(l.roleGender)).dy;

      // Navn and Alder share a row.
      expect(nameTop, ageTop);
      // Kjønn sits on its own row, below.
      expect(genderTop, greaterThan(nameTop));
    },
  );

  testWidgets('no "Følger person(en)" text anywhere, in nb — collapsed, panel '
      'expanded, or with an override', (tester) async {
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
  });

  testWidgets(
    'no "Følger personens lokasjon" text on the position card, in nb — the '
    'location name reads as the source instead',
    (tester) async {
      final station = Station(
        index: 0,
        name: 'Post 1',
        locations: const [
          Location(
            slug: 'lkp',
            label: 'Bosted',
            position: LatLng(58.99, 10.43),
          ),
        ],
        persons: const [
          Person(slug: 'anne', name: 'Anne Glemsk', locSlug: 'lkp'),
        ],
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
      expect(find.byKey(const Key('position-expand')), findsOneWidget);
      expect(find.textContaining('Følger'), findsNothing);
    },
  );

  testWidgets(
    'the Post card row and the identity "Tilpass" disclosure row (collapsed) '
    'do not overflow at narrow (compact) widths',
    (tester) async {
      // `tester.binding.setSurfaceSize` (not used here) resizes the render
      // surface but does not update `MediaQuery`, which still reports
      // flutter_test's default ~800x600 — so `WindowSizeClass.hasMasterDetail`
      // would keep rendering the 210px-wide rail (`_WideBody`) regardless of
      // this size, squeezing content far narrower than any real device at
      // this width ever would (a real device this narrow reports the same
      // width to MediaQuery, which drops the rail entirely — see
      // WindowSizeClass.of). `tester.view.physicalSize` keeps layout and
      // MediaQuery consistent, so this test exercises the real compact
      // (rail-less) layout its name promises.
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _open(tester);

      expect(find.byKey(const Key('station-field')), findsOneWidget);
      expect(find.byKey(const Key('identity-disclosure')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the Post card row and the identity "Tilpass" disclosure row (collapsed) '
    'do not overflow at the narrowest real width with a rail (medium '
    'breakpoint)',
    (tester) async {
      // 600px is [WindowSizeClass.medium]'s own threshold — the narrowest
      // width a real device shows the 210px rail (`_WideBody`) alongside
      // content, and so the tightest content width this layout ever has to
      // support (compact widths below it never show a rail at all).
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _open(tester);

      expect(find.byKey(const Key('station-field')), findsOneWidget);
      expect(find.byKey(const Key('identity-disclosure')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the identity "Tilpass" disclosure row sits flush against the row\'s '
    'own right edge, not shifted left with dead space after it',
    (tester) async {
      await _open(tester);

      final disclosureRect = tester.getRect(
        find.byKey(const Key('identity-disclosure')),
      );
      final chevronRect = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('identity-disclosure')),
          matching: find.byIcon(Icons.keyboard_arrow_down),
        ),
      );
      // The row's own horizontal padding is 12 (see `_buildIdentityCard`):
      // the chevron's right edge should sit exactly that far from the
      // container's right edge — not further left with unclaimed space
      // in between, which a sibling Flexible on the label used to cause
      // (splitting free space evenly with the spacer regardless of what
      // the label actually needed).
      expect(disclosureRect.right - chevronRect.right, 12.0);
    },
  );

  testWidgets(
    'the Post card row keeps its chevron flush against the row\'s own '
    'right edge even when the station name is short',
    (tester) async {
      await _open(tester);

      final stationRect = tester.getRect(
        find.byKey(const Key('station-field')),
      );
      final chevronRect = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('station-field')),
          matching: find.byIcon(Icons.chevron_right),
        ),
      );
      // The row's own horizontal padding is 12 (see `_buildPostCard`): the
      // chevron's right edge should sit exactly that far from the card's
      // right edge — not further left with unclaimed space in between,
      // which a sibling Flexible on the "Edit"/"Rediger" label used to
      // cause for a short station name like "Post 1" (splitting free
      // space evenly with the name's Expanded regardless of what the
      // label actually needed — the same regression the identity card's
      // "Tilpass" row had, fixed here via `LayoutBuilder` instead).
      expect(stationRect.right - chevronRect.right, 12.0);
    },
  );
}
