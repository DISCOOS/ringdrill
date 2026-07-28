import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/edit_permissions.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/staff_form_screen.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/edit_affordance.dart';
import 'package:ringdrill/views/widgets/face_badge_icon.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';

/// Opens the marker sheet for [rolePlay] and applies whatever the user chose
/// (select/clear) via [PlanService.saveRolePlay] — the one apply step
/// every marker-management affordance shares (DESIGN-010 browser tile
/// polish: unify on the bottom sheet). Both the Poster tile's marker-row
/// icon (`StationRoleSummary.onTapMarker`) and the Spill tile's cast chip
/// (`RolePlayListView._buildCastAction`) call this instead of each
/// re-deriving the select-vs-clear-vs-noop `copyWith` themselves.
Future<void> openCastPickerAndApply(
  BuildContext context,
  AppLocalizations localizations,
  RolePlay rolePlay,
) async {
  final result = await showCastPickerSheet(context, rolePlay: rolePlay);
  if (result == null) return;
  final updated = switch (result) {
    CastPickerSelect(:final staffUuid) =>
      staffUuid == rolePlay.staffUuid
          ? null
          : rolePlay.copyWith(staffUuid: staffUuid),
    CastPickerClear() =>
      rolePlay.staffUuid == null ? null : rolePlay.copyWith(staffUuid: null),
  };
  if (updated == null) return;
  await PlanService().saveRolePlay(localizations, updated);
}

/// Opens [CastPickerSheet] through ADR-0049's adaptive surface split — a
/// bottom sheet on compact, a dialog reusing the form-dialog's rounded
/// chrome on medium/expanded — same as every other selector.
///
/// [CastPickerResult] carries a select-or-clear choice, which does not fit
/// [showRingdrillPicker]'s "tap an item, pop with it" contract (clearing
/// and creating a new actor are not list items), so this keeps
/// [CastPickerSheet]'s own bespoke body (search field, sticky "New actor"
/// and "Clear" rows) rather than forcing it through that primitive — only
/// the surface choice is shared.
Future<CastPickerResult?> showCastPickerSheet(
  BuildContext context, {
  required RolePlay rolePlay,
}) {
  final wide = WindowSizeClass.of(context).hasMasterDetail;
  Widget builder(BuildContext context) =>
      CastPickerSheet(rolePlay: rolePlay, showCloseButton: wide);

  if (wide) {
    return showRingdrillDialogShell<CastPickerResult>(
      context: context,
      builder: builder,
      maxWidth: 480,
      maxHeightFraction: 0.7,
    );
  }
  return showRingdrillActionSheet<CastPickerResult>(
    context: context,
    builder: builder,
  );
}

/// The one marker-management surface (DESIGN-010 browser tile polish):
/// assigns an [Staff] to a [RolePlay], and does everything else a marker
/// needs too, so neither tile carries its own separate `⋮` context menu.
///
/// Shows a searchable list of all [Staff] records. If the actor is already
/// cast to another role in the same exercise an [alreadyCastAs] annotation
/// appears below their name (still selectable). A sticky "New actor" row at
/// the top lets the user create an actor inline via [StaffFormScreen]
/// (add); a sticky "Clear" row unlinks the current actor (remove); tapping
/// a row selects that actor (change) — the currently cast one shows a
/// check; and each row's pencil opens [StaffFormScreen] for *that* actor
/// (edit), independent of which one is currently cast to this role.
///
/// Returns [CastPickerSelect] when an actor is selected, [CastPickerClear]
/// when the current actor is removed, or null on cancel/after only editing.
///
/// Usage:
/// ```dart
/// final result = await showCastPickerSheet(context, rolePlay: rolePlay);
/// ```
class CastPickerSheet extends StatefulWidget {
  const CastPickerSheet({
    super.key,
    required this.rolePlay,
    this.showCloseButton = false,
  });

  final RolePlay rolePlay;

  /// Shows a header close (X) affordance, matching the picker primitive's
  /// dialog path (ADR-0049) — set by [showCastPickerSheet] on
  /// medium/expanded, left off on the compact sheet path (drag handle only).
  final bool showCloseButton;

  @override
  State<CastPickerSheet> createState() => _CastPickerSheetState();
}

sealed class CastPickerResult {
  const CastPickerResult();
}

final class CastPickerSelect extends CastPickerResult {
  const CastPickerSelect(this.staffUuid);

  final String staffUuid;
}

final class CastPickerClear extends CastPickerResult {
  const CastPickerClear();
}

class _CastPickerSheetState extends State<CastPickerSheet> {
  final _service = PlanService();
  final _searchController = TextEditingController();

  List<Staff> _actors = [];
  List<RolePlay> _rolePlays = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _actors = _service.loadStaff();
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
  String? _crossCastName(String staffUuid) {
    for (final rp in _rolePlays) {
      if (rp.staffUuid == staffUuid &&
          rp.exerciseUuid == widget.rolePlay.exerciseUuid &&
          rp.uuid != widget.rolePlay.uuid) {
        return rp.name;
      }
    }
    return null;
  }

