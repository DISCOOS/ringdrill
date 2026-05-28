import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

void main() {
  testWidgets('show opens a sheet whose body matches the initial target', (
    tester,
  ) async {
    final controller = ContextSheetController();
    await tester.pumpWidget(_Harness(controller: controller));

    await tester.tap(find.text('show station'));
    await tester.pumpAndSettle();

    expect(find.text('body: station'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('replace swaps body without dismissing the route', (
    tester,
  ) async {
    final controller = ContextSheetController();
    final observer = _RouteObserver();
    await tester.pumpWidget(
      _Harness(controller: controller, observer: observer),
    );

    await tester.tap(find.text('show station'));
    await tester.pumpAndSettle();
    final route = observer.lastPushed;

    await tester.tap(find.text('replace team'));
    await tester.pumpAndSettle();

    expect(find.text('body: team'), findsOneWidget);
    expect(observer.lastPushed, same(route));
    expect(observer.poppedRoutes, isEmpty);
    controller.dispose();
  });

  testWidgets('close dismisses the sheet and resets target to null', (
    tester,
  ) async {
    final controller = ContextSheetController();
    await tester.pumpWidget(_Harness(controller: controller));

    await tester.tap(find.text('show station'));
    await tester.pumpAndSettle();
    controller.close();
    await tester.pumpAndSettle();

    expect(find.text('body: station'), findsNothing);
    expect(controller.target.value, isNull);
    controller.dispose();
  });

  testWidgets('show after close opens a new sheet', (tester) async {
    final controller = ContextSheetController();
    final observer = _RouteObserver();
    await tester.pumpWidget(
      _Harness(controller: controller, observer: observer),
    );

    await tester.tap(find.text('show station'));
    await tester.pumpAndSettle();
    final firstRoute = observer.lastPushed;
    controller.close();
    await tester.pumpAndSettle();

    await tester.tap(find.text('show station'));
    await tester.pumpAndSettle();

    expect(observer.lastPushed, isNot(same(firstRoute)));
    expect(find.text('body: station'), findsOneWidget);
    controller.dispose();
  });
}

class _Harness extends StatelessWidget {
  const _Harness({required this.controller, this.observer});

  final ContextSheetController controller;
  final NavigatorObserver? observer;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [?observer],
      home: ContextSheet(
        controller: controller,
        bodyBuilder: (context, target) {
          final label = switch (target) {
            StationSheetTarget() => 'station',
            TeamSheetTarget() => 'team',
            RoleSheetTarget() => 'role',
            BriefSheetTarget() => 'brief',
          };
          return Center(
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
              ],
            ),
          );
        },
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
                ],
              ),
            );
          },
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
