import 'package:flutter/material.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/edit_permissions.dart';

/// Rebuilds [builder] with whether this device may edit [target] (ADR-0057).
///
/// The base of the two affordance wrappers below. Listens to [appUserRole], so
/// switching role from the drawer updates every gated affordance already on
/// screen instead of leaving them stale until the surface is rebuilt.
///
/// [exerciseUuid] scopes the live lock — pass the owning exercise for anything
/// belonging to one, and leave it null for plan-level things. See [canEdit].
class EditGate extends StatelessWidget {
  const EditGate({
    super.key,
    required this.target,
    required this.builder,
    this.exerciseUuid,
  });

  final EditTarget target;
  final String? exerciseUuid;
  final Widget Function(BuildContext context, bool allowed) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppUserRole>(
      valueListenable: appUserRole,
      builder: (context, role, _) =>
          builder(context, canEdit(role, target, exerciseUuid: exerciseUuid)),
    );
  }
}

/// Shows [child] only to a role that may edit [target] — the gate for every "+"
/// affordance: create FABs, "+ Ny person" rows, AppBar add buttons.
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
