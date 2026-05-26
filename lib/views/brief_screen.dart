import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/services/brief/brief_renderer.dart';
import 'package:ringdrill/services/program_service.dart';
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
    );
  }

  void _setAudience(BriefAudience audience) {
    setState(() {
      _audience = audience;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _kWideBreakpoint;
        return Scaffold(
          appBar: _buildAppBar(context, localizations, isWide),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isWide) _buildNarrowAudienceToggle(localizations),
              Expanded(
                child: _buildContent(context, localizations, isWide),
              ),
            ],
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    AppLocalizations localizations,
    bool isWide,
  ) {
    return AppBar(
      title: Text(localizations.briefScreenTitle),
      bottom: _searchOpen ? _buildSearchBar(localizations) : null,
      actions: [
        if (isWide) _buildAudienceToggle(localizations),
        if (isWide) const SizedBox(width: 8),
        IconButton(
          icon: Icon(_searchOpen ? Icons.search_off : Icons.search),
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
            tooltip: localizations.briefPrint,
            onPressed: printBrief,
          ),
      ],
    );
  }

  PreferredSizeWidget _buildSearchBar(AppLocalizations localizations) {
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
                  final hasMatch = snapshot.data!
                      .toLowerCase()
                      .contains(_searchQuery.toLowerCase());
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

  Widget _buildNarrowAudienceToggle(AppLocalizations localizations) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: _buildAudienceToggle(localizations),
    );
  }

  Widget _buildAudienceToggle(AppLocalizations localizations) {
    return SegmentedButton<BriefAudience>(
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
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations localizations,
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
              _buildTocSidebar(localizations),
              const VerticalDivider(width: 1),
              Expanded(child: _buildMarkdown(markdown)),
            ],
          );
        }
        return _buildMarkdown(markdown);
      },
    );
  }

  /// Wraps search matches in `<mark>` tags so markdown_widget renders them
  /// highlighted. Case-insensitive. Returns the original string unchanged
  /// when the query is empty.
  String _applySearch(String markdown) {
    if (_searchQuery.isEmpty) return markdown;
    final pattern = RegExp(
      RegExp.escape(_searchQuery),
      caseSensitive: false,
    );
    return markdown.replaceAllMapped(
      pattern,
      (m) => '<mark>${m.group(0)}</mark>',
    );
  }

  Widget _buildTocSidebar(AppLocalizations localizations) {
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              localizations.briefToc,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TocWidget(controller: _tocController),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdown(String markdown) {
    return MarkdownWidget(
      data: markdown,
      tocController: _tocController,
      config: MarkdownConfig(
        configs: [
          const PConfig(textStyle: TextStyle(height: 1.5)),
        ],
      ),
    );
  }
}
