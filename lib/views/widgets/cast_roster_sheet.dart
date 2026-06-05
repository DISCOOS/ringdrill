import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/actor_form_screen.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';

/// Bottom sheet listing all [Actor] records in the active program.
///
/// Each row shows the actor's name and phone, with a footer listing the roles
/// they are currently cast to. Tapping a row opens [ActorFormScreen] (edit).
/// Swipe-left and the edit form reveal delete actions that are blocked when
/// the actor is cast in one or more roles (uses [castDeleteBlocked] ARB key).
/// The FAB inside the sheet opens [ActorFormScreen] in create mode.
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
    final localizations = AppLocalizations.of(context)!;
    final result = await openFormSurface<ActorFormResult>(
      context,
      builder: (_) => ActorFormScreen(actor: actor),
    );
    if (result == null || !mounted) return;
    switch (result) {
      case ActorFormSave(:final actor):
        await _service.saveActor(localizations, actor);
      case ActorFormDelete(:final actor):
        await _tryDelete(context, actor);
    }
    if (!mounted) return;
    _reload();
  }

  Future<void> _openCreate() async {
    final localizations = AppLocalizations.of(context)!;
    final result = await openFormSurface<ActorFormResult>(
      context,
      builder: (_) => const ActorFormScreen(),
    );
    if (result == null) return;
    if (result case ActorFormSave(:final actor)) {
      await _service.saveActor(localizations, actor);
    }
    if (!mounted) return;
    _reload();
  }

  Future<void> _tryDelete(BuildContext context, Actor actor) async {
    final localizations = AppLocalizations.of(context)!;
    final roles = _rolesFor(actor.uuid);
    if (roles.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.castDeleteBlocked(roles.length))),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.person_add),
        label: Text(localizations.newActor),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              localizations.castRoster,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: _actors.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        localizations.noActorsInRoster,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
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
                          leading: const Icon(Icons.face),
                          title: Text(actor.realName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (actor.phone != null) Text(actor.phone!),
                              if (roles.isNotEmpty)
                                Text(
                                  localizations.castedAs(roles.join(', ')),
                                  // ADR-0037: themed bodySmall instead of 12.
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
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
          ),
        ],
      ),
    );
  }
}
