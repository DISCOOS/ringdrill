import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:markdown/markdown.dart' as m;
import 'package:markdown_widget/markdown_widget.dart';
import 'package:ringdrill/utils/external_links.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';
import 'package:ringdrill/views/widgets/code_chip.dart';

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
  // Body style as the base, `codeConfig.style` (BriefTheme.typography.code +
  // code colors) on top: `a.merge(b)` lets b win, so the code config must be
  // the argument — otherwise the surrounding body font size overrides the code
  // size and the chip reads too large.
  TextStyle get style =>
      (parentStyle ?? const TextStyle()).merge(codeConfig.style);

  @override
  InlineSpan build() {
    final merged = style;
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      baseline: TextBaseline.alphabetic,
      child: CodeChip(
        text: text,
        // Strip backgroundColor on the Text so we don't double-paint the chip
        // color behind the glyphs — the Container paints it instead.
        textStyle: merged.copyWith(backgroundColor: Colors.transparent),
        backgroundColor: merged.backgroundColor ?? const Color(0xCCEFF1F3),
        // Parentheses folded into a code span (e.g. a location's
        // `(<utm>)`) render just outside the pill in the surrounding body
        // style, not on the chip background.
        adornmentStyle: parentStyle,
      ),
    );
  }
}

class _ActionChipNode extends ElementNode {
  _ActionChipNode(this.text, this.uri, this.codeConfig);

  final String text;
  final Uri uri;
  final CodeConfig codeConfig;

  @override
  // Body style as the base, `codeConfig.style` (BriefTheme.typography.code +
  // code colors) on top: `a.merge(b)` lets b win, so the code config must be
  // the argument — otherwise the surrounding body font size overrides the code
  // size and the chip reads too large.
  TextStyle get style =>
      (parentStyle ?? const TextStyle()).merge(codeConfig.style);

  @override
  InlineSpan build() {
    final merged = style;
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      baseline: TextBaseline.alphabetic,
      child: CodeActionChip(
        text: text,
        textStyle: merged.copyWith(backgroundColor: Colors.transparent),
        backgroundColor: merged.backgroundColor ?? const Color(0xCCEFF1F3),
        adornmentStyle: parentStyle,
        actions: chipActions(uri),
      ),
    );
  }
}

/// The shared link-tag generator for [BriefMarkdown] and [BriefMarkdownBlock]:
/// a `ringdrill://chip` href renders [_ActionChip]; anything else falls
/// through to the package's own [LinkNode] (i.e. the ambient [LinkConfig]
/// behaviour), so a normal link is unaffected whether or not this generator
/// is registered.
SpanNodeGeneratorWithTag _actionChipGenerator() => SpanNodeGeneratorWithTag(
  tag: MarkdownTag.a.name,
  generator: (e, config, visitor) {
    final href = e.attributes['href'] ?? '';
    final uri = Uri.tryParse(href);
    if (uri == null || uri.scheme != 'ringdrill' || uri.host != 'chip') {
      return LinkNode(e.attributes, config.a);
    }
    return _ActionChipNode(e.textContent, uri, config.code);
  },
);

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
  TextStyle get style =>
      (parentStyle ?? const TextStyle()).copyWith(backgroundColor: highlight);

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
/// that package's internal `ListView`. [BriefMarkdown] does not use
/// `MarkdownWidget`: it splits the parsed document into *sections* at every
/// H2/H3 heading and renders those through a lazy `SliverList`, so only the
/// sections near the viewport are ever laid out (ADR-0069).
///
/// A lazy viewport is what makes heading navigation non-trivial: a heading
/// outside the built window has no `BuildContext`, so `ensureVisible` alone
/// would silently do nothing — which is precisely what a TOC tap on a
/// far-away exercise needs to do *something* about. Hence
/// [jumpToWidgetIndex] first brings the owning section into the built window
/// by estimating its scroll offset from the extents of the sections that
/// have been laid out so far, and only then scrolls exactly.
class BriefMarkdownController extends ChangeNotifier {
  BriefMarkdownController() {
    scrollController.addListener(_handleScroll);
  }

  /// Drives the single scroll view that wraps the whole brief body.
  final ScrollController scrollController = ScrollController();

