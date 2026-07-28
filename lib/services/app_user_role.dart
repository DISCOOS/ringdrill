import 'package:flutter/foundation.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/ui_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  /// The person, not the character: an `Actor` in the roster is who portrays a
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
/// Seeded synchronously by [readAppUserRoleNow] where possible — see [UiPrefs] —
/// so a gated affordance never renders under the wrong role for a frame.
final ValueNotifier<AppUserRole> appUserRole = ValueNotifier<AppUserRole>(
  readAppUserRoleNow() ?? AppUserRole.director,
);

AppUserRole? _parse(String? name) => name == null
    ? null
    : AppUserRole.values.where((r) => r.name == name).firstOrNull;

/// The stored role read synchronously, or null when [UiPrefs] has no bound
/// instance yet (a test, or an entry point that skips `main`).
AppUserRole? readAppUserRoleNow() =>
    _parse(UiPrefs.instanceOrNull?.getString(AppConfig.keyAppUserRole));

/// Reads the stored [AppUserRole] preference, defaulting to [AppUserRole.director]
/// when nothing is stored or the stored value is unrecognized — participants
/// do not use the app, so director (full content) is the safe default,
/// mirroring `BriefScreen._loadStoredRole`'s own default.
///
/// Also refreshes [appUserRole], so a caller that reaches the stored value
/// asynchronously brings the listenable up to date rather than leaving the two
/// disagreeing.
Future<AppUserRole> loadStoredAppUserRole() async {
  final prefs = UiPrefs.instanceOrNull ?? await SharedPreferences.getInstance();
  final role =
      _parse(prefs.getString(AppConfig.keyAppUserRole)) ?? AppUserRole.director;
  appUserRole.value = role;
  return role;
}

/// Persists [role] and publishes it to [appUserRole].
Future<void> setAppUserRole(AppUserRole role) async {
  appUserRole.value = role;
  final prefs = UiPrefs.instanceOrNull ?? await SharedPreferences.getInstance();
  await prefs.setString(AppConfig.keyAppUserRole, role.name);
}
