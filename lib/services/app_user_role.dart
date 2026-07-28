import 'package:flutter/foundation.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/prefs.dart';

/// The role the person holding *this* device has in the exercise.
///
/// This is a local, device-level preference — distinct from:
/// - [BriefAudience]: which document view a reader gets (export/print axis).
/// - The Roster/Bemanning staffing of *other* people (DESIGN-006).
/// - The ADR-0019 session role (coordinator / observer / roleplayer).
///
/// Participants do not use the app, so only staff roles are offered. The stored
/// role drives [BriefAudience] as the default brief view (DESIGN-006 step 4) and,
/// since ADR-0057, what this device may edit.
enum AppUserRole {
  /// Øvelsesleder — plans and runs the exercise. Edits everything.
  director,

  /// Veileder — supervises during the drill. Edits teams.
  instructor,

  /// Aktør — plays one or more markører. Edits roleplays.
  ///
  /// The person, not the character: an `Staff` in the roster is who portrays a
  /// `RolePlay`. Added after director and instructor, because an actor adjusting
  /// their own marker mid-drill is the one edit that has to survive a live
  /// exercise.
  actor;

  /// Maps to the corresponding [BriefAudience] for the brief renderer.
  ///
  /// An actor gets the *director* view rather than a reduced one: they are staff
  /// running the scenario from the inside and need the same detail — including
  /// other actors' PII, since they have to find and work with them. Participants
  /// are the audience that gets less, and they do not use the app.
  BriefAudience get briefAudience => switch (this) {
    AppUserRole.director => BriefAudience.director,
    AppUserRole.instructor => BriefAudience.instructor,
    AppUserRole.actor => BriefAudience.director,
  };
}

/// The role in force on this device, as a listenable.
///
/// Exists because the role now gates *edit affordances*, not just a brief's
/// default view: every gated widget has to rebuild the moment the role changes,
/// and before this the role was read once per screen and never re-read. Switching
/// role from the drawer would have left every open surface stale.
///
/// Seeded synchronously by [readAppUserRoleNow] where possible — see [Prefs] —
/// so a gated affordance never renders under the wrong role for a frame.
final ValueNotifier<AppUserRole> appUserRole = ValueNotifier<AppUserRole>(
  readAppUserRoleNow() ?? AppUserRole.director,
);

AppUserRole? _parse(String? name) => name == null
    ? null
    : AppUserRole.values.where((r) => r.name == name).firstOrNull;

/// The stored role read synchronously, or null when [Prefs] has no bound
/// instance yet (a test, or an entry point that skips `main`).
AppUserRole? readAppUserRoleNow() =>
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
  appUserRole.value = readAppUserRoleNow() ?? AppUserRole.director;
}

/// The role in force, for a caller that only needs it once.
///
/// Reads [appUserRole], **not** the store: a write is asynchronous while the
/// notifier is immediate, so re-reading the store right after a change can serve
/// the previous role. The store seeds the notifier once ([readAppUserRoleNow]);
/// after that the notifier leads.
AppUserRole currentAppUserRole() => appUserRole.value;

/// Persists [role] and publishes it to [appUserRole].
Future<void> setAppUserRole(AppUserRole role) async {
  // Published first, awaited second: the UI must not wait on a platform write to
  // show the role the user just picked.
  appUserRole.value = role;
  await Prefs.setString(AppConfig.keyAppUserRole, role.name);
}
