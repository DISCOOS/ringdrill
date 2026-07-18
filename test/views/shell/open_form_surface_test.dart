import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';

Widget _harness({required Size size, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('compact opens form as a pushed route', (tester) async {
    await tester.pumpWidget(
      _harness(
        size: const Size(400, 800),
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                openFormSurface<void>(
                  context,
                  builder: (_) => const Scaffold(body: Text('Form')),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final formContext = tester.element(find.text('Form'));
    expect(Navigator.canPop(formContext), isTrue);
    expect(ModalRoute.of(formContext), isA<MaterialPageRoute<void>>());
  });

  testWidgets('wide opens form as a dialog route', (tester) async {
    await tester.pumpWidget(
      _harness(
        size: const Size(1024, 800),
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                openFormSurface<void>(
                  context,
                  builder: (_) => const Text('Form'),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final formContext = tester.element(find.text('Form'));
    expect(ModalRoute.of(formContext), isA<DialogRoute<void>>());
  });

  testWidgets(
    'FormSurfaceScope.of defaults to false, and reflects commitsToParent '
    'when set',
    (tester) async {
      late bool defaultValue;
      late bool explicitValue;

      await tester.pumpWidget(
        _harness(
          size: const Size(400, 800),
          child: Builder(
            builder: (context) {
              return Column(
                children: [
                  TextButton(
                    onPressed: () => openFormSurface<void>(
                      context,
                      // FormSurfaceScope is inserted as an *ancestor* of
                      // whatever `builder` returns, so probing it requires
                      // a descendant context (a nested Builder) — the
                      // `builder` callback's own argument is the pushed
                      // route's outer context, a sibling/parent of the
                      // scope, not a descendant of it.
                      builder: (_) => Builder(
                        builder: (innerContext) {
                          defaultValue = FormSurfaceScope.of(innerContext);
                          return const Text('Default form');
                        },
                      ),
                    ),
                    child: const Text('Open default'),
                  ),
                  TextButton(
                    onPressed: () => openFormSurface<void>(
                      context,
                      commitsToParent: true,
                      builder: (_) => Builder(
                        builder: (innerContext) {
                          explicitValue = FormSurfaceScope.of(innerContext);
                          return const Text('Commit-to-parent form');
                        },
                      ),
                    ),
                    child: const Text('Open commit-to-parent'),
                  ),
                ],
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open default'));
      await tester.pumpAndSettle();
      expect(defaultValue, isFalse);
      Navigator.of(tester.element(find.text('Default form'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open commit-to-parent'));
      await tester.pumpAndSettle();
      expect(explicitValue, isTrue);
    },
  );
}
