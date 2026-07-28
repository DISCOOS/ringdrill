import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/staff.dart';

/// The localized label for a [StaffRole] (DESIGN-011).
///
/// A null [role] means the **derived** markør role — the one that is not in the
/// enum because it is computed from casting rather than stored, and so has no
/// enum value to key off. Kept in this one helper so the roster list, the editor's
/// multi-select and the derived chip cannot label the same role differently.
String staffRoleLabel(AppLocalizations l10n, StaffRole? role) => switch (role) {
  StaffRole.director => l10n.staffRoleDirector,
  StaffRole.instructor => l10n.staffRoleInstructor,
  StaffRole.other => l10n.staffRoleOther,
  null => l10n.staffRoleMarkor,
};
