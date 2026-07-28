import 'package:flutter/material.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/edit_permissions.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/context_extensions.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/widgets/edit_affordance.dart';
import 'package:ringdrill/views/widgets/ringdrill_text.dart';
import 'package:ringdrill/views/widgets/app_user_role_selector.dart';

/// Form for creating or editing an [Staff] record.
///
/// Accepts an existing [actor] (edit mode) or null (create mode).
/// Pops with [StaffFormSave] on save, [StaffFormDelete] on delete, or null on
/// cancel.
///
/// When [modal] is true the caller provided a bottom-sheet context and the
/// save button text is "Add" rather than "Save". The widget is stateless
/// with respect to persistence — the caller persists via [PlanService].
class StaffFormScreen extends StatefulWidget {
  const StaffFormScreen({super.key, this.staff, this.modal = false});

  /// Existing member to edit; null to create a new one.
  final Staff? staff;

  /// When true, the form is shown inside a bottom sheet (cast roster FAB /
  /// cast picker inline). Changes button label from "Save" to the locale's
  /// "Add" / "Done" equivalent.
  final bool modal;

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

sealed class StaffFormResult {
  const StaffFormResult();
}

final class StaffFormSave extends StaffFormResult {
  const StaffFormSave(this.staff);

  final Staff staff;
}

final class StaffFormDelete extends StaffFormResult {
  const StaffFormDelete(this.staff);

  final Staff staff;
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();

  /// The stored organizational roles. Markør is *not* here: it is derived from
  /// casting (DESIGN-011) and shown read-only below.
  Set<StaffRole> _roles = <StaffRole>{};

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final staff = widget.staff;
    if (staff != null) {
      _nameController.text = staff.realName;
      _phoneController.text = staff.phone ?? '';
      _notesController.text = staff.notes ?? '';
      // A record written before roles existed has none. Default it to `other`
      // rather than opening in an invalid state: the validation below applies to
      // edits too, and an empty selection would otherwise block saving an
      // unrelated change like a phone number. `other` is the honest answer for a
      // member whose role was never recorded, and the user can correct it.
      _roles = staff.roles.isEmpty ? {StaffRole.other} : {...staff.roles};
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isNew = widget.staff == null;
    final title = isNew ? localizations.newStaff : widget.staff!.realName;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: localizations.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title),
        actions: [
          if (!isNew)
            IfDeletable(
              target: EditTarget.actor,
              child: IconButton(
                icon: const Icon(Icons.delete),
                tooltip: localizations.deleteStaff,
                onPressed: _confirmDelete,
              ),
            ),
          ElevatedButton(onPressed: _save, child: Text(localizations.save)),
        ],
        actionsPadding: const EdgeInsets.only(right: 16),
      ),
      body: DismissKeyboard(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Real name (required)
                  TextFormField(
                    autofocus: true,
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: localizations.actorRealName,
                    ),
                    validator: (value) =>
                        value != null && value.trim().isNotEmpty
                        ? null
                        : localizations.pleaseEnterAName,
                  ),
                  const SizedBox(height: 12),

