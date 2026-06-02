import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/actor_form_screen.dart';
import 'package:ringdrill/views/roster_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _programUuid = 'prog-roster';
const _actorUuid = 'actor-r1';
const _roleUuid = 'role-r1';

// A role that references _actorUuid so delete is blocked.
final _castRole = RolePlay(
  uuid: _roleUuid,
  index: 0,
  exerciseUuid: 'ex-r1',
  name: 'Markør 1',
  actorUuid: _actorUuid,
);

Map<String, Object> _buildPrefs() => {
  'app:activeProgram:v1': _programUuid,
  'app:librarySchema:v1': '1',
  'p:$_programUuid': jsonEncode({
    'uuid': _programUuid,
    'name': 'Roster Test Plan',
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
  // One actor with phone.
  'pa:$_programUuid:$_actorUuid': jsonEncode({
    'uuid': _actorUuid,
    'realName': 'Per Hansen',
    'phone': '99887766',
  }),
  // One role cast to the actor (used for the delete-block test).
  'pr:$_programUuid:$_roleUuid': jsonEncode(_castRole.toJson()),
};

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildView() {
  final controller = RosterController();
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        floatingActionButton: controller.buildFAB(
          context,
          BoxConstraints.loose(const Size(400, 56)),
        ),
        body: RosterView(controller: controller),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(_buildPrefs());
    await ProgramService().init();
  });

  testWidgets('actor name appears in the list', (tester) async {
    await tester.pumpWidget(_buildView());
    await tester.pump();
    expect(find.text('Per Hansen'), findsOneWidget);
  });

  testWidgets('actor phone appears in the list', (tester) async {
    await tester.pumpWidget(_buildView());
    await tester.pump();
    expect(find.text('99887766'), findsOneWidget);
  });

  testWidgets('tapping an actor row opens ActorFormScreen in edit mode',
      (tester) async {
    await tester.pumpWidget(_buildView());
    await tester.pump();

    await tester.tap(find.text('Per Hansen'));
    await tester.pumpAndSettle();

    expect(find.byType(ActorFormScreen), findsOneWidget);
    // In edit mode the AppBar title shows the actor's real name.
    expect(find.text('Per Hansen'), findsWidgets);
  });

  testWidgets('FAB with newActor label is present', (tester) async {
    await tester.pumpWidget(_buildView());
    await tester.pump();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text(l10n.newActor), findsOneWidget);
  });

  testWidgets('tapping FAB opens ActorFormScreen in create mode',
      (tester) async {
    await tester.pumpWidget(_buildView());
    await tester.pump();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(ActorFormScreen), findsOneWidget);
    // In create mode the AppBar title shows "New actor" (at minimum once).
    expect(find.text(l10n.newActor), findsWidgets);
  });

  testWidgets('swiping a cast actor shows castDeleteBlocked SnackBar',
      (tester) async {
    await tester.pumpWidget(_buildView());
    await tester.pumpAndSettle();

    // Swipe the actor row end-to-start past the dismiss threshold.
    // Default test screen is 800 px wide; threshold is 40 % (320 px).
    await tester.drag(find.text('Per Hansen'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.castDeleteBlocked(1)), findsOneWidget);
  });
}
