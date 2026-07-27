import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

/// Inline mode: a host that renders the target *itself* — the fullscreen drill
/// player (ADR-0056) — rather than presenting it in a modal route or a
/// master/detail pane.
///
/// Regression: `show()`'s "navigate within the open sheet" branch is gated on
/// `_navigator != null`, which is null for an inline controller, so an
/// in-player `show()` used to fall through and open a modal *on top of* the
/// player. Dismissing that modal then ran the modal-close cleanup
/// (`_target = null; _isOpen = false`), blanking the player permanently and
/// making every later navigation open yet another modal.
void main() {
  group('inline navigation', () {
    testWidgets('show replaces the host body in place, pushing no route', (
      tester,
    ) async {
      final controller = ContextSheetController()
        ..adoptInlineTarget(
          const ExerciseSheetTarget(exerciseUuid: 'exercise-1'),
        );
      addTearDown(controller.dispose);
      final observer = _RouteObserver();
      await tester.pumpWidget(
        _InlineHarness(controller: controller, observer: observer),
      );
      await tester.pumpAndSettle();
      final initialRoute = observer.lastPushed;

      expect(find.text('body: exercise'), findsOneWidget);

      await tester.tap(find.text('show station'));
      await tester.pumpAndSettle();

      expect(find.text('body: station'), findsOneWidget);
      expect(find.text('body: exercise'), findsNothing);
      expect(
        observer.lastPushed,
        same(initialRoute),
        reason: 'no surface may open over an inline host',
      );
      expect(observer.poppedRoutes, isEmpty);
    });

    // The failure mode that made the old behaviour unrecoverable: not the
    // stacked modal itself but the state it left behind on dismissal.
    testWidgets('show leaves the controller open and inline', (tester) async {
      final controller = ContextSheetController()
        ..adoptInlineTarget(
          const ExerciseSheetTarget(exerciseUuid: 'exercise-1'),
        );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_InlineHarness(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('show station'));
      await tester.pumpAndSettle();

      expect(controller.isOpen, isTrue);
      expect(controller.isInline, isTrue);
      expect(controller.isModal, isFalse);
      expect(controller.target.value, isA<StationSheetTarget>());
    });

    // Briefs are the deliberate exception: they are a modal surface by
    // definition, and must restore the host's state — including its inline
    // mode — on dismissal.
    testWidgets('a brief opens its own modal and restores the inline state', (
      tester,
    ) async {
      const initial = ExerciseSheetTarget(exerciseUuid: 'exercise-1');
      final controller = ContextSheetController()..adoptInlineTarget(initial);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_InlineHarness(controller: controller));
      await tester.pumpAndSettle();

      await tester.tap(find.text('show brief'));
      await tester.pumpAndSettle();

      expect(find.text('body: brief'), findsOneWidget);
      expect(
        controller.isInline,
        isFalse,
        reason:
            'while the brief is up, navigation must not swap the host body '
            'behind it',
      );

      await tester.tap(find.byTooltip('Close brief'));
      await tester.pumpAndSettle();

      expect(find.text('body: brief'), findsNothing);
      expect(find.text('body: exercise'), findsOneWidget);
      expect(controller.isInline, isTrue);
      expect(controller.isOpen, isTrue);
      expect(controller.target.value, same(initial));
    });
  });

  group('clearSelection', () {
    // close() is a no-op on an adoptWideSelection target: with no navigator to
    // pop and no active scope, it returns without touching the target. The
    // docked mini player needs the pane actually cleared before it opens the
    // player over it.
    test('empties a wide selection that close() leaves standing', () {
      final controller = ContextSheetController();
      addTearDown(controller.dispose);
      controller.adoptWideSelection(
        const ExerciseSheetTarget(exerciseUuid: 'exercise-1'),
      );

      controller.close();
      expect(controller.target.value, isNotNull);
      expect(controller.isOpen, isTrue);

      controller.clearSelection();
      expect(controller.target.value, isNull);
      expect(controller.isOpen, isFalse);
      expect(controller.isInline, isFalse);
    });
  });
}

/// Mirrors `DrillPlayerCoordinator.openDrillPlayer`: a route with its own
/// [ContextSheet] over an inline controller, whose body *is* the target.
class _InlineHarness extends StatelessWidget {
  const _InlineHarness({required this.controller, this.observer});

  final ContextSheetController controller;
  final NavigatorObserver? observer;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [?observer],
      home: ContextSheet(
        controller: controller,
        bodyBuilder: _body,
        child: ValueListenableBuilder<ContextSheetTarget?>(
          valueListenable: controller.target,
          builder: (context, target, _) {
            if (target == null) return const SizedBox.shrink();
            return KeyedSubtree(
              key: ValueKey(target),
              child: _body(context, target),
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ContextSheetTarget target) {
    final label = switch (target) {
      ExerciseSheetTarget() => 'exercise',
      StationSheetTarget() => 'station',
      TeamSheetTarget() => 'team',
      TeamOverviewSheetTarget() => 'team-overview',
      RoleSheetTarget() => 'role',
      BriefSheetTarget() => 'brief',
    };
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('body: $label'),
            if (target is BriefSheetTarget)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close brief',
                onPressed: () => Navigator.pop(context),
              ),
            if (target is ExerciseSheetTarget) ...[
              TextButton(
                onPressed: () => ContextSheet.of(context).show(
                  context,
                  const StationSheetTarget(
                    exerciseUuid: 'exercise-1',
                    stationIndex: 0,
                  ),
                ),
                child: const Text('show station'),
              ),
              TextButton(
                onPressed: () => ContextSheet.of(
                  context,
                ).show(context, const BriefSheetTarget(planUuid: 'plan-1')),
                child: const Text('show brief'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteObserver extends NavigatorObserver {
  Route<dynamic>? lastPushed;
  final poppedRoutes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastPushed = route;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    poppedRoutes.add(route);
  }
}
