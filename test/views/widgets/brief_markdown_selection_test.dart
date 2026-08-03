// Guards the framework behaviour that lets [BriefMarkdown]'s viewport be lazy.
//
// The brief used to render an eager `Column` inside a `SingleChildScrollView`
// purely so its `SelectionArea` could sit *inside* the scrollable: with the
// SelectionArea outside, a long-press-then-drag that started inside the
// Scrollable tripped the framework's `!_selectionStartsInScrollable` assertion
// (https://github.com/flutter/flutter/issues/115787). That eager layout is what
// made a real plan's brief take ~590 ms and 18,600 elements to open.
//
// The assertion no longer fires on the Flutter version this app pins, which is
// what made the lazy viewport in ADR-0069 available. If a future Flutter
// upgrade brings it back, this test fails here — with the reason — rather than
// as a crash in a user's hands while they drag to select a paragraph.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';

const _document = '''
# Plan title

## Exercise 1

A paragraph long enough to drag a selection across without running out of
glyphs part way through the gesture.

### Station 1a

Another paragraph, in a different section, so a drag between the two crosses a
section boundary in the lazy viewport.

Trailing prose so the document scrolls.
''';

Widget _host(BriefMarkdownController controller) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(
    builder: (context) => Scaffold(
      body: BriefMarkdown(
        data: _document,
        theme: BriefTheme.of(context),
        controller: controller,
      ),
    ),
  ),
);

void main() {
  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('long-press-drag with $kind does not assert', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = BriefMarkdownController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(controller));
      await tester.pump();

      final paragraph = find.byType(RichText);
      expect(paragraph, findsWidgets);

      final gesture = await tester.startGesture(
        tester.getCenter(paragraph.at(1)),
        kind: kind,
      );
      // Hold past the long-press threshold, then drag — the sequence that used
      // to assert, because the gesture both starts a selection and could scroll.
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveBy(const Offset(120, 60));
      await tester.pump();
      await gesture.moveBy(const Offset(60, 200));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('SelectionArea wraps the scrollable, not the other way round', (
    tester,
  ) async {
    final controller = BriefMarkdownController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(controller));
    await tester.pump();

    // The nesting order is the whole point: a SelectionArea *inside* the
    // scrollable forces every block to be laid out, because the thing it wraps
    // cannot be a lazy sliver list.
    expect(
      find.ancestor(
        of: find.byType(CustomScrollView),
        matching: find.byType(SelectionArea),
      ),
      findsOneWidget,
    );
    expect(find.byType(SingleChildScrollView), findsNothing);
  });
}
