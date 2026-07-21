import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';

RolePlay _baseRole() => const RolePlay(
  uuid: 'role-1',
  index: 0,
  exerciseUuid: 'ex-1',
  name: 'Anna Hansen',
);

Exercise _exercise() => Exercise(
  uuid: 'ex-1',
  name: 'Øvelse 1',
  startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
  numberOfTeams: 1,
  numberOfRounds: 1,
  executionTime: 10,
  evaluationTime: 5,
  rotationTime: 2,
  stations: const [
    Station(index: 0, name: 'Post 1'),
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

/// Expands the identity card's "Tilpass" override panel — DESIGN-009
/// prompt 4i moved Navn/Alder/Kjønn/Signalement inside it, only mounted
/// while expanded.
Future<void> _expandIdentity(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('identity-disclosure')));
  await tester.pumpAndSettle();
}

Widget _buildForm({RolePlay? rolePlay, Exercise? exercise}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: RolePlayFormScreen(
      rolePlay: rolePlay ?? _baseRole(),
      exercise: exercise,
    ),
  );
}

void main() {
  testWidgets('name field is required', (tester) async {
    await tester.pumpWidget(_buildForm());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _expandIdentity(tester);

    // Clear the name field
    final nameField = find.widgetWithText(TextFormField, 'Anna Hansen');
    await tester.enterText(nameField, '');

    await tester.tap(find.text(l10n.save));
    await tester.pump();

    expect(find.text(l10n.pleaseEnterAName), findsOneWidget);
  });

  testWidgets('age outside 0–120 shows validation error', (tester) async {
    await tester.pumpWidget(_buildForm());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _expandIdentity(tester);

    await tester.enterText(find.byKey(const Key('age-field')), '200');

    await tester.tap(find.text(l10n.save));
    await tester.pump();

    expect(find.text(l10n.ageRange), findsOneWidget);
  });

  testWidgets('valid age passes validation', (tester) async {
    await tester.pumpWidget(_buildForm());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await _expandIdentity(tester);

    await tester.enterText(find.byKey(const Key('age-field')), '35');

    // No validation error; ageRange not shown
    await tester.tap(find.text(l10n.save));
    await tester.pump();

    expect(find.text(l10n.ageRange), findsNothing);
  });

  testWidgets('save pops with updated name', (tester) async {
    RolePlayFormSave? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await Navigator.push<RolePlayFormSave>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => RolePlayFormScreen(rolePlay: _baseRole()),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await _expandIdentity(tester);

    // Change name
    final nameField = find.widgetWithText(TextFormField, 'Anna Hansen');
    await tester.enterText(nameField, 'Maria Olsen');

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(result?.rolePlay.name, 'Maria Olsen');
  });

  testWidgets('a new draft (isExisting: false) shows no delete action', (
    tester,
  ) async {
    await tester.pumpWidget(_buildForm());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete), findsNothing);
  });

  testWidgets(
    'an existing role shows a delete action that pops RolePlayFormDelete '
    'after confirmation',
    (tester) async {
      RolePlayFormResult? result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                result = await Navigator.push<RolePlayFormResult>(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => RolePlayFormScreen(
                      rolePlay: _baseRole(),
                      isExisting: true,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // The AppBar delete action → confirm the destructive dialog.
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.delete));
      await tester.pumpAndSettle();

      expect(result, isA<RolePlayFormDelete>());
    },
  );

  testWidgets('AppBar title is the static "New role" for a new draft', (
    tester,
  ) async {
    final emptyRole = const RolePlay(
      uuid: 'role-new',
      index: 0,
      exerciseUuid: 'ex-1',
      name: '',
    );
    await tester.pumpWidget(_buildForm(rolePlay: emptyRole));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Also shows as a placeholder in the collapsed identity card's header
    // (DESIGN-009 prompt 4i), so this is scoped to the AppBar.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(l10n.newRolePlayTitle),
      ),
      findsOneWidget,
    );
  });

  testWidgets('AppBar title is the static "Edit role", not the role name '
      '(DESIGN-009 prompt 4j)', (tester) async {
    await tester.pumpWidget(_buildForm());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text(l10n.editRolePlayTitle),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Anna Hansen'),
      ),
      findsNothing,
    );
  });

  testWidgets('localized form labels render', (tester) async {
    await tester.pumpWidget(_buildForm());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Signalement lives inside the identity card's "Tilpass" override
    // panel (DESIGN-009 prompt 4i); background and behavior are addable
    // sections, listed once revealed.
    await _expandIdentity(tester);
    expect(find.text(l10n.roleSignalement), findsOneWidget);
    await tester.tap(find.text(l10n.formSectionAddAction));
    await tester.pumpAndSettle();
    expect(find.text(l10n.roleBackground), findsOneWidget);
    expect(find.text(l10n.roleBehavior), findsOneWidget);
  });

  testWidgets('the Post card picker lists exercise stations', (tester) async {
    await tester.pumpWidget(_buildForm(exercise: _exercise()));

    await tester.tap(find.byKey(const Key('station-field')));
    await tester.pumpAndSettle();

    expect(find.text('Post 1'), findsWidgets);
    expect(find.text('Post 2'), findsWidgets);
  });

  testWidgets(
    'the Post is a compact card naming the post, with a discreet "Endre" '
    'action — not a full-width dropdown',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final rolePlay = _baseRole().copyWith(stationIndex: 0);
      await tester.pumpWidget(
        _buildForm(rolePlay: rolePlay, exercise: _exercise()),
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('station-field')),
          matching: find.text('Post 1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('station-field')),
          matching: find.text(l10n.rolePlayPostEditAction),
        ),
        findsOneWidget,
      );
      expect(find.byType(DropdownButtonFormField<int?>), findsNothing);

      // "Endre" opens the same picker and changes the post.
      await tester.tap(find.byKey(const Key('station-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post 2').last);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('station-field')),
          matching: find.text('Post 2'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('station is required when the exercise has stations', (
    tester,
  ) async {
    await tester.pumpWidget(_buildForm(exercise: _exercise()));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // No station selected on the draft → saving must surface the error.
    await tester.tap(find.text(l10n.save));
    await tester.pump();

    expect(find.text(l10n.pleaseSelectStation), findsOneWidget);
  });

  testWidgets('new markør on a post defaults position to the post location', (
    tester,
  ) async {
    final exercise = _exercise().copyWith(
      stations: const [
        Station(index: 0, name: 'Post 1', position: LatLng(59.911, 10.757)),
        Station(index: 1, name: 'Post 2'),
      ],
    );
    // Draft markør already assigned to post 1 but without its own position.
    final draft = const RolePlay(
      uuid: 'role-new',
      index: 0,
      exerciseUuid: 'ex-1',
      name: 'Esel',
      stationIndex: 0,
    );

    await tester.pumpWidget(_buildForm(rolePlay: draft, exercise: exercise));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Position should be pre-filled from the post, not "Pick a Location".
    expect(find.text(l10n.pickAPlacement), findsNothing);
    expect(find.byType(PositionWidget), findsOneWidget);
  });

  testWidgets(
    'markør without a post is gated: no position section, a post-required '
    'hint instead (ADR-0047, amended 2026-07-10)',
    (tester) async {
      final exercise = _exercise().copyWith(
        stations: const [
          Station(index: 0, name: 'Post 1', position: LatLng(59.911, 10.757)),
        ],
      );
      // No stationIndex assigned yet — identity and position are gated
      // behind Post selection, so the position picker is not shown.
      await tester.pumpWidget(_buildForm(exercise: exercise));
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text(l10n.rolePlayPostRequiredHint), findsOneWidget);
      expect(find.text(l10n.pickAPlacement), findsNothing);
    },
  );

  testWidgets('AppBar subtitle is not shown', (tester) async {
    await tester.pumpWidget(_buildForm(exercise: _exercise()));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      find.text(l10n.roleSubtitleExercise(_exercise().name)),
      findsNothing,
    );
  });
}
