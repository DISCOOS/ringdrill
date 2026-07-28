import 'package:ringdrill/services/app_user_role.dart';
import 'package:ringdrill/services/exercise_service.dart';

/// What kind of thing an edit affordance would change.
///
/// Coarser than the model on purpose: permission follows the *kind of work* a
/// role does, not the entity graph. A station's persons and locations are part of
/// building the scenario, so they answer as [EditTarget.station] rather than
/// earning entries of their own.
enum EditTarget {
  /// The plan itself, and the library it lives in.
  plan,

  /// An exercise: its timing, rounds and structure.
  exercise,

  /// A post, and the persons and locations placed at it.
  station,

  /// A team and its rotation.
  team,

  /// A markør — the character, its script and its casting.
  rolePlay,

  /// The roster of actors who portray markører.
  actor,
}

/// Whether the person holding this device may edit [target] (ADR-0057).
///
/// Three rules, and the exceptions are the point:
/// - **Director** edits everything. It is the planning role.
/// - **Instructor** edits teams — the thing they supervise during a drill.
/// - **Actor** edits roleplays — their own marker's script and casting.
///
/// [exerciseUuid] scopes the live check. While an exercise is running, its
/// structure is frozen for everyone including the director: changing rounds or
/// posts under a drill in progress invalidates what every other device is
/// showing. **Roleplays are the deliberate exception** — a marker's behaviour is
/// exactly what gets adjusted mid-scenario, so it stays editable while live.
///
/// Passing null for [exerciseUuid] means "not tied to a particular exercise"
/// (the plan, the roster), which the live check therefore does not restrict —
/// those are already director-only, and a director editing the roster mid-drill
/// breaks nothing another device is rendering.
bool canEdit(
  AppUserRole role,
  EditTarget target, {
  String? exerciseUuid,
  ExerciseService? exerciseService,
}) {
  final live =
      exerciseUuid != null &&
      (exerciseService ?? ExerciseService()).isStartedOn(exerciseUuid);

  switch (target) {
    case EditTarget.rolePlay:
      // Survives the live lock by design.
      return role == AppUserRole.director || role == AppUserRole.actor;
    case EditTarget.team:
      if (live) return false;
      return role == AppUserRole.director || role == AppUserRole.instructor;
    case EditTarget.plan:
    case EditTarget.exercise:
    case EditTarget.station:
    case EditTarget.actor:
      if (live) return false;
      return role == AppUserRole.director;
  }
}
