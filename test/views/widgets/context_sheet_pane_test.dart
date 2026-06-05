import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

void main() {
  testWidgets('show renders station target in pane without opening a route', (
    tester,
  ) async {
    final controller = ContextSheetController();
    final observer = _RouteObserver();
    await tester.pumpWidget(
      _Harness(controller: controller, observer: observer),
    );

    await tester.tap(find.text('show station'));
    await tester.pumpAndSettle();

    expect(find.text('body: station'), findsOneWidget);
    expect(find.byKey(const Key('ringdrill-sheet-drag-handle')), findsNothing);
    expect(observer.pushedRoutes.length, 1);
    controller.dispose();
  });

  testWidgets('Brief target opens a sheet even with a scope present', (
    tester,
  ) async {
    final controller = ContextSheetController();
    final observer = _RouteObserver();
    await tester.pumpWidget(
      _Harness(controller: controller, observer: observer),
    );

    await tester.tap(find.text('show brief'));
    await tester.pumpAndSettle();

    expect(find.text('body: brief'), findsOneWidget);
    expect(
      find.byKey(const Key('ringdrill-sheet-drag-handle')),
      findsOneWidget,
    );
    expect(observer.pushedRoutes.length, 2);
    controller.dispose();
  });

  testWidgets('replace swaps pane body without opening or closing a route', (
    tester,
  ) async {
    final controller = ContextSheetController();
    final observer = _RouteObserver();
    await tester.pumpWidget(
      _Harness(controller: controller, observer: observer),
    );

    await tester.tap(find.text('show station'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('replace team'));
    await tester.pumpAndSettle();

    expect(find.text('body: team'), findsOneWidget);
    expect(observer.pushedRoutes.length, 1);
    expect(observer.poppedRoutes, isEmpty);
    controller.dispose();
  });

  testWidgets('close clears pane without popping Navigator', (tester) async {
    final controller = ContextSheetController();
    final observer = _RouteObserver();
    await tester.pumpWidget(
      _Harness(controller: controller, observer: observer),
    );

    await tester.tap(find.text('show station'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('close pane'));
    await tester.pumpAndSettle();

    expect(find.text('empty pane'), findsOneWidget);
    expect(find.text('body: station'), findsNothing);
    expect(observer.poppedRoutes, isEmpty);
    controller.dispose();
  });
}

class _Harness extends StatelessWidget {
  _Harness({required this.controller, this.observer});

  final ContextSheetController controller;
  final NavigatorObserver? observer;
  final ValueNotifier<ContextSheetTarget?> target =
      ValueNotifier<ContextSheetTarget?>(null);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [?observer],
      home: ContextSheet(
        controller: controller,
        bodyBuilder: _bodyBuilder,
        child: MasterDetailScope(
          target: controller.targetNotifier,
          emptyPaneBuilder: (_) => const Center(child: Text('empty pane')),
          bodyBuilder: _bodyBuilder,
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Column(
                  children: [
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
                      onPressed: () => ContextSheet.of(context).show(
                        context,
                        const BriefSheetTarget(programUuid: 'program-1'),
                      ),
                      child: const Text('show brief'),
                    ),
                    const Expanded(child: MasterDetailPane()),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

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
                onPressed: () => ContextSheet.of(context).replace(
                  const TeamSheetTarget(
                    exerciseUuid: 'exercise-1',
                    teamIndex: 1,
                  ),
                ),
                child: const Text('replace team'),
              ),
            TextButton(
              onPressed: () => ContextSheet.of(context).close(),
              child: const Text('close pane'),
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
