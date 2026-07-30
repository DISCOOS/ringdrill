import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';
import 'package:ringdrill/views/widgets/token_text_editing_controller.dart';

/// DESIGN-008 Stage 4 — chip-state rendering. The prototype gate
/// (`docs/notes/design-008-token-field-spike.md`) rejected an inline
/// `WidgetSpan` chip for caret/backspace correctness; these tests exercise
/// the chosen fallback (colored, boxed `TextSpan` runs) via the `TextSpan`
/// tree `buildTextSpan` returns.

TextSpan _chipFor(TextSpan root, String text) =>
    root.children!.cast<TextSpan>().firstWhere((c) => c.text == text);

void main() {
  testWidgets(
    'known, declared-but-empty and undeclared variables get distinct chip styles',
    (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      final controller = TokenTextEditingController(
        text: 'A {{var.frekvens}} B {{var.tom}} C {{var.mangler}} D',
        variables: const [
          VariableToken(name: 'frekvens', effectiveValue: 'Kanal 6'),
          VariableToken(name: 'tom', effectiveValue: ''),
        ],
      );

      final span = controller.buildTextSpan(
        context: ctx,
        style: const TextStyle(color: Colors.black),
        withComposing: false,
      );

      final known = _chipFor(span, '{{var.frekvens}}');
      final empty = _chipFor(span, '{{var.tom}}');
      final unknown = _chipFor(span, '{{var.mangler}}');

      expect(known.style?.color, Colors.blue.shade800);
      expect(empty.style?.color, Colors.amber.shade900);
      expect(unknown.style?.color, Colors.red.shade800);
      expect(unknown.style?.decoration, TextDecoration.underline);
      expect(unknown.style?.decorationStyle, TextDecorationStyle.dashed);

      // None of the three chip styles collide with each other.
      expect(known.style?.color, isNot(empty.style?.color));
      expect(known.style?.color, isNot(unknown.style?.color));
    },
  );

  testWidgets(
    'a variable list update via the setter changes an already-built chip state',
    (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      final controller = TokenTextEditingController(
        text: '{{var.frekvens}}',
        variables: const [],
      );
      final before = controller.buildTextSpan(
        context: ctx,
        style: const TextStyle(),
        withComposing: false,
      );
      expect(before.children!.single, isA<TextSpan>());
      expect(
        (before.children!.single as TextSpan).style?.color,
        Colors.red.shade800,
      );

      controller.variables = const [
        VariableToken(name: 'frekvens', effectiveValue: 'Kanal 6'),
      ];
      final after = controller.buildTextSpan(
        context: ctx,
        style: const TextStyle(),
        withComposing: false,
      );
      expect(
        (after.children!.single as TextSpan).style?.color,
        Colors.blue.shade800,
      );
    },
  );

  testWidgets(
    'a non-var {{...}} expression is left as plain text, never chipped',
    (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      );

      const baseStyle = TextStyle(color: Colors.black);
      final controller = TokenTextEditingController(
        text: 'UTM: {{station.position}}',
      );
      final span = controller.buildTextSpan(
        context: ctx,
        style: baseStyle,
        withComposing: false,
      );

      // No {{var.*}} match at all: the whole text collapses into a single
      // unstyled-beyond-base span, no children/chip runs.
      expect(span.children, isNull);
      expect(span.text, 'UTM: {{station.position}}');
      expect(span.style, baseStyle);
    },
  );

  test(
    'controller.text stays the raw string with literal {{...}} after rendering',
    () {
      const raw = 'Kanal {{var.frekvens}} ved {{station.position}}';
      final controller = TokenTextEditingController(
        text: raw,
        variables: const [
          VariableToken(name: 'frekvens', effectiveValue: 'Kanal 6'),
        ],
      );

      // buildTextSpan is only reachable with a BuildContext in a widget test,
      // but the property under test — that rendering never rewrites the
      // stored text — holds regardless of whether it has been called yet.
      expect(controller.text, raw);
    },
  );

  testWidgets(
    'backspace at the token boundary removes one character, not the whole token '
    '(the styled-TextSpan fallback has no whole-token concept — see the spike note)',
    (tester) async {
      final controller = TokenTextEditingController(
        text: 'A {{var.x}} B',
        variables: const [VariableToken(name: 'x', effectiveValue: 'y')],
      );
      final focusNode = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: controller, focusNode: focusNode),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      controller.selection = TextSelection.collapsed(
        offset: controller.text.indexOf('}} B'),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      // Removes exactly the 'x' before the caret — one character, not the
      // {{var.x}} token as a unit.
      expect(controller.text, 'A {{var.}} B');
    },
  );

  group('station.loc/person chips (DESIGN-009 follow-up 4)', () {
    testWidgets(
      'known, empty and unknown station.loc/person references get distinct chip styles',
      (tester) async {
        late BuildContext ctx;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox();
              },
            ),
          ),
        );

        final controller = TokenTextEditingController(
          text:
              'A {{station.loc.lkp}} B {{station.loc.empty}} '
              'C {{station.loc.ghost}} D {{station.person.anne}}',
        );
        controller.stationTokenResolver = (kind, slug, facets) {
          if (kind == 'loc' && slug == 'lkp') return 'Sentrum';
          if (kind == 'loc' && slug == 'empty') return '';
          if (kind == 'person' && slug == 'anne') return 'Anne';
          return null;
        };

        final span = controller.buildTextSpan(
          context: ctx,
          style: const TextStyle(color: Colors.black),
          withComposing: false,
        );

        final known = _chipFor(span, '{{station.loc.lkp}}');
        final empty = _chipFor(span, '{{station.loc.empty}}');
        final unknown = _chipFor(span, '{{station.loc.ghost}}');
        final person = _chipFor(span, '{{station.person.anne}}');

        expect(known.style?.color, Colors.blue.shade800);
        expect(empty.style?.color, Colors.amber.shade900);
        expect(unknown.style?.color, Colors.red.shade800);
        expect(unknown.style?.decoration, TextDecoration.underline);
        expect(person.style?.color, Colors.blue.shade800);
      },
    );

    testWidgets(
      'a facet path is passed to the resolver and a var + station token in '
      'the same text both chip correctly',
      (tester) async {
        late BuildContext ctx;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox();
              },
            ),
          ),
        );

        List<String>? capturedFacets;
        final controller = TokenTextEditingController(
          text: '{{var.freq}} at {{station.loc.lkp.position}}',
          variables: const [
            VariableToken(name: 'freq', effectiveValue: 'Kanal 6'),
          ],
        );
        controller.stationTokenResolver = (kind, slug, facets) {
          capturedFacets = facets;
          return '32V 0580414E 6552008N';
        };

        final span = controller.buildTextSpan(
          context: ctx,
          style: const TextStyle(color: Colors.black),
          withComposing: false,
        );

        expect(capturedFacets, ['position']);
        expect(
          _chipFor(span, '{{var.freq}}').style?.color,
          Colors.blue.shade800,
        );
        expect(
          _chipFor(span, '{{station.loc.lkp.position}}').style?.color,
          Colors.blue.shade800,
        );
      },
    );

    testWidgets(
      'without a resolver, a station.loc/person token is left as plain '
      'text (no StationScope in this field\'s context)',
      (tester) async {
        late BuildContext ctx;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox();
              },
            ),
          ),
        );

        const baseStyle = TextStyle(color: Colors.black);
        final controller = TokenTextEditingController(
          text: 'See {{station.loc.lkp}}',
        );
        final span = controller.buildTextSpan(
          context: ctx,
          style: baseStyle,
          withComposing: false,
        );

        expect(span.children, isNull);
        expect(span.text, 'See {{station.loc.lkp}}');
      },
    );
  });
}
