import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Records every `launchUrl` call instead of hitting a real platform channel
/// (ADR-0050's ringdrill://chip action-chip tests) —
/// [UrlLauncherPlatform.instance] is the officially supported seam for this,
/// distinct from the `SystemChannels.platform` mock the copy-icon tests use
/// for Clipboard.
class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launchedUrls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return true;
  }
}

// Helper: recursively collect all TextSpan leaf colors from a widget's render tree.
Iterable<Color?> _collectTextColors(RichText widget) sync* {
  final span = widget.text;
  yield* _spanColors(span);
}

/// The weight one rendered cell's text is actually drawn at.
///
/// Resolved down the span tree, not read off the `RichText` root: the root carries the
/// ambient `DefaultTextStyle` (a plain w400) and the cell's own style sits on the leaf
/// that holds the text, where it overrides its ancestors.
FontWeight? _weightOf(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(find.text(text, findRichText: true));
  return _resolveWeight(rich.text, null);
}

FontWeight? _resolveWeight(InlineSpan span, FontWeight? inherited) {
  final here = span.style?.fontWeight ?? inherited;
  if (span is TextSpan && span.text == null && span.children != null) {
    for (final child in span.children!) {
      final resolved = _resolveWeight(child, here);
      if (resolved != null) return resolved;
    }
  }
  return here;
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

  // BriefMarkdown now owns its scroll position, TOC and heading keys through
  // a BriefMarkdownController. Create a fresh one per test and dispose it so
  // the leak tracker stays quiet.
  late BriefMarkdownController controller;
  setUp(() => controller = BriefMarkdownController());
  tearDown(() => controller.dispose());

  Widget buildWidget({String? data, double width = 600}) {
    return MaterialApp(
      // _CodeChip pulls AppLocalizations for the snackbar message and the
      // copy-icon tooltip, so the test app needs localization delegates.
      // Locale is pinned to en so the snackbar-text assertion below is
      // predictable across host machines.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 800,
          child: BriefMarkdown(
            data: data ?? fixture,
            theme: lightTheme,
            controller: controller,
          ),
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
    setUp(() {
      // Clipboard.setData goes through SystemChannels.platform; provide a
      // no-op mock so the method channel resolves in tests.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

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
        reason:
            'Inline code should render inside a Container chip with '
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

    testWidgets('inline code chip carries a copy icon', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      final copyIconFinder = find.byIcon(Icons.content_copy);
      expect(
        copyIconFinder,
        findsAtLeastNWidgets(1),
        reason: 'Inline code chip should display a copy icon next to the text',
      );
    });

    testWidgets('tapping inline code chip shows a copied snackbar', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      await tester.pump();

      final chipFinder = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        return decoration.color == lightTheme.code.background;
      });

      await tester.tap(chipFinder.first);
      // pumpAndSettle lets the async Clipboard.setData future resolve and the
      // SnackBar animation complete before asserting.
      await tester.pumpAndSettle();

      // The snackbar message is the localized briefCodeCopied — "Copied"
      // in English.
      expect(
        find.text('Copied'),
        findsOneWidget,
        reason:
            'Tapping the code chip should show a SnackBar with the copied label',
      );
    });

    testWidgets(
      'a code chip wrapped in parentheses draws the parens outside the pill '
      'and copies only the inner text',
      (tester) async {
        String? copied;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copied = (call.arguments as Map)['text'] as String?;
              }
              return null;
            });

        await tester.pumpWidget(
          buildWidget(
            data: 'Sist sett på Meiselen 14 `(32V 0563689E 6622277N)`.',
          ),
        );
        await tester.pump();

        // The pill shows the bare coordinate; the parens are their own text
        // runs (rendered outside the pill so "(pill)" stays one line).
        expect(find.text('32V 0563689E 6622277N'), findsOneWidget);
        expect(find.text('('), findsOneWidget);
        expect(find.text(')'), findsOneWidget);

        final chipFinder = find.byWidgetPredicate((widget) {
          if (widget is! Container) return false;
          final decoration = widget.decoration;
          if (decoration is! BoxDecoration) return false;
          return decoration.color == lightTheme.code.background;
        });
        await tester.tap(chipFinder.first);
        await tester.pumpAndSettle();

        expect(copied, '32V 0563689E 6622277N');
      },
    );
  });

  group('BriefMarkdown — actionable ringdrill://chip (ADR-0050)', () {
    late _FakeUrlLauncher fakeLauncher;

    setUp(() {
      fakeLauncher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = fakeLauncher;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    // Finds the chip's own Container (the same code.background pill the
    // inline-code tests match on) by its "code" child text, since a plain
    // find.byIcon(Icons.content_copy) would also match a real inline-code
    // chip elsewhere on the page.
    Finder chipContainer(String text) => find.ancestor(
      of: find.text(text),
      matching: find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        if (decoration is! BoxDecoration) return false;
        return decoration.color == lightTheme.code.background;
      }),
    );

    const geoHref = 'ringdrill://chip?action=map&lat=58.99&lng=10.43';
    const telHref = 'ringdrill://chip?action=call&tel=99887766';

    testWidgets(
      'a ringdrill://chip map link renders as a pill with a copy icon',
      (tester) async {
        await tester.pumpWidget(
          buildWidget(data: '[32V 601234 6643210]($geoHref)'),
        );
        await tester.pump();

        expect(find.text('32V 601234 6643210'), findsOneWidget);
        expect(chipContainer('32V 601234 6643210'), findsOneWidget);
        expect(find.byIcon(Icons.content_copy), findsOneWidget);
      },
    );

    testWidgets(
      'tapping the body of a ringdrill://chip map link opens the maps URL, '
      'not a copy',
      (tester) async {
        await tester.pumpWidget(
          buildWidget(data: '[32V 601234 6643210]($geoHref)'),
        );
        await tester.pump();

        await tester.tap(find.text('32V 601234 6643210'));
        await tester.pumpAndSettle();

        expect(
          fakeLauncher.launchedUrls,
          contains(
            'https://www.google.com/maps/search/?api=1&query=58.99,10.43',
          ),
        );
        // The action ran, not a copy — no "Copied" snackbar.
        expect(find.text('Copied'), findsNothing);
      },
    );

    testWidgets(
      'tapping the copy icon of a ringdrill://chip map link copies the '
      'display text without launching',
      (tester) async {
        String? copied;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copied = (call.arguments as Map)['text'] as String?;
              }
              return null;
            });

        await tester.pumpWidget(
          buildWidget(data: '[32V 601234 6643210]($geoHref)'),
        );
        await tester.pump();

        await tester.tap(find.byIcon(Icons.content_copy));
        await tester.pumpAndSettle();

        expect(copied, '32V 601234 6643210');
        expect(fakeLauncher.launchedUrls, isEmpty);
      },
    );

    testWidgets(
      'a ringdrill://chip call link dials the number, not the raw href, '
      'when tapped',
      (tester) async {
        await tester.pumpWidget(buildWidget(data: '[99887766]($telHref)'));
        await tester.pump();

        await tester.tap(find.text('99887766'));
        await tester.pumpAndSettle();

        expect(fakeLauncher.launchedUrls, contains('tel:99887766'));
      },
    );

    testWidgets(
      'a regular https link is unaffected by the ringdrill://chip generator',
      (tester) async {
        await tester.pumpWidget(
          buildWidget(data: '[link](https://example.com)'),
        );
        await tester.pump();

        await tester.tap(find.textContaining('link'));
        await tester.pumpAndSettle();

        expect(fakeLauncher.launchedUrls, contains('https://example.com'));
        // Not rendered as a chip: no copy icon for a plain link.
        expect(find.byIcon(Icons.content_copy), findsNothing);
      },
    );
  });

  group('BriefMarkdown — tables', () {
    const table =
        '| Rolle | Talegruppe |\n'
        '|---|---|\n'
        '| LSOR Deltakere | RK-VFOLD-ØV4 / DMO-ANDRE-1 |\n'
        '| LSOR Stab | RK-VFOLD-ØV5 / DMO-ANDRE-2 |\n';

    testWidgets('a wide table scrolls horizontally instead of overflowing', (
      tester,
    ) async {
      // 320 px is narrower than this table's intrinsic width, which is the case
      // that used to clip: TableNode puts the built Table straight into a
      // WidgetSpan with no scroll of its own.
      await tester.pumpWidget(buildWidget(data: table, width: 320));
      await tester.pumpAndSettle();

      expect(find.byType(Table), findsOneWidget);
      expect(
        find.text('Rolle', findRichText: true),
        findsOneWidget,
        reason: 'header cell',
      );
      expect(
        find.text('LSOR Deltakere', findRichText: true),
        findsOneWidget,
        reason: 'body cell',
      );

      // The table sits inside a horizontal Scrollable — the fix — and rendering
      // raised no overflow.
      final scrollables = tester
          .widgetList<Scrollable>(
            find.ancestor(
              of: find.byType(Table),
              matching: find.byType(Scrollable),
            ),
          )
          .toList();
      expect(
        scrollables.any((s) => s.axisDirection == AxisDirection.right),
        isTrue,
        reason: 'a horizontal scroll view wraps the table',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a table that fits is unaffected', (tester) async {
      await tester.pumpWidget(buildWidget(data: table, width: 900));
      await tester.pumpAndSettle();

      expect(find.byType(Table), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the header is bold and the body is not', (tester) async {
      // Reported from the exercise editor's round table: every cell was bold, so the
      // header stopped reading as one. The cause is in the package —
      // `TBodyNode.style` reads `config.table.headerStyle`, and `bodyStyle` is applied
      // to nothing (markdown_widget 2.3.2+8) — so setting a weight for the header sets
      // it for the body too. The fix is to set neither and let each node fall back,
      // which only works while the nodes have no inherited style to prefer. That is
      // exactly what this asserts, and it is why it is asserted rather than assumed:
      // an upgrade could restore `bodyStyle` and change which branch runs.
      await tester.pumpWidget(buildWidget(data: table, width: 900));
      await tester.pumpAndSettle();

      expect(_weightOf(tester, 'Rolle'), FontWeight.bold, reason: 'header cell');
      expect(
        _weightOf(tester, 'LSOR Deltakere'),
        isNot(FontWeight.bold),
        reason: 'body cell',
      );
    });

    testWidgets('the header fill is an overlay, so it darkens any surface', (
      tester,
    ) async {
      // An opaque light grey was lighter than the rollup card the editor's round-table
      // preview sits in, which inverted the intent: the header read as the lighter row.
      // Translucent is what makes "darker in light mode" true off-canvas as well.
      await tester.pumpWidget(buildWidget(data: table, width: 900));
      await tester.pumpAndSettle();

      final rows = tester.widget<Table>(find.byType(Table)).children;
      final header = rows.first.decoration as BoxDecoration;
      final fill = header.color!;

      expect(fill.a, lessThan(1.0), reason: 'an overlay, not a fill');
      expect(fill.a, greaterThan(0.0), reason: 'and actually visible');
      // Light theme: the overlay is black, so it darkens whatever is behind it.
      expect(fill.r, lessThan(0.5));
      expect(fill.g, lessThan(0.5));
      expect(fill.b, lessThan(0.5));
      // Dark theme inverts, which is the whole reason this is a theme token.
      final dark = BriefTheme.dark().surfaces.tableHeader;
      expect(dark.a, lessThan(1.0));
      expect(dark.r, greaterThan(0.5));

      expect(
        rows.last.decoration,
        isNull,
        reason: 'body rows stay on the surrounding surface',
      );
    });
  });
}
