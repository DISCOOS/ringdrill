// Performance regression tests for the brief reading surface.
//
// A real plan's brief is large — the 2026 LSOR øvelseshefte renders ~69 KB of
// markdown into ~740 top-level blocks, some 72,000 px tall. Two properties keep
// that openable, and both are the kind that regress silently because the small
// fixtures in `brief_screen_test.dart` are far too short to notice:
//
//   1. The viewport is lazy. Only the sections around the reading position are
//      built and laid out. Reverting to an eager `Column` inside a
//      `SingleChildScrollView` cost ~590 ms and 18,600 elements on first frame
//      versus ~56 ms and ~1,300 (ADR-0069).
//   2. The parse is memoised. `MarkdownGenerator.buildWidgets` on a document
//      this size is ~55 ms, and it used to run on every `setState` — so every
//      search keystroke and every audience switch paid it again.
//
// The third property, that a lazy viewport can still *navigate* to a heading it
// has not built, is a correctness consequence of (1) rather than a speed one,
// and is covered here too because the same change introduces both.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';

/// Number of H2 sections the synthetic document has, each with three H3
/// subsections. Chosen so the document is comparable in size and shape to a
/// real plan's brief (~30 navigable sections, tens of thousands of pixels tall)
/// without depending on a plan fixture or an asset.
const int _kSections = 10;

/// Builds a brief-shaped markdown document big enough for laziness to matter.
String _largeDocument() {
  final out = StringBuffer('# Plan title\n\n');
  out.writeln('Plan-level prose above the first exercise.\n');
  for (var e = 1; e <= _kSections; e++) {
    out.writeln('## Exercise $e\n');
    out.writeln('Exercise $e briefing paragraph.\n');
    for (var s = 1; s <= 3; s++) {
      out.writeln('### Station $e$s\n');
      out.writeln('#### Time\n');
      out.writeln('08:0$s - 09:0$s\n');
      out.writeln('#### Situation\n');
      for (var p = 0; p < 6; p++) {
        out.writeln(
          'Station $e$s situation paragraph $p. Enough running prose that the '
          'block genuinely needs laying out, with `a code chip` and a '
          '[link](https://example.com) in it.\n',
        );
      }
    }
  }
  return out.toString();
}

Widget _host({
  required String data,
  required BriefMarkdownController controller,
  Key? currentMatchKey,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: BriefMarkdown(
          data: data,
          theme: BriefTheme.of(context),
          controller: controller,
          currentMatchKey: currentMatchKey,
        ),
      ),
    ),
  );
}

