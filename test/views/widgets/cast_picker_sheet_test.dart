import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/widgets/cast_picker_sheet.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

Finder _pencilFor(String realName) => find.descendant(
  of: find.ancestor(
    of: find.text(realName),
    matching: find.byType(ListTile),
  ),
  matching: find.byIcon(Icons.edit_outlined),
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _planUuid = 'prog-1';
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

/// Seeds SharedPreferences with a plan, two roles, and two actors,
/// then initialises PlanService.
Future<void> _seedAndInit() async {
  SharedPreferences.setMockInitialValues({
    'app:activePlan:v1': _planUuid,
    'app:librarySchema:v1': '1',
    'p:$_planUuid': jsonEncode({
      'uuid': _planUuid,
      'name': 'Test Plan',
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
    'pr:$_planUuid:${_roleA.uuid}': jsonEncode(_roleA.toJson()),
    'pr:$_planUuid:${_roleB.uuid}': jsonEncode(_roleB.toJson()),
    'pa:$_planUuid:${_actorUncast.uuid}': jsonEncode(_actorUncast.toJson()),
    'pa:$_planUuid:${_actorCast.uuid}': jsonEncode(_actorCast.toJson()),
  });
  await PlanService().init();
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
    // Actions live at the bottom (like "Velg person"), below the actor list:
    // the actor rows come before "Ny markør", which comes before "Fjern markør".
    expect(
      tester.getTopLeft(find.text(_actorUncast.realName)).dy,
      lessThan(tester.getTopLeft(find.text(l10n.newActor)).dy),
    );
    expect(
      tester.getTopLeft(find.text(l10n.newActor)).dy,
      lessThan(tester.getTopLeft(find.text(l10n.clearCast)).dy),
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

  testWidgets('search (shown past the threshold) filters by realName', (
    tester,
  ) async {
    // Search only renders once the list is long enough (like the shared
    // picker), so seed enough actors to cross the threshold.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    for (var i = 0; i < 6; i++) {
      await PlanService().saveActor(
        l10n,
        Actor(uuid: 'extra-$i', realName: 'Extra $i'),
      );
    }
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

  group('showCastPickerSheet (ADR-0049 adaptive surface)', () {
    Future<void> open(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () async {
                await showCastPickerSheet(ctx, rolePlay: _roleA);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the static "Velg markør" title', (tester) async {
      await open(tester, 1000);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.pickerSelectRolePlayTitle), findsOneWidget);
    });

    testWidgets('compact width opens as a bottom sheet, no close button', (
      tester,
    ) async {
      await open(tester, 400);

      expect(
        find.byKey(const Key('ringdrill-sheet-drag-handle')),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('expanded width opens as a dialog with a close button', (
      tester,
    ) async {
      await open(tester, 1000);

      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.byKey(const Key('ringdrill-sheet-drag-handle')),
        findsNothing,
      );
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------
  // DESIGN-010 browser tile polish (Fix 4) — the sheet is the one
  // marker-management surface: no `⋮` context menu anywhere, and every
  // actor row carries its own edit pencil in addition to add/remove/change.
  // ---------------------------------------------------------------------
  group('per-row edit (Fix 4: no context menu, edit lives in the sheet)', () {
    testWidgets('no PopupMenuButton exists in the sheet', (tester) async {
      await tester.pumpWidget(_buildPicker(_roleA));
      await tester.pump();

      expect(
        find.byWidgetPredicate((w) => w is PopupMenuButton),
        findsNothing,
      );
    });

    testWidgets(
      'the pencil opens ActorFormScreen for that row\'s own actor and '
      'saving updates the name in place without closing the sheet',
      (tester) async {
        await tester.pumpWidget(_buildPicker(_roleA));
        await tester.pump();

        await tester.tap(_pencilFor(_actorUncast.realName));
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await tester.enterText(
          find.widgetWithText(TextFormField, _actorUncast.realName),
          'Anna Skog',
        );
        await tester.tap(find.text(l10n.save));
        await tester.pumpAndSettle();

        // Still the sheet, not popped — the new name shows in the list.
        expect(find.text('Anna Skog'), findsOneWidget);
        expect(find.text(_actorUncast.realName), findsNothing);
        expect(find.byType(CastPickerSheet), findsOneWidget);
      },
    );

    testWidgets(
      'deleting an actor who is still cast to a role is blocked, sheet '
      'stays open',
      (tester) async {
        await tester.pumpWidget(_buildPicker(_roleA));
        await tester.pump();

        // _actorCast is cast to _roleB — still blocked even from _roleA's
        // own sheet, since the guard is "cast to any role", not just this one.
        await tester.tap(_pencilFor(_actorCast.realName));
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await tester.tap(find.byIcon(Icons.delete));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.delete));
        await tester.pumpAndSettle();

        expect(find.text(l10n.castDeleteBlocked(1)), findsOneWidget);
        expect(find.byType(CastPickerSheet), findsOneWidget);
        // Still listed — the delete never went through.
        expect(find.text(_actorCast.realName), findsOneWidget);
      },
    );
  });
}
