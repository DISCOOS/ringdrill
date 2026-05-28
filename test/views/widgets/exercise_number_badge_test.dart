import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/exercise_number_badge.dart';

Widget _harness(Widget badge) => MaterialApp(
      home: Scaffold(body: Center(child: badge)),
    );

void main() {
  testWidgets('renders #1 for number: 1', (tester) async {
    await tester.pumpWidget(_harness(const ExerciseNumberBadge(number: 1)));
    await tester.pumpAndSettle();
    expect(find.text('#1'), findsOneWidget);
  });

  testWidgets('renders #12 for number: 12 without overflow', (tester) async {
    await tester.pumpWidget(_harness(const ExerciseNumberBadge(number: 12)));
    await tester.pumpAndSettle();
    expect(find.text('#12'), findsOneWidget);
    // FittedBox should scale the text down without a RenderFlex overflow.
    // pumpAndSettle completing without exception is the assertion.
  });

  testWidgets('renders at custom size', (tester) async {
    await tester.pumpWidget(_harness(const ExerciseNumberBadge(number: 1, size: 36)));
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(ExerciseNumberBadge));
    expect(size.width, 36.0);
    expect(size.height, 36.0);
  });

  testWidgets('highlight: true paints with primary background', (tester) async {
    await tester.pumpWidget(
      _harness(const ExerciseNumberBadge(number: 3, highlight: true)),
    );
    await tester.pumpAndSettle();

    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ExerciseNumberBadge),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration as BoxDecoration;
    final scheme = Theme.of(
      tester.element(find.byType(ExerciseNumberBadge)),
    ).colorScheme;
    expect(decoration.color, scheme.primary);
  });
}