  // widgetIndex (Toc.widgetIndex / position in the generated widget list) ->
  // the GlobalKey attached to that block. Stable across rebuilds so selection
  // state and scroll targets survive re-renders. Only the headings inside a
  // *built* section have a context; see [jumpToWidgetIndex].
  final Map<int, GlobalKey> _headingKeys = {};

  // Section index -> the GlobalKey on that section's block group.
  final Map<int, GlobalKey> _sectionKeys = {};

  // Section index -> the main-axis extent it measured the last time it was
  // laid out. Only built sections can be measured, so this fills in as the
  // reader scrolls; [_estimatedOffsetOfSection] substitutes the running
  // average for the sections that have never been on screen.
  final Map<int, double> _sectionExtents = {};

  /// `widgetIndex` of the first block of each section, ascending. The first
  /// entry is always 0 (the pre-heading preamble: the H1 title and any
  /// plan-level prose above the first exercise).
  List<int> _sectionStarts = const [0];
  int get sectionCount => _sectionStarts.length;

  List<Toc> _tocList = const [];

  /// The headings discovered in the most recent render, in document order.
  List<Toc> get tocList => _tocList;

  /// `widgetIndex` of the heading currently scrolled to the top of the
  /// viewport (the last one whose top has passed the viewport top). `-1`
  /// before the first scroll or while the preamble is still on screen.
  int _activeWidgetIndex = -1;
  int get activeWidgetIndex => _activeWidgetIndex;

  /// Returns the stable key for the block at [widgetIndex], creating it on
  /// first request. [BriefMarkdown] attaches these to heading blocks.
  GlobalKey keyFor(int widgetIndex) =>
      _headingKeys.putIfAbsent(widgetIndex, () => GlobalKey());

  /// Returns the stable key for section [index]. [BriefMarkdown] attaches
  /// these to the section block groups the `SliverList` builds.
  GlobalKey sectionKeyFor(int index) =>
      _sectionKeys.putIfAbsent(index, () => GlobalKey());

  /// Replaces the cached TOC and section layout. No-op (and no notification)
  /// when both are unchanged, so the post-frame call from every
  /// [BriefMarkdown] build doesn't churn listeners.
  void updateDocument({required List<Toc> toc, required List<int> sections}) {
    if (_sameWidgetIndices(toc) && _sameSections(sections)) return;
    _tocList = List.unmodifiable(toc);
    _sectionStarts = List.unmodifiable(sections);
    final validHeadings = toc.map((t) => t.widgetIndex).toSet();
    _headingKeys.removeWhere((index, _) => !validHeadings.contains(index));
    _sectionKeys.removeWhere((index, _) => index >= sections.length);
    // Extents belong to the previous document's section boundaries; keeping
    // them would make the first jump into the new one land at random.
    _sectionExtents.clear();
    notifyListeners();
  }

  bool _sameWidgetIndices(List<Toc> toc) {
    if (toc.length != _tocList.length) return false;
    for (var i = 0; i < toc.length; i++) {
      if (toc[i].widgetIndex != _tocList[i].widgetIndex) return false;
    }
    return true;
  }

  bool _sameSections(List<int> sections) {
    if (sections.length != _sectionStarts.length) return false;
    for (var i = 0; i < sections.length; i++) {
      if (sections[i] != _sectionStarts[i]) return false;
    }
    return true;
  }

