import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/teaching_empty_state.dart';

void main() {
  testWidgets('renders icon, title, body, and optional action', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeachingEmptyState(
            icon: Icons.update,
            title: 'No exercises yet',
            body: 'Add your first to see the ring in motion.',
            actionLabel: 'Create',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.update), findsOneWidget);
    expect(find.text('No exercises yet'), findsOneWidget);
    expect(
      find.text('Add your first to see the ring in motion.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Create'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    expect(tapped, isTrue);
  });
}
