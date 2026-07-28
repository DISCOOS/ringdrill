import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

/// [ContextSheetController.showOrReplace] has to tell "something is presenting
/// this target" from "something has merely *selected* it".
///
/// Regression it used to have: the test was [ContextSheetController.isOpen],
/// but [ContextSheetController.adoptWideSelection] sets that with no navigator
/// and no scope. `MainScreen` re-adopts the remembered target on every
/// Plan-segment change — in the compact layout too, where there is no detail
/// pane to render it — so after opening an item once and closing it, every
/// later open went through `replace`, wrote the target into the void, and
/// nothing appeared. Only surfaces still calling `show()` directly (the Lag
/// segment) kept working, which is how it was spotted.
const _station = StationSheetTarget(
  exerciseUuid: 'exercise-1',
  stationIndex: 0,
);
const _team = TeamSheetTarget(exerciseUuid: 'exercise-1', teamIndex: 1);

void main() {
  testWidgets('reopens after a close, despite a re-adopted wide selection', (
    tester,
  ) async {
    final controller = ContextSheetController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_Harness(controller: controller));

    await tester.tap(find.text('open station'));
    await tester.pumpAndSettle();
    expect(find.text('body: station'), findsOneWidget);

    controller.close();
    await tester.pumpAndSettle();
    expect(find.text('body: station'), findsNothing);

    // What MainScreen's selection memory does on the next segment change.
    // Nothing is presenting it: the compact layout has no detail pane.
    controller.adoptWideSelection(_station);

    await tester.tap(find.text('open station'));
    await tester.pumpAndSettle();

    expect(
      find.text('body: station'),
      findsOneWidget,
      reason: 'a remembered selection must not block the next open',
    );
  });

  testWidgets('a re-adopted selection does not accumulate routes', (
    tester,
  ) async {
    final controller = ContextSheetController();
    addTearDown(controller.dispose);
    final observer = _RouteObserver();
    await tester.pumpWidget(
      _Harness(controller: controller, observer: observer),
    );

    await tester.tap(find.text('open station'));
    await tester.pumpAndSettle();
    controller.close();
    await tester.pumpAndSettle();
    controller.adoptWideSelection(_station);
    await tester.tap(find.text('open station'));
    await tester.pumpAndSettle();

    // One sheet route per open (plus MaterialApp's own home route), the first
    // of them dismissed — not a stack of orphaned sheets.
    expect(observer.pushedRoutes.length, 3);
    expect(observer.poppedRoutes.length, 1);
  });

  // Preserves the reason showOrReplace does not *always* delegate to show():
  // in the wide layout that would re-latch the scope and null the navigator,
  // losing a modal sitting above a detail pane.
  testWidgets('navigates within an already-open modal, pushing no route', (
    tester,
  ) async {
    final controller = ContextSheetController();
    addTearDown(controller.dispose);
    final observer = _RouteObserver();
    await tester.pumpWidget(
      _Harness(controller: controller, observer: observer),
    );

    await tester.tap(find.text('open station'));
    await tester.pumpAndSettle();
    final routes = observer.pushedRoutes.length;

    // Driven from inside the sheet: the shell's own buttons sit behind the
    // modal barrier, where a tap dismisses rather than reaches them.
    await tester.tap(find.text('open team from body'));
    await tester.pumpAndSettle();

    expect(find.text('body: team'), findsOneWidget);
    expect(observer.pushedRoutes.length, routes);
    expect(observer.poppedRoutes, isEmpty);
  });

  group('with a master/detail scope', () {
    testWidgets('routes through the scope, so close() clears the pane', (
      tester,
    ) async {
      final controller = ContextSheetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _Harness(controller: controller, withScope: true),
      );

      // The wide layout's auto-select-first, before any explicit tap.
      controller.adoptWideSelection(_team);
      await tester.pumpAndSettle();

      await tester.tap(find.text('open station'));
      await tester.pumpAndSettle();
      expect(find.text('body: station'), findsOneWidget);

      // The old replace path left _activeScope null, so close() returned
      // without touching the pane and the station stayed put.
      controller.close();
      await tester.pumpAndSettle();

      expect(find.text('body: station'), findsNothing);
      expect(find.text('empty pane'), findsOneWidget);
    });
  });
}

class _Harness extends StatelessWidget {
  const _Harness({
    required this.controller,
    this.observer,
    this.withScope = false,
  });

  final ContextSheetController controller;
  final NavigatorObserver? observer;

  /// Wide layout. Left false for the compact layout, where a re-adopted
  /// selection has nothing rendering it — the state the bug needed.
  final bool withScope;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [?observer],
      home: ContextSheet(
        controller: controller,
        bodyBuilder: _bodyBuilder,
        // The buttons must be built BELOW the scope, or `show()` cannot find it
        // and opens a modal over the pane instead of filling it.
        child: withScope
            ? MasterDetailScope(
                target: controller.targetNotifier,
                emptyPaneBuilder: (_) =>
                    const Center(child: Text('empty pane')),
                bodyBuilder: _bodyBuilder,
                child: Builder(
                  builder: (context) => Scaffold(
                    body: Column(
                      children: [
                        _buttons(context),
                        const Expanded(child: MasterDetailPane()),
                      ],
                    ),
                  ),
                ),
              )
            : Builder(builder: (context) => Scaffold(body: _buttons(context))),
      ),
    );
  }

  Widget _buttons(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      TextButton(
        onPressed: () =>
            ContextSheet.of(context).showOrReplace(context, _station),
        child: const Text('open station'),
      ),
      TextButton(
        onPressed: () => ContextSheet.of(context).showOrReplace(context, _team),
        child: const Text('open team'),
      ),
    ],
  );

  Widget _bodyBuilder(BuildContext context, ContextSheetTarget target) {
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
            if (target is StationSheetTarget)
              TextButton(
                onPressed: () =>
                    ContextSheet.of(context).showOrReplace(context, _team),
                child: const Text('open team from body'),
              ),
          ],
        ),
      ),
    );
  }
}

class _RouteObserver extends NavigatorObserver {
  final pushedRoutes = <Route<dynamic>>[];
  final poppedRoutes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    poppedRoutes.add(route);
  }
}
