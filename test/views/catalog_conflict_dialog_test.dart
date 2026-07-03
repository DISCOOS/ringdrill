import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/catalog_conflict_dialog.dart';

/// Coverage for the responsive presentation (bottom sheet on mobile, larger
/// dialog on wide form factors) and the field-level "what changed" detail
/// added to the catalog conflict diff, so a modified exercise/rolePlay shows
/// which fields changed and their before/after values, not just its name.
void main() {
  final diff = ProgramDiff(
    modifiedExercises: [
      ItemDiff(
        name: 'Ladder',
        changes: [
          FieldChange(
            field: 'methodMd',
            local: 'Old method',
            remote: 'New method',
          ),
          const FieldChange(field: 'stations'),
        ],
      ),
    ],
    addedTeams: const ['Green'],
    modifiedRolePlays: [
      ItemDiff(
        name: 'Anna',
        changes: [FieldChange(field: 'age', local: '30', remote: '31')],
      ),
    ],
  );

  CatalogConflictChoice? result;

  Future<void> openDialog(
    WidgetTester tester, {
    bool withSnackBar = false,
  }) async {
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                if (withSnackBar) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Refreshing…')),
                  );
                }
                result = await showCatalogConflictDialog(
                  context,
                  diff: diff,
                  ownedSlug: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows a Dialog with field-level diff detail on wide surfaces',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await openDialog(tester);

      expect(find.byType(Dialog), findsOneWidget);
      // Modified exercise shows its name plus which fields changed and
      // their before/after values — not just "Ladder" in a bare list.
      expect(find.textContaining('Old method'), findsOneWidget);
      expect(find.textContaining('New method'), findsOneWidget);
      // A structural (non-scalar) change renders the field label alone.
      expect(find.textContaining('Stations'), findsOneWidget);
      // RolePlays now get their own diff group (previously missing).
      expect(find.textContaining('Anna'), findsOneWidget);
      expect(find.textContaining('30'), findsOneWidget);
      expect(find.textContaining('31'), findsOneWidget);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.catalogConflictOverwrite));
      await tester.pumpAndSettle();
      expect(result, CatalogConflictChoice.overwriteLocal);
    },
  );

  testWidgets('shows a bottom sheet (no Dialog) on narrow surfaces', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await openDialog(tester);

    expect(find.byType(Dialog), findsNothing);
    expect(find.textContaining('Old method'), findsOneWidget);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.catalogConflictCancel));
    await tester.pumpAndSettle();
    expect(result, CatalogConflictChoice.cancel);
  });

  testWidgets(
    'wide dialog only dismisses via action buttons (not barrier/back)',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await openDialog(tester);
      expect(find.byType(Dialog), findsOneWidget);

      // Barrier tap must not dismiss.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(result, isNull);

      // System back must not dismiss.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(result, isNull);

      // An explicit action still closes it.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.catalogConflictCancel));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(result, CatalogConflictChoice.cancel);
    },
  );

  testWidgets(
    'narrow sheet only dismisses via action buttons (no drag, no back)',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await openDialog(tester);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.catalogConflictTitle), findsOneWidget);

      // Non-draggable, so the drag-handle affordance is hidden.
      expect(
        find.byKey(const Key('ringdrill-sheet-drag-handle')),
        findsNothing,
      );

      // Dragging down must not dismiss.
      await tester.drag(
        find.text(l10n.catalogConflictTitle),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.catalogConflictTitle), findsOneWidget);
      expect(result, isNull);

      // System back must not dismiss.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.text(l10n.catalogConflictTitle), findsOneWidget);
      expect(result, isNull);

      // An explicit action still closes it.
      await tester.tap(find.text(l10n.catalogConflictPublish));
      await tester.pumpAndSettle();
      expect(find.text(l10n.catalogConflictTitle), findsNothing);
      expect(result, CatalogConflictChoice.publishMyChanges);
    },
  );

  testWidgets('hides a visible snackbar when first shown', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await openDialog(tester, withSnackBar: true);

    // The "Refreshing…" snackbar shown just before the conflict surfaced
    // must be gone once the sheet is up.
    expect(find.byType(SnackBar), findsNothing);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.catalogConflictTitle), findsOneWidget);
  });

  testWidgets('plan-level changes render as the first group', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final planFirstDiff = ProgramDiff(
      nameLocal: 'My plan',
      nameRemote: 'My plan (catalog)',
      modifiedExercises: diff.modifiedExercises,
    );
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showCatalogConflictDialog(
                  context,
                  diff: planFirstDiff,
                  ownedSlug: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final planGroupTop = tester
        .getTopLeft(find.text(l10n.catalogDiffPlan))
        .dy;
    final exercisesGroupTop = tester
        .getTopLeft(find.text(l10n.catalogDiffExercises))
        .dy;
    expect(planGroupTop, lessThan(exercisesGroupTop));
  });

  testWidgets(
    'header close icon pops with the cancel choice, same as the Cancel button',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await openDialog(tester);
      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(result, CatalogConflictChoice.cancel);
    },
  );

  Exercise buildExercise(String uuid, String name, {int index = 0}) =>
      Exercise(
        uuid: uuid,
        index: index,
        name: name,
        startTime: const SimpleTimeOfDay(hour: 8, minute: 0),
        numberOfTeams: 1,
        numberOfRounds: 1,
        executionTime: 10,
        evaluationTime: 5,
        rotationTime: 2,
        stations: const [Station(index: 0, name: 'Station 1')],
        schedule: const [
          [
            SimpleTimeOfDay(hour: 8, minute: 0),
            SimpleTimeOfDay(hour: 8, minute: 10),
            SimpleTimeOfDay(hour: 8, minute: 15),
          ],
        ],
        endTime: const SimpleTimeOfDay(hour: 8, minute: 17),
      );

  Future<void> openRealDiffDialog(WidgetTester tester, ProgramDiff realDiff) async {
    result = null;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showCatalogConflictDialog(
                  context,
                  diff: realDiff,
                  ownedSlug: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a pure reorder of same-named exercises shows one card per exercise, '
    'not "Other changes"',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Mirrors the reported bug: two exercises sharing a name (a routine
      // occurrence — the same round repeated) swap positions. Built via the
      // real diffPrograms(), not a hand-authored ProgramDiff, so this is an
      // end-to-end regression check on the diff engine itself.
      final local = Program(
        uuid: 'p1',
        name: 'Test',
        description: '',
        metadata: ProgramMetadata(
          created: DateTime(2026),
          updated: DateTime(2026),
          version: '1.0',
        ),
        teams: const [],
        sessions: const [],
        exercises: [
          buildExercise('ex-1', 'Førsteinnsats søk', index: 0),
          buildExercise('ex-2', 'Førsteinnsats søk', index: 1),
        ],
      );
      final remote = local.copyWith(
        exercises: [
          buildExercise('ex-1', 'Førsteinnsats søk', index: 1),
          buildExercise('ex-2', 'Førsteinnsats søk', index: 0),
        ],
      );
      final realDiff = diffPrograms(local, remote);

      await openRealDiffDialog(tester, realDiff);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.catalogDiffReorderedTo('#1')), findsOneWidget);
      expect(find.text(l10n.catalogDiffReorderedTo('#2')), findsOneWidget);
      expect(find.textContaining(l10n.catalogDiffFieldOther), findsNothing);
      // Two distinct cards for the two identically-named exercises — the
      // number badges are what tells them apart.
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
    },
  );

  testWidgets(
    'reordering and editing the same exercise shows both facts on one card',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final local = Program(
        uuid: 'p1',
        name: 'Test',
        description: '',
        metadata: ProgramMetadata(
          created: DateTime(2026),
          updated: DateTime(2026),
          version: '1.0',
        ),
        teams: const [],
        sessions: const [],
        exercises: [
          buildExercise('ex-1', 'Warmup', index: 0),
          buildExercise('ex-2', 'Ladder', index: 1),
        ],
      );
      final remote = local.copyWith(
        exercises: [
          buildExercise('ex-1', 'Warmup', index: 1),
          buildExercise(
            'ex-2',
            'Ladder',
            index: 0,
          ).copyWith(methodMd: 'New method'),
        ],
      );
      final realDiff = diffPrograms(local, remote);

      await openRealDiffDialog(tester, realDiff);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // 'Ladder' both moved (to #1) and had its method edited — one card,
      // both facts, not split across two sections.
      expect(find.text(l10n.catalogDiffReorderedTo('#1')), findsOneWidget);
      expect(find.textContaining('New method'), findsOneWidget);
    },
  );
}
