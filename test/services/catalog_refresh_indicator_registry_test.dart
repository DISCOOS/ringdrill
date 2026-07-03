import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/services/catalog_refresh_indicator_registry.dart';

void main() {
  testWidgets('trigger returns false when nothing is registered', (
    tester,
  ) async {
    expect(await CatalogRefreshIndicatorRegistry().trigger(), isFalse);
  });

  testWidgets(
    'trigger shows the registered RefreshIndicator and runs its onRefresh',
    (tester) async {
      final key = GlobalKey<RefreshIndicatorState>();
      var refreshed = false;
      // Held open deliberately, so the indicator can't dismiss out from
      // under the assertion below — onRefresh only completes once the test
      // explicitly does so, giving a stable window to check the spinner.
      final refreshGate = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: RefreshIndicator(
            key: key,
            onRefresh: () {
              refreshed = true;
              return refreshGate.future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 2000)],
            ),
          ),
        ),
      );

      // Stored once and reused for both calls — registerProvider/
      // unregisterProvider match by closure equality, and two separately
      // *evaluated* `() => key` literals are never `==` to each other, only
      // the same evaluated closure object referenced twice.
      GlobalKey<RefreshIndicatorState>? provider() => key;
      CatalogRefreshIndicatorRegistry().registerProvider(provider);
      addTearDown(
        () => CatalogRefreshIndicatorRegistry().unregisterProvider(provider),
      );

      final result = CatalogRefreshIndicatorRegistry().trigger();
      // Advance past RefreshIndicator's internal 150ms snap-in animation
      // (the drag→armed→"snap into place"→"refresh" sequence .show()
      // replays programmatically) so the indeterminate spinner is actually
      // composed into the tree.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(refreshed, isTrue);
      expect(find.byType(RefreshProgressIndicator), findsOneWidget);

      refreshGate.complete();
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    },
  );

  testWidgets('unregisterProvider clears the registration', (tester) async {
    GlobalKey<RefreshIndicatorState>? provider() => null;
    CatalogRefreshIndicatorRegistry().registerProvider(provider);
    CatalogRefreshIndicatorRegistry().unregisterProvider(provider);
    expect(await CatalogRefreshIndicatorRegistry().trigger(), isFalse);
  });

  testWidgets(
    'unregisterProvider is a no-op when a different provider is current',
    (tester) async {
      final key = GlobalKey<RefreshIndicatorState>();
      GlobalKey<RefreshIndicatorState>? current() => key;
      GlobalKey<RefreshIndicatorState>? stale() => null;

      CatalogRefreshIndicatorRegistry().registerProvider(current);
      addTearDown(
        () => CatalogRefreshIndicatorRegistry().unregisterProvider(current),
      );
      // Simulates a disposed widget's stale unregister call racing a fresh
      // registration — it must not clear the still-live one.
      CatalogRefreshIndicatorRegistry().unregisterProvider(stale);

      // No RefreshIndicator is mounted for `key`, so `.currentState` is
      // null and trigger() still reports false — but that's a *different*
      // reason than "nothing registered", which the first test covers.
      expect(await CatalogRefreshIndicatorRegistry().trigger(), isFalse);
    },
  );
}
