import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/markdown_widget.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _launchExternalLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ---------------------------------------------------------------------------
// Private heading-config subclasses that suppress the built-in divider
// ---------------------------------------------------------------------------
//
// markdown_widget v2.x ships H1Config / H2Config / H3Config with a non-null
// `divider` getter that renders an underline below every heading, coloured
// from the default Material palette.  The `tag` getter is @nonVirtual on each
// concrete class, so subclasses still register under the correct tag.  We
// override only `divider → null` to remove the underlines without touching
// any other logic.

class _BriefH1Config extends H1Config {
  const _BriefH1Config({super.style});
  @override
  HeadingDivider? get divider => null;
}

class _BriefH2Config extends H2Config {
  const _BriefH2Config({super.style});
  @override
  HeadingDivider? get divider => null;
}

class _BriefH3Config extends H3Config {
  const _BriefH3Config({super.style});
  @override
  HeadingDivider? get divider => null;
}

// ---------------------------------------------------------------------------
// Inline-code chip
// ---------------------------------------------------------------------------
//
// markdown_widget's default `CodeNode` renders inline `` `code` `` as a plain
// `TextSpan` styled with `TextStyle.backgroundColor`, which paints a flat,
// no-padding strip behind the glyphs.  At our subtle slate-100 / slate-800
// background colors the strip is barely visible against the canvas.
//
// To get a proper docs-site code chip (rounded corners, horizontal padding)
// we override the `code` span generator with one that emits a `WidgetSpan`
// wrapping the text in a padded, rounded `Container`.

class _CodeChipNode extends ElementNode {
  _CodeChipNode(this.text, this.codeConfig);

  final String text;
  final CodeConfig codeConfig;

  @override
  TextStyle get style => codeConfig.style.merge(parentStyle);

  @override
  InlineSpan build() {
    final merged = style;
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      baseline: TextBaseline.alphabetic,
      child: _CodeChip(
        text: text,
        // Strip backgroundColor on the Text so we don't double-paint the chip
        // color behind the glyphs — the Container paints it instead.
        textStyle: merged.copyWith(backgroundColor: Colors.transparent),
        backgroundColor: merged.backgroundColor ?? const Color(0xCCEFF1F3),
      ),
    );
  }
}

/// Visual + behavioural shell for an inline code chip.
///
/// Renders the code text inside a padded, rounded `Container` and adds a
/// small copy icon to the right of the text. Tapping anywhere on the chip
/// copies the code content to the clipboard and shows a `SnackBar`
/// confirmation. Hovering over the chip on web/desktop shows a click cursor.
class _CodeChip extends StatelessWidget {
  const _CodeChip({
    required this.text,
    required this.textStyle,
    required this.backgroundColor,
  });

