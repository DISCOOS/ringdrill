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
}
