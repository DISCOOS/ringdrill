import 'package:json_annotation/json_annotation.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';

/// A role in the exercise — **the authoritative role enum**.
///
/// One enum for two things that turned out to be the same (DESIGN-011, revised):
/// what a [Staff] member *is* in the roster, and what the person holding this
/// device *is* (formerly `AppUserRole`). They were 1:1, so keeping them apart only
/// created two lists that could drift. The roster defines the roles that exist; the
/// device setting says which one you are.
///
/// Consequences worth knowing:
/// - A staff member's brief audience comes free from [briefAudience], so the
///   role -> audience mapping helper DESIGN-011 deferred needs no separate
///   existence.
/// - ADR-0057's permission matrix keys off this same enum, so "what this device may
///   edit" and "what this person is on the roster" cannot disagree by construction.
/// - It lives in `models/` and is serialized, so it must stay free of
///   `package:flutter/*`: the CLI reaches the models (AGENTS.md). The
///   `ValueNotifier` and `Prefs` plumbing stay in `services/app_user_role.dart`.
///
/// The `@JsonValue`s are explicit so renaming a Dart identifier cannot silently
/// change the wire format.
///
/// **`actor` (markør) is stored**, reversing DESIGN-011's decision 2, which had it
/// derived from casting alone. Two things forced the change: a member's role is
/// mandatory when creating one, and a person who only ever plays markører had
/// nothing to select; and someone is recruited *as* a markør before there is any
/// roleplay to cast them to, so a purely derived role cannot express the plan.
/// The design anticipated this — "if decision 2 goes the other way, markør joins
/// the enum and casting stays its detail".
///
/// The derivation is kept as a *fallback*, not dropped: a member cast to a roleplay
/// counts as an actor whether or not the flag is set, so records written before this
/// and casts made without ticking the box still read correctly. Stored and derived
/// are unioned wherever roles are shown.
///
/// **`deltaker` is still absent.** "Stab" means the non-participants: course
/// participants are not rostered individually, they stay a `Team.numberOfMembers`
/// count. "Deltaker" survives only as a brief audience.
@JsonEnum()
enum StaffRole {
  /// Øvelsesleder — runs the exercise.
  @JsonValue('director')
  director,

  /// Veileder — supervises a team through it.
  @JsonValue('instructor')
  instructor,

  /// Markør — plays a roleplay. Also implied by any `RolePlay.staffUuid` pointing
  /// at this member, so the flag and the cast are unioned rather than one
  /// overriding the other.
  @JsonValue('actor')
  actor,

  /// Anything the three above do not cover — a support role the enum does not name.
  /// An escape hatch so adding a kind of helper does not need a schema change, and
  /// selectable as this device's own role too: someone staffing an exercise without
  /// being director, veileder or markør still has to be able to say so.
  ///
  /// Carries **no edit rights** (ADR-0057). The permission functions ask
  /// `role == director` and friends, so a role they do not name gets nothing — the
  /// right default for one whose duties are undefined by construction.
  @JsonValue('other')
  other;

  /// The [BriefAudience] for this role — the identity mapping (ADR-0063).
  ///
  /// Every role has its own audience, so nothing here decides what a role may
  /// see: that is declared per field (`SourceField.audiences`) and, for the cast's
  /// contact details, by [BriefAudience.includesActorPii]. This used to collapse
  /// four roles onto three audiences — an actor borrowed the *director* view, and
  /// `other` the instructor one — which handed a markör every station's withheld
  /// answers and the evaluation rubric for the whole course.
  BriefAudience get briefAudience => switch (this) {
    StaffRole.director => BriefAudience.director,
    StaffRole.instructor => BriefAudience.instructor,
    StaffRole.actor => BriefAudience.actor,
    StaffRole.other => BriefAudience.other,
  };
}
