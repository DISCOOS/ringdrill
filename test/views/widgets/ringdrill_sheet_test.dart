import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';

void main() {
  const handleKey = Key('ringdrill-sheet-drag-handle');

  testWidgets('viewer sheet opens with drag handle above body only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showRingdrillViewerSheet<void>(
                context: context,
                builder: (context, scrollController) {
                  return const Center(child: Text('viewer body'));
                },
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(handleKey), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.text('viewer body'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(handleKey)).dy,
      lessThan(tester.getTopLeft(find.text('viewer body')).dy),
    );

    Navigator.of(tester.element(find.text('viewer body'))).pop();
    await tester.pumpAndSettle();

    expect(find.text('viewer body'), findsNothing);
  });

  testWidgets('action sheet opens with drag handle and no close button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _Harness(
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showRingdrillActionSheet<void>(
                context: context,
                builder: (context) => const Text('action body'),
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(handleKey), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.text('action body'), findsOneWidget);
  });

  testWidgets(
    'viewer and action sheets share surface color and corner radius',
    (tester) async {
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          surface: const Color(0xfff4fbf9),
        ),
      );
      await tester.pumpWidget(
        _Harness(
          theme: theme,
          child: Builder(
            builder: (context) {
              return Column(
                children: [
                  TextButton(
                    onPressed: () => showRingdrillViewerSheet<void>(
                      context: context,
                      builder: (context, scrollController) {
                        return const Text('viewer body');
                      },
                    ),
                    child: const Text('viewer'),
                  ),
                  TextButton(
                    onPressed: () => showRingdrillActionSheet<void>(
                      context: context,
                      builder: (context) => const Text('action body'),
                    ),
                    child: const Text('action'),
                  ),
                ],
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('viewer'));
      await tester.pumpAndSettle();

      _expectSharedChrome(tester, theme.colorScheme.surface);

      Navigator.of(tester.element(find.text('viewer body'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('action'));
      await tester.pumpAndSettle();

      _expectSharedChrome(tester, theme.colorScheme.surface);
    },
  );

  testWidgets('viewer body is constrained to 720 px on wide screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _Harness(
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showRingdrillViewerSheet<void>(
                context: context,
                builder: (context, scrollController) {
                  return Container(
                    key: const Key('viewer-body'),
                    color: Colors.blue,
                  );
                },
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(const Key('viewer-body'))).width, 720);
  });

  testWidgets('viewer body is not constrained on narrow screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _Harness(
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showRingdrillViewerSheet<void>(
                context: context,
                builder: (context, scrollController) {
                  return Container(
                    key: const Key('viewer-body'),
                    color: Colors.blue,
                  );
                },
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(const Key('viewer-body'))).width, 400);
  });

  testWidgets('action sheet wraps its body in SafeArea', (tester) async {
    await tester.pumpWidget(
      _Harness(
        child: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showRingdrillActionSheet<void>(
                context: context,
                builder: (context) => const Text('action body'),
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text('action body'),
        matching: find.byType(SafeArea),
      ),
      findsAtLeastNWidgets(1),
    );
  });
}

void _expectSharedChrome(WidgetTester tester, Color surface) {
  final materials = tester.widgetList<Material>(
    find.ancestor(
      of: find.byKey(const Key('ringdrill-sheet-drag-handle')),
      matching: find.byType(Material),
    ),
  );
  expect(materials.any((material) => material.color == surface), isTrue);

  final clip = tester.widget<ClipRRect>(
    find.ancestor(
      of: find.byKey(const Key('ringdrill-sheet-drag-handle')),
      matching: find.byType(ClipRRect),
    ),
  );
  expect(
    clip.borderRadius,
    const BorderRadius.vertical(top: Radius.circular(16)),
  );
}

class _Harness extends StatelessWidget {
  const _Harness({required this.child, this.theme});

  final Widget child;
  final ThemeData? theme;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: child),
      theme: theme,
    );
  }
}
