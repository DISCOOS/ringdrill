import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/active_plan_actions.dart' as active_actions;
import 'package:ringdrill/views/actor_form_screen.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/teaching_empty_state.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class RosterController extends ScreenController {
  final _reloadTick = ValueNotifier<int>(0);

  /// Listenable that fires whenever the controller saves or deletes an actor
  /// so that [RosterView] can call setState without waiting for a
  /// [PlanService] event (actor CRUD does not emit one).
  Listenable get reloadSignal => _reloadTick;

  void dispose() {
    _reloadTick.dispose();
  }

  @override
  String title(BuildContext context) =>
      // Mirror the Plan tab header so the Roster tab anchors in the
      // active plan (DESIGN-006: Roster is a plan-scoped layer). Falls
      // back to the bottom-nav label when no plan is active yet so the
      // header still reads cleanly on first launch.
      PlanService().activePlan?.name ??
      AppLocalizations.of(context)!.rosterTab;

  @override
  Widget? buildFAB(BuildContext context, BoxConstraints constraints) {
    final label = AppLocalizations.of(context)!.newActor;
    // Compact circular FAB on phones so the labelled bar does not cover the
    // bottom list rows; keep the extended variant on medium/expanded.
    if (WindowSizeClass.of(context) == WindowSizeClass.compact) {
      return FloatingActionButton(
        tooltip: label,
        onPressed: () => _openCreate(context),
        child: const Icon(Icons.add),
      );
    }
    return FloatingActionButton.extended(
      icon: const Icon(Icons.add),
      label: Text(label),
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
      await PlanService().saveActor(localizations, actor);
      if (context.mounted) _reloadTick.value++;
    }
  }
}

// ---------------------------------------------------------------------------
// View
// ---------------------------------------------------------------------------

/// Flat registry of every [Actor] in the active plan.
///
/// Promoted from the cast-roster sheet that lives in the Spill segment —
/// that sheet remains as the inline quick-cast affordance. This view is the
/// primary home for [Actor] records on the dedicated Roster tab.
///
/// Reads and writes go exclusively through [PlanService] actor CRUD
/// ([PlanService.loadActors], [PlanService.saveActor],
/// [PlanService.deleteActor]) — no actor data is pushed to any
/// publish / wire path.
class RosterView extends StatefulWidget {
  const RosterView({
    super.key,
    required this.controller,
    this.refreshIndicatorKey,
  });

  final RosterController controller;

  /// Lets the host (`MainScreen`) reuse this view's pull-to-refresh
  /// [RefreshIndicator] from elsewhere — the drawer's "Oppdater fra
  /// katalog" entry triggers it via `CatalogRefreshIndicatorRegistry`
  /// instead of running the refresh with no visible progress. Null in
  /// contexts that don't need that (e.g. most tests).
  final GlobalKey<RefreshIndicatorState>? refreshIndicatorKey;

  @override
  State<RosterView> createState() => _RosterViewState();
}

class _RosterViewState extends State<RosterView> {
  final _service = PlanService();
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

    final Widget content;
    if (_actors.isEmpty) {
      // Same teaching affordance as the empty Plan segments so the
      // Roster tab reads with the same visual language (icon disc +
      // title + body) instead of a bare centered string. The cast
      // roster sheet keeps the compact noActorsInRoster one-liner.
      //
      // Wrapped in a CustomScrollView (rather than returned directly) so a
      // wrapping RefreshIndicator below still has a real Scrollable to
      // attach to even with zero actors — SliverFillRemaining keeps the
      // centered look TeachingEmptyState's own `Center` expects, which a
      // plain ListView([TeachingEmptyState(...)]) would collapse to the
      // widget's intrinsic height instead of the full viewport.
      content = CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: TeachingEmptyState(
              icon: Icons.face,
              title: localizations.emptyRosterTitle,
              body: localizations.emptyRosterBody,
            ),
          ),
        ],
      );
    } else {
      content = ListView.builder(
        // AlwaysScrollableScrollPhysics: lets a short list still overscroll
        // enough for the pull-to-refresh RefreshIndicator below to trigger.
        physics: const AlwaysScrollableScrollPhysics(),
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
            // Own Material (transparent) so the tile's ink/splash paints
            // above the shell's surface-toned ColoredBox instead of being
            // hidden by it.
            child: Material(
              type: MaterialType.transparency,
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
                        // ADR-0037: themed bodySmall instead of a hardcoded 12.
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                onTap: () => _openEdit(actor),
              ),
            ),
          );
        },
      );
    }

    // Drag-to-update is only meaningful for a plan installed from the online
    // catalog — local plans have nothing to refresh against. Reuses the same
    // `refreshActivePlanFromCatalog` flow as the Plan tab's segments and
    // the drawer's "Oppdater fra katalog" entry.
    final plan = _service.activePlan;
    final isCatalogPlan =
        plan != null && active_actions.isCatalogPlan(plan);
    if (!isCatalogPlan) return content;
    return RefreshIndicator(
      key: widget.refreshIndicatorKey,
      onRefresh: () => active_actions.refreshActivePlanFromCatalog(context),
      child: content,
    );
  }
}
