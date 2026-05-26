import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/actor_form_screen.dart';

/// Bottom sheet for assigning an [Actor] to a [RolePlay].
///
/// Shows a searchable list of all [Actor] records. If the actor is already
/// cast to another role in the same exercise an [alreadyCastAs] annotation
/// appears below their name (still selectable). A sticky "New actor" row at
/// the top lets the user create an actor inline via [ActorFormScreen].
///
/// Returns the selected [Actor.uuid] on selection, or null on cancel.
///
/// Usage:
/// ```dart
/// final uuid = await showModalBottomSheet<String>(
///   context: context,
///   isScrollControlled: true,
///   useSafeArea: true,
///   showDragHandle: true,
///   builder: (_) => CastPickerSheet(rolePlay: rolePlay),
/// );
/// ```
class CastPickerSheet extends StatefulWidget {
  const CastPickerSheet({super.key, required this.rolePlay});

  final RolePlay rolePlay;

  @override
  State<CastPickerSheet> createState() => _CastPickerSheetState();
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
    final created = await Navigator.of(context).push<Actor>(
      MaterialPageRoute(builder: (_) => const ActorFormScreen()),
    );
    if (created == null || !mounted) return;
    await _service.saveActor(localizations, created);
    if (!mounted) return;
    Navigator.of(context).pop(created.uuid);
  }

  void _select(String actorUuid) => Navigator.of(context).pop(actorUuid);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final filtered = _filtered;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) {
        return Column(
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
                controller: scrollController,
                itemCount: filtered.length + 1, // +1 for "New actor" row
                itemBuilder: (context, index) {
                  // Sticky new-actor row at top
                  if (index == 0) {
                    return ListTile(
                      leading: const Icon(Icons.person_add),
                      title: Text(localizations.newActor),
                      onTap: _createAndSelect,
                    );
                  }

                  final actor = filtered[index - 1];
                  final crossCast = _crossCastName(actor.uuid);

                  return ListTile(
                    leading: const Icon(Icons.face),
                    title: Text(actor.realName),
                    subtitle: crossCast != null
                        ? Text(
                            localizations.alreadyCastAs(crossCast),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          )
                        : (actor.phone != null ? Text(actor.phone!) : null),
                    onTap: () => _select(actor.uuid),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
