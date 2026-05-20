import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/program_diff_widgets.dart';
import 'package:ringdrill/views/program_view.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> showAddExercisesDialog(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width > 600) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 560,
            maxHeight: 560,
            minWidth: 460,
          ),
          child: const _AddExercisesBody(),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
    ),
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: const _AddExercisesBody(),
    ),
  );
}

Program projectMergedProgram(
  Program active,
  Program source,
  List<String> selectedExerciseUuids,
) {
  final selected = source.exercises.where(
    (exercise) => selectedExerciseUuids.contains(exercise.uuid),
  );
  return active.copyWith(
    exercises: _unionByUuid(active.exercises, selected, (item) => item.uuid),
    teams: _unionByUuid(active.teams, source.teams, (item) => item.uuid),
  );
}

Program applyProjectedMerge(
  Program active,
  Program source,
  List<String> selectedExerciseUuids,
) {
  return projectMergedProgram(active, source, selectedExerciseUuids);
}

List<T> _unionByUuid<T>(
  Iterable<T> base,
  Iterable<T> incoming,
  String Function(T item) uuid,
) {
  final byUuid = {for (final item in base) uuid(item): item};
  for (final item in incoming) {
    byUuid[uuid(item)] = item;
  }
  return byUuid.values.toList();
}

class _AddExercisesBody extends StatefulWidget {
  const _AddExercisesBody();

  @override
  State<_AddExercisesBody> createState() => _AddExercisesBodyState();
}

class _AddExercisesBodyState extends State<_AddExercisesBody>
    with SingleTickerProviderStateMixin {
  final _programService = ProgramService();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const SizedBox(height: 8),
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: localizations.libraryMyPlans),
                Tab(text: localizations.addFromFile),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildFromPlans(context), _buildFromFile(context)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFromFile(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    size: 64,
                    color: colors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations.libraryFromFileHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    icon: const Icon(Icons.folder_open),
                    label: Text(localizations.libraryFromFilePickAction),
                    onPressed: () => _mergeFromFile(context),
                  ),
                ],
              ),
            ),
          ),
        ),
        TabFooter(subtitle: localizations.addExercisesFromFileSubtitle),
      ],
    );
  }

  Widget _buildFromPlans(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final activeUuid = _programService.activeProgramUuid;
    final programs = _programService
        .listPrograms()
        .where((program) => program.uuid != activeUuid)
        .toList();

    return Column(
      children: [
        Expanded(
          child: programs.isEmpty
              ? EmptyState(
                  icon: Icons.folder_open_outlined,
                  text: localizations.addExercisesEmptyMyPlans,
                )
              : ListView.builder(
                  itemCount: programs.length,
                  itemBuilder: (context, index) {
                    final program = programs[index];
                    final loaded =
                        _programService.loadProgram(program.uuid) ?? program;
                    return ListTile(
                      title: Text(program.name),
                      subtitle: Text(_programSubtitle(localizations, loaded)),
                      onTap: () => _mergeIntoActivePlan(context, loaded),
                    );
                  },
                ),
        ),
        TabFooter(subtitle: localizations.addExercisesMyPlansSubtitle),
      ],
    );
  }

  Future<void> _mergeFromFile(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final drillFile = await ProgramPageController.pickOpenFile(
      context,
      _constraintsFor(context),
      localizations,
    );
    if (!context.mounted || drillFile == null) return;

    try {
      final source = drillFile.program();
      final selectedUuids = await _selectAndConfirmMerge(context, source);
      if (!context.mounted || selectedUuids == null) return;

      final program = await _programService.importProgram(
        localizations,
        drillFile,
        onSelect: (items) async =>
            items.where((exercise) => selectedUuids.contains(exercise.uuid)),
      );
      if (!context.mounted || program == null) return;
      _showSnackBar(context, localizations.importSuccess(drillFile.fileName));
      Navigator.pop(context);
    } on Exception catch (e, stackTrace) {
      if (context.mounted) {
        _showSnackBar(context, localizations.importFailure(drillFile.fileName));
      }
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
    }
  }

  Future<void> _mergeIntoActivePlan(
    BuildContext context,
    Program source,
  ) async {
    final localizations = AppLocalizations.of(context)!;
    final selectedUuids = await _selectAndConfirmMerge(context, source);
    if (!context.mounted || selectedUuids == null) return;

    await _programService.mergeFromProgram(
      localizations,
      source,
      selectedUuids,
    );
    if (!context.mounted) return;
    Navigator.pop(context);
  }

  Future<List<String>?> _selectAndConfirmMerge(
    BuildContext context,
    Program source,
  ) async {
    final localizations = AppLocalizations.of(context)!;
    final active = _programService.activeProgram;
    if (active == null) return null;

    final selectedUuids = await ProgramPageControllerBase.selectExercises(
      context,
      localizations.importProgram,
      source.exercises,
      _constraintsFor(context),
      localizations,
      true,
    );
    if (!context.mounted || selectedUuids.isEmpty) return null;

    final projected = projectMergedProgram(active, source, selectedUuids);
    final diff = diffPrograms(active, projected);
    if (diff.modifiedExercises.isEmpty && diff.modifiedTeams.isEmpty) {
      return selectedUuids;
    }

    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.confirmChangesTitle),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DiffGroup(
                  title: localizations.catalogDiffExercises,
                  added: diff.addedExercises,
                  removed: diff.removedExercises,
                  modified: diff.modifiedExercises,
                ),
                DiffGroup(
                  title: localizations.catalogDiffTeams,
                  added: diff.addedTeams,
                  removed: diff.removedTeams,
                  modified: diff.modifiedTeams,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localizations.apply),
          ),
        ],
      ),
    );

    return apply == true ? selectedUuids : null;
  }
}

String _programSubtitle(AppLocalizations localizations, Program program) {
  return [
    _sourceLabel(localizations, program.source),
    localizations.exercise(program.exercises.length),
  ].join(' · ');
}

String _sourceLabel(AppLocalizations localizations, ProgramSource source) {
  return source.when(
    local: () => localizations.librarySourceLocal,
    imported: (fileName) => localizations.librarySourceImported(fileName),
    catalog: (slug, latestEtag, installedAt) =>
        localizations.librarySourceCatalog(slug),
  );
}

BoxConstraints _constraintsFor(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return BoxConstraints.tight(size);
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      showCloseIcon: true,
      dismissDirection: DismissDirection.endToStart,
      content: Text(message),
    ),
  );
}