                  // Phone (optional)
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: localizations.actorPhone,
                      hintText: localizations.optional,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes (optional, multiline)
                  TextFormField(
                    controller: _notesController,
                    keyboardType: TextInputType.multiline,
                    minLines: 2,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: localizations.actorNotes,
                      hintText: localizations.optional,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildRoles(context, localizations),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The stored roles as a filter-chip multi-select, plus the derived markør
  /// role as a read-only chip.
  ///
  /// Markør is deliberately not selectable: a person *is* one precisely when a
  /// roleplay is cast to them, so it is computed from the cast rather than stored
  /// (DESIGN-011 decision 2). A stored flag could disagree with the actual
  /// casting, with no way to tell which was right. Editing it happens in the
  /// Spill segment, by casting.
  Widget _buildRoles(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final plays = _playedRolePlays();
    // A FormField rather than a check inside _save(), so the role participates in
    // the same validate() pass as the name field: one save path, one place errors
    // appear, and the chips cannot drift out of the form's notion of validity.
    //
    // Enforced on edit as well as create. That is only fair because a role-less
    // record arrives pre-set to `other` (see initState), so an existing member is
    // never opened in a state that blocks saving — the rule cannot punish the user
    // for the schema's history.
    return FormField<Set<StaffRole>>(
      initialValue: _roles,
      validator: (_) => _roles.isEmpty ? l10n.staffRolesRequired : null,
      builder: (field) => _buildRolesBody(context, l10n, theme, plays, field),
    );
  }

  Widget _buildRolesBody(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    List<RolePlay> plays,
    FormFieldState<Set<StaffRole>> field,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.staffRolesLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: field.hasError
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in StaffRole.values)
              FilterChip(
                label: Text(staffRoleLabel(role, l10n)),
                selected: _roles.contains(role),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _roles.add(role);
                    } else {
                      _roles.remove(role);
                    }
                  });
                  // Clears the error as soon as a role is picked, instead of
                  // leaving it until the next save attempt.
                  field.didChange(_roles);
                  if (field.hasError) field.validate();
                },
              ),
            // Only when cast *without* the flag set: actor is a real selectable
            // role now, so the implied chip exists just to explain why a member
            // reads as an actor in the list without the box being ticked.
            if (plays.isNotEmpty && !_roles.contains(StaffRole.actor))
              Chip(
                avatar: Icon(staffRoleIcon(StaffRole.actor), size: 18),
                label: Text(staffRoleLabel(StaffRole.actor, l10n)),
              ),
          ],
        ),
        if (field.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              field.errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        if (plays.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.staffPlaysLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          for (final rolePlay in plays)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  // Locked: casting happens in the Spill segment, not here.
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RingDrillText.plain(
                      _playsRowLabel(l10n, rolePlay),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  /// One row of the read-only Spiller list: the markør's name, the post it sits
  /// at rendered in the *plan's* numbering format (dotted `1.1` or alpha `2a`, not
  /// a fixed string), and when it runs.
  ///
  /// The window is the whole exercise's, not a round's: a markør occupies one post
  /// for the duration, so a per-round span would answer a question nobody asked.
  String _playsRowLabel(AppLocalizations l10n, RolePlay rolePlay) {
    final service = PlanService();
    final exercise = service.getExercise(rolePlay.exerciseUuid);
    final plan = service.activePlan;
    if (exercise == null || plan == null) return rolePlay.name;
    // RolePlay.stationIndex is nullable — a markør can exist before being placed
    // — so fall back to a bare 1-based number rather than dropping the post.
    final stationIndex = rolePlay.stationIndex;
    final station =
        stationIndex != null && stationIndex < exercise.stations.length
        ? exercise.stations[stationIndex]
        : null;
    final badge = station == null
        ? '${(stationIndex ?? 0) + 1}'
        : station.numberLabel(
            plan.stationNumberFormat,
            exerciseNumber: exercise.index + 1,
          );
    final window = '${exercise.startTime}–${exercise.endTime}';
    return l10n.staffPlaysRow(rolePlay.name, badge, window);
  }

  /// The roleplays cast to this member — the derivation behind the markør chip.
  /// Empty for a new member, which has no uuid to be cast to yet.
  List<RolePlay> _playedRolePlays() {
    final uuid = widget.staff?.uuid;
    if (uuid == null) return const [];
    return PlanService()
        .loadRolePlays()
        .where((r) => r.staffUuid == uuid)
        .toList();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final existing = widget.staff;
    final saved = existing == null
        ? Staff(
            uuid: nanoid(10),
            roles: _roles,
            realName: _nameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          )
        : existing.copyWith(
            roles: _roles,
            realName: _nameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );

    Navigator.of(context).pop(StaffFormSave(saved));
  }

  Future<void> _confirmDelete() async {
    final actor = widget.staff;
    if (actor == null) return;

    final localizations = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: localizations.deleteStaff,
      message: localizations.confirmDeleteActor(actor.realName),
      confirmLabel: localizations.delete,
    );
    if (confirmed && mounted) {
      Navigator.of(context).pop(StaffFormDelete(actor));
    }
  }
}
