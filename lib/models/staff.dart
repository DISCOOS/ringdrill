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
    @JsonKey(includeFromJson: false, includeToJson: false) String? notes,

    /// The roles this person holds. Additive and defaulted, so a record written
    /// before DESIGN-011 reads back unchanged — and one written before [actor]
    /// existed still reads as an actor when a roleplay is cast to them.
    @Default(<StaffRole>{}) Set<StaffRole> roles,
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
