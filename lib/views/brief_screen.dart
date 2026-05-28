import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/brief_renderer.dart';
import 'package:ringdrill/services/program_service.dart';
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
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isWide) _buildNarrowAudienceToggle(localizations, theme),
                Expanded(
                  child: _buildContent(context, localizations, theme, isWide),
                ),
              ],
            ),
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
        if (isWide) _buildAudienceToggle(localizations, theme),
        if (isWide) const SizedBox(width: 8),
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

  Widget _buildNarrowAudienceToggle(
    AppLocalizations localizations,
    BriefTheme theme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: _buildAudienceToggle(localizations, theme),
    );
  }

  Widget _buildAudienceToggle(
    AppLocalizations localizations,
    BriefTheme theme,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return theme.surfaces.sidebar;
              }
              return Colors.transparent;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return theme.text.heading;
              }
              return theme.text.body;
            }),
          ),
        ),
      ),
      child: SegmentedButton<BriefAudience>(
        segments: [
          ButtonSegment(
            value: BriefAudience.participant,
            label: Text(localizations.briefAudienceParticipant),
          ),
          ButtonSegment(
            value: BriefAudience.instructor,
            label: Text(localizations.briefAudienceInstructor),
          ),
          ButtonSegment(
            value: BriefAudience.director,
            label: Text(localizations.briefAudienceDirector),
          ),
        ],
        selected: {_audience},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => _setAudience(selection.first),
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
              Expanded(child: _buildMarkdown(markdown, theme)),
            ],
          );
        }
        return _buildMarkdown(markdown, theme);
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
                  if (level > 3) return const SizedBox.shrink();
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
                    onTap: () => data.refreshIndexCallback(data.index),
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

  Widget _buildMarkdown(String markdown, BriefTheme theme) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: theme.spacing.readingColumnMax),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.spacing.gutter),
          child: BriefMarkdown(
            data: markdown,
            theme: theme,
            tocController: _tocController,
            currentMatchKey: _currentMatchKey,
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
    if (mounted) Navigator.of(context).pop();
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
