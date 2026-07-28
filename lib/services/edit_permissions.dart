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

/// Which of the three permission questions an affordance asks (ADR-0057).
///
/// They have genuinely different answers, so an affordance has to say which one
/// it means: an actor may *create* a roster entry, may not *edit* or *delete*
/// one; an actor may *edit* a roleplay but not *delete* it; a roleplay stays
/// editable while an exercise runs but never deletable.
enum EditPermission { create, edit, delete }

/// Whether the person holding this device may edit [target] (ADR-0057).
///
/// Three rules, and the exceptions are the point:
/// - **Director** edits everything. It is the planning role.
/// - **Instructor** edits teams — the thing they supervise during a drill.
/// - **Staff** edits roleplays — their own marker's script and casting.
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
      // Survives the live lock by design. See canDelete: *removing* one does
      // not.
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

/// Whether this device may *add* a new [target] (ADR-0057).
///
/// The third question, and the one the roster forced: adding yourself to the
/// staff list is not the same authority as editing the list. Anyone working the
/// exercise can put themselves on it — today the only rostered kind is the markør
/// an actor plays — while changing or removing *other* people's records stays
/// with the director.
///
/// Everything else is structural (a new exercise, post, team or plan renumbers
/// and reshapes what other devices show), so it stays director-only, and the live
/// lock applies as for [canEdit].
///
/// Note the deliberate gap: an actor may create a roster entry but may not edit
/// or delete one, *including their own*. "Their own" is not currently
/// representable — DESIGN-011 §"Out of scope" keeps roster people separate from
/// app users, so nothing links this device to a particular record. Narrowing
/// edit/delete to self needs the account link on the ADR-0024/0025 track.
bool canCreate(
  AppUserRole role,
  EditTarget target, {
  String? exerciseUuid,
  ExerciseService? exerciseService,
}) {
  if (target == EditTarget.actor) {
    // Adding a person to the staff roster. An instructor supervises teams and
    // has no roster of their own to join yet (DESIGN-011 adds director and
    // instructor as staff roles; until then the roster holds markører only).
    return role == AppUserRole.director || role == AppUserRole.actor;
  }
  final live =
      exerciseUuid != null &&
      (exerciseService ?? ExerciseService()).isStartedOn(exerciseUuid);
  if (live) return false;
  return role == AppUserRole.director;
}

/// Whether this device may *remove* a [target] (ADR-0057).
///
/// Deliberately not [canEdit]. Removing content is a command act, so it does not
/// inherit either of canEdit's delegations:
/// - An **actor** authors a markør's script, but does not delete the markør —
///   nor the persons and locations it references, which an actor *overrides*
///   rather than removes.
/// - An **instructor** adjusts a team, but removing one from the plan is a
///   structural change to what everyone else is running.
///
/// So: director only. And unlike canEdit, the live lock has **no exception** —
/// adjusting a markør's behaviour mid-scenario is exactly what live editing is
/// for, while deleting one the running exercise still references is data loss
/// with no undo.
///
/// [target] is unused today and kept for symmetry with [canEdit], so call sites
/// read alike and a future per-kind rule lands here rather than at the surfaces.
bool canDelete(
  AppUserRole role,
  EditTarget target, {
  String? exerciseUuid,
  ExerciseService? exerciseService,
}) {
  if (role != AppUserRole.director) return false;
  final live =
      exerciseUuid != null &&
      (exerciseService ?? ExerciseService()).isStartedOn(exerciseUuid);
  return !live;
}
