import 'package:flutter/material.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/edit_permissions.dart';

/// Rebuilds [builder] with whether this device may change [target] (ADR-0057).
///
/// The base of the affordance wrappers below. Listens to [appUserRole], so
/// switching role from the drawer updates every gated affordance already on
/// screen instead of leaving them stale until the surface is rebuilt.
///
/// [exerciseUuid] scopes the live lock — pass the owning exercise for anything
/// belonging to one, and leave it null for plan-level things. See [canEdit].
///
/// [permission] picks which question to ask — editing an existing thing (the
/// default), creating a new one, or removing one. Three different answers: an
/// actor may add themselves to the roster, not edit or delete the entries there;
/// and unlike [canEdit], [canDelete] has no roleplay exemption from the live lock. Reusing the edit
class EditGate extends StatelessWidget {
  const EditGate({
    super.key,
    required this.target,
    required this.builder,
    this.exerciseUuid,
    this.permission = EditPermission.edit,
  });

  final EditTarget target;
  final String? exerciseUuid;
  final EditPermission permission;
  final Widget Function(BuildContext context, bool allowed) builder;

  @override
  Widget build(BuildContext context) {
    final ask = switch (permission) {
      EditPermission.edit => canEdit,
      EditPermission.create => canCreate,
      EditPermission.delete => canDelete,
    };
    return ValueListenableBuilder<StaffRole>(
      valueListenable: appUserRole,
      builder: (context, role, _) =>
          builder(context, ask(role, target, exerciseUuid: exerciseUuid)),
    );
  }
}

/// Shows [child] only to a role that may *create* a [target] — the gate for every
/// "+" affordance: create FABs, "+ Ny person" rows, AppBar add buttons.
///
/// Deliberately a wrapper rather than a `canEdit` call at each site. Both are one
/// line, but a wrapper is the kind of line you cannot *forget*: an ungated "+"
/// looks exactly like a gated one in review, while an unwrapped button is visibly
/// missing something. Seven surfaces carry these affordances, so the difference
/// matters.
///
/// Renders [replacement] (default: nothing) when not permitted. Hiding rather
/// than disabling, because a create action a role will never have is noise, not
/// information — unlike the picker rows that stay visible-but-inert to explain a
/// *temporary* live lock.
class IfCreatable extends StatelessWidget {
  const IfCreatable({
    super.key,
    required this.target,
    required this.child,
    this.exerciseUuid,
    this.replacement,
  });

  final EditTarget target;
  final String? exerciseUuid;
  final Widget child;
  final Widget? replacement;

  @override
  Widget build(BuildContext context) {
    return EditGate(
      target: target,
      exerciseUuid: exerciseUuid,
      permission: EditPermission.create,
      builder: (context, allowed) =>
          allowed ? child : (replacement ?? const SizedBox.shrink()),
    );
  }
}

/// Shows [child] only to a role that may *edit* [target] — for an affordance that
/// changes something that already exists, such as an AppBar pencil.
class IfEditable extends StatelessWidget {
  const IfEditable({
    super.key,
    required this.target,
    required this.child,
    this.exerciseUuid,
    this.replacement,
  });

  final EditTarget target;
  final String? exerciseUuid;
  final Widget child;
  final Widget? replacement;

  @override
  Widget build(BuildContext context) {
    return EditGate(
      target: target,
      exerciseUuid: exerciseUuid,
      builder: (context, allowed) =>
          allowed ? child : (replacement ?? const SizedBox.shrink()),
    );
  }
}

/// Shows [child] only to a role that may *delete* [target] — the delete twin of
/// [IfEditable], for a standalone destructive action such as an AppBar bin.
///
/// Separate widget rather than a flag on [IfEditable], so the stricter question
/// is visible at the call site: `IfDeletable` next to a bin icon reads as
/// obviously right, while `IfEditable(destructive: true)` reads as a typo.
class IfDeletable extends StatelessWidget {
  const IfDeletable({
    super.key,
    required this.target,
    required this.child,
    this.exerciseUuid,
    this.replacement,
  });

  final EditTarget target;
  final String? exerciseUuid;
  final Widget child;
  final Widget? replacement;

  @override
  Widget build(BuildContext context) {
    return EditGate(
      target: target,
      exerciseUuid: exerciseUuid,
      permission: EditPermission.delete,
      builder: (context, allowed) =>
          allowed ? child : (replacement ?? const SizedBox.shrink()),
    );
  }
}