  final String text;
  final TextStyle textStyle;
  final Color backgroundColor;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(l10n.briefCodeCopied),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final iconColor = textStyle.color?.withValues(alpha: 0.7);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _copy(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(text, style: textStyle),
              const SizedBox(width: 6),
              Tooltip(
                message: l10n.briefCodeCopyTooltip,
                child: Icon(Icons.content_copy, size: 16, color: iconColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search highlight (<mark> / <curr-mark>)
// ---------------------------------------------------------------------------
//
// BriefScreen wraps search matches in HTML-like `<mark>` (other matches) and
// `<curr-mark>` (the active match the user has cycled to) tags. The base
// markdown parser does not handle HTML tags, so we register two custom
// inline syntaxes plus matching SpanNode generators. The rendered output is
// a TextSpan styled with the BriefTheme.searchHighlight background color.

class _HighlightInlineSyntax extends m.InlineSyntax {
  _HighlightInlineSyntax({required this.tag, required String pattern})
      : super(pattern, caseSensitive: false);

  final String tag;

  @override
  bool onMatch(m.InlineParser parser, Match match) {
    parser.addNode(m.Element.text(tag, match.group(1) ?? ''));
    return true;
  }
}

/// Renders a `<mark>` span (non-current search match) as a plain TextSpan
/// with backgroundColor on the TextStyle. The flat fill is acceptable here
/// because matches are usually short tokens and the background paints
/// directly behind the glyphs without padding — which keeps line-wrapping
/// well-behaved.
class _HighlightNode extends ElementNode {
  _HighlightNode(this.text, this.highlight);

  final String text;
  final Color highlight;

  @override
  TextStyle get style => (parentStyle ?? const TextStyle()).copyWith(
        backgroundColor: highlight,
      );

  @override
  InlineSpan build() => TextSpan(style: style, text: text);
}

/// Renders the `<curr-mark>` span — the search match the user has cycled
/// to via Enter or the next/previous controls — as a WidgetSpan wrapping
/// a Container.
///
/// The Container carries an externally-supplied [markerKey] so that
/// `BriefScreen` can call `Scrollable.ensureVisible` against its build
/// context after the index changes. There is at most one `<curr-mark>` in
/// the rendered markdown at any time, so a single shared GlobalKey works.
///
/// Trade-off vs the flat-TextSpan path: the WidgetSpan can't be split
/// mid-match by the line-wrapping algorithm. In practice search tokens
/// are short enough that this isn't noticeable.
class _CurrentHighlightNode extends ElementNode {
  _CurrentHighlightNode(this.text, this.highlight, this.markerKey);

  final String text;
  final Color highlight;
  final Key markerKey;

  @override
  TextStyle get style => parentStyle ?? const TextStyle();

  @override
  InlineSpan build() {
    final merged = style;
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      baseline: TextBaseline.alphabetic,
      child: Container(
        key: markerKey,
        decoration: BoxDecoration(
          color: highlight,
          borderRadius: BorderRadius.circular(2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Text(
          text,
          style: merged.copyWith(backgroundColor: Colors.transparent),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BriefMarkdownController
// ---------------------------------------------------------------------------

/// Owns the scroll position, table-of-contents list, and per-heading anchor
/// keys for a [BriefMarkdown].
///
/// This replaces markdown_widget's `TocController`, which is wired only to
/// that package's internal `ListView`. [BriefMarkdown] no longer uses
/// `MarkdownWidget`: it renders an eager `Column` inside a single
/// [SingleChildScrollView] so a [SelectionArea] can sit *inside* the
/// scrollable (the layout Flutter requires to keep text selectable without
/// tripping the `!_selectionStartsInScrollable` assertion — see
/// https://github.com/flutter/flutter/issues/115787). Heading navigation is
/// therefore driven by `Scrollable.ensureVisible` against per-heading
/// [GlobalKey]s instead of `ListView` indices.
class BriefMarkdownController extends ChangeNotifier {
  BriefMarkdownController() {
    scrollController.addListener(_handleScroll);
  }

  /// Drives the single scroll view that wraps the whole brief body.
  final ScrollController scrollController = ScrollController();

  // widgetIndex (Toc.widgetIndex / position in the generated widget list) ->
  // the GlobalKey attached to that block. Stable across rebuilds so selection
  // state and scroll targets survive re-renders.
  final Map<int, GlobalKey> _headingKeys = {};

  List<Toc> _tocList = const [];

  /// The headings discovered in the most recent render, in document order.
  List<Toc> get tocList => _tocList;

  /// `widgetIndex` of the heading currently scrolled to the top of the
  /// viewport (the last one whose top has passed the viewport top). `-1`
  /// before the first scroll or when no heading is mounted.
  int _activeWidgetIndex = -1;
  int get activeWidgetIndex => _activeWidgetIndex;

  /// Returns the stable key for the block at [widgetIndex], creating it on
  /// first request. [BriefMarkdown] attaches these to heading blocks.
  GlobalKey keyFor(int widgetIndex) =>
      _headingKeys.putIfAbsent(widgetIndex, () => GlobalKey());

  /// Replaces the cached TOC. No-op (and no notification) when the heading
  /// set is unchanged, so the post-frame call from every [BriefMarkdown]
  /// build doesn't churn listeners.
  void updateToc(List<Toc> toc) {
    if (_sameWidgetIndices(toc)) return;
    _tocList = List.unmodifiable(toc);
    final valid = toc.map((t) => t.widgetIndex).toSet();
    _headingKeys.removeWhere((index, _) => !valid.contains(index));
    notifyListeners();
  }

  bool _sameWidgetIndices(List<Toc> toc) {
    if (toc.length != _tocList.length) return false;
    for (var i = 0; i < toc.length; i++) {
      if (toc[i].widgetIndex != _tocList[i].widgetIndex) return false;
    }
    return true;
  }

  /// Scrolls the heading at [widgetIndex] so it sits at [alignment] of the
  /// viewport (0.0 = top). No-op when that heading isn't mounted.
  Future<void> jumpToWidgetIndex(
    int widgetIndex, {
    double alignment = 0.0,
  }) async {
    final ctx = _headingKeys[widgetIndex]?.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 200),
      alignment: alignment,
      curve: Curves.easeOut,
    );
  }

  void _handleScroll() {
    if (_tocList.isEmpty || !scrollController.hasClients) return;
    final offset = scrollController.offset;
    var active = -1;
    for (final toc in _tocList) {
      final ro = _headingKeys[toc.widgetIndex]?.currentContext
          ?.findRenderObject();
      if (ro == null) continue;
      final viewport = RenderAbstractViewport.maybeOf(ro);
      if (viewport == null) continue;
      // Scroll offset at which this heading reaches the viewport top.
      final reveal = viewport.getOffsetToReveal(ro, 0.0).offset;
      if (reveal <= offset + 4.0) {
        active = toc.widgetIndex;
      } else {
        break;
      }
    }
    if (active != _activeWidgetIndex) {
      _activeWidgetIndex = active;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// BriefMarkdown
// ---------------------------------------------------------------------------

/// Renders brief markdown as a selectable, scrollable reading surface styled
/// entirely through [BriefTheme].
///
/// Unlike markdown_widget's `MarkdownWidget` (which wraps its internal
/// `ListView` in a `SelectionArea`), this builds the markdown into an eager
/// `Column` via [MarkdownGenerator.buildWidgets] and places a single
/// [SelectionArea] *inside* one [SingleChildScrollView]. That nesting keeps
/// partial text selection working without the framework's
/// `!_selectionStartsInScrollable` assertion firing on long-press scroll
/// (https://github.com/flutter/flutter/issues/115787).
///
/// Scroll position, the table of contents and heading anchors are owned by a
/// [BriefMarkdownController]; all style decisions flow through [BriefTheme].
///
/// Usage:
/// ```dart
/// BriefMarkdown(
///   data: markdownString,
///   theme: BriefTheme.of(context),
///   controller: _briefController,
/// )
/// ```
class BriefMarkdown extends StatelessWidget {
  const BriefMarkdown({
    super.key,
    required this.data,
    required this.theme,
    required this.controller,
    this.currentMatchKey,
    this.onAnchorTap,
  });

  final String data;
  final BriefTheme theme;
  final BriefMarkdownController controller;

  /// Optional [GlobalKey] attached to the active search-match widget so
  /// callers can call `Scrollable.ensureVisible` against it. Only used when
  /// the rendered markdown contains a `<curr-mark>` tag.
  final Key? currentMatchKey;

  /// Called when the user taps a markdown link whose URL starts with `#`
  /// (an in-doc anchor link, e.g. the table-of-contents entries). The
  /// callback receives the anchor without the leading `#`. When `null` —
  /// or when the URL is a regular http(s) link — the LinkConfig falls
  /// back to its default `launchUrl` behaviour.
  ///
  /// Without this hook web builds reload the page when an anchor link is
  /// tapped (the browser navigates to `current-url#anchor` which Flutter
  /// Web treats as a full navigation).
  final ValueChanged<String>? onAnchorTap;

  @override
  Widget build(BuildContext context) {
    final generator = MarkdownGenerator(
      // Register HTML-like `<mark>` and `<curr-mark>` inline syntaxes so
      // BriefScreen's search-highlight wrapping renders as styled spans
      // instead of plain literal text.
      inlineSyntaxList: [
        _HighlightInlineSyntax(
          tag: 'curr-mark',
          pattern: r'<curr-mark>(.*?)</curr-mark>',
        ),
        _HighlightInlineSyntax(
          tag: 'mark',
          pattern: r'<mark>(.*?)</mark>',
        ),
      ],
      generators: [
        // Override default `<code>` rendering with the padded-chip
        // generator defined above. Registering for the same tag replaces
        // the package's built-in CodeNode generator cleanly.
        SpanNodeGeneratorWithTag(
          tag: MarkdownTag.code.name,
          generator: (e, config, _) =>
              _CodeChipNode(e.textContent, config.code),
        ),
        // Search highlight generators. `<mark>` paints the non-current
        // matches as a flat-background TextSpan. `<curr-mark>` paints the
        // active match as a WidgetSpan attached to [currentMatchKey] so
        // BriefScreen can scroll to it.
        SpanNodeGeneratorWithTag(
          tag: 'mark',
          generator: (e, config, visitor) =>
              _HighlightNode(e.textContent, theme.searchHighlight.match),
        ),
        SpanNodeGeneratorWithTag(
          tag: 'curr-mark',
          generator: (e, config, visitor) {
            final key = currentMatchKey;
            if (key == null) {
              // No scroll target requested — fall through to a flat
              // backgroundColor like the non-current matches.
              return _HighlightNode(
                e.textContent,
                theme.searchHighlight.current,
              );
            }
            return _CurrentHighlightNode(
              e.textContent,
              theme.searchHighlight.current,
              key,
            );
          },
        ),
      ],
    );

    // Build the markdown into a flat widget list and capture the TOC in the
    // same synchronous pass. `onTocList` fires during `buildWidgets`.
    final toc = <Toc>[];
    // Copy into a growable list: the generated list may be unmodifiable, and
    // we replace heading entries with keyed wrappers below.
    final widgets = List<Widget>.of(
      generator.buildWidgets(
        data,
        config: _buildConfig(),
        onTocList: (list) {
          toc
            ..clear()
            ..addAll(list);
        },
      ),
    );

    // Attach the controller's stable keys to heading blocks so TOC taps,
    // anchor links and active-heading tracking can target them.
    for (final entry in toc) {
      final i = entry.widgetIndex;
      if (i < 0 || i >= widgets.length) continue;
      widgets[i] = KeyedSubtree(key: controller.keyFor(i), child: widgets[i]);
    }

    // Surface the captured TOC to the controller after the frame so we never
    // notify listeners during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.updateToc(toc);
    });

    return Scrollbar(
      controller: controller.scrollController,
      child: SingleChildScrollView(
        controller: controller.scrollController,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: theme.spacing.readingColumnMax,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.gutter),
              // SelectionArea sits *inside* the scroll view, wrapping the
              // non-scrolling Column. See class doc / issue #115787.
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widgets,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  MarkdownConfig _buildConfig() {
    final t = theme;

    return MarkdownConfig(
      configs: [
        // Headings — style from theme, no built-in dividers
        _BriefH1Config(style: t.typography.h1.copyWith(color: t.text.heading)),
        _BriefH2Config(style: t.typography.h2.copyWith(color: t.text.heading)),
        _BriefH3Config(style: t.typography.h3.copyWith(color: t.text.heading)),
        H4Config(style: t.typography.h4.copyWith(color: t.text.heading)),
        // Paragraphs
        PConfig(textStyle: t.typography.body.copyWith(color: t.text.body)),
        // Links — body color with thin underline; distinction is the
        // underline opacity, not a different hue. The onTap callback
        // intercepts `#anchor` URLs and forwards them to [onAnchorTap]
        // rather than letting the default LinkConfig dispatch a real
        // navigation (which would reload the whole page on web).
        LinkConfig(
          style: TextStyle(
            color: t.link.color,
            decoration: TextDecoration.underline,
            decorationColor: t.link.color.withValues(
              alpha: t.link.underlineOpacity,
            ),
          ),
          onTap: (url) {
            if (url.startsWith('#')) {
              onAnchorTap?.call(url.substring(1));
              return;
            }
            // Non-anchor links fall through to the package's default
            // url_launcher behaviour by re-dispatching to the LinkNode's
            // internal handler. The simplest path: just launch directly
            // here using the same logic.
            // ignore: discarded_futures
            _launchExternalLink(url);
          },
        ),
        // Inline code
        CodeConfig(
          style: t.typography.code.copyWith(
            color: t.code.foreground,
            backgroundColor: t.code.background,
          ),
        ),
        // Fenced code blocks
        PreConfig(
          textStyle: t.typography.code.copyWith(color: t.code.foreground),
          decoration: BoxDecoration(
            color: t.code.background,
            border: Border.all(color: t.code.border),
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
        // Blockquotes
        BlockquoteConfig(sideColor: t.borders.subtle, textColor: t.text.muted),
        // Tables
        TableConfig(
          border: TableBorder.all(color: t.borders.subtle),
          headerStyle: TextStyle(
            color: t.text.heading,
            fontWeight: FontWeight.bold,
          ),
          bodyStyle: TextStyle(color: t.text.body),
        ),
        // Horizontal rules
        HrConfig(color: t.borders.subtle, height: 1),
      ],
    );
  }
}
