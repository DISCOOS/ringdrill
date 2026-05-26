import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/roleplay_form_screen.dart';
import 'package:ringdrill/views/widgets/role_marker.dart';

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
              // Name + age
              Text(
                rolePlay.age != null
                    ? '${rolePlay.name}, ${rolePlay.age}'
                    : rolePlay.name,
                style: Theme.of(context).textTheme.headlineSmall,
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
              const Divider(height: 24),

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
              if (rolePlay.behavior?.isNotEmpty == true) ...[
                _FieldBlock(
                  label: localizations.roleBehavior,
                  text: rolePlay.behavior!,
                ),
                const SizedBox(height: 8),
              ],

              // Station
              _StationRow(
                stationIndex: rolePlay.stationIndex,
                exercise: exercise,
                noStation: localizations.noStationAssigned,
              ),

              // Position mini-map
              if (rolePlay.position != null) ...[
                const SizedBox(height: 16),
                _RoleMiniMap(
                  position: rolePlay.position!,
                  label: rolePlay.name,
                ),
              ],
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

/// Compact static preview of a role's position. Tapping opens a bottom sheet
/// with an interactive full-screen map. Mirrors the StationMiniMap pattern
/// but accepts a LatLng directly rather than a Station/Exercise pair so it
/// stays domain-agnostic per the project's MapView rule.
class _RoleMiniMap extends StatelessWidget {
  const _RoleMiniMap({required this.position, required this.label});

  final LatLng position;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openMapSheet(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: IgnorePointer(
            child: MapView(
              layers: MapConfig.layers,
              withToggle: false,
              initialZoom: 15,
              initialCenter: position,
              markers: [
                MapMarkerSpec(
                  id: 0,
                  label: label,
                  point: position,
                  child: const RoleMarker(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMapSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 1.0,
        child: MapView(
          layers: MapConfig.layers,
          withZoom: true,
          withCenter: true,
          withToggle: true,
          initialZoom: 16,
          initialCenter: position,
          interactionFlags: MapConfig.interactive,
          markers: [
            MapMarkerSpec(
              id: 0,
              label: label,
              point: position,
              child: const RoleMarker(),
            ),
          ],
        ),
      ),
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
    return Row(
      children: [
        const Icon(Icons.place, size: 18),
        const SizedBox(width: 8),
        Text('Post: ${station.name}'),
      ],
    );
  }
}
