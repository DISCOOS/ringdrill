import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/actor_form_screen.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';

/// Bottom sheet for assigning an [Actor] to a [RolePlay].
///
/// Shows a searchable list of all [Actor] records. If the actor is already
/// cast to another role in the same exercise an [alreadyCastAs] annotation
/// appears below their name (still selectable). A sticky "New actor" row at
/// the top lets the user create an actor inline via [ActorFormScreen].
///
/// Returns [CastPickerSelect] when an actor is selected, [CastPickerClear]
/// when the current actor is removed, or null on cancel.
///
/// Usage:
/// ```dart
/// final result = await showRingdrillActionSheet<CastPickerResult>(
///   context: context,
///   builder: (context) => CastPickerSheet(rolePlay: rolePlay),
/// );
/// ```
class CastPickerSheet extends StatefulWidget {
  const CastPickerSheet({super.key, required this.rolePlay});

  final RolePlay rolePlay;

  @override
  State<CastPickerSheet> createState() => _CastPickerSheetState();
}

sealed class CastPickerResult {
  const CastPickerResult();
}

final class CastPickerSelect extends CastPickerResult {
  const CastPickerSelect(this.actorUuid);

  final String actorUuid;
}

final class CastPickerClear extends CastPickerResult {
  const CastPickerClear();
}

class _CastPickerSheetState extends State<CastPickerSheet> {
  final _service = ProgramService();
  final _searchController = TextEditingController();

  List<Actor> _actors = [];
  List<RolePlay> _rolePlays = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _actors = _service.loadActors();
      _rolePlays = _service.loadRolePlays();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Returns the name of a role (in the same exercise) that this actor is
  /// already cast to, or null if they are uncast / cast only in other exercises.
  String? _crossCastName(String actorUuid) {
    for (final rp in _rolePlays) {
      if (rp.actorUuid == actorUuid &&
          rp.exerciseUuid == widget.rolePlay.exerciseUuid &&
          rp.uuid != widget.rolePlay.uuid) {
        return rp.name;
      }
    }
    return null;
  }

  List<Actor> get _filtered {
    if (_query.isEmpty) return _actors;
    final q = _query.toLowerCase();
    return _actors.where((a) => a.realName.toLowerCase().contains(q)).toList();
  }

  Future<void> _createAndSelect() async {
    final localizations = AppLocalizations.of(context)!;
    final result = await openFormSurface<ActorFormResult>(
      context,
      builder: (_) => const ActorFormScreen(),
    );
    if (result == null || !mounted) return;
    if (result case ActorFormSave(:final actor)) {
      await _service.saveActor(localizations, actor);
      if (!mounted) return;
      Navigator.of(context).pop(CastPickerSelect(actor.uuid));
    }
  }

  void _select(String actorUuid) {
    Navigator.of(context).pop(CastPickerSelect(actorUuid));
  }

  void _clear() {
    Navigator.of(context).pop(const CastPickerClear());
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final filtered = _filtered;
    final hasCurrentActor = widget.rolePlay.actorUuid != null;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.6;

    return SizedBox(
      height: sheetHeight,
      child: Column(
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              localizations.castPickerTitle(widget.rolePlay.name),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: localizations.castRoster,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),

          // Actor list
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length + 2 + (hasCurrentActor ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const Icon(Icons.person_add),
                    title: Text(localizations.newActor),
                    onTap: _createAndSelect,
                  );
                }

                if (hasCurrentActor && index == 1) {
                  return ListTile(
                    leading: const Icon(Icons.person_remove),
                    title: Text(localizations.clearCast),
                    onTap: _clear,
                  );
                }

                final dividerIndex = hasCurrentActor ? 2 : 1;
                if (index == dividerIndex) {
                  return const Divider(height: 1);
                }

                final actor = filtered[index - dividerIndex - 1];
                final crossCast = _crossCastName(actor.uuid);
                final isSelected = actor.uuid == widget.rolePlay.actorUuid;

                return ListTile(
                  selected: isSelected,
                  leading: const Icon(Icons.face),
                  title: Text(actor.realName),
                  subtitle: crossCast != null
                      ? Text(
                          localizations.alreadyCastAs(crossCast),
                          // ADR-0037: themed bodySmall instead of 12.
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        )
                      : (actor.phone != null ? Text(actor.phone!) : null),
                  trailing: isSelected ? const Icon(Icons.check) : null,
                  onTap: () => _select(actor.uuid),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
