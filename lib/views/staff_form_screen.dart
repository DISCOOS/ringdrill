import 'package:flutter/material.dart';
import 'package:nanoid/nanoid.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/role_play.dart';
import 'dart:async';

import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/services/auth_service.dart';
import 'package:ringdrill/views/widgets/inline_message.dart';
import 'package:ringdrill/views/widgets/staff_from_account_picker.dart';
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
  const StaffFormScreen({
    super.key,
    this.staff,
    this.template,
    this.modal = false,
  });

  /// Existing member to edit; null to create a new one.
  final Staff? staff;

  /// Values to open a *new* form with — the name and account link of somebody
  /// picked from the account roster.
  ///
  /// Separate from [staff] because the difference is not cosmetic: this is
  /// still a create, so there is no delete action and the title says so.
  /// Passing a half-built record as [staff] would offer to delete a member who
  /// does not exist yet. Ignored when [staff] is set.
  final Staff? template;

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

  /// The stored roles, including [StaffRole.actor] — which *is* stored, reversing
  /// DESIGN-011's decision 2. Casting still implies it (see
  /// [StaffRoles.effectiveRoles]), but the flag is what this form edits.
  ///
  /// Never empty once the user has touched it: unticking the last role falls back
  /// to [StaffRole.other], since "not any of the named roles" is what that means.
  Set<StaffRole> _roles = <StaffRole>{};

  /// The account identity this row refers to, if any.
  ///
  /// Editable state rather than read straight from the record, because linking
  /// is a form change like any other: nothing is written until Save, and
  /// Cancel leaves the row exactly as it was.
  String? _userId;
  String? _linkedName;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The template only ever fills the boxes: everything below reads from
    // whichever record is in play, and a create with a template is still a
    // create (see [StaffFormScreen.template]).
    final staff = widget.staff ?? widget.template;
    if (staff != null) {
      _nameController.text = staff.realName;
      _phoneController.text = staff.phone ?? '';
      _emailController.text = staff.email ?? '';
      _notesController.text = staff.notes ?? '';
      // A record written before roles existed has none. Default it to `other`
      // rather than opening in an invalid state: the validation below applies to
      // edits too, and an empty selection would otherwise block saving an
      // unrelated change like a phone number. `other` is the honest answer for a
      // member whose role was never recorded, and the user can correct it.
      _roles = staff.roles.isEmpty ? {StaffRole.other} : {...staff.roles};
      _userId = staff.userId;
      if (staff.userId == null) unawaited(_lookForMatch(staff));
      // The stored row has no copy of the account's own name, so the linked
      // label falls back to the row's — which is what it was created from.
      _linkedName = staff.userId == null ? null : staff.realName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
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
              target: EditTarget.staff,
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

                  // Email (optional). Beside the phone rather than below the
                  // notes: they are the same question — how the director
                  // reaches this person — asked for two different moments.
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: localizations.actorEmail,
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
                  _buildAccountLink(context, localizations),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Attach this row to the account member it refers to — or detach it.
  ///
  /// **Rows arrive unlinked far more often than not.** Most of a roster is
  /// typed in on the day, and somebody who wrote their own name in before
  /// signing in has a row that no amount of name matching can safely claim is
  /// them: two people called Kari Nordmann are two people. Linking is that
  /// judgement, made by the person who knows the answer.
  ///
  /// Absent when there is no account to link to, rather than disabled: an
  /// offer that cannot be taken invites the question why.
  Widget _buildAccountLink(BuildContext context, AppLocalizations l10n) {
    final available =
        AuthService.isInstalled &&
        AuthService.instance.authAvailable &&
        AuthService.instance.state.user != null;
    if (!available) return const SizedBox.shrink();

    final theme = Theme.of(context);

    final suggestion = _suggestion;
    if (_userId == null && suggestion != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: InlineMessage(
          message: l10n.staffLinkSuggestion(suggestion.name),
          tone: MessageTone.info,
          trailing: TextButton(
            onPressed: () => _acceptSuggestion(suggestion),
            child: Text(l10n.staffLinkSuggestionAccept),
          ),
        ),
      );
    }

    if (_userId != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Row(
          children: [
            Icon(
              Icons.link,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.staffLinkedTo(_linkedName ?? _nameController.text.trim()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              // Only the link goes. The row and the name it shows are the
              // plan's own data and survive it.
              onPressed: () => setState(() {
                _userId = null;
                _linkedName = null;
              }),
              child: Text(l10n.staffUnlinkFromAccount),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          icon: const Icon(Icons.link),
          label: Text(l10n.staffLinkToAccount),
          onPressed: () => _linkToAccount(l10n),
        ),
      ),
    );
  }

  /// The account member this hand-typed row is probably meant to be.
  ///
  /// Looked up in the background on open, so the form is usable immediately
  /// and the suggestion appears when it can. Silent on failure: a nudge that
  /// could not load is a nudge nobody was waiting for.
  StaffCandidate? _suggestion;

  Future<void> _lookForMatch(Staff member) async {
    if (!AuthService.isInstalled ||
        !AuthService.instance.authAvailable ||
        AuthService.instance.state.user == null) {
      return;
    }
    final roster = PlanService()
        .loadStaff()
        .where((row) => row.uuid != member.uuid)
        .toList();
    final loaded = await loadStaffCandidates(roster: roster);
    if (!mounted) return;
    final match = suggestedLinkFor(member, loaded.candidates);
    if (match != null) setState(() => _suggestion = match);
  }

  void _acceptSuggestion(StaffCandidate candidate) {
    setState(() {
      _suggestion = null;
      _userId = candidate.userId;
      _linkedName = candidate.name;
      _nameController.text = candidate.name;
      if (_phoneController.text.trim().isEmpty && candidate.phone != null) {
        _phoneController.text = candidate.phone!;
      }
      if (_emailController.text.trim().isEmpty && candidate.email != null) {
        _emailController.text = candidate.email!;
      }
    });
  }

  Future<void> _linkToAccount(AppLocalizations l10n) async {
    // The roster minus this row: linking to somebody already on it would make
    // two rows the same person, which is the thing the link exists to prevent.
    final roster = PlanService()
        .loadStaff()
        .where((member) => member.uuid != widget.staff?.uuid)
        .toList();
    final loaded = await loadStaffCandidates(roster: roster);
    if (!mounted) return;
    if (loaded.failed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.staffFromAccountFailed)));
    }

    final candidate = await pickStaffFromAccount(
      context,
      candidates: loaded.candidates,
      title: l10n.staffLinkToAccount,
    );
    if (candidate == null || !mounted) return;

    setState(() {
      _userId = candidate.userId;
      _linkedName = candidate.name;
      // **Fills empty boxes, never overwrites a typed one.** A coordinator who
      // wrote a duty number against this person knows something the account
      // does not — that is the number for *this* exercise — and a link should
      // not quietly replace it with a personal mobile.
      if (_phoneController.text.trim().isEmpty && candidate.phone != null) {
        _phoneController.text = candidate.phone!;
      }
      if (_emailController.text.trim().isEmpty && candidate.email != null) {
        _emailController.text = candidate.email!;
      }
      // **Replaces the name too.** A row typed as "kenneth" that turns out to
      // be an account member should read as that member does everywhere else,
      // and the form is not saved yet — anyone who wanted the local spelling
      // can type it back before pressing Save.
      _nameController.text = candidate.name;
    });
  }

  /// The roles as a filter-chip multi-select, with the read-only "Spiller" list
  /// below naming the markører this member plays.
  ///
  /// All four roles are selectable, markør included. An earlier version showed an
  /// extra non-interactive "Markør" chip when the member was cast without the flag
  /// set, to explain why they read as one in the roster list. It was removed: with
  /// the role directly selectable it renders as the same label twice, and the
  /// Spiller list below already states the fact without the ambiguity.
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
                      // Picking anything else drops the `other` fallback: it means
                      // "none of the named roles", so it cannot coexist with one.
                      if (role != StaffRole.other) {
                        _roles.remove(StaffRole.other);
                      }
                      _roles.add(role);
                    } else {
                      _roles.remove(role);
                      // Never leave the selection empty: unticking the last role
                      // means "not any of the named ones", which is what `other`
                      // says. Keeps the mandatory-role rule from being something
                      // the user can walk into by deselecting.
                      if (_roles.isEmpty) _roles.add(StaffRole.other);
                    }
                  });
                  // Clears the error as soon as a role is picked, instead of
                  // leaving it until the next save attempt.
                  field.didChange(_roles);
                  if (field.hasError) field.validate();
                },
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
            // What makes the row *that* account user rather than somebody with
            // the same name. Never typed: it arrives from the template the
            // account picker built, or from linking below.
            userId: _userId,
            roles: _roles,
            realName: _nameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          )
        : existing.copyWith(
            userId: _userId,
            roles: _roles,
            realName: _nameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
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
