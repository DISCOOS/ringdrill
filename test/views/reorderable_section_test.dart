// Tests for ReorderableSection<T> (ADR-0036).
//
// Each test harness pumps a minimal MaterialApp containing a
// ReorderableSection<String> so we can exercise the header, mode toggle,
// deferred-commit logic, and the enabled flag without any domain coupling.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/reorderable_section.dart';

// ---------------------------------------------------------------------------
// Minimal harness
// ---------------------------------------------------------------------------

/// Pumps a [ReorderableSection<String>] with the supplied [items].
///
/// [onCommitReorder] is invoked (and stored in [commits]) on every Done tap.
/// [enabled] controls whether the reorder toggle is shown.
/// [externalNotifier] lets the test supply a host-owned reorder-mode flag.
class _Harness extends StatefulWidget {
  const _Harness({
    required this.items,
    required this.commits,
    this.enabled = true,
    this.externalNotifier,
  });

  final List<String> items;
  final List<List<String>> commits;
  final bool enabled;
  final ValueNotifier<bool>? externalNotifier;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late List<String> _items;

  @override
  void initState() {
    super.initState();
    _items = List<String>.from(widget.items);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ReorderableSection<String>(
      items: _items,
      keyOf: (item) => ValueKey(item),
      orderLabel: l10n.exerciseSortBy,
      enabled: widget.enabled,
      reorderMode: widget.externalNotifier,
      onCommitReorder: (newOrder) {
        widget.commits.add(List<String>.from(newOrder));
        setState(() => _items = List<String>.from(newOrder));
      },
      itemBuilder: (context, item, position, reordering, dragHandle) {
        return ListTile(
          key: ValueKey(item),
          title: Text(item),
          trailing: reordering ? dragHandle : null,
        );
      },
    );
  }
}

Widget _wrap(_Harness harness) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: harness),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Load l10n once so we can read key strings.
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('ReorderableSection — header visibility', () {
    testWidgets('header is hidden when items < 2', (tester) async {
      final commits = <List<String>>[];
      await tester.pumpWidget(
        _wrap(_Harness(items: ['Only'], commits: commits)),
      );
      await tester.pumpAndSettle();

      // No anchor label, no toggle.
      expect(find.text(l10n.exerciseSortBy), findsNothing);
      expect(find.text(l10n.exerciseReorderMode), findsNothing);
    });

    testWidgets('header shows for 2+ items in default mode', (tester) async {
      final commits = <List<String>>[];
      await tester.pumpWidget(
        _wrap(_Harness(items: ['A', 'B'], commits: commits)),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.exerciseSortBy), findsOneWidget);
      expect(find.text(l10n.exerciseReorderMode), findsOneWidget);
    });

    testWidgets('reorder toggle hidden when enabled: false', (tester) async {
      final commits = <List<String>>[];
      await tester.pumpWidget(
        _wrap(
          _Harness(items: ['A', 'B', 'C'], enabled: false, commits: commits),
        ),
      );
      await tester.pumpAndSettle();

      // Anchor label visible but toggle is absent.
      expect(find.text(l10n.exerciseSortBy), findsOneWidget);
      expect(find.text(l10n.exerciseReorderMode), findsNothing);
    });
  });

  group('ReorderableSection — mode toggle', () {
    testWidgets(
      'entering reorder mode shows drag handles and Done button',
      (tester) async {
        final commits = <List<String>>[];
        await tester.pumpWidget(
          _wrap(_Harness(items: ['A', 'B', 'C'], commits: commits)),
        );
        await tester.pumpAndSettle();

        // Default: no handles.
        expect(find.byIcon(Icons.drag_handle), findsNothing);
        expect(find.text(l10n.exerciseReorderDone), findsNothing);

        await tester.tap(find.text(l10n.exerciseReorderMode));
        await tester.pumpAndSettle();

        // Reorder: one handle per item, Done visible, Reorder gone.
        expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
        expect(find.text(l10n.exerciseReorderDone), findsOneWidget);
        expect(find.text(l10n.exerciseReorderMode), findsNothing);
      },
    );

    testWidgets(
      'tapping Done exits reorder mode and restores the default view',
      (tester) async {
        final commits = <List<String>>[];
        await tester.pumpWidget(
          _wrap(_Harness(items: ['A', 'B', 'C'], commits: commits)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.exerciseReorderMode));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.exerciseReorderDone));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.drag_handle), findsNothing);
        expect(find.text(l10n.exerciseReorderMode), findsOneWidget);
      },
    );

    testWidgets(
      'external notifier flip forces exit from reorder mode',
      (tester) async {
        final commits = <List<String>>[];
        final notifier = ValueNotifier<bool>(false);
        addTearDown(notifier.dispose);

        await tester.pumpWidget(
          _wrap(
            _Harness(
              items: ['A', 'B', 'C'],
              commits: commits,
              externalNotifier: notifier,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter reorder mode via the notifier.
        notifier.value = true;
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));

        // Force-exit via the notifier (simulates segment switch).
        notifier.value = false;
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.drag_handle), findsNothing);
      },
    );
  });

  group('ReorderableSection — deferred commit', () {
    testWidgets(
      'onCommitReorder is NOT called on each drag drop — only on Done',
      (tester) async {
        final commits = <List<String>>[];
        await tester.pumpWidget(
          _wrap(_Harness(items: ['A', 'B', 'C'], commits: commits)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.exerciseReorderMode));
        await tester.pumpAndSettle();

        // Simulate a drag via the ReorderableListView callback.
        final listView = tester.widget<ReorderableListView>(
          find.byType(ReorderableListView).first,
        );
        listView.onReorderItem!(0, 2); // move A from 0 to 2 → [B, C, A]
        await tester.pumpAndSettle();

        // onCommitReorder not called yet — deferred until Done.
        expect(commits, isEmpty);

        // UI already reflects the new order.
        final titles = tester
            .widgetList<ListTile>(find.byType(ListTile))
            .map((t) => (t.title as Text).data!)
            .toList();
        expect(titles, ['B', 'C', 'A']);

        // Press Done — now the commit fires.
        await tester.tap(find.text(l10n.exerciseReorderDone));
        await tester.pumpAndSettle();

        expect(commits.length, 1);
        expect(commits.first, ['B', 'C', 'A']);
      },
    );

    testWidgets(
      'draft order is shown synchronously without waiting for onCommitReorder',
      (tester) async {
        final commits = <List<String>>[];
        await tester.pumpWidget(
          _wrap(_Harness(items: ['A', 'B', 'C'], commits: commits)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(l10n.exerciseReorderMode));
        await tester.pumpAndSettle();

        final listView = tester.widget<ReorderableListView>(
          find.byType(ReorderableListView).first,
        );
        listView.onReorderItem!(2, 0); // move C from 2 to 0 → [C, A, B]
        await tester.pumpAndSettle();

        final titles = tester
            .widgetList<ListTile>(find.byType(ListTile))
            .map((t) => (t.title as Text).data!)
            .toList();
        expect(titles, ['C', 'A', 'B']);
        // Still no commit.
        expect(commits, isEmpty);
      },
    );
  });
}
