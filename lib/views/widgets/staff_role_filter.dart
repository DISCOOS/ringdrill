import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/views/widgets/app_user_role_selector.dart';

/// Segmented role filter above a staff list.
///
/// Multi-select rather than single: "show me the øvelsesledere *and* veiledere" is
/// a real question, and a single-select would answer it only by making the user
/// look twice. Nothing selected means **no filter** — every member shows — which is
/// also why this is not a `SegmentedButton` with `emptySelectionAllowed: false`.
///
/// Filters on [Staff.effectiveRoles], not the stored set, so a member who is cast
/// to a roleplay but was never ticked as an actor still appears under the actor
/// filter. Filtering on the stored set would hide exactly the people the cast
/// picker exists to find.
class StaffRoleFilter extends StatelessWidget {
  const StaffRoleFilter({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// Empty means "no filter", not "match nothing".
  final Set<StaffRole> selected;
  final ValueChanged<Set<StaffRole>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SegmentedButton<StaffRole>(
        multiSelectionEnabled: true,
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        segments: [
          for (final role in StaffRole.values)
            ButtonSegment<StaffRole>(
              value: role,
              icon: Icon(staffRoleIcon(role), size: 16),
              label: Text(staffRoleLabel(role, l10n)),
            ),
        ],
        selected: selected,
        onSelectionChanged: onChanged,
      ),
    );
  }
}

/// Applies a [StaffRoleFilter]'s selection to [staff].
///
/// [isCast] answers "is this member cast to any roleplay", which the actor filter
/// needs so an untagged-but-cast member is not hidden. An empty [selected] returns
/// the list unchanged.
List<Staff> filterStaffByRole(
  List<Staff> staff,
  Set<StaffRole> selected, {
  required bool Function(Staff) isCast,
}) {
  if (selected.isEmpty) return staff;
  return staff
      .where(
        (member) => member
            .effectiveRoles(isCast: isCast(member))
            .any(selected.contains),
      )
      .toList();
}
