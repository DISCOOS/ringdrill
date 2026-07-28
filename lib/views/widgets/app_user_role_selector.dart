import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/views/widgets/ringdrill_picker.dart';

/// The role's own icon, reusing the vocabulary the app already reads by.
///
/// The actor is a **face**: `Icons.face` is this app's established
/// one-concrete-actor sign, carried by `FaceBadgeIcon` and the cast pill wherever
/// a marker's portrayer is shown. `Icons.theater_comedy` — the Spill segment's
/// masks — stands for the collection of roles, so it would read as the segment
/// rather than as the person holding the device.
IconData staffRoleIcon(StaffRole role) => switch (role) {
  StaffRole.director => Icons.manage_accounts,
  StaffRole.instructor => Icons.school,
  StaffRole.actor => Icons.face,
  // Neutral by design: the role is defined by not being one of the others.
  StaffRole.other => Icons.person_outline,
};

/// Director and instructor reuse the brief-audience labels they have always been
/// named by, so the same role reads the same wherever it appears.
String staffRoleLabel(StaffRole role, AppLocalizations l10n) => switch (role) {
  StaffRole.director => l10n.briefAudienceDirector,
  StaffRole.instructor => l10n.briefAudienceInstructor,
  StaffRole.actor => l10n.appUserRoleActor,
  StaffRole.other => l10n.staffRoleOther,
};

/// Picks the role this device acts as, persisting it through [setAppUserRole].
///
/// Adaptive picker (ADR-0049), like every other "choose one" in the app.
Future<void> showAppUserRolePicker(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final current = appUserRole.value;
  final picked = await showRingdrillPicker<StaffRole>(
    context: context,
    title: l10n.appUserRoleSectionTitle,
    items: StaffRole.values,
    itemBuilder: (context, role, onTap) {
      final theme = Theme.of(context);
      final isCurrent = role == current;
      return ListTile(
        leading: Icon(staffRoleIcon(role)),
        title: Text(
          staffRoleLabel(role, l10n),
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: isCurrent
            ? Icon(Icons.check, color: theme.colorScheme.primary)
            : null,
        onTap: isCurrent ? () => Navigator.of(context).pop() : onTap,
      );
    },
  );
  if (picked == null) return;
  await setAppUserRole(picked);
  // The drawer is a menu: it has served its purpose once a choice is made, and
  // leaving it open hides the very UI whose affordances just changed. No-op in
  // the wide layout, where the selector lives in the rail and no drawer is open.
  if (context.mounted) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) scaffold!.closeDrawer();
  }
}

/// The current role, as a tappable affordance that opens
/// [showAppUserRolePicker].
///
/// Replaces the radio list that used to live in Settings. The role now decides
/// what this device may *edit* (ADR-0057), not only which brief variant it
/// defaults to, so it belongs where the user can see and change it in passing —
/// buried three taps deep in Settings is the wrong depth for something that
/// changes what the UI offers.
///
/// [iconOnly] is the rail form: the wide shell's rail is 72px and icon-only, so
/// the label moves into the tooltip.
class AppUserRoleButton extends StatelessWidget {
  const AppUserRoleButton({
    super.key,
    this.iconOnly = false,
    this.foregroundColor,
  });

  final bool iconOnly;

  /// Set where the surrounding surface is not themed — the drawer header paints
  /// a fixed brand tone, so its content colour cannot be inferred.
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<StaffRole>(
      valueListenable: appUserRole,
      builder: (context, role, _) {
        final label = staffRoleLabel(role, l10n);
        final tooltip = '${l10n.appUserRoleSectionTitle}: $label';
        if (iconOnly) {
          return IconButton(
            icon: Icon(staffRoleIcon(role), color: foregroundColor),
            tooltip: tooltip,
            onPressed: () => showAppUserRolePicker(context),
          );
        }
        return Tooltip(
          message: tooltip,
          child: TextButton.icon(
            onPressed: () => showAppUserRolePicker(context),
            icon: Icon(staffRoleIcon(role), size: 18),
            label: Text(label),
            style: TextButton.styleFrom(foregroundColor: foregroundColor),
          ),
        );
      },
    );
  }
}
