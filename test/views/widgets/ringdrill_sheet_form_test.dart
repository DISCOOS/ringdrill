import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';

Widget _harness({required Size size, required Widget child}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('form dialog constrains body to 720 px on wide screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        size: const Size(1024, 800),
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showRingdrillFormDialog<void>(
                  context: context,
                  builder: (_) => const SizedBox.expand(key: Key('form-body')),
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

    expect(tester.getSize(find.byKey(const Key('form-body'))).width, 720);
  });

  testWidgets('form dialog does not artificially constrain narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        size: const Size(400, 800),
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showRingdrillFormDialog<void>(
                  context: context,
                  builder: (_) => const SizedBox.expand(key: Key('form-body')),
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

    expect(tester.getSize(find.byKey(const Key('form-body'))).width, 352);
  });

  testWidgets('form dialog returns Navigator.pop result', (tester) async {
    String? result;
    await tester.pumpWidget(
      _harness(
        size: const Size(1024, 800),
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showRingdrillFormDialog<String>(
                  context: context,
                  builder: (dialogContext) => TextButton(
                    onPressed: () => Navigator.pop(dialogContext, 'done'),
                    child: const Text('Done'),
                  ),
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
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(result, 'done');
  });
}