  List<Staff> get _filtered {
    if (_query.isEmpty) return _actors;
    final q = _query.toLowerCase();
    return _actors.where((a) => a.realName.toLowerCase().contains(q)).toList();
  }

  Future<void> _createAndSelect() async {
    final localizations = AppLocalizations.of(context)!;
    final result = await openFormSurface<StaffFormResult>(
      context,
      builder: (_) => const StaffFormScreen(),
    );
    if (result == null || !mounted) return;
    if (result case StaffFormSave(:final staff)) {
      await _service.saveStaff(localizations, staff);
      if (!mounted) return;
      Navigator.of(context).pop(CastPickerSelect(staff.uuid));
    }
  }

  /// Edits (or deletes) [actor]'s own record — the "Rediger markør"
  /// affordance folded into this sheet (DESIGN-010 browser tile polish),
  /// replacing the `⋮` context menu the Spill tile used to carry
  /// separately. Reloads the list in place rather than popping the sheet,
  /// so the user can keep browsing/selecting after editing. A delete is
  /// blocked (matching the previous overflow-menu behaviour) when the
  /// actor is still cast to any role — including this one, so clearing the
  /// cast first is required before an actor can be deleted from here.
  Future<void> _editActor(Staff actor) async {
    final localizations = AppLocalizations.of(context)!;
    final result = await openFormSurface<StaffFormResult>(
      context,
      builder: (_) => StaffFormScreen(staff: actor),
    );
    if (result == null || !mounted) return;
    switch (result) {
      // `staff` is the edited record, not the method's pre-edit parameter.
      case StaffFormSave(:final staff):
        await _service.saveStaff(localizations, staff);
      case StaffFormDelete(:final staff):
        final roles = _service.loadRolePlays().where(
          (rolePlay) => rolePlay.staffUuid == staff.uuid,
        );
        if (roles.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.castDeleteBlocked(roles.length)),
            ),
          );
          return;
        }
        await _service.deleteStaff(actor.uuid);
    }
    if (mounted) _reload();
  }

  void _select(String staffUuid) {
    Navigator.of(context).pop(CastPickerSelect(staffUuid));
  }

  void _clear() {
    Navigator.of(context).pop(const CastPickerClear());
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final filtered = _filtered;
    final hasCurrentActor = widget.rolePlay.staffUuid != null;
    // Search only once the list is long enough to need it — the same threshold
    // the shared `showRingdrillPicker` uses, instead of always showing it.
    final showSearch = _actors.length >= 8;

    // Mirrors `showRingdrillPicker`'s layout so both selectors read alike:
    // title, divider, (conditional) search, list, divider, footer actions at
    // the bottom.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title (ADR-0049: static "Velg markør").
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  localizations.pickerSelectRolePlayTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (widget.showCloseButton)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: localizations.pickerSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),

        // Staff list.
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final actor = filtered[index];
              final crossCast = _crossCastName(actor.uuid);
              final isSelected = actor.uuid == widget.rolePlay.staffUuid;
              return ListTile(
                selected: isSelected,
                // Selection is shown by a leading check + the row tint, not a
                // trailing checkmark.
                leading: isSelected
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : const Icon(Icons.face),
                title: Text(actor.realName),
                subtitle: crossCast != null
                    ? Text(
                        localizations.alreadyCastAs(crossCast),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : (actor.phone != null ? Text(actor.phone!) : null),
                // The pencil is its own IconButton (not the row's onTap) so
                // editing a *different* actor never accidentally selects it —
                // tapping the row body still selects; only the pencil edits.
                //
                // Gated separately from the sheet itself (ADR-0057): *casting* is
                // work an actor does, but this pencil edits the person record
                // behind the row — roster work, director-only. Selecting stays
                // available to whoever may cast.
                trailing: IfEditable(
                  target: EditTarget.actor,
                  child: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: localizations.editCast,
                    onPressed: () => _editActor(actor),
                  ),
                ),
                onTap: () => _select(actor.uuid),
              );
            },
          ),
        ),

        const Divider(height: 1),
        // Footer actions at the bottom (like "Velg person"), with semantic
        // face-badge icons rather than a bare +/−.
        // Creating follows canCreate, not canEdit: an actor casting a markør may
        // add the person they are, while the pencil above stays director-only.
        IfCreatable(
          target: EditTarget.actor,
          child: ListTile(
            leading: AddFaceIcon(color: theme.colorScheme.primary),
            title: Text(
              localizations.newStaff,
              style: TextStyle(color: theme.colorScheme.primary),
            ),
            onTap: _createAndSelect,
          ),
        ),
        if (hasCurrentActor)
          ListTile(
            leading: const RemoveFaceIcon(),
            title: Text(localizations.clearCast),
            onTap: _clear,
          ),
      ],
    );
  }
}
