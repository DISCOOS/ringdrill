import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';

void main() {
  testWidgets('tap on empty space removes focus from a text field', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DismissKeyboard(
            child: Column(
              children: [
                TextField(focusNode: focusNode),
                const Expanded(child: SizedBox(key: Key('empty-space'))),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);

    await tester.tapAt(tester.getCenter(find.byKey(const Key('empty-space'))));
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
  });
}
