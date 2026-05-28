import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/actor_form_screen.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/widgets/cast_picker_sheet.dart';
import 'package:ringdrill/views/widgets/cast_roster_sheet.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/role_code_badge.dart';
import 'package:ringdrill/views/widgets/role_position_panel.dart';
import 'package:url_launcher/url_launcher.dart';

enum _CastAction { edit, clear }

/// Flat list of all [RolePlay] rows across all exercises, sorted by
/// exercise order then role index. Each row uses [ExpandableTile].
///
/// The tab also carries an exercise filter (mirrors [StationListView])
/// and a cast roster button in the AppBar.
class RolePlaysView extends StatefulWidget {
  const RolePlaysView({super.key, required this.controller});

  final RolePlaysController controller;

  @override
  State<RolePlaysView> createState() => _RolePlaysViewState();
}

class _RolePlaysViewState extends State<RolePlaysView> {
  final _service = ProgramService();
  StreamSubscription? _subscription;

  int? _expandedRowIndex;

  RolePlaysController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _subscription = _service.events.listen((_) {
      if (mounted) setState(() {});
    });
    _controller.filterExerciseUuid.addListener(_onFilterChanged);
  }

  @override
  void didUpdateWidget(covariant RolePlaysView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.filterExerciseUuid.removeListener(_onFilterChanged);
      widget.controller.filterExerciseUuid.addListener(_onFilterChanged);
    }
  }

  void _onFilterChanged() {
    if (!mounted) return;
    setState(() {
      _expandedRowIndex = null;
    });
  }

  @override
  void dispose() {
    _controller.filterExerciseUuid.removeListener(_onFilterChanged);
    _subscription?.cancel();
    super.dispose();
  }

  /// Returns a flat list of `(exerciseNumber, exercise, rolePlay)` triples
  /// sorted by exercise order (1-based) then by role index.
  List<(int, Exercise, RolePlay)> _collectRows() {
    final exercises = _service.loadExercises();
    final rolePlays = _service.loadRolePlays();
    final filterUuid = _controller.filterExerciseUuid.value;
    final rows = <(int, Exercise, RolePlay)>[];
    for (var i = 0; i < exercises.length; i++) {
      final exercise = exercises[i];
      if (filterUuid != null && exercise.uuid != filterUuid) continue;
      final exerciseNumber = i + 1;
      final roles =
          rolePlays.where((rp) => rp.exerciseUuid == exercise.uuid).toList()
            ..sort((a, b) => a.index.compareTo(b.index));
      for (final rp in roles) {
        rows.add((exerciseNumber, exercise, rp));
      }
    }
    return rows;
  }

  Exercise? _filterExercise() {
    final uuid = _controller.filterExerciseUuid.value;
    if (uuid == null) return null;
    return _service.getExercise(uuid);
  }

  bool get _hasAnyRole => _service.loadRolePlays().isNotEmpty;

  bool get _hasActiveProgram => _service.activeProgramUuid != null;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    // No-active-program guard: show hint, disable filter FAB.
    if (!_hasActiveProgram) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            localizations.noActiveProgramHint,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final rows = _collectRows();
    final filterExercise = _filterExercise();

    final Widget body;
    if (!_hasAnyRole) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            localizations.noRolesInProgram,
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (rows.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            localizations.noRolesInExercise,
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 96),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final (exerciseNumber, exercise, rolePlay) = rows[index];
          return _buildRow(
            context,
            localizations,
            exerciseNumber: exerciseNumber,
            exercise: exercise,
            rolePlay: rolePlay,
            rowIndex: index,
          );
        },
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: body),
              Positioned(
                right: 16,
                bottom: 16,
                child: _buildFilterFab(context, localizations),
              ),
            ],
          ),
        ),
        if (filterExercise != null)
          _buildFilterBanner(context, localizations, filterExercise),
      ],
    );
  }

  Widget _buildFilterFab(BuildContext context, AppLocalizations localizations) {
    return ValueListenableBuilder<String?>(
      valueListenable: _controller.filterExerciseUuid,
      builder: (context, active, _) {
        final fab = FloatingActionButton(
          heroTag: 'rolePlayFilter',
          tooltip: localizations.selectExercises,
          onPressed: () => _controller.openFilterSheet(context),
          child: const Icon(Icons.filter_list),
        );
        if (active == null) return fab;
        return Badge.count(count: 1, child: fab);
      },
    );
  }

  Widget _buildRow(
    BuildContext context,
    AppLocalizations localizations, {
    required int exerciseNumber,
    required Exercise exercise,
    required RolePlay rolePlay,
    required int rowIndex,
  }) {
    final expanded = _expandedRowIndex == rowIndex;
    final colorScheme = Theme.of(context).colorScheme;
    final actor = rolePlay.actorUuid != null
        ? _service.getActor(rolePlay.actorUuid!)
        : null;

    return Dismissible(
      key: ValueKey('role-row-${rolePlay.uuid}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: colorScheme.secondaryContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              localizations.roleSection,
              style: TextStyle(color: colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit, color: colorScheme.onSecondaryContainer),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _openRolePlayForm(exercise, rolePlay);
        return false;
      },
      child: ExpandableTile(
        leading: RoleCodeBadge(
          code: '$exerciseNumber.${rolePlay.index + 1}',
          highlight: actor != null,
        ),
        title: Text(
          () {
            final tb = StringBuffer(rolePlay.name);
            if (rolePlay.age != null) tb.write(', ${rolePlay.age}');
            if (actor != null) tb.write(' (${actor.realName})');
            return tb.toString();
          }(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          (rolePlay.stationIndex != null &&
                  rolePlay.stationIndex! < exercise.stations.length)
              ? localizations.roleSubtitleStation(
                  exercise.stations[rolePlay.stationIndex!].name,
                )
              : localizations.roleSubtitleExercise(exercise.name),
        ),
        trailing: _buildCastChip(context, localizations, rolePlay, actor),
        expanded: expanded,
        onOpen: () => _openRolePlay(rolePlay),
        onToggle: () {
          setState(() {
            _expandedRowIndex = expanded ? null : rowIndex;
          });
        },
        body: _buildExpandedBody(
          context,
          localizations,
          exercise,
          rolePlay,
          actor,
        ),
      ),
    );
  }

  Widget _buildCastChip(
    BuildContext context,
    AppLocalizations localizations,
    RolePlay rolePlay,
    Actor? actor,
  ) {
    return IconButton(
      tooltip: actor != null ? localizations.editCast : localizations.addCast,
      icon: Icon(
        actor != null ? Icons.person : Icons.person_add_outlined,
        color: actor != null
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: () => _openCastPicker(rolePlay),
    );
  }

  Widget _buildExpandedBody(
    BuildContext context,
    AppLocalizations localizations,
    Exercise exercise,
    RolePlay rolePlay,
    Actor? actor,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Scenario fields — labeled, matching the RolePlayScreen card style
        if (rolePlay.signalement?.isNotEmpty == true) ...[
          _ExpandedFieldBlock(
            label: localizations.roleSignalement,
            text: rolePlay.signalement!,
          ),
          const SizedBox(height: 8),
        ],
        if (rolePlay.background?.isNotEmpty == true) ...[
          _ExpandedFieldBlock(
            label: localizations.roleBackground,
            text: rolePlay.background!,
          ),
          const SizedBox(height: 8),
        ],
        if (rolePlay.behavior?.isNotEmpty == true) ...[
          _ExpandedFieldBlock(
            label: localizations.roleBehavior,
            text: rolePlay.behavior!,
          ),
          const SizedBox(height: 8),
        ],

        // Position panel (label row + mini-map)
        if (rolePlay.position != null) ...[
          const Divider(height: 16),
          RolePositionPanel(
            key: ValueKey('role-map-${rolePlay.uuid}'),
            position: rolePlay.position!,
            label: rolePlay.name,
            mapHeight: 140,
          ),
        ],

        const Divider(height: 16),

        // Cast
        if (actor == null)
          TextButton.icon(
            onPressed: () => _openCastPicker(rolePlay),
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: Text(localizations.addCast),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(actor.realName, style: theme.textTheme.bodyMedium),
                    if (actor.phone != null)
                      InkWell(
                        onTap: () => launchUrl(Uri.parse('tel:${actor.phone}')),
                        child: Text(
                          actor.phone!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    if (actor.notes != null && actor.notes!.isNotEmpty)
                      Text(
                        actor.notes!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    Text(
                      localizations.castPrivateHint,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_CastAction>(
                onSelected: (action) async {
                  if (action == _CastAction.clear) {
                    await _clearCast(rolePlay);
                  } else {
                    await _editCast(actor, rolePlay);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _CastAction.edit,
                    child: Text(localizations.editCast),
                  ),
                  PopupMenuItem(
                    value: _CastAction.clear,
                    child: Text(localizations.clearCast),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildFilterBanner(
    BuildContext context,
    AppLocalizations localizations,
    Exercise exercise,
  ) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.filter_alt,
                size: 18,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  localizations.showingRolesIn(exercise.name),
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => _controller.filterExerciseUuid.value = null,
                child: Text(localizations.showAllRoles),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openRolePlay(RolePlay rolePlay) async {
    await ContextSheet.of(
      context,
    ).show(context, RoleSheetTarget(rolePlayUuid: rolePlay.uuid));
    if (mounted) setState(() {});
  }

  Future<void> _openRolePlayForm(Exercise exercise, RolePlay rolePlay) async {
    final localizations = AppLocalizations.of(context)!;
    final updated = await Navigator.of(context).push<RolePlay>(
      MaterialPageRoute(
        builder: (_) =>
            RolePlayFormScreen(rolePlay: rolePlay, exercise: exercise),
      ),
    );
    if (updated == null || !mounted) return;
    await _service.saveRolePlay(localizations, updated);
    if (mounted) setState(() {});
  }

  Future<void> _openCastPicker(RolePlay rolePlay) async {
    final localizations = AppLocalizations.of(context)!;
    final actorUuid = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => CastPickerSheet(rolePlay: rolePlay),
    );
    if (actorUuid == null || !mounted) return;
    await _service.saveRolePlay(
      localizations,
      rolePlay.copyWith(actorUuid: actorUuid),
    );
    if (mounted) setState(() {});
  }

  Future<void> _clearCast(RolePlay rolePlay) async {
    final localizations = AppLocalizations.of(context)!;
    await _service.saveRolePlay(
      localizations,
      rolePlay.copyWith(actorUuid: null),
    );
    if (mounted) setState(() {});
  }

  Future<void> _editCast(Actor actor, RolePlay rolePlay) async {
    final localizations = AppLocalizations.of(context)!;
    final updated = await Navigator.of(context).push<Actor>(
      MaterialPageRoute(builder: (_) => ActorFormScreen(actor: actor)),
    );
    if (updated == null || !mounted) return;
    await _service.saveActor(localizations, updated);
    if (mounted) setState(() {});
  }
}

// ---------------------------------------------------------------------------
// Small helper widget — labeled field block matching RolePlayScreen style.
// ---------------------------------------------------------------------------

class _ExpandedFieldBlock extends StatelessWidget {
  const _ExpandedFieldBlock({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(text),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Owns the current exercise filter selection for the RolePlays tab.
/// Mirrors [StationListController] in structure.
class RolePlaysController extends ScreenController {
  RolePlaysController();

  final ValueNotifier<String?> filterExerciseUuid = ValueNotifier<String?>(
    null,
  );

  void dispose() {
    filterExerciseUuid.dispose();
  }

  @override
  String title(BuildContext context) =>
      AppLocalizations.of(context)!.rolePlaysTab;

  @override
  List<Widget>? buildActions(BuildContext context, BoxConstraints constraints) {
    final localizations = AppLocalizations.of(context)!;
    final hasActiveProgram = ProgramService().activeProgramUuid != null;
    return [
      IconButton(
        icon: const Icon(Icons.recent_actors),
        tooltip: hasActiveProgram
            ? localizations.castSection
            : localizations.noActiveProgramHint,
        onPressed: hasActiveProgram ? () => _openCastRoster(context) : null,
      ),
    ];
  }

  Future<void> _openCastRoster(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 1.0,
        child: CastRosterSheet(),
      ),
    );
  }

  Future<void> openFilterSheet(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final exercises = ProgramService().loadExercises();
    final current = filterExerciseUuid.value;
    final selected = await showModalBottomSheet<_FilterChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final groupValue = current == null
            ? const _FilterChoice.all()
            : _FilterChoice.one(current);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RadioGroup<_FilterChoice>(
              groupValue: groupValue,
              onChanged: (choice) {
                if (choice == null) return;
                Navigator.pop(sheetContext, choice);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Radio<_FilterChoice>(
                      value: _FilterChoice.all(),
                    ),
                    title: Text(localizations.allExercises),
                    onTap: () =>
                        Navigator.pop(sheetContext, const _FilterChoice.all()),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: exercises.length,
                      itemBuilder: (context, index) {
                        final ex = exercises[index];
                        final choice = _FilterChoice.one(ex.uuid);
                        return ListTile(
                          leading: Radio<_FilterChoice>(value: choice),
                          title: Text(ex.name),
                          onTap: () => Navigator.pop(sheetContext, choice),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected != null) {
      filterExerciseUuid.value = selected.uuid;
    }
  }
}

class _FilterChoice {
  final String? uuid;
  const _FilterChoice.all() : uuid = null;
  const _FilterChoice.one(String this.uuid);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _FilterChoice && other.uuid == uuid;

  @override
  int get hashCode => uuid.hashCode;
}
