import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Helper: recursively collect all TextSpan leaf colors from a widget's render tree.
Iterable<Color?> _collectTextColors(RichText widget) sync* {
  final span = widget.text;
  yield* _spanColors(span);
}

Iterable<Color?> _spanColors(InlineSpan span) sync* {
  yield span.style?.color;
  if (span is TextSpan && span.children != null) {
    for (final child in span.children!) {
      yield* _spanColors(child);
    }
  }
}

void main() {
  setUpAll(() {
    // Disable visibility_detector's 500 ms debounce timer so tests complete
    // without "pending timers" failures.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  const fixture = '# H1\n\nbody [link](https://example.com) and `code`.';
  final lightTheme = BriefTheme.light();

  Widget buildWidget({String? data}) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 800,
          child: BriefMarkdown(data: data ?? fixture, theme: lightTheme),
        ),
      ),
    );
  }

  group('BriefMarkdown — heading color', () {
    testWidgets('H1 text is rendered in theme.text.heading color', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      // Find all RichText widgets and check if any have a text span colored
      // with the heading color.
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      final allColors = richTexts
          .expand(_collectTextColors)
          .whereType<Color>()
          .toSet();

      expect(
        allColors,
        contains(lightTheme.text.heading),
        reason: 'At least one span should use the heading color',
      );
    });
  });

  group('BriefMarkdown — link style', () {
    testWidgets('link text uses body color with underline decoration', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      // Find a RichText that contains the link text "link"
      final linkFinder = find.byWidgetPredicate((widget) {
        if (widget is! RichText) return false;
        final plain = widget.text.toPlainText();
        return plain.contains('link');
      });

      expect(linkFinder, findsWidgets);

      // Collect all text styles from matching RichTexts and check for
      // underline with the expected color.
      bool foundUnderlinedBodyColor = false;
      for (final el in tester.widgetList<RichText>(linkFinder)) {
        for (final color in _collectTextColors(el)) {
          if (color == lightTheme.link.color) {
            foundUnderlinedBodyColor = true;
            break;
          }
        }
        // Also check the decoration via style inspection
        void checkSpan(InlineSpan span) {
          final style = span.style;
          if (style != null &&
              style.color == lightTheme.link.color &&
              style.decoration == TextDecoration.underline) {
            foundUnderlinedBodyColor = true;
          }
          if (span is TextSpan && span.children != null) {
            for (final child in span.children!) {
              checkSpan(child);
            }
          }
        }

        checkSpan(el.text);
      }

      expect(
        foundUnderlinedBodyColor,
        isTrue,
        reason: 'Link should use body color with underline',
      );
    });
  });

  group('BriefMarkdown — inline code chip', () {
    testWidgets('inline code renders as a padded chip with code.background', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      // Inline `code` is rendered via a WidgetSpan that wraps the text in a
      // padded, rounded Container. Look for a Container whose decoration
      // carries the BriefTheme code.background color.
      final chipFinder = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        return decoration.color == lightTheme.code.background;
      });

      expect(
        chipFinder,
        findsAtLeastNWidgets(1),
        reason: 'Inline code should render inside a Container chip with '
            'code.background as the fill',
      );

      // The chip should also have a non-zero border radius so it reads as a
      // chip rather than a flat fill.
      final chip = tester.widget<Container>(chipFinder.first);
      final decoration = chip.decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        isNotNull,
        reason: 'Code chip should have rounded corners',
      );
    });
  });
}