void main() {
  late String document;

  setUpAll(() {
    document = _largeDocument();
  });

  setUp(() {
    BriefMarkdown.debugParseCount = 0;
  });

  group('BriefMarkdown — lazy viewport', () {
    testWidgets('builds only the sections near the reading position', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = BriefMarkdownController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(data: document, controller: controller));
      await tester.pump();

      // The document has 10 H2 + 30 H3 headings, so 40 navigable sections plus
      // the preamble. A 900 px viewport can only show a couple of them.
      expect(controller.sectionCount, _kSections * 4 + 1);

      // An eager Column laid all of it out: for the real LSOR brief that was
      // 18,600 elements. The bound here is deliberately loose — it is guarding
      // against the whole document being built, not pinning an exact count.
      expect(
        tester.allElements.length,
        lessThan(2000),
        reason:
            'the whole document appears to be built eagerly; a lazy viewport '
            'should only build the sections near the reading position',
      );

      // Proof the rest really is unbuilt: the last exercise's heading has no
      // element yet.
      expect(find.text('Exercise $_kSections'), findsNothing);
      expect(find.text('Exercise 1'), findsOneWidget);
    });

    testWidgets('scroll extent covers the whole document, not just what is '
        'built', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = BriefMarkdownController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(data: document, controller: controller));
      await tester.pump();

      expect(
        controller.scrollController.position.maxScrollExtent,
        greaterThan(10000),
      );
    });
  });

  group('BriefMarkdown — memoised parse', () {
    testWidgets('parses once on mount', (tester) async {
      final controller = BriefMarkdownController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(data: document, controller: controller));
      await tester.pump();

      expect(BriefMarkdown.debugParseCount, 1);
    });

    testWidgets('a rebuild with unchanged data does not re-parse', (
      tester,
    ) async {
      final controller = BriefMarkdownController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(data: document, controller: controller));
      await tester.pump();
      expect(BriefMarkdown.debugParseCount, 1);

      // Three more frames driven by an ancestor rebuild — what a setState on
      // BriefScreen (caching the markdown, switching the search bar on, the
      // TOC highlight moving) does to this widget.
      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(_host(data: document, controller: controller));
        await tester.pump();
      }

      expect(
        BriefMarkdown.debugParseCount,
        1,
        reason:
            'the document was re-parsed for a rebuild whose inputs did not '
            'change; buildWidgets must stay memoised',
      );
    });

    testWidgets('changed data does re-parse', (tester) async {
      final controller = BriefMarkdownController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(data: document, controller: controller));
      await tester.pump();
      expect(BriefMarkdown.debugParseCount, 1);

      // What a search keystroke does: the same document with <mark> wrappers.
      await tester.pumpWidget(
        _host(
          data: document.replaceAll('situation', '<mark>situation</mark>'),
          controller: controller,
        ),
      );
      await tester.pump();

      expect(BriefMarkdown.debugParseCount, 2);
    });
  });

  group('BriefMarkdownController — navigating to unbuilt sections', () {
    testWidgets('jumps to a heading the lazy viewport has not built', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = BriefMarkdownController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(data: document, controller: controller));
      await tester.pump();

      // The last section: far outside the built window, so its heading has no
      // BuildContext and ensureVisible alone would silently do nothing — which
      // is what a TOC tap on the last exercise used to do.
      final target = controller.tocList.last;
      expect(
        controller.sectionKeyFor(controller.sectionCount - 1).currentContext,
        isNull,
        reason: 'precondition: the target section must start out unbuilt',
      );

      final done = controller.jumpToWidgetIndex(target.widgetIndex);
      // Each convergence attempt consumes a frame, then ensureVisible animates.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await done;
      await tester.pumpAndSettle();

      expect(find.text('Station ${_kSections}3'), findsOneWidget);
      expect(
        controller.scrollController.offset,
        greaterThan(10000),
        reason: 'the viewport should have scrolled to the end of the document',
      );
    });

    testWidgets('active heading tracks past sections that are no longer built', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = BriefMarkdownController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_host(data: document, controller: controller));
      await tester.pump();
      expect(controller.activeWidgetIndex, -1);

      // Scroll well past the first few sections. They are unbuilt now, so the
      // active heading has to be inferred from the built window's position
      // rather than measured — a naive loop over mounted headings reports the
      // first *visible* one instead of the last one passed, or nothing at all.
      controller.scrollController.jumpTo(
        controller.scrollController.position.maxScrollExtent / 2,
      );
      await tester.pump();

      expect(
        controller.activeWidgetIndex,
        greaterThan(0),
        reason:
            'scrolling into the middle of the document should mark some '
            'heading active, not fall back to the pre-scroll -1',
      );
    });

    testWidgets('scrolls to a search match below the built window', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = BriefMarkdownController();
      addTearDown(controller.dispose);
      final matchKey = GlobalKey();

      // Mark a single occurrence deep in the last section, as BriefScreen's
      // search does for the active match.
      final needle = 'Station ${_kSections}3 situation paragraph 5.';
      expect(document.contains(needle), isTrue);
      final marked = document.replaceFirst(
        needle,
        '<curr-mark>$needle</curr-mark>',
      );
      final fraction = marked.indexOf('<curr-mark>') / marked.length;

      await tester.pumpWidget(
        _host(data: marked, controller: controller, currentMatchKey: matchKey),
      );
      await tester.pump();
      expect(
        matchKey.currentContext,
        isNull,
        reason: 'precondition: the match must start out unbuilt',
      );

      final done = controller.ensureKeyVisible(
        matchKey,
        documentFraction: fraction,
        alignment: 0.3,
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await done;
      await tester.pumpAndSettle();

      expect(matchKey.currentContext, isNotNull);
    });
  });
}
