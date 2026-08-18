import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ringdrill/models/staff_role.dart';

// Re-exported: the enum is the authoritative role list and every surface holding a
// Staff wants it, so importing the model is enough.
export 'package:ringdrill/models/staff_role.dart';

part 'staff.freezed.dart';
part 'staff.g.dart';

/// A real person staffing an exercise — a markør, an øvelsesleder, a veileder
/// (DESIGN-011, generalizing DESIGN-009's `Staff`).
///
/// Carries **PII** (real name, phone, notes) and is local-only: the catalog strips
/// the `staff/` folder server-side before publishing (ADR-0018). Distinct from
/// `Person`, which is a *fictional* scenario character with no PII — the mental
/// model is that a real person ([Staff]) plays a script (`RolePlay`) portraying a
/// character (`Person`).
@freezed
sealed class Staff with _$Staff {
  const factory Staff({
    required String uuid,
    required String realName,
    String? phone,

    /// How to reach them in writing, when a phone call is the wrong register.
    ///
    /// A director talks to staff before, during and after an execution —
    /// briefing material and a plan link go out days ahead, the phone is for
    /// the day itself. A roster that carries only a number covers one of
    /// those.
    ///
    /// PII like the rest of this record, and it travels by exactly the same
    /// rule (ADR-0072): to the account that owns the plan, never to the public
    /// catalog.
    String? email,
    @JsonKey(includeFromJson: false, includeToJson: false) String? notes,

    /// The roles this person holds. Additive and defaulted, so a record written
    /// before DESIGN-011 reads back unchanged — and one written before [actor]
    /// existed still reads as an actor when a roleplay is cast to them.
    @Default(<StaffRole>{}) Set<StaffRole> roles,

    /// The account user this row was created from, when it came from one.
    ///
    /// **A link, not an identity.** The row is still a plain local record: the
    /// name here is a copy made when it was added, and nothing keeps the two in
    /// step. What the id buys is knowing that two rows are the same person —
    /// "you are already on this roster" instead of a second you, which is
    /// otherwise unanswerable when the only handle is a name somebody typed.
    /// It is also what ADR-0057's self-edit rule can key on: an actor may put
    /// *themselves* on the list, and "themselves" needs a referent.
    ///
    /// Null for everyone typed in by hand, which is most of a roster — markører
    /// recruited for a day have no RingDrill account and never will.
    ///
    /// Where it travels is the roster's own rule (ADR-0072), which is not "PII
    /// never leaves the device": a plan owned by an account is stored whole,
    /// roster included, because the co-coordinator running the same exercise
    /// needs the same phone list. Only the **catalog** path strips `staff/`,
    /// at write time, because those bytes must not exist in a publicly
    /// readable store. So this id reaches the account and never the catalog —
    /// which is also what makes it useful, since a roster shared between two
    /// coordinators is exactly where "is this row already me?" gets asked.
    String? userId,
  }) = _Staff;

  factory Staff.fromJson(Map<String, dynamic> json) => _$StaffFromJson(json);
}

extension StaffName on Staff {
  /// The member's first name — the first whitespace-delimited token of
  /// [realName] — used where a compact marker label is wanted (the Spill
  /// tile/identity card's collapsed "(Fornavn)" parenthesis). Falls back to
  /// the full [realName] when it has no internal whitespace.
  String get firstName {
    final trimmed = realName.trim();
    final match = RegExp(r'\s').firstMatch(trimmed);
    return match == null ? trimmed : trimmed.substring(0, match.start);
  }
}

extension StaffRoles on Staff {
  /// The roles to *show*: the stored set, plus [StaffRole.actor] when a roleplay is
  /// cast to this member even if the flag is not set.
  ///
  /// The union is why casting stays "its detail" rather than the source of truth: a
  /// record written before [StaffRole.actor] was storable, or a cast made without
  /// ticking the box, still reads as an actor. Returned in enum order so two
  /// surfaces listing the same member cannot disagree about sequence.
  Set<StaffRole> effectiveRoles({required bool isCast}) => {
    for (final role in StaffRole.values)
      if (roles.contains(role) || (isCast && role == StaffRole.actor)) role,
  };
}
