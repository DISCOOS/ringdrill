import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/edit_permissions.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/active_plan_actions.dart' as active_actions;
import 'package:ringdrill/views/staff_form_screen.dart';
import 'package:ringdrill/views/page_widget.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/edit_affordance.dart';
import 'package:ringdrill/views/widgets/staff_role_label.dart';
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
      PlanService().activePlan?.name ?? AppLocalizations.of(context)!.rosterTab;

  @override
  Widget? buildFAB(BuildContext context, BoxConstraints constraints) {
    final label = AppLocalizations.of(context)!.newStaff;
    // Gated on the role (ADR-0057): a create action a role will never have is
    // noise, so it is absent rather than disabled.
    // Adding yourself to the staff roster is not the same authority as editing
    // it (ADR-0057): an actor may put themselves on the list. Narrowing that to
    // *only* themselves needs the account link — see canCreate.
    return IfCreatable(
      target: EditTarget.actor,
      child: _buildCreateFab(context, label),
    );
  }

  Widget _buildCreateFab(BuildContext context, String label) {
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
    final result = await openFormSurface<StaffFormResult>(
      context,
      builder: (_) => const StaffFormScreen(),
    );
    if (result == null || !context.mounted) return;
    if (result case StaffFormSave(:final staff)) {
      await PlanService().saveStaff(localizations, staff);
      if (context.mounted) _reloadTick.value++;
    }
  }
}

// ---------------------------------------------------------------------------
// View
// ---------------------------------------------------------------------------

/// Flat registry of every [Staff] in the active plan.
///
/// Promoted from the cast-roster sheet that lives in the Spill segment —
/// that sheet remains as the inline quick-cast affordance. This view is the
/// primary home for [Staff] records on the dedicated Roster tab.
///
/// Reads and writes go exclusively through [PlanService] actor CRUD
/// ([PlanService.loadStaff], [PlanService.saveStaff],
/// [PlanService.deleteStaff]) — no actor data is pushed to any
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

  List<Staff> _actors = [];
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
      _actors = _service.loadStaff();
      _rolePlays = _service.loadRolePlays();
    });
  }

  List<String> _rolesFor(String staffUuid) => _rolePlays
      .where((rp) => rp.staffUuid == staffUuid)
      .map((rp) => rp.name)
      .toList();

  Future<void> _openEdit(Staff actor) async {
    final localizations = AppLocalizations.of(context)!;
    final result = await openFormSurface<StaffFormResult>(
      context,
      builder: (_) => StaffFormScreen(staff: actor),
    );
    if (result == null || !mounted) return;
    switch (result) {
      // `staff` is the *edited* record the form returned. The enclosing method's
      // parameter is the pre-edit one — this used to rely on the pattern shadowing
      // it, so read the binding explicitly.
      case StaffFormSave(:final staff):
        await _service.saveStaff(localizations, staff);
      case StaffFormDelete(:final staff):
        await _tryDelete(staff);
    }
    if (!mounted) return;
    _reload();
  }

  Future<void> _tryDelete(Staff actor) async {
    final localizations = AppLocalizations.of(context)!;
    final roles = _rolesFor(actor.uuid);
    if (roles.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.castDeleteBlocked(roles.length))),
      );
      return;
    }
    await _service.deleteStaff(actor.uuid);
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
          final tile = _buildStaffTile(context, localizations, actor, roles);
          // Deleting an actor is director-only (ADR-0057) — an actor authors a
          // markør's script but does not remove people from the roster. Note
          // canDelete, not canEdit: a DeletableRow asks the stricter question.
          return DeletableRow(
            target: EditTarget.actor,
            dismissKey: ValueKey(actor.uuid),
            // Still cast in a markør? Explain instead of deleting, and keep the
            // row.
            confirmDelete: () async {
              if (_rolesFor(actor.uuid).isNotEmpty) {
                await _tryDelete(actor);
                return false;
              }
              return true;
            },
            onDelete: () async {
              await _service.deleteStaff(actor.uuid);
              _reload();
            },
            builder: (context, _) => tile,
          );
        },
      );
    }

    // Drag-to-update is only meaningful for a plan installed from the online
    // catalog — local plans have nothing to refresh against. Reuses the same
    // `refreshActivePlanFromCatalog` flow as the Plan tab's segments and
    // the drawer's "Oppdater fra katalog" entry.
    final plan = _service.activePlan;
    final isCatalogPlan = plan != null && active_actions.isCatalogPlan(plan);
    if (!isCatalogPlan) return content;
    return RefreshIndicator(
      key: widget.refreshIndicatorKey,
      onRefresh: () => active_actions.refreshActivePlanFromCatalog(context),
      child: content,
    );
  }

  /// The actor row itself, built once and used with or without the swipe
  /// wrapper so the two paths cannot drift apart.
  ///
  /// Own Material (transparent) so the tile's ink/splash paints above the
  /// shell's surface-toned ColoredBox instead of being hidden by it.
  Widget _buildStaffTile(
    BuildContext context,
    AppLocalizations localizations,
    Staff staff,
    List<String> castAs,
  ) {
    final theme = Theme.of(context);
    // ADR-0037: themed bodySmall instead of a hardcoded 12.
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // The stored organizational roles, then the derived markør one — derived
    // because a person *is* a markør exactly when a roleplay is cast to them
    // (DESIGN-011), which is what `castAs` already tells us. Ordered with the
    // stored roles first so the line reads the same way the editor's chips do.
    Widget chip(String label, {required bool derived}) => Chip(
      label: Text(label, style: theme.textTheme.labelSmall),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      side: derived ? null : BorderSide.none,
      backgroundColor: derived
          ? Colors.transparent
          : theme.colorScheme.secondaryContainer,
    );
    final roleChips = [
      for (final role in StaffRole.values)
        if (staff.roles.contains(role))
          chip(staffRoleLabel(localizations, role), derived: false),
      if (castAs.isNotEmpty)
        chip(staffRoleLabel(localizations, null), derived: true),
    ];
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: const Icon(Icons.face),
        // Chips on the name line, right-aligned (DESIGN-011 / the staff-roster
        // mockup): the stored roles as filled chips, the derived markør one
        // outlined so the two read as different kinds of fact — one is asserted
        // here, the other follows from casting elsewhere.
        title: Row(
          children: [
            Expanded(child: Text(staff.realName)),
            if (roleChips.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  runSpacing: 2,
                  children: roleChips,
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (staff.phone != null) Text(staff.phone!),
            // Which markører, separately from the chip saying *that* they are one:
            // the chip answers "what is this person", this answers "doing what".
            if (castAs.isNotEmpty)
              Text(localizations.castedAs(castAs.join(', ')), style: metaStyle),
          ],
        ),
        onTap: () => _openEdit(staff),
      ),
    );
  }
}
