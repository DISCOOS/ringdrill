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
import 'package:ringdrill/views/widgets/app_user_role_selector.dart';
import 'package:ringdrill/views/widgets/expandable_tile.dart';
import 'package:ringdrill/views/widgets/teaching_empty_state.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class RosterController extends ScreenController {
  final _reloadTick = ValueNotifier<int>(0);

  /// Listenable that fires whenever the controller saves or deletes a member
  /// so that [RosterView] can call setState without waiting for a
  /// [PlanService] event (staff CRUD does not emit one).
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
      target: EditTarget.staff,
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
/// Reads and writes go exclusively through [PlanService] staff CRUD
/// ([PlanService.loadStaff], [PlanService.saveStaff],
/// [PlanService.deleteStaff]) — no staff data is pushed to any
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

  List<Staff> _staff = [];
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
      _staff = _service.loadStaff();
      _rolePlays = _service.loadRolePlays();
    });
  }

  List<String> _castAsFor(String staffUuid) => _rolePlays
      .where((rp) => rp.staffUuid == staffUuid)
      .map((rp) => rp.name)
      .toList();

  Future<void> _openEdit(Staff member) async {
    final localizations = AppLocalizations.of(context)!;
    final result = await openFormSurface<StaffFormResult>(
      context,
      builder: (_) => StaffFormScreen(staff: member),
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

  Future<void> _tryDelete(Staff member) async {
    final localizations = AppLocalizations.of(context)!;
    final castAs = _castAsFor(member.uuid);
    if (castAs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.castDeleteBlocked(castAs.length))),
      );
      return;
    }
    await _service.deleteStaff(member.uuid);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    final Widget content;
    if (_staff.isEmpty) {
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
        itemCount: _staff.length,
        itemBuilder: (context, index) {
          final member = _staff[index];
          final castAs = _castAsFor(member.uuid);
          // Swipe and long-press are one affordance (ADR-0031) and gated on the
          // role (ADR-0057) — the same shape as the exercise, post, roleplay and
          // team lists. This list used to swipe-to-*delete* instead, the only one
          // in the app that did: the same gesture meant "edit" everywhere else and
          // "destroy" here. Delete now lives where the other lists put it, on the
          // editor's bin, which also keeps the still-cast guard on one path.
          return EditableRow(
            target: EditTarget.staff,
            dismissKey: ValueKey('staff-row-${member.uuid}'),
            label: localizations.editStaff,
            onEdit: () => _openEdit(member),
            builder: (context, onLongPress) => ExpandableTile(
              onLongPress: onLongPress,
              leading: const Icon(Icons.face),
              title: _buildTitle(context, localizations, member, castAs),
              subtitle: _buildSubtitle(context, localizations, member, castAs),
              onOpen: () => _openEdit(member),
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
  /// The name line, with role chips right-aligned — the layout every other list
  /// uses for its trailing metadata.
  Widget _buildTitle(
    BuildContext context,
    AppLocalizations localizations,
    Staff member,
    List<String> castAs,
  ) {
    final theme = Theme.of(context);
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
    // Stored roles plus actor-by-casting, unioned and deduped, so a member who is
    // cast but never ticked as an actor still reads as one — and never shows the
    // same role twice. Outlined when only *implied* by casting: that one is not
    // asserted on the record and cannot be edited here.
    final chips = [
      for (final role in member.effectiveRoles(isCast: castAs.isNotEmpty))
        chip(
          staffRoleLabel(role, localizations),
          derived: !member.roles.contains(role),
        ),
    ];
    return Row(
      children: [
        Expanded(
          child: Text(
            member.realName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        if (chips.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 2,
              children: chips,
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildSubtitle(
    BuildContext context,
    AppLocalizations localizations,
    Staff member,
    List<String> castAs,
  ) {
    final parts = <String>[
      if (member.phone != null) member.phone!,
      // Which markører, separately from the chip saying *that* they are one.
      if (castAs.isNotEmpty) localizations.castedAs(castAs.join(', ')),
    ];
    if (parts.isEmpty) return null;
    return Text(parts.join(' · '));
  }
}
