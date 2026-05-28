import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/brief_renderer.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/widgets/brief_markdown.dart';
import 'package:ringdrill/views/widgets/brief_theme.dart';
// Web implementation provides a real window.print(); the stub is a no-op.
// Pattern: unqualified = web, if(dart.library.io) = native stub.
import 'package:ringdrill/web/brief_print_web.dart'
    if (dart.library.io) 'package:ringdrill/web/brief_print.dart';

/// Breakpoint above which the brief shows a left TOC sidebar and moves
/// the audience toggle into the app bar. The brief uses a higher
/// threshold than MainScreen's 600 px rail breakpoint because the TOC
/// sidebar + markdown table layout needs more horizontal room to remain
/// readable.
const double _kWideBreakpoint = 900.0;

class BriefScreen extends StatefulWidget {
  const BriefScreen({
    super.key,
    this.exerciseUuid,
    this.programUuid,
    this.isSheet = false,
    this.onClose,
  }) : assert(
         (exerciseUuid == null) != (programUuid == null),
         'exactly one of exerciseUuid or programUuid must be provided',
       );

  /// When non-null, the brief is scoped to this single exercise.
  final String? exerciseUuid;

  /// When non-null, the brief covers the whole program. Currently a marker
  /// only; the active program is resolved via `ProgramService` because the
  /// app holds at most one active program at a time.
  final String? programUuid;

  /// When `true`, the AppBar leading icon becomes a close button that calls
  /// [onClose]. Use this when the screen is embedded in a modal sheet.
  final bool isSheet;

  /// Called when the close button is tapped (only relevant when [isSheet] is
  /// `true`).
  final VoidCallback? onClose;

  @override
  State<BriefScreen> createState() => _BriefScreenState();
}

class _BriefScreenState extends State<BriefScreen> {
  BriefAudience _audience = BriefAudience.participant;
  final TocController _tocController = TocController();
  bool _searchOpen = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _wideTocSidebar = false;

  // Search-cycle state. _matchCount is recomputed when the rendered markdown
  // arrives or when the query changes. _currentMatchIndex is what the user
  // has cycled to via Enter / next-prev buttons. _renderedMarkdown caches
  // the latest async render so we can recount matches synchronously when
  // the query changes without re-rendering.
  int _matchCount = 0;
  int _currentMatchIndex = 0;
  String? _renderedMarkdown;

  // GlobalKey attached to the currently-highlighted match in the rendered
  // markdown (the <curr-mark> WidgetSpan child). On next/previous we use
  // it to call Scrollable.ensureVisible, scrolling the match into view.
  // markdown_widget's ListView.builder is lazy, so the key's context will
  // be null when the match sits far outside the cache extent — in that
  // case the scroll silently no-ops and the counter still updates so the
  // reader can scroll manually.
  final GlobalKey _currentMatchKey = GlobalKey();

