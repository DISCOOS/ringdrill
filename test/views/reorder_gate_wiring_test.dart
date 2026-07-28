import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/edit_permissions.dart';
import 'package:ringdrill/views/widgets/reorderable_section.dart';

/// Reordering is an edit, so it is director-only (ADR-0057).
///
/// Changing the order renumbers exercises and posts for every device reading the
/// plan, which is exactly the kind of change the matrix reserves to the director
/// — it is not a display preference, even though the control sits in a list
/// header next to one.
///
/// Gated inside [ReorderableSection] rather than at its three call sites, so the
/// assertions here cover every reorderable list at once and a fourth cannot ship
/// ungated. Both affordances the header carries are covered: the drag toggle and
/// the one-shot sort actions, which commit a new order just as permanently.
const _items = ['Alpha', 'Bravo', 'Charlie'];

class _Harness extends StatelessWidget {
  const _Harness({this.sortActions = const []});

  final List<SortAction> sortActions;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ReorderableSection<String>(
          items: _items,
          keyOf: (item) => ValueKey(item),
          orderLabel: 'Order',
          target: EditTarget.exercise,
          sortActions: sortActions,
          onCommitReorder: (_) {},
          itemBuilder: (context, item, position, reordering, dragHandle) =>
              ListTile(
                key: ValueKey(item),
                title: Text(item),
                trailing: reordering ? dragHandle : null,
              ),
        ),
      ),
    );
  }
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    appUserRole.value = AppUserRole.director;
    addTearDown(() => appUserRole.value = AppUserRole.director);
  });

  testWidgets('a director gets the reorder toggle', (tester) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    expect(find.text(l10n.exerciseReorderMode), findsOneWidget);
  });

  testWidgets('an actor does not', (tester) async {
    appUserRole.value = AppUserRole.actor;
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    expect(find.text(l10n.exerciseReorderMode), findsNothing);
    // The rows themselves stay: the gate removes the affordance, not the list.
    for (final item in _items) {
      expect(find.text(item), findsOneWidget);
    }
  });

  testWidgets('nor an instructor', (tester) async {
    appUserRole.value = AppUserRole.instructor;
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    expect(find.text(l10n.exerciseReorderMode), findsNothing);
  });

  // A one-shot sort commits a new order without ever entering reorder mode, so
  // gating only the toggle would leave the whole thing reachable.
  testWidgets('the one-shot sort actions are gated too', (tester) async {
    final sortActions = [(label: 'By name', onPressed: () {})];

    await tester.pumpWidget(_Harness(sortActions: sortActions));
    await tester.pumpAndSettle();
    expect(find.text('By name'), findsOneWidget);

    appUserRole.value = AppUserRole.actor;
    await tester.pumpAndSettle();

    expect(
      find.text('By name'),
      findsNothing,
      reason: 'sorting commits an order as permanently as dragging does',
    );
  });

  // Switching role while dragging must not leave the list in a mode this role no
  // longer has: the handles would still be live.
  testWidgets('a role change mid-reorder leaves the mode', (tester) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.exerciseReorderMode));
    await tester.pumpAndSettle();
    expect(find.text(l10n.exerciseReorderDone), findsOneWidget);

    appUserRole.value = AppUserRole.actor;
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.exerciseReorderDone),
      findsNothing,
      reason: 'the Done bar belongs to a mode this role cannot be in',
    );
    // And back to director: the toggle returns, not the Done bar — the mode was
    // exited, not merely hidden.
    appUserRole.value = AppUserRole.director;
    await tester.pumpAndSettle();

    expect(find.text(l10n.exerciseReorderMode), findsOneWidget);
    expect(find.text(l10n.exerciseReorderDone), findsNothing);
  });
}
