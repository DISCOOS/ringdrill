import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/optional_field_sections.dart';

enum _DemoSection { alpha, beta }

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final _alpha = TextEditingController();
  final _beta = TextEditingController();
  final _activeIds = <_DemoSection>{};

  @override
  void dispose() {
    _alpha.dispose();
    _beta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: OptionalFieldSections<_DemoSection>(
            sections: [
              OptionalFieldSection(
                id: _DemoSection.alpha,
                label: 'Alpha',
                controller: _alpha,
              ),
              OptionalFieldSection(
                id: _DemoSection.beta,
                label: 'Beta',
                controller: _beta,
              ),
            ],
            activeIds: _activeIds,
            onAdd: (id) => setState(() => _activeIds.add(id)),
            onRemove: (id) => setState(() {
              _activeIds.remove(id);
              switch (id) {
                case _DemoSection.alpha:
                  _alpha.clear();
                case _DemoSection.beta:
                  _beta.clear();
              }
            }),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('add button reveals the section field, remove hides it', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());

    // No active sections initially; both labels render only inside the add
    // buttons.
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    // Add Alpha — its field appears, the Alpha add-button disappears.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Alpha'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Alpha'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Beta'), findsOneWidget);

    // Type something and then remove the section.
    await tester.enterText(find.byType(TextFormField), 'hello');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Alpha'), findsOneWidget);
  });

  testWidgets('add buttons disappear once all sections are active', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());

    await tester.tap(find.widgetWithText(OutlinedButton, 'Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Beta'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