  // Re-assigned when audience or layout changes so FutureBuilder re-runs.
  late Future<String> _renderFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-build on first mount (replaces initState) and whenever l10n changes.
    _renderFuture = _buildRenderFuture(AppLocalizations.of(context)!);
  }

  Future<String> _buildRenderFuture(AppLocalizations l10n) {
    final program = ProgramService().activeProgram;
    if (program == null) return Future.value('');

    Exercise? exercise;
    if (widget.exerciseUuid != null) {
      exercise = program.exercises.cast<Exercise?>().firstWhere(
        (e) => e?.uuid == widget.exerciseUuid,
        orElse: () => null,
      );
      if (exercise == null) return Future.value('');
    }

    return BriefRenderer().render(
      program: program,
      exercise: exercise,
      audience: _audience,
      l10n: l10n,
      wideTocSidebar: _wideTocSidebar,
    );
  }

  void _setAudience(BriefAudience audience) {
    setState(() {
      _audience = audience;
      _renderFuture = _buildRenderFuture(AppLocalizations.of(context)!);
    });
  }

  void _setWideTocSidebar(bool isWide) {
    if (!mounted) return;
    setState(() {
      _wideTocSidebar = isWide;
      _renderFuture = _buildRenderFuture(AppLocalizations.of(context)!);
    });
  }

  @override
  void dispose() {
    _tocController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = BriefTheme.of(context);
    final program = ProgramService().activeProgram;

    if (program == null) {
      return Scaffold(
        appBar: AppBar(title: Text(localizations.briefScreenTitle)),
        body: Center(child: Text(localizations.briefMissingProgram)),
      );
    }

    Exercise? exercise;
    if (widget.exerciseUuid != null) {
      exercise = program.exercises.cast<Exercise?>().firstWhere(
            (e) => e?.uuid == widget.exerciseUuid,
            orElse: () => null,
          );
      if (exercise == null) {
        return Scaffold(
          appBar: AppBar(title: Text(localizations.briefScreenTitle)),
          body: Center(child: Text(localizations.briefMissingExercise)),
        );
      }
    }

    if (widget.programUuid != null && widget.programUuid != program.uuid) {
      debugPrint(
        '[BriefScreen] programUuid ${widget.programUuid} does not match '
        'active program ${program.uuid}; rendering active program.',
      );
    }

    // Slim-app-bar title reflects what the reader is actually viewing.
    // Single-exercise mode shows the exercise name; program mode shows the
    // program name. Falls back to the generic localized label when neither
    // resolves (e.g. before data is loaded).
    final appBarTitle = exercise?.name ?? program.name;

    return Theme(
      data: Theme.of(context).copyWith(
        appBarTheme: AppBarTheme(
          backgroundColor: theme.surfaces.appBar,
          foregroundColor: theme.text.heading,
          elevation: 0,
        ),
        scaffoldBackgroundColor: theme.surfaces.canvas,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _kWideBreakpoint;
          if (isWide != _wideTocSidebar) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _setWideTocSidebar(isWide);
            });
          }
          return Scaffold(
            appBar: _buildAppBar(
              context,
              localizations,
              theme,
              isWide,
              appBarTitle,
            ),
            body: _buildContent(context, localizations, theme, isWide),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    AppLocalizations localizations,
    BriefTheme theme,
    bool isWide,
    String title,
  ) {
    return AppBar(
      leading: widget.isSheet
          ? IconButton(
              icon: const Icon(Icons.close),
              color: theme.text.heading,
              tooltip: localizations.briefClose,
              onPressed: widget.onClose,
            )
          : null,
      title: Text(
        title,
        style: theme.typography.h4.copyWith(color: theme.text.heading),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      shape: Border(bottom: BorderSide(color: theme.borders.subtle)),
      bottom: _searchOpen ? _buildSearchBar(localizations, theme) : null,
      actions: [
        _buildAudiencePicker(localizations, theme),
        const SizedBox(width: 4),
        IconButton(
          icon: Icon(_searchOpen ? Icons.search_off : Icons.search),
          color: theme.text.heading,
          tooltip: localizations.briefSearch,
          onPressed: () {
            setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) {
                _searchQuery = '';
                _searchController.clear();
              }
            });
          },
        ),
        if (kIsWeb)
          IconButton(
            icon: const Icon(Icons.print),
            color: theme.text.heading,
            tooltip: localizations.briefPrint,
            onPressed: printBrief,
          ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchBar(
    AppLocalizations localizations,
    BriefTheme theme,
  ) {
    final hasMatches = _matchCount > 0;
    final hasQueryButNoMatches =
        _searchQuery.isNotEmpty && _renderedMarkdown != null && _matchCount == 0;

    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: localizations.briefSearchHint,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                              _recomputeMatchCount();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _currentMatchIndex = 0;
                    _recomputeMatchCount();
                  });
                },
                onSubmitted: (_) {
                  if (_matchCount > 0) _goToNextMatch();
                },
              ),
            ),
            if (hasMatches) ...[
              const SizedBox(width: 12),
              Text(
                localizations.briefSearchMatchCount(
                  _currentMatchIndex + 1,
                  _matchCount,
                ),
                style: TextStyle(color: theme.text.muted, fontSize: 12),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                color: theme.text.heading,
                tooltip: localizations.briefSearchPreviousMatch,
                onPressed: _goToPreviousMatch,
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                color: theme.text.heading,
                tooltip: localizations.briefSearchNextMatch,
                onPressed: _goToNextMatch,
              ),
            ],
            if (hasQueryButNoMatches) ...[
              const SizedBox(width: 12),
              Text(
                localizations.briefSearchNoMatches,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Compact audience picker that lives in the slim app bar. Replaces the
  /// SegmentedButton variant because three side-by-side labels eat a lot
  /// of horizontal space — especially in the sheet's slim bar — and the
  /// visible difference between audiences is often subtle. The picker
  /// shows the current audience label with a chevron and opens a
  /// PopupMenu with the three options on tap.
  Widget _buildAudiencePicker(
    AppLocalizations localizations,
    BriefTheme theme,
  ) {
    String labelFor(BriefAudience a) {
      switch (a) {
        case BriefAudience.participant:
          return localizations.briefAudienceParticipant;
        case BriefAudience.instructor:
          return localizations.briefAudienceInstructor;
        case BriefAudience.director:
          return localizations.briefAudienceDirector;
      }
    }

    return PopupMenuButton<BriefAudience>(
      initialValue: _audience,
      onSelected: _setAudience,
      tooltip: localizations.briefAudienceParticipant,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => BriefAudience.values
          .map(
            (a) => CheckedPopupMenuItem<BriefAudience>(
              value: a,
              checked: a == _audience,
              child: Text(labelFor(a)),
            ),
          )
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              labelFor(_audience),
              style: TextStyle(
                color: theme.text.heading,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: theme.text.heading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations localizations,
    BriefTheme theme,
    bool isWide,
  ) {
    return FutureBuilder<String>(
      future: _renderFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              localizations.briefRenderError(snapshot.error.toString()),
            ),
          );
        }

        // Cache the resolved markdown in state so search-cycle controls can
        // count matches synchronously. Scheduled after the current build so
        // we don't call setState during build.
        final data = snapshot.data ?? '';
        if (_renderedMarkdown != data) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onRenderCompleted(data);
          });
        }

        final markdown = _applySearch(data);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTocSidebar(localizations, theme),
              VerticalDivider(width: 1, color: theme.borders.subtle),
              Expanded(
                child: _buildMarkdown(markdown, theme, localizations, isWide),
              ),
            ],
          );
        }
        return _buildMarkdown(markdown, theme, localizations, isWide);
      },
    );
  }

  /// Wraps search matches in `<mark>` tags so markdown_widget renders them
  /// highlighted. Case-insensitive. The current match (the one the user has
  /// cycled to via Enter / the next-prev buttons) gets a stronger
  /// `<curr-mark>` so it visually stands out from the other matches.
  /// Returns the original string unchanged when the query is empty.
  String _applySearch(String markdown) {
    if (_searchQuery.isEmpty) return markdown;
    final pattern = RegExp(RegExp.escape(_searchQuery), caseSensitive: false);
    var i = 0;
    return markdown.replaceAllMapped(pattern, (m) {
      final tag = (i == _currentMatchIndex) ? 'curr-mark' : 'mark';
      final wrapped = '<$tag>${m.group(0)}</$tag>';
      i++;
      return wrapped;
    });
  }

  /// Recomputes [_matchCount] from the cached [_renderedMarkdown] and the
  /// current [_searchQuery]. Clamps [_currentMatchIndex] into the new range.
  void _recomputeMatchCount() {
    final markdown = _renderedMarkdown;
    if (markdown == null || _searchQuery.isEmpty) {
      _matchCount = 0;
      _currentMatchIndex = 0;
      return;
    }
    final pattern = RegExp(RegExp.escape(_searchQuery), caseSensitive: false);
    _matchCount = pattern.allMatches(markdown).length;
    if (_currentMatchIndex >= _matchCount) {
      _currentMatchIndex = _matchCount == 0 ? 0 : _matchCount - 1;
    }
  }

  /// Called from the FutureBuilder once the renderer finishes. Caches the
  /// markdown and recomputes the match count if the result changed.
  void _onRenderCompleted(String markdown) {
    if (!mounted) return;
    if (_renderedMarkdown == markdown) return;
    setState(() {
      _renderedMarkdown = markdown;
      _recomputeMatchCount();
    });
  }

  void _goToNextMatch() {
    if (_matchCount == 0) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchCount;
    });
    _scheduleScrollToCurrentMatch();
  }

  void _goToPreviousMatch() {
    if (_matchCount == 0) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _matchCount) % _matchCount;
    });
    _scheduleScrollToCurrentMatch();
  }

  /// Copies the current rendered brief markdown to the system clipboard.
  /// Uses the cached `_renderedMarkdown` which is the renderer's raw output
  /// — without the `<mark>` and `<curr-mark>` highlights that the search
  /// path layers on top — so the pasted text is a clean markdown document.
  Future<void> _copyMarkdownToClipboard() async {
    final markdown = _renderedMarkdown;
    if (markdown == null || markdown.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: markdown));
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(l10n.briefMarkdownCopied),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Opens a modal bottom sheet containing the same `TocWidget` shown in
  /// the sidebar on wide screens. Tapping an entry jumps the document to
  /// that heading and closes the sheet. Used by the floating TOC button
  /// that appears in narrow mode where there is no persistent sidebar.
  Future<void> _openTocSheet(AppLocalizations l10n, BriefTheme theme) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.surfaces.sidebar,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    l10n.briefToc,
                    style: TextStyle(
                      color: theme.text.heading,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Divider(height: 1, color: theme.borders.subtle),
                Expanded(
                  child: TocWidget(
                    controller: _tocController,
                    itemBuilder: (data) {
                      final tag = data.toc.node.headingConfig.tag;
                      final level = headingTag2Level[tag] ?? 1;
                      // Outline starts at exercise (H2). H1 is the program
                      // title — the document name, not a navigation target —
                      // and H4+ are per-section metadata headings that the
                      // sidebar deliberately collapses.
                      if (level < 2 || level > 3) {
                        return const SizedBox.shrink();
                      }
                      final label = data.toc.node.build().toPlainText();
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.only(
                          left: 16.0 + 16.0 * (level - 1),
                          right: 16,
                        ),
                        title: Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: level <= 2
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: theme.text.body,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        onTap: () {
                          _tocController.jumpToIndex(data.toc.widgetIndex);
                          Navigator.of(sheetContext).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Handles tap on a markdown link whose URL begins with `#`. Resolves
  /// the anchor against the TocController's heading list (using the same
  /// slug algorithm the renderer used to emit the link target) and
  /// scrolls the matching heading into view.
  ///
  /// Without this, tapping an in-doc TOC link would let
  /// `url_launcher` navigate to `current-page#anchor`, which on Flutter
  /// Web triggers a full page reload that fails because the router does
  /// not recognise the fragment.
  void _onAnchorTap(String anchor) {
    final tocList = _tocController.tocList;
    if (tocList.isEmpty) return;
    final target = anchor.toLowerCase();
    for (final toc in tocList) {
      final headingText = toc.node.build().toPlainText();
      if (BriefRenderer.toAnchor(headingText) == target) {
        _tocController.jumpToIndex(toc.widgetIndex);
        return;
      }
    }
  }

  /// Schedules a post-frame scroll so the active `<curr-mark>` widget is
  /// brought into view. The markdown re-renders after setState, then the
  /// callback fires once the widget tree has settled. If the match's
  /// widget isn't in the render tree (markdown_widget's ListView.builder
  /// hasn't built that index yet), `currentContext` is null and we no-op.
  void _scheduleScrollToCurrentMatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _currentMatchKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 200),
        // Position the match a third of the way down the viewport so the
        // reader has surrounding context above and below.
        alignment: 0.3,
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildTocSidebar(AppLocalizations localizations, BriefTheme theme) {
    return ColoredBox(
      color: theme.surfaces.sidebar,
      child: SizedBox(
        width: theme.spacing.sidebarWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                localizations.briefToc,
                style: TextStyle(color: theme.text.muted, fontSize: 12),
              ),
            ),
            Divider(height: 1, color: theme.borders.subtle),
            Expanded(
              child: TocWidget(
                controller: _tocController,
                itemBuilder: (data) {
                  final isActive = data.index == data.currentIndex;
                  final tag = data.toc.node.headingConfig.tag;
                  final level = headingTag2Level[tag] ?? 1;
                  // Outline starts at exercise (H2). H1 is the program
                  // title — the document name, not a navigation target —
                  // and H4+ are per-section metadata headings that the
                  // sidebar deliberately collapses.
                  if (level < 2 || level > 3) {
                    return const SizedBox.shrink();
                  }
                  // The TocNode's own build() returns a TextSpan styled with
                  // the heading's full h2/h3 typography (24/18 px). That is
                  // far too big for a sidebar entry. Pull just the plain
                  // text out and re-render it with a controlled compact
                  // style — H2 entries are slightly bolder, H3 entries
                  // sit in body color at the same size for visual nesting.
                  final label = data.toc.node.build().toPlainText();
                  final tocStyle = TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: level <= 2
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: isActive ? theme.text.heading : theme.text.body,
                  );
                  return GestureDetector(
                    onTap: () {
                      // refreshIndexCallback only updates the highlighted
                      // entry in the sidebar; jumpToIndex is what actually
                      // scrolls the markdown to that heading.
                      _tocController.jumpToIndex(data.toc.widgetIndex);
                      data.refreshIndexCallback(data.index);
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 2,
                          height: 20,
                          color: isActive
                              ? theme.accent.activeStripe
                              : Colors.transparent,
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: 8.0 + 12.0 * (level - 1),
                              top: 4,
                              bottom: 4,
                              right: 8,
                            ),
                            child: Text(
                              label,
                              style: tocStyle,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdown(
    String markdown,
    BriefTheme theme,
    AppLocalizations l10n,
    bool isWide,
  ) {
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: theme.spacing.readingColumnMax,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.spacing.gutter),
              child: BriefMarkdown(
                data: markdown,
                theme: theme,
                tocController: _tocController,
                currentMatchKey: _currentMatchKey,
                onAnchorTap: _onAnchorTap,
              ),
            ),
          ),
        ),
        // Floating copy-markdown button at the top-right of the reading
        // column. Visible on every viewport.
        Positioned(
          top: 8,
          right: 8,
          child: _FloatingActionIcon(
            icon: Icons.content_copy,
            tooltip: l10n.briefCopyMarkdown,
            theme: theme,
            onPressed: _copyMarkdownToClipboard,
          ),
        ),
        // Floating TOC button at the top-left, only when the sidebar is
        // hidden (narrow viewport). Wide screens already show the TOC in
        // the persistent sidebar.
        if (!isWide)
          Positioned(
            top: 8,
            left: 8,
            child: _FloatingActionIcon(
              icon: Icons.toc,
              tooltip: l10n.briefOpenToc,
              theme: theme,
              onPressed: () => _openTocSheet(l10n, theme),
            ),
          ),
      ],
    );
  }
}

/// A small icon button styled as a soft floating affordance over the brief
/// reading column. Used for the copy-markdown and open-TOC actions that
/// sit on top of the markdown content rather than in the app bar.
class _FloatingActionIcon extends StatelessWidget {
  const _FloatingActionIcon({
    required this.icon,
    required this.tooltip,
    required this.theme,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final BriefTheme theme;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.surfaces.sidebar.withValues(alpha: 0.85),
      elevation: 0,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: theme.text.heading),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BriefSheetLauncher — transparent route that immediately opens BriefScreen
// as a fullscreen modal bottom sheet and pops itself when the sheet closes.
// ---------------------------------------------------------------------------

/// Transparent route widget that opens [BriefScreen] as a fullscreen modal
/// bottom sheet. Used by the `/brief` GoRoutes so the brief is presented as a
/// sheet on top of the current page instead of a full navigation push.
class BriefSheetLauncher extends StatefulWidget {
  const BriefSheetLauncher({super.key, this.exerciseUuid, this.programUuid})
    : assert(
        (exerciseUuid == null) != (programUuid == null),
        'exactly one of exerciseUuid or programUuid must be provided',
      );

  final String? exerciseUuid;
  final String? programUuid;

  @override
  State<BriefSheetLauncher> createState() => _BriefSheetLauncherState();
}

class _BriefSheetLauncherState extends State<BriefSheetLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet());
  }

  Future<void> _openSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      // Material 3 defaults the modal bottom sheet to a max width of 640 dp
      // on wide viewports. The Brief is the only reading surface in the app
      // and is meant to feel like a fullscreen docs page on every viewport,
      // so we override the constraint to fill the available width.
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (_) => _BriefSheetBody(
        exerciseUuid: widget.exerciseUuid,
        programUuid: widget.programUuid,
      ),
    );
    if (!mounted) return;
    // Popping the underlying transparent route works when the user reached
    // the brief from another tab (the previous route is still on the
    // stack). When the app was deep-linked directly into /brief/... — for
    // example by typing the URL into the browser, opening a shared link
    // or restarting on this page — the brief is the only route on the
    // GoRouter stack, and `pop()` would leave the navigator with nothing
    // to show ("You have popped the last page off of the stack"). Fall
    // back to the program route in that case so the user lands on a real
    // screen instead of crashing.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go(routeProgram);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ---------------------------------------------------------------------------
// _BriefSheetBody — the draggable sheet wrapping BriefScreen
// ---------------------------------------------------------------------------

class _BriefSheetBody extends StatelessWidget {
  const _BriefSheetBody({this.exerciseUuid, this.programUuid});

  final String? exerciseUuid;
  final String? programUuid;

  @override
  Widget build(BuildContext context) {
    final theme = BriefTheme.of(context);
    final localizations = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (sheetContext, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: ColoredBox(
            color: theme.surfaces.canvas,
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Semantics(
                    label: localizations.briefDragHandle,
                    child: SizedBox(
                      height: 32,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.borders.subtle,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: BriefScreen(
                    exerciseUuid: exerciseUuid,
                    programUuid: programUuid,
                    isSheet: true,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
