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
  // `local` is the user's current/new value, `remote` the catalog's
  // old/stored value — the dialog reads old → new (remote → local), so the
  // strings below are deliberately named to catch a regression if that
  // order ever flips back (see the "field change direction" test below).
  final diff = ProgramDiff(
    modifiedExercises: [
      ItemDiff(
        name: 'Ladder',
        changes: [
          FieldChange(
            field: 'methodMd',
            local: 'New method',
            remote: 'Old method',
          ),
          const FieldChange(field: 'stations'),
        ],
      ),
    ],
    addedTeams: const ['Green'],
    modifiedRolePlays: [
      ItemDiff(
        name: 'Anna',
        changes: [FieldChange(field: 'age', local: '31', remote: '30')],
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
      // their before/after values — not just "Ladder" in a bare list. "Old"
      // and "New" render as separate colored spans (not one contiguous
      // "Old method"/"New method" phrase) since the shared word "method"
      // only appears once in the word-diff — see the dedicated direction
      // test below for the actual old/new color assertion.
      expect(find.textContaining('Old'), findsOneWidget);
      expect(find.textContaining('New'), findsOneWidget);
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

  testWidgets(
    'a field change reads old (catalog) to new (local), not the reverse, '
    'and drops the changed/endret verb from the label',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await openDialog(tester);

      // The label is just "Method: " now — the colored diff itself is the
      // signal something changed, so the verb is redundant.
      expect(find.textContaining('Method:'), findsOneWidget);
      expect(find.textContaining('Method changed'), findsNothing);

      // Regression: this previously rendered "New" as the struck-through
      // (deleted/old) word and "Old" as the kept (inserted/new) one —
      // backwards, since `local` (the user's current edit) is the new
      // value and `remote` (the catalog's stored value) is the old one.
      // "Old" and "New" don't share any words, so the word-diff renders
      // them as a single replace: "Old" struck through, "New" kept plain.
      expect(_spanStyle(tester, 'Old')?.decoration, TextDecoration.lineThrough);
      expect(_spanStyle(tester, 'New')?.decoration, isNot(TextDecoration.lineThrough));
    },
  );

  testWidgets(
    'action buttons are right-aligned against the dialog edge, not just '
    'grouped within their own bounding box',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await openDialog(tester);

      // Regression: a bare Wrap inside this Column (CrossAxisAlignment.start)
      // sizes itself to its own content, so WrapAlignment.end had nothing to
      // align against — the whole group sat flush left instead of right.
      // OverflowBar stretches to the full row width first, so its trailing
      // child's right edge must land on the same x as the close icon's
      // mirrored left inset.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final publishBox =
          tester.renderObject(
                find.widgetWithText(
                  FilledButton,
                  l10n.catalogConflictPublish,
                ),
              )
              as RenderBox;
      final publishRight =
          publishBox.localToGlobal(Offset.zero).dx + publishBox.size.width;

      // The content Padding (EdgeInsets.fromLTRB(16, 8, 16, 12) in
      // catalog_conflict_dialog.dart) sets the dialog's content bounds —
      // found by its exact padding value rather than find.byType(Padding)
      // .first, since ancestor traversal order among several Padding
      // widgets is not something this test should depend on.
      final contentPadding = find.byWidgetPredicate(
        (w) =>
            w is Padding &&
            w.padding == const EdgeInsets.fromLTRB(16, 8, 16, 12),
      );
      final contentBox = tester.renderObject(contentPadding) as RenderBox;
      // The Padding's own RenderBox reports its outer bound, before the
      // inset is subtracted — knock off the 16px right inset to get the
      // actual content edge the buttons should align against.
      final contentRight =
          contentBox.localToGlobal(Offset.zero).dx +
          contentBox.size.width -
          16;

      expect(publishRight, closeTo(contentRight, 1));
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
    expect(find.textContaining('Old'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
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
      await tester.tap(find.byIcon(Icons.close));
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
    final planGroupTop = tester.getTopLeft(find.text(l10n.catalogDiffPlan)).dy;
    final exercisesGroupTop = tester
        .getTopLeft(find.text(l10n.catalogDiffExercises))
        .dy;
    expect(planGroupTop, lessThan(exercisesGroupTop));
  });

  testWidgets(
    'a plan-level rename uses the same colored word-diff rendering as '
    'every other field change, not the old two-line Your version/Catalog '
    'version layout',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final planRenameDiff = ProgramDiff(
        nameLocal: 'My plan',
        nameRemote: 'My plan (catalog)',
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
                    diff: planRenameDiff,
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
      // The old rendering ("Your version: X" / "Catalog version: Y" on two
      // separate lines, no coloring) must be gone entirely.
      expect(find.textContaining(l10n.catalogDiffLocal), findsNothing);
      expect(find.textContaining(l10n.catalogDiffRemote), findsNothing);
      // Same muted-label-without-verb convention as every other field.
      expect(find.textContaining('${l10n.catalogDiffName}:'), findsOneWidget);
      expect(find.textContaining('Name changed'), findsNothing);
      // "(catalog)" only exists on the remote/old side and was deleted —
      // proves this goes through the real word-diff, not plain text.
      expect(
        _spanStyle(tester, '(catalog)')?.decoration,
        TextDecoration.lineThrough,
      );
    },
  );

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
      // ex-1 was #2 in the catalog and is now #1 locally; ex-2 the reverse.
      expect(
        find.text(l10n.catalogDiffReorderedFromTo('#2', '#1')),
        findsOneWidget,
      );
      expect(
        find.text(l10n.catalogDiffReorderedFromTo('#1', '#2')),
        findsOneWidget,
      );
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
      // 'Ladder' was #1 in the catalog and is now #2 locally, and also had
      // its method edited — one card, both facts, not split across two
      // sections.
      expect(
        find.text(l10n.catalogDiffReorderedFromTo('#1', '#2')),
        findsOneWidget,
      );
      expect(find.textContaining('New method'), findsOneWidget);
    },
  );

  testWidgets(
    'a station edit renders nested under its exercise, indented like any '
    'other field change',
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
        exercises: [buildExercise('ex-1', 'Søk og redning', index: 0)],
      );
      final remote = local.copyWith(
        exercises: [
          local.exercises.single.copyWith(
            stations: [
              local.exercises.single.stations.single.copyWith(
                name: 'Gammelt navn',
              ),
            ],
          ),
        ],
      );
      final realDiff = diffPrograms(local, remote);

      await openRealDiffDialog(tester, realDiff);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // "Poster" (stationsTab) sub-header, dotted station label "1.1" (the
      // only station of exercise #1), and its own field label without the
      // dropped verb.
      expect(find.text(l10n.stationsTab), findsOneWidget);
      expect(find.text('1.1'), findsOneWidget);
      expect(find.textContaining('Name:'), findsOneWidget);
      expect(find.textContaining('Name changed'), findsNothing);

      // The exercise row and the station row sit at the same left edge —
      // the "Poster" block moves as one unit, not just its header — since
      // both rows lead with their own number badge at that same indent.
      final exerciseBadgeLeft = tester.getTopLeft(find.text('#1')).dx;
      final stationBadgeLeft = tester.getTopLeft(find.text('1.1')).dx;
      expect(stationBadgeLeft, closeTo(exerciseBadgeLeft, 1));
    },
  );

  testWidgets(
    'reordering two stations with unchanged names shows no changes at all '
    'for that exercise',
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
          buildExercise('ex-1', 'Søk og redning', index: 0).copyWith(
            stations: const [
              Station(index: 0, name: 'Fremrykning'),
              Station(index: 1, name: 'Søk i rasmasse'),
            ],
          ),
        ],
      );
      final remote = local.copyWith(
        exercises: [
          local.exercises.single.copyWith(
            stations: const [
              Station(index: 0, name: 'Søk i rasmasse'),
              Station(index: 1, name: 'Fremrykning'),
            ],
          ),
        ],
      );
      final realDiff = diffPrograms(local, remote);

      // Nothing meaningfully differs (before name-based matching, this
      // looked like both stations fully changed), so the exercise never
      // shows up as modified at all — matching against a diff with nothing
      // in it, we can only assert the dialog opens without any exercise
      // section rendering.
      expect(realDiff.modifiedExercises, isEmpty);

      await openRealDiffDialog(tester, realDiff);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.catalogDiffExercises), findsNothing);
      expect(find.text(l10n.stationsTab), findsNothing);
      expect(find.textContaining(l10n.catalogDiffFieldOther), findsNothing);
    },
  );

  testWidgets(
    'a station added only in the catalog shows under Added, not as a full '
    'card',
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
        exercises: [buildExercise('ex-1', 'Søk og redning', index: 0)],
      );
      final remote = local.copyWith(
        exercises: [
          local.exercises.single.copyWith(
            stations: [
              ...local.exercises.single.stations,
              const Station(index: 1, name: 'Ny post'),
            ],
          ),
        ],
      );
      final realDiff = diffPrograms(local, remote);

      await openRealDiffDialog(tester, realDiff);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.stationsTab), findsOneWidget);
      expect(
        find.text('${l10n.catalogDiffAdded}: Ny post'),
        findsOneWidget,
      );
    },
  );
}

/// Returns the resolved [TextStyle] of the first [TextSpan] found anywhere
/// in the widget tree whose exact text matches [text], or null if none is
/// found. Used to assert on word-diff coloring/decoration without needing
/// to match an entire interpolated string.
///
/// [InlineSpan.visitChildren] already recursively visits a span and every
/// descendant, calling the visitor once per span — it must NOT be combined
/// with a second layer of manual recursion (calling visitChildren again
/// inside the visitor for the same span re-visits it and never terminates).
TextStyle? _spanStyle(WidgetTester tester, String text) {
  TextStyle? found;
  for (final richText in tester.widgetList<RichText>(find.byType(RichText))) {
    richText.text.visitChildren((span) {
      if (span is TextSpan && span.text == text) {
        found = span.style;
        return false;
      }
      return true;
    });
    if (found != null) break;
  }
  return found;
}
