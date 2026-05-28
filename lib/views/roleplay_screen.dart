import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/role_position_panel.dart';

/// Read-only view of a single [RolePlay]. Shows the publishable scenario
/// fields (name, age, signalement, background, behavior, station, position).
///
/// The Cast section (Actor assignment) is intentionally absent here because
/// this view represents the publishable role, not the local cast record.
/// Casting is managed from the RolePlays list via the cast picker.
///
/// Tap the edit pencil in the AppBar to push [RolePlayFormScreen].
///
/// TODO: When the observer-player shell (DESIGN-001) lands, a Role tab will
/// surface these same fields in the player context via a separate route.
class RolePlayScreen extends StatefulWidget {
  const RolePlayScreen({super.key, required this.rolePlayUuid});

  final String rolePlayUuid;

  @override
  State<RolePlayScreen> createState() => _RolePlayScreenState();
}

class _RolePlayScreenState extends State<RolePlayScreen> {
  final _programService = ProgramService();

  RolePlay? _rolePlay;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _rolePlay = _programService.getRolePlay(widget.rolePlayUuid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final rolePlay = _rolePlay;

    if (rolePlay == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final exercise = _programService.getExercise(rolePlay.exerciseUuid);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.rolePlayScreenTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: localizations.roleSection,
            onPressed: () async {
              final updated = await Navigator.of(context).push<RolePlay>(
                MaterialPageRoute(
                  builder: (_) => RolePlayFormScreen(
                    rolePlay: rolePlay,
                    exercise: exercise,
                  ),
                ),
              );
              if (updated != null) {
                await _programService.saveRolePlay(localizations, updated);
                if (context.mounted) _load();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Identity header — name + age + exercise name (outside card,
              // mirrors the station-name heading in StationExerciseScreen)
              Text(
                rolePlay.age != null
                    ? '${rolePlay.name}, ${rolePlay.age}'
                    : rolePlay.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (exercise != null) ...[
                const SizedBox(height: 4),
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // Scenario fields — only shown when at least one is present
              if (rolePlay.signalement?.isNotEmpty == true ||
                  rolePlay.background?.isNotEmpty == true ||
                  rolePlay.behavior?.isNotEmpty == true)
                Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.theater_comedy,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              localizations.roleSection,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (rolePlay.signalement?.isNotEmpty == true) ...[
                          _FieldBlock(
                            label: localizations.roleSignalement,
                            text: rolePlay.signalement!,
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (rolePlay.background?.isNotEmpty == true) ...[
                          _FieldBlock(
                            label: localizations.roleBackground,
                            text: rolePlay.background!,
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (rolePlay.behavior?.isNotEmpty == true)
                          _FieldBlock(
                            label: localizations.roleBehavior,
                            text: rolePlay.behavior!,
                          ),
                      ],
                    ),
                  ),
                ),

              // Station card
              Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _StationRow(
                    stationIndex: rolePlay.stationIndex,
                    exercise: exercise,
                    noStation: localizations.noStationAssigned,
                  ),
                ),
              ),

              // Position card
              if (rolePlay.position != null)
                Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 8),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: RolePositionPanel(
                      position: rolePlay.position!,
                      label: rolePlay.name,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  const _FieldBlock({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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

class _StationRow extends StatelessWidget {
  const _StationRow({
    required this.stationIndex,
    required this.noStation,
    this.exercise,
  });

  final int? stationIndex;
  final dynamic exercise;
  final String noStation;

  @override
  Widget build(BuildContext context) {
    if (stationIndex == null || exercise == null) {
      return Text(
        noStation,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    final stations = exercise.stations as List<dynamic>;
    if (stationIndex! >= stations.length) return Text(noStation);
    final station = stations[stationIndex!];
    return InkWell(
      onTap: () => ContextSheet.of(context).replace(
        StationSheetTarget(
          exerciseUuid: exercise.uuid as String,
          stationIndex: stationIndex!,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.place, size: 18),
          const SizedBox(width: 8),
          Text('Post: ${station.name}'),
        ],
      ),
    );
  }
}
