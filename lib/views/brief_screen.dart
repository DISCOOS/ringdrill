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
  const BriefScreen({super.key, this.exerciseUuid, this.programUuid})
    : assert(
        (exerciseUuid == null) != (programUuid == null),
        'exactly one of exerciseUuid or programUuid must be provided',
      );

  /// When non-null, the brief is scoped to this single exercise.
  final String? exerciseUuid;

  /// When non-null, the brief covers the whole program. Currently a marker
  /// only; the active program is resolved via `ProgramService` because the
  /// app holds at most one active program at a time.
  final String? programUuid;

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

  // Re-assigned when audience changes so FutureBuilder re-runs.
  late Future<String> _renderFuture;

  @override
  void initState() {
    super.initState();
    _renderFuture = _buildRenderFuture();
  }

  Future<String> _buildRenderFuture() {
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
      wideTocSidebar: _wideTocSidebar,
    );
  }

  void _setAudience(BriefAudience audience) {
    setState(() {
      _audience = audience;
      _renderFuture = _buildRenderFuture();
    });
  }

  void _setWideTocSidebar(bool isWide) {
    if (!mounted) return;
    setState(() {
      _wideTocSidebar = isWide;
      _renderFuture = _buildRenderFuture();
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

    if (widget.exerciseUuid != null) {
      final found = program.exercises.any((e) => e.uuid == widget.exerciseUuid);
      if (!found) {
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
            appBar: _buildAppBar(context, localizations, theme, isWide),
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
  ) {
    return AppBar(
      title: Text(
        localizations.briefScreenTitle,
        style: theme.typography.h4.copyWith(color: theme.text.heading),
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
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(width: 8),
              FutureBuilder<String>(
                future: _renderFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final hasMatch = snapshot.data!.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  );
                  if (hasMatch) return const SizedBox.shrink();
                  return Text(
                    localizations.briefSearchNoMatches,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  );
                },
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

        final markdown = _applySearch(snapshot.data ?? '');

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
  /// highlighted. Case-insensitive. Returns the original string unchanged
  /// when the query is empty.
  String _applySearch(String markdown) {
    if (_searchQuery.isEmpty) return markdown;
    final pattern = RegExp(RegExp.escape(_searchQuery), caseSensitive: false);
    return markdown.replaceAllMapped(
      pattern,
      (m) => '<mark>${m.group(0)}</mark>',
    );
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
                  return GestureDetector(
                    onTap: () => data.refreshIndexCallback(data.index),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 2,
                          height: 24,
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
                            child: ProxyRichText(data.toc.node.build()),
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
          ),
        ),
      ),
    );
  }
}
