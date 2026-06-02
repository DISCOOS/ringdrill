import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/actor_form_screen.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class RosterController extends ScreenController {
  final _reloadTick = ValueNotifier<int>(0);

  /// Listenable that fires whenever the controller saves or deletes an actor
  /// so that [RosterView] can call setState without waiting for a
  /// [ProgramService] event (actor CRUD does not emit one).
  Listenable get reloadSignal => _reloadTick;

  void dispose() {
    _reloadTick.dispose();
  }

  @override
  String title(BuildContext context) =>
      AppLocalizations.of(context)!.rosterTab;

  @override
  Widget? buildFAB(BuildContext context, BoxConstraints constraints) {
    return FloatingActionButton.extended(
      icon: const Icon(Icons.add),
      label: Text(AppLocalizations.of(context)!.newActor),
      onPressed: () => _openCreate(context),
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final result = await openFormSurface<ActorFormResult>(
      context,
      builder: (_) => const ActorFormScreen(),
    );
    if (result == null || !context.mounted) return;
    if (result case ActorFormSave(:final actor)) {
      await ProgramService().saveActor(localizations, actor);
      if (context.mounted) _reloadTick.value++;
    }
  }
}

// ---------------------------------------------------------------------------
// View
// ---------------------------------------------------------------------------

/// Flat registry of every [Actor] in the active program.
///
/// Promoted from the cast-roster sheet that lives in the Spill segment —
/// that sheet remains as the inline quick-cast affordance. This view is the
/// primary home for [Actor] records on the dedicated Roster tab.
///
/// Reads and writes go exclusively through [ProgramService] actor CRUD
/// ([ProgramService.loadActors], [ProgramService.saveActor],
/// [ProgramService.deleteActor]) — no actor data is pushed to any
/// publish / wire path.
class RosterView extends StatefulWidget {
  const RosterView({super.key, required this.controller});

  final RosterController controller;

  @override
  State<RosterView> createState() => _RosterViewState();
}

class _RosterViewState extends State<RosterView> {
  final _service = ProgramService();
  StreamSubscription? _subscription;

  List<Actor> _actors = [];
  List<RolePlay> _rolePlays = [];

  RosterController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.reloadSignal.addListener(_reload);
    _subscription = _service.events.listen((_) {
      if (mounted) _reload();
    });
    _reload();
  }

  @override
  void didUpdateWidget(covariant RosterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.reloadSignal.removeListener(_reload);
      widget.controller.reloadSignal.addListener(_reload);
    }
  }

  @override
  void dispose() {
    _controller.reloadSignal.removeListener(_reload);
    _subscription?.cancel();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _actors = _service.loadActors();
      _rolePlays = _service.loadRolePlays();
    });
  }

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
        await _tryDelete(actor);
    }
    if (!mounted) return;
    _reload();
  }

  Future<void> _tryDelete(Actor actor) async {
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

    if (_actors.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
      itemCount: _actors.length,
      itemBuilder: (context, index) {
        final actor = _actors[index];
        final roles = _rolesFor(actor.uuid);
        return Dismissible(
          key: ValueKey(actor.uuid),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            if (_rolesFor(actor.uuid).isNotEmpty) {
              await _tryDelete(actor);
              return false;
            }
            return true;
          },
          onDismissed: (_) async {
            await _service.deleteActor(actor.uuid);
            _reload();
          },
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            onTap: () => _openEdit(actor),
          ),
        );
      },
    );
  }
}