  /// The index of the section that owns the block at [widgetIndex] — the last
  /// section whose first block is at or before it.
  int sectionIndexForWidgetIndex(int widgetIndex) {
    var lo = 0;
    var hi = _sectionStarts.length - 1;
    var found = 0;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (_sectionStarts[mid] <= widgetIndex) {
        found = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return found;
  }

  /// Records the laid-out extent of every currently built section, so the
  /// offset estimate for the ones that have never been on screen improves as
  /// the reader moves through the document.
  void recordBuiltSectionExtents() {
    for (final entry in _sectionKeys.entries) {
      final ro = entry.value.currentContext?.findRenderObject();
      if (ro is RenderBox && ro.hasSize) {
        _sectionExtents[entry.key] = ro.size.height;
      }
    }
  }

  double get _averageSectionExtent {
    if (_sectionExtents.isEmpty) return 0;
    var sum = 0.0;
    for (final extent in _sectionExtents.values) {
      sum += extent;
    }
    return sum / _sectionExtents.length;
  }

  /// Best guess at the scroll offset where section [index] begins: measured
  /// extents where we have them, the running average everywhere else.
  double _estimatedOffsetOfSection(int index) {
    final average = _averageSectionExtent;
    var offset = 0.0;
    for (var i = 0; i < index; i++) {
      offset += _sectionExtents[i] ?? average;
    }
    return offset;
  }

  /// Scrolls until section [index] is inside the lazy viewport's built
  /// window, so its heading has a [BuildContext] to scroll to exactly.
  ///
  /// Each attempt jumps to the current estimate and lets one frame build,
  /// which measures more sections and sharpens the next estimate — so this
  /// converges rather than merely guessing once. Already-built sections cost
  /// nothing: the loop exits on the first check.
  Future<void> _ensureSectionBuilt(int index) async {
    if (!scrollController.hasClients) return;
    for (var attempt = 0; attempt < 5; attempt++) {
      if (_sectionKeys[index]?.currentContext != null) return;
      final position = scrollController.position;
      final target = _estimatedOffsetOfSection(
        index,
      ).clamp(position.minScrollExtent, position.maxScrollExtent);
      if (target == position.pixels && attempt > 0) return;
      scrollController.jumpTo(target);
      await SchedulerBinding.instance.endOfFrame;
      recordBuiltSectionExtents();
    }
  }

  /// Scrolls the heading at [widgetIndex] so it sits at [alignment] of the
  /// viewport (0.0 = top).
  Future<void> jumpToWidgetIndex(
    int widgetIndex, {
    double alignment = 0.0,
  }) async {
    final section = sectionIndexForWidgetIndex(widgetIndex);
    await _ensureSectionBuilt(section);
    // Prefer the heading itself; fall back to the section group, whose first
    // block *is* that heading for every section but the preamble.
    final ctx =
        _headingKeys[widgetIndex]?.currentContext ??
        _sectionKeys[section]?.currentContext;
    // Read after the await above, so this is a fresh context, not one held
    // across the gap; `mounted` states that for the analyzer.
    if (ctx == null || !ctx.mounted) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 200),
      alignment: alignment,
      curve: Curves.easeOut,
    );
  }

  /// Scrolls [key] into view at [alignment], for a target that is not a
  /// heading — the active search match.
  ///
  /// [documentFraction] is where the target sits in the markdown source, as a
  /// fraction of its length. It is only consulted when [key] is outside the
  /// built window: character position tracks scroll position closely enough
  /// in running prose to land in the right neighbourhood, after which the
  /// exact scroll takes over.
  ///
  /// Iterates for the same reason [_ensureSectionBuilt] does, with one extra
  /// wrinkle: until every section has been laid out at least once, a lazy
  /// viewport's own `maxScrollExtent` is an estimate too, so a fraction of it
  /// is a moving target. Each attempt measures more sections and lands closer.
  Future<void> ensureKeyVisible(
    GlobalKey key, {
    double? documentFraction,
    double alignment = 0.0,
  }) async {
    if (documentFraction != null && scrollController.hasClients) {
      var previous = double.nan;
      for (var attempt = 0; attempt < 6; attempt++) {
        if (key.currentContext != null) break;
        final position = scrollController.position;
        final target = (documentFraction * position.maxScrollExtent).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
        // The estimate has stopped moving and still has not built the target —
        // further attempts would jump to the same place.
        if (target == previous) break;
        previous = target;
        scrollController.jumpTo(target);
        await SchedulerBinding.instance.endOfFrame;
        recordBuiltSectionExtents();
      }
    }
    final ctx = key.currentContext;
    // Read after the possible await above — a fresh context, not one held
    // across the gap; `mounted` states that for the analyzer.
    if (ctx == null || !ctx.mounted) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 200),
      alignment: alignment,
      curve: Curves.easeOut,
    );
  }

  void _handleScroll() {
    if (_tocList.isEmpty || !scrollController.hasClients) return;
    recordBuiltSectionExtents();
    final offset = scrollController.offset;

    // Sections before the built window have scrolled off the top, so the last
    // of them counts as passed even though it has no render object to measure.
    var firstBuilt = -1;
    for (var i = 0; i < _sectionStarts.length; i++) {
      if (_sectionKeys[i]?.currentContext != null) {
        firstBuilt = i;
        break;
      }
    }
    if (firstBuilt < 0) return;
    var active = firstBuilt - 1;

    for (var i = firstBuilt; i < _sectionStarts.length; i++) {
      final ro = _sectionKeys[i]?.currentContext?.findRenderObject();
      if (ro == null) break;
      final viewport = RenderAbstractViewport.maybeOf(ro);
      if (viewport == null) break;
      // Scroll offset at which this section reaches the viewport top.
      final reveal = viewport.getOffsetToReveal(ro, 0.0).offset;
      if (reveal <= offset + 4.0) {
        active = i;
      } else {
        break;
      }
    }

    // Section 0 is the preamble, which owns no navigable heading.
    final activeIndex = active <= 0 ? -1 : _sectionStarts[active];
    if (activeIndex != _activeWidgetIndex) {
      _activeWidgetIndex = activeIndex;
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

/// The heading levels a brief is split into sections at — the same range
/// [BriefScreen]'s outline offers as navigation targets, so a section always
/// begins at something the reader can jump to.
const int _kSectionMinLevel = 2;
const int _kSectionMaxLevel = 3;

/// A run of top-level markdown blocks beginning at one H2/H3 heading and
/// running to just before the next. The unit a [BriefMarkdown]'s lazy
/// viewport builds, lays out and discards as a whole.
class _Section {
  const _Section({required this.start, required this.end});

  /// Index of the first block, into the flat generated widget list.
  final int start;

  /// Index one past the last block.
  final int end;
}

/// The parsed form of one markdown string: the flat block list
/// [MarkdownGenerator] produced, its table of contents, and the section
/// grouping the lazy viewport builds from.
///
/// Cached by [_BriefMarkdownState] and rebuilt only when an input that
/// actually affects parsing changes. Without that cache every `setState` on
/// the screen re-parsed the whole document — 55 ms and ~740 freshly
/// constructed block widgets for a real plan's brief, per keystroke.
class _ParsedBrief {
  const _ParsedBrief({
    required this.blocks,
    required this.toc,
    required this.sections,
  });

  final List<Widget> blocks;
  final List<Toc> toc;
  final List<_Section> sections;

  /// `widgetIndex` of each section's first block — what the controller needs
  /// to map a heading to the section that owns it.
  List<int> get sectionStarts => [for (final s in sections) s.start];
}

/// Renders brief markdown as a selectable, scrollable reading surface styled
/// entirely through [BriefTheme].
///
/// Unlike markdown_widget's `MarkdownWidget` (which wraps its internal
/// `ListView` in a `SelectionArea`), this parses the markdown itself via
/// [MarkdownGenerator.buildWidgets], groups the resulting blocks into
/// sections at each H2/H3 heading, and renders those through a lazy
/// `SliverList` with one [SelectionArea] around the whole scroll view
/// (ADR-0069).
///
/// The laziness is the point. A real plan's brief is ~69 KB of markdown —
/// 737 blocks, some 72,000 px tall. Laying all of that out eagerly, which an
/// earlier `SingleChildScrollView` + `Column` did, cost ~590 ms and 18,600
/// elements before the first frame; the lazy viewport builds only the two or
/// so sections around the reading position, for ~56 ms and ~1,300 elements.
///
/// That earlier eager `Column` existed to keep [SelectionArea] *inside* the
/// scrollable, working around the framework's `!_selectionStartsInScrollable`
/// assertion on long-press scroll
/// (https://github.com/flutter/flutter/issues/115787). That assertion no
/// longer fires on Flutter 3.44 for either touch or mouse drag, which is what
/// made the lazy viewport available — see
/// `test/views/widgets/brief_markdown_selection_test.dart`, which fails if it
/// comes back. What the lazy viewport does cost is selection *reach*: text
/// scrolled out of the built window leaves the selection tree, so a drag
/// cannot select more than roughly a screenful either side. Copying the whole
/// document is the copy-markdown button's job, not selection's.
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
class BriefMarkdown extends StatefulWidget {
  const BriefMarkdown({
    super.key,
    required this.data,
    required this.theme,
    required this.controller,
    this.currentMatchKey,
    this.onAnchorTap,
    this.gutter,
    this.linesMargin,
  });

  final String data;
  final BriefTheme theme;
  final BriefMarkdownController controller;

  /// Horizontal inset around the reading column. Defaults to
  /// [BriefSpacing.gutter] — the brief page's own margin, generous because
  /// nothing else shares that page's left edge. A caller embedding this
  /// next to other chrome that shares an edge (DESIGN-010's per-section
  /// preview sits directly under the field's own label, at that label's own
  /// x) should override this to `0` so the two align, rather than the
  /// resolved text sitting further right than everything around it.
  final double? gutter;

  /// Vertical margin `MarkdownGenerator` wraps around *every* top-level
  /// block (heading, paragraph, ...), including the first/last — defaults
  /// to the package's own `EdgeInsets.symmetric(vertical: 8)`, generous
  /// breathing room between blocks on the brief's own reading page. A
  /// single-paragraph preview sitting directly under external chrome (the
  /// per-section preview's own label) should override this to
  /// `EdgeInsets.zero`: that 8px top margin otherwise pushes the text away
  /// from the label above it, even though nothing else about their spacing
  /// changed.
  final EdgeInsets? linesMargin;

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

  /// Number of times any [BriefMarkdown] has parsed its markdown. A rebuild
  /// with unchanged inputs must not move this — that is the regression
  /// `test/views/widgets/brief_markdown_performance_test.dart` pins.
  @visibleForTesting
  static int debugParseCount = 0;

  @override
  State<BriefMarkdown> createState() => _BriefMarkdownState();
}

class _BriefMarkdownState extends State<BriefMarkdown> {
  late _ParsedBrief _parsed;

  @override
  void initState() {
    super.initState();
    _parsed = _parse();
    _publishDocument();
  }

  @override
  void didUpdateWidget(BriefMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only the inputs the parse actually consumes invalidate the cache. Note
    // `theme` is safe to compare by identity: BriefTheme.of returns one of two
    // const instances, so it is stable across rebuilds.
    if (oldWidget.data != widget.data ||
        oldWidget.theme != widget.theme ||
        oldWidget.linesMargin != widget.linesMargin ||
        oldWidget.currentMatchKey != widget.currentMatchKey ||
        oldWidget.onAnchorTap != widget.onAnchorTap) {
      _parsed = _parse();
      _publishDocument();
    }
  }

  /// Surfaces the TOC and section layout to the controller after the frame so
  /// we never notify listeners during build.
  void _publishDocument() {
    final toc = _parsed.toc;
    final sections = _parsed.sectionStarts;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.updateDocument(toc: toc, sections: sections);
      widget.controller.recordBuiltSectionExtents();
    });
  }

  _ParsedBrief _parse() {
    BriefMarkdown.debugParseCount++;
    final generator = _buildGenerator();
    final toc = <Toc>[];
    // Copy into a growable list: the generated list may be unmodifiable, and
    // we replace heading entries with keyed wrappers below.
    final blocks = List<Widget>.of(
      generator.buildWidgets(
        widget.data,
        config: _briefMarkdownConfig(
          widget.theme,
          onAnchorTap: widget.onAnchorTap,
        ),
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
      if (i < 0 || i >= blocks.length) continue;
      blocks[i] = KeyedSubtree(
        key: widget.controller.keyFor(i),
        child: blocks[i],
      );
    }

    return _ParsedBrief(
      blocks: blocks,
      toc: List.unmodifiable(toc),
      sections: _splitIntoSections(blocks.length, toc),
    );
  }

  /// Groups [blockCount] blocks into sections at every H2/H3 heading.
  ///
  /// The first section is whatever precedes the first such heading — the H1
  /// title and any plan-level prose — and is present even when empty so that
  /// section indices and [_ParsedBrief.sectionStarts] stay aligned. A document
  /// with no H2/H3 at all (a short preview) yields a single section, which is
  /// simply the old eager behaviour and correct for content that small.
  List<_Section> _splitIntoSections(int blockCount, List<Toc> toc) {
    final starts = <int>[0];
    for (final entry in toc) {
      final level = headingTag2Level[entry.node.headingConfig.tag] ?? 1;
      if (level < _kSectionMinLevel || level > _kSectionMaxLevel) continue;
      final index = entry.widgetIndex;
      if (index <= 0 || index >= blockCount) continue;
      if (index == starts.last) continue;
      starts.add(index);
    }
    return [
      for (var i = 0; i < starts.length; i++)
        _Section(
          start: starts[i],
          end: i + 1 < starts.length ? starts[i + 1] : blockCount,
        ),
    ];
  }

  MarkdownGenerator _buildGenerator() {
    final theme = widget.theme;
    return MarkdownGenerator(
      linesMargin:
          widget.linesMargin ?? const EdgeInsets.symmetric(vertical: 8),
      // Register HTML-like `<mark>` and `<curr-mark>` inline syntaxes so
      // BriefScreen's search-highlight wrapping renders as styled spans
      // instead of plain literal text.
      inlineSyntaxList: [
        _HighlightInlineSyntax(
          tag: 'curr-mark',
          pattern: r'<curr-mark>(.*?)</curr-mark>',
        ),
        _HighlightInlineSyntax(tag: 'mark', pattern: r'<mark>(.*?)</mark>'),
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
        // A `ringdrill://chip` link renders as an actionable pill
        // (ADR-0050); every other link keeps the ambient LinkConfig
        // behaviour.
        _actionChipGenerator(),
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
            final key = widget.currentMatchKey;
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final sections = _parsed.sections;

    // Record extents for whatever this frame ended up building, so the
    // controller's estimate for the sections that have never been on screen
    // keeps improving as the reader moves through the document.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.recordBuiltSectionExtents();
    });

    // SelectionArea sits *outside* the scrollable now, which is what lets the
    // viewport be lazy at all — see the class doc for the assertion this used
    // to work around and the selection reach it costs.
    return SelectionArea(
      child: Scrollbar(
        controller: widget.controller.scrollController,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // The reading column is capped and centred with padding on the
            // sliver rather than a box inside the scroll view, so the
            // scrollbar stays at the pane's own right edge instead of moving
            // in to the column's. Geometry is otherwise identical to the box
            // version: the cap is centred in the available width, and the
            // gutter is inset within it.
            final available = constraints.maxWidth;
            final columnWidth = math.min(
              available,
              theme.spacing.readingColumnMax,
            );
            final inset =
                (available - columnWidth) / 2 +
                (widget.gutter ?? theme.spacing.gutter);

            return CustomScrollView(
              controller: widget.controller.scrollController,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: inset),
                  sliver: SliverList.builder(
                    itemCount: sections.length,
                    itemBuilder: (context, index) {
                      final section = sections[index];
                      return KeyedSubtree(
                        key: widget.controller.sectionKeyFor(index),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _parsed.blocks.sublist(
                            section.start,
                            section.end,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The heading/link/code/table styling both [BriefMarkdown] (the full-page
/// brief reading surface, with search highlighting) and [BriefMarkdownBlock]
/// (DESIGN-010's section rollup/preview, no search) apply — a shared builder
/// so both stay visually identical to the brief.
MarkdownConfig _briefMarkdownConfig(
  BriefTheme theme, {
  ValueChanged<String>? onAnchorTap,
}) {
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
          launchExternalApp(url);
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
        // A fill, not weight alone: a header row that differs only in boldness stops
        // reading as a header the moment anything else on the row is emphasised.
        headerRowDecoration: BoxDecoration(color: t.surfaces.tableHeader),
        // `headerStyle` and `bodyStyle` are deliberately not set, which is the only way
        // to get a bold header and a plain body out of this package: `TBodyNode.style`
        // reads `config.table.headerStyle` — not `bodyStyle`, which is applied to
        // nothing at all (markdown_widget 2.3.2+8, blocks/container/table.dart:144).
        // So any weight set for the header is also the body's weight, which is what
        // rendered every cell of the round table bold. Left null, each node falls back
        // to its own default: `p.textStyle` bolded for the header, `p.textStyle` as-is
        // for the body. Colour comes from `PConfig` either way.
        //
        // Revisit on upgrade: if the package starts honouring `bodyStyle`, state both
        // rather than relying on fallbacks.
        // A table wider than its slot scrolls rather than overflowing. Without
        // this, `TableNode` puts the built `Table` straight into a `WidgetSpan`
        // with no scroll of its own, so a plan's "Talegrupper" table is fine on a
        // desktop brief and clipped with a yellow stripe on a phone — or in the
        // plan overview card at any width.
        //
        // Safe inside a `WidgetSpan`: the package already defaults
        // `defaultColumnWidth` to `IntrinsicColumnWidth`, so the table sizes to its
        // content under the scroll view's unbounded width. A `FlexColumnWidth`
        // default would assert instead, which is why this comment names the
        // dependency.
        wrapper: (table) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: table,
        ),
      ),
      // Horizontal rules
      HrConfig(color: t.borders.subtle, height: 1),
    ],
  );
}

/// Renders [data] with the same [BriefTheme] styling [BriefMarkdown] uses
/// (headings, links, the inline-code UTM chip), but without its own scroll
/// view or [BriefMarkdownController] — for embedding inline inside an
/// already-scrollable ancestor, e.g. DESIGN-010's section rollup on narrow,
/// where the resolved sections are a continuation of the same page scroll
/// as the structural fields above them, not an independent scrollable
/// island. [BriefMarkdown] itself (its own scroll, TOC, search
/// highlighting) is still the right choice for a bounded pane that should
/// scroll on its own — e.g. the rollup's wide side-by-side preview pane.
class BriefMarkdownBlock extends StatelessWidget {
  const BriefMarkdownBlock({
    super.key,
    required this.data,
    required this.theme,
    this.onAnchorTap,
    this.gutter,
  });

  final String data;
  final BriefTheme theme;
  final ValueChanged<String>? onAnchorTap;

  /// Horizontal inset around the content — see [BriefMarkdown.gutter].
  /// Defaults to [BriefSpacing.gutter]; the section rollup overrides this
  /// to `0` since its own container already insets the available width to
  /// match the structural fields and the rollup toggle above it.
  final double? gutter;

  @override
  Widget build(BuildContext context) {
    final generator = MarkdownGenerator(
      generators: [
        // Same inline-code chip treatment as BriefMarkdown — no search
        // highlighting here, this surface never has a search query.
        SpanNodeGeneratorWithTag(
          tag: MarkdownTag.code.name,
          generator: (e, config, _) =>
              _CodeChipNode(e.textContent, config.code),
        ),
        // A `ringdrill://chip` link renders as an actionable pill
        // (ADR-0050); every other link keeps the ambient LinkConfig
        // behaviour.
        _actionChipGenerator(),
      ],
    );
    final widgets = generator.buildWidgets(
      data,
      config: _briefMarkdownConfig(theme, onAnchorTap: onAnchorTap),
    );
    // No Align/ConstrainedBox reading-column cap here, unlike BriefMarkdown:
    // that combination centers a Column that doesn't otherwise stretch to
    // fill the available width, so short content (a one-line heading plus
    // a short sentence — the common case for a rollup block) visibly
    // shifted to the middle instead of sitting flush left. BriefMarkdown's
    // own full-page reading surface is wide enough that the effect goes
    // unnoticed; a compact rollup block is exactly where it shows up. The
    // rollup's own container already caps/pads the available width
    // (RollupCard.withScrollable), so this block just fills whatever it is
    // given.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter ?? theme.spacing.gutter),
      // Deliberately no SelectionArea, unlike BriefMarkdown: the section
      // rollup wraps each block in its own tap-to-edit InkWell, and a
      // descendant SelectionArea's own tap/long-press recognizers win
      // the gesture arena over an ancestor InkWell's onTap, silently
      // breaking that navigation. This surface trades text selection
      // for a working tap target — read-only preview text, not the
      // brief's own reading surface.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      ),
    );
  }
}
