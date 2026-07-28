import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/utils/app_config.dart';
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

/// Reads the stored [AppUserRole] preference, defaulting to [AppUserRole.director]
/// when nothing is stored or the stored value is unrecognized — participants
/// do not use the app, so director (full content) is the safe default,
/// mirroring `BriefScreen._loadStoredRole`'s own default.
Future<AppUserRole> loadStoredAppUserRole() async {
  final prefs = await SharedPreferences.getInstance();
  final roleStr = prefs.getString(AppConfig.keyAppUserRole);
  final role = roleStr == null
      ? null
      : AppUserRole.values.where((r) => r.name == roleStr).firstOrNull;
  return role ?? AppUserRole.director;
}
