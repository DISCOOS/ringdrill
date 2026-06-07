import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/widgets/role_number_badge.dart';

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

    await tester.enterText(find.byKey(const Key('age-field')), '200');

    await tester.tap(find.text(l10n.save));
    await tester.pump();

    expect(find.text(l10n.ageRange), findsOneWidget);
  });

  testWidgets('valid age passes validation', (tester) async {
    await tester.pumpWidget(_buildForm());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.enterText(find.byKey(const Key('age-field')), '35');

    // No validation error; ageRange not shown
    await tester.tap(find.text(l10n.save));
    await tester.pump();

    expect(find.text(l10n.ageRange), findsNothing);
  });

  testWidgets('save pops with updated name', (tester) async {
    RolePlay? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await Navigator.push<RolePlay>(
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

    // Change name
    final nameField = find.widgetWithText(TextFormField, 'Anna Hansen');
    await tester.enterText(nameField, 'Maria Olsen');

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(result?.name, 'Maria Olsen');
  });

  testWidgets('AppBar title shows newRolePlayTitle when name is empty',
      (tester) async {
    final emptyRole = const RolePlay(
      uuid: 'role-new',
      index: 0,
      exerciseUuid: 'ex-1',
      name: '',
    );
    await tester.pumpWidget(_buildForm(rolePlay: emptyRole));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.newRolePlayTitle), findsOneWidget);
  });

  testWidgets('AppBar title shows role name when name is non-empty',
      (tester) async {
    await tester.pumpWidget(_buildForm());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text('Anna Hansen'), findsAtLeastNWidgets(1));
    expect(find.text(l10n.newRolePlayTitle), findsNothing);
  });

  testWidgets('localized form labels render', (tester) async {
    await tester.pumpWidget(_buildForm());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(l10n.roleSignalement), findsOneWidget);
    expect(find.text(l10n.roleBackground), findsOneWidget);
    expect(find.text(l10n.roleBehavior), findsOneWidget);
  });

  testWidgets('station dropdown shows exercise stations', (tester) async {
    await tester.pumpWidget(_buildForm(exercise: _exercise()));

    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();

    expect(find.text('Post 1'), findsWidgets);
    expect(find.text('Post 2'), findsWidgets);
  });

  testWidgets('station is required when the exercise has stations',
      (tester) async {
    await tester.pumpWidget(_buildForm(exercise: _exercise()));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // No station selected on the draft → saving must surface the error.
    await tester.tap(find.text(l10n.save));
    await tester.pump();

    expect(find.text(l10n.pleaseSelectStation), findsOneWidget);
  });

  testWidgets(
    'new markør on a post defaults position to the post location',
    (tester) async {
      final exercise = _exercise().copyWith(
        stations: const [
          Station(
            index: 0,
            name: 'Post 1',
            position: LatLng(59.911, 10.757),
          ),
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
      expect(find.text(l10n.pickALocation), findsNothing);
      expect(find.byType(PositionWidget), findsOneWidget);
    },
  );

  testWidgets(
    'markør without a post keeps Pick a Location',
    (tester) async {
      final exercise = _exercise().copyWith(
        stations: const [
          Station(
            index: 0,
            name: 'Post 1',
            position: LatLng(59.911, 10.757),
          ),
        ],
      );
      // No stationIndex assigned yet.
      await tester.pumpWidget(_buildForm(exercise: exercise));
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text(l10n.pickALocation), findsOneWidget);
    },
  );

  testWidgets('AppBar contains a RoleNumberBadge', (tester) async {
    await tester.pumpWidget(_buildForm());
    await tester.pump();
    // ProgramService not initialized → exerciseIndex = -1 → code = '?.1'
    expect(find.byType(RoleNumberBadge), findsOneWidget);
  });

  testWidgets('AppBar subtitle is not shown', (tester) async {
    await tester.pumpWidget(_buildForm(exercise: _exercise()));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      find.text(l10n.roleSubtitleExercise(_exercise().name)),
      findsNothing,
    );
  });
}
