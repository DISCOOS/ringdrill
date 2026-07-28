import 'package:flutter/foundation.dart';
import 'package:ringdrill/models/staff_role.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/prefs.dart';

// Re-exported so the ~40 files importing this for the enum keep working, and so
// there is one obvious place to reach it from either side.
export 'package:ringdrill/models/staff_role.dart';

/// The role in force on this device, as a listenable.
///
/// Exists because the role now gates *edit affordances*, not just a brief's
/// default view: every gated widget has to rebuild the moment the role changes,
/// and before this the role was read once per screen and never re-read. Switching
/// role from the drawer would have left every open surface stale.
///
/// Seeded synchronously by [readAppUserRoleNow] where possible — see [Prefs] —
/// so a gated affordance never renders under the wrong role for a frame.
final ValueNotifier<StaffRole> appUserRole = ValueNotifier<StaffRole>(
  readAppUserRoleNow() ?? StaffRole.director,
);

StaffRole? _parse(String? name) => name == null
    ? null
    : StaffRole.values.where((r) => r.name == name).firstOrNull;

/// The stored role read synchronously, or null when [Prefs] has no bound
/// instance yet (a test, or an entry point that skips `main`).
StaffRole? readAppUserRoleNow() =>
    _parse(Prefs.getString(AppConfig.keyAppUserRole));

/// Re-reads the store into [appUserRole].
///
/// The notifier seeds itself lazily on first access, which is *whenever something
/// first touches it* — so a caller that binds [Prefs] afterwards (`main` in an
/// unusual order, or any test that seeds a stored role) can find the notifier
/// already initialised from an unbound read. This makes the seeding explicit
/// instead of dependent on that order.
///
/// Not for reacting to changes: after seeding, the notifier leads and the store
/// follows.
void seedAppUserRoleFromStore() {
  appUserRole.value = readAppUserRoleNow() ?? StaffRole.director;
}

/// The role in force, for a caller that only needs it once.
///
/// Reads [appUserRole], **not** the store: a write is asynchronous while the
/// notifier is immediate, so re-reading the store right after a change can serve
/// the previous role. The store seeds the notifier once ([readAppUserRoleNow]);
/// after that the notifier leads.
StaffRole currentAppUserRole() => appUserRole.value;

/// Persists [role] and publishes it to [appUserRole].
Future<void> setAppUserRole(StaffRole role) async {
  // Published first, awaited second: the UI must not wait on a platform write to
  // show the role the user just picked.
  appUserRole.value = role;
  await Prefs.setString(AppConfig.keyAppUserRole, role.name);
}
