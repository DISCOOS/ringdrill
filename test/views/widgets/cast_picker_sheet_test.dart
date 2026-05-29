import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/widgets/cast_picker_sheet.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _programUuid = 'prog-1';
const _exerciseUuid = 'ex-1';

const _actorUncast = Actor(uuid: 'actor-a', realName: 'Anna Skov');
const _actorCast = Actor(uuid: 'actor-b', realName: 'Bjørn Lie');

const _roleA = RolePlay(
  uuid: 'role-a',
  index: 0,
  exerciseUuid: _exerciseUuid,
  name: 'Pasient A',
);
const _roleB = RolePlay(
  uuid: 'role-b',
  index: 1,
  exerciseUuid: _exerciseUuid,
  name: 'Pasient B',
  actorUuid: 'actor-b', // cast to _actorCast
);

/// Seeds SharedPreferences with a program, two roles, and two actors,
/// then initialises ProgramService.
Future<void> _seedAndInit() async {
  SharedPreferences.setMockInitialValues({
    'app:activeProgram:v1': _programUuid,
    'app:librarySchema:v1': '1',
    'p:$_programUuid': jsonEncode({
      'uuid': _programUuid,
      'name': 'Test Program',
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
    'pr:$_programUuid:${_roleA.uuid}': jsonEncode(_roleA.toJson()),
    'pr:$_programUuid:${_roleB.uuid}': jsonEncode(_roleB.toJson()),
    'pa:$_programUuid:${_actorUncast.uuid}': jsonEncode(_actorUncast.toJson()),
    'pa:$_programUuid:${_actorCast.uuid}': jsonEncode(_actorCast.toJson()),
  });
  await ProgramService().init();
}

Widget _buildPicker(RolePlay rolePlay) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: CastPickerSheet(rolePlay: rolePlay)),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(_seedAndInit);

  testWidgets('shows all actors and new-actor row', (tester) async {
    await tester.pumpWidget(_buildPicker(_roleA));
    await tester.pump();

    expect(find.text(_actorUncast.realName), findsOneWidget);
    expect(find.text(_actorCast.realName), findsOneWidget);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.newActor), findsOneWidget);
    expect(find.text(l10n.clearCast), findsNothing);
  });

  testWidgets('shows clear row and selected actor when role has actor', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPicker(_roleB));
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.clearCast), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(l10n.newActor)).dy,
      lessThan(tester.getTopLeft(find.text(l10n.clearCast)).dy),
    );
    expect(
      tester.getTopLeft(find.byType(Divider)).dy,
      greaterThan(tester.getTopLeft(find.text(l10n.clearCast)).dy),
    );
    expect(
      tester.getTopLeft(find.byType(Divider)).dy,
      lessThan(tester.getTopLeft(find.text(_actorUncast.realName)).dy),
    );

    final selectedTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text(_actorCast.realName),
        matching: find.byType(ListTile),
      ),
    );
    expect(selectedTile.selected, isTrue);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text(_actorCast.realName),
          matching: find.byType(ListTile),
        ),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
  });

  testWidgets('cross-cast annotation shown for actor cast to sibling role', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPicker(_roleA));
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // _actorCast is cast to _roleB; _roleA is in the same exercise
    expect(find.text(l10n.alreadyCastAs(_roleB.name)), findsOneWidget);
  });

  testWidgets('search filters by realName', (tester) async {
    await tester.pumpWidget(_buildPicker(_roleA));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Anna');
    await tester.pump();

    expect(find.text(_actorUncast.realName), findsOneWidget);
    expect(find.text(_actorCast.realName), findsNothing);
  });

  testWidgets('selecting an actor closes picker and returns uuid', (
    tester,
  ) async {
    CastPickerResult? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await showModalBottomSheet<CastPickerResult>(
                context: ctx,
                builder: (_) => CastPickerSheet(rolePlay: _roleA),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_actorUncast.realName));
    await tester.pumpAndSettle();

    expect(
      result,
      isA<CastPickerSelect>().having(
        (result) => result.actorUuid,
        'actorUuid',
        _actorUncast.uuid,
      ),
    );
  });

  testWidgets('clear row closes picker and returns clear result', (
    tester,
  ) async {
    CastPickerResult? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await showModalBottomSheet<CastPickerResult>(
                context: ctx,
                builder: (_) => CastPickerSheet(rolePlay: _roleB),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.clearCast));
    await tester.pumpAndSettle();

    expect(result, isA<CastPickerClear>());
  });

  testWidgets('opens inside Ringdrill action sheet without layout errors', (
    tester,
  ) async {
    CastPickerResult? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await showRingdrillActionSheet<CastPickerResult>(
                context: ctx,
                builder: (_) => CastPickerSheet(rolePlay: _roleA),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_actorUncast.realName), findsOneWidget);

    await tester.tap(find.text(_actorUncast.realName));
    await tester.pumpAndSettle();

    expect(
      result,
      isA<CastPickerSelect>().having(
        (result) => result.actorUuid,
        'actorUuid',
        _actorUncast.uuid,
      ),
    );
  });
}