/// A row that can be edited by swiping it or long-pressing it (ADR-0031), gated
/// on the role (ADR-0057).
///
/// Both affordances in one place because they are one affordance conceptually —
/// "edit this row" — and were duplicated across every list: each surface built
/// its own `Dismissible(endToStart)` with its own background, its own
/// confirmDismiss, and wired `onLongPress` separately. Consistency between them
/// was maintained by hand, and the role gate would have had to be remembered
/// twice per list.
///
/// When the role may not edit, the row renders bare: no swipe, no long-press, no
/// background. Not a disabled state — a swipe that visibly starts and then snaps
/// back reads as a bug rather than as a permission.
///
/// The long-press is passed to [builder] rather than wrapped, because the row
/// widgets already own their tap handling (`ExpandableTile.onLongPress`,
/// `InkWell`) and stacking another gesture detector over them would fight for the
/// same pointer.
class EditableRow extends StatelessWidget {
  const EditableRow({
    super.key,
    required this.target,
    required this.onEdit,
    required this.builder,
    required this.dismissKey,
    required this.label,
    this.exerciseUuid,
  });

  final EditTarget target;
  final String? exerciseUuid;

  /// Invoked by both the swipe and the long-press.
  final VoidCallback onEdit;

  /// Builds the row, given the long-press handler to wire into whatever tile it
  /// uses — null when the role may not edit.
  final Widget Function(BuildContext context, VoidCallback? onLongPress)
  builder;

  /// Key for the [Dismissible]. Must be stable and unique within the list.
  final Key dismissKey;

  /// Named on the swipe background, e.g. "Rediger post". Kept rather than
  /// reduced to a bare pencil: the lists this replaces all showed the action in
  /// words, and a swipe that reveals only an icon is guessable at best.
  final String label;

  @override
  Widget build(BuildContext context) {
    return EditGate(
      target: target,
      exerciseUuid: exerciseUuid,
      builder: (context, allowed) {
        final row = builder(context, allowed ? onEdit : null);
        if (!allowed) return row;
        final scheme = Theme.of(context).colorScheme;
        return Dismissible(
          key: dismissKey,
          direction: DismissDirection.endToStart,
          // Never actually dismisses: the swipe *is* the edit gesture, so it
          // opens the editor and springs back (ADR-0031). Returning false is
          // what keeps the row in the list — a true dismissal would oblige the
          // caller to remove it.
          confirmDismiss: (_) async {
            onEdit();
            return false;
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: scheme.secondaryContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  label,
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
                const SizedBox(width: 8),
                Icon(Icons.edit, color: scheme.onSecondaryContainer),
              ],
            ),
          ),
          child: row,
        );
      },
    );
  }
}

/// A row that is *deleted* by swiping it, gated on the role (ADR-0057).
///
/// The delete twin of [EditableRow], and deliberately not a mode of it: the two
/// have opposite dismiss contracts. [EditableRow] returns false from
/// `confirmDismiss` because the swipe *is* the edit gesture and the row must
/// spring back; here the swipe must confirm, dismiss for real, and the caller
/// must remove the item. Folding them together would mean one widget whose swipe
/// either opens a form or destroys data depending on a flag — and getting that
/// flag wrong is silent data loss in one direction, a row that mysteriously
/// bounces back in the other.
///
/// [confirmDelete] runs before the row leaves the list. Return false to keep it
/// (a cancelled dialog, or a precondition such as "this actor still portrays a
/// markør"); [onDelete] then never runs.
///
/// The swipe is icon-only by default, unlike [EditableRow]'s labelled background:
/// the two must not look alike, and a red panel with a bin is unambiguous where a
/// pencil needs its word. Pass [label] to name it anyway.
class DeletableRow extends StatelessWidget {
  const DeletableRow({
    super.key,
    required this.target,
    required this.dismissKey,
    required this.confirmDelete,
    required this.onDelete,
    required this.builder,
    this.exerciseUuid,
    this.onLongPress,
    this.label,
  });

  final EditTarget target;
  final String? exerciseUuid;

  /// Key for the [Dismissible]. Must be stable and unique within the list.
  final Key dismissKey;

  /// Asked before the row is removed. False keeps it and skips [onDelete].
  final Future<bool> Function() confirmDelete;

  /// Removes the item. The row is already gone from the viewport by now, so this
  /// must actually delete it or the next rebuild will bring it back.
  final VoidCallback onDelete;

  /// Optional secondary action, e.g. a menu of row actions. Passed to [builder]
  /// as null when the role may not delete — callers use this for menus that
  /// *contain* destructive entries.
  final VoidCallback? onLongPress;

  /// Optional word on the swipe background.
  final String? label;

  /// Builds the row, given the long-press handler — null when not permitted.
  final Widget Function(BuildContext context, VoidCallback? onLongPress)
  builder;

  @override
  Widget build(BuildContext context) {
    return EditGate(
      target: target,
      exerciseUuid: exerciseUuid,
      permission: EditPermission.delete,
      builder: (context, allowed) {
        final row = builder(context, allowed ? onLongPress : null);
        if (!allowed) return row;
        final scheme = Theme.of(context).colorScheme;
        return Dismissible(
          key: dismissKey,
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => confirmDelete(),
          onDismissed: (_) => onDelete(),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: scheme.error,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (label != null) ...[
                  Text(label!, style: TextStyle(color: scheme.onError)),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.delete, color: scheme.onError),
              ],
            ),
          ),
          child: row,
        );
      },
    );
  }
}
