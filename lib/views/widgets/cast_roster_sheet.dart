import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/actor_form_screen.dart';

/// Bottom sheet listing all [Actor] records in the active program.
///
/// Each row shows the actor's name and phone, with a footer listing the roles
/// they are currently cast to. Tapping a row opens [ActorFormScreen] (edit).
/// Swipe-left reveals a delete action that is blocked when the actor is cast
/// in one or more roles (uses [castDeleteBlocked] ARB key). The FAB inside
/// the sheet opens [ActorFormScreen] in create mode.
///
/// All mutations are immediately persisted via [ProgramService]. The sheet
/// rebuilds its state after each mutation via [setState].
class CastRosterSheet extends StatefulWidget {
  const CastRosterSheet({super.key});

  @override
  State<CastRosterSheet> createState() => _CastRosterSheetState();
}

class _CastRosterSheetState extends State<CastRosterSheet> {
  final _service = ProgramService();

  List<Actor> _actors = [];
  List<RolePlay> _rolePlays = [];

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

  /// Returns the names of roles that this actor is cast to.
  List<String> _rolesFor(String actorUuid) => _rolePlays
      .where((rp) => rp.actorUuid == actorUuid)
      .map((rp) => rp.name)
      .toList();

  Future<void> _openEdit(Actor actor) async {
    final updated = await Navigator.of(context).push<Actor>(
      MaterialPageRoute(builder: (_) => ActorFormScreen(actor: actor)),
    );
    if (updated == null) return;
    await _service.saveActor(updated);
    _reload();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<Actor>(
      MaterialPageRoute(builder: (_) => const ActorFormScreen()),
    );
    if (created == null) return;
    await _service.saveActor(created);
    _reload();
  }

  Future<void> _tryDelete(BuildContext context, Actor actor) async {
    final localizations = AppLocalizations.of(context)!;
    final roles = _rolesFor(actor.uuid);
    if (roles.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.castDeleteBlocked(roles.length)),
        ),
      );
      return;
    }
    await _service.deleteActor(actor.uuid);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.castRoster)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.person_add),
        label: Text(localizations.newActor),
      ),
      body: _actors.isEmpty
          ? Center(child: Text(localizations.newActor))
          : ListView.builder(
              itemCount: _actors.length,
              itemBuilder: (context, index) {
                final actor = _actors[index];
                final roles = _rolesFor(actor.uuid);
                return Dismissible(
                  key: ValueKey(actor.uuid),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    final roles = _rolesFor(actor.uuid);
                    if (roles.isNotEmpty) {
                      await _tryDelete(context, actor);
                      return false;
                    }
                    return true;
                  },
                  onDismissed: (_) => _service.deleteActor(actor.uuid),
                  background: Container(
                    color: Theme.of(context).colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(
                      Icons.delete,
                      color: Theme.of(context).colorScheme.onError,
                    ),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(actor.realName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (actor.phone != null) Text(actor.phone!),
                        if (roles.isNotEmpty)
                          Text(
                            localizations.castedAs(roles.join(', ')),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    onTap: () => _openEdit(actor),
                  ),
                );
              },
            ),
    );
  }
}
