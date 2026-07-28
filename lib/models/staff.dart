import 'package:freezed_annotation/freezed_annotation.dart';

part 'staff.freezed.dart';
part 'staff.g.dart';

/// An organizational role a [Staff] member holds (DESIGN-011).
///
/// **`markør` is deliberately absent.** A person is a markør precisely when some
/// `RolePlay.staffUuid` points at them, so it is derived from the cast rather than
/// stored — a stored flag could disagree with the actual casting, and there would
/// be no way to tell which was right.
///
/// **`deltaker` is absent too, for a different reason.** "Stab" means the
/// non-participants: course participants are not rostered individually, they stay
/// a `Team.numberOfMembers` count. "Deltaker" survives only as a brief audience.
enum StaffRole {
  /// Øvelsesleder — runs the exercise.
  @JsonValue('director')
  director,

  /// Veileder — supervises a team through it.
  @JsonValue('instructor')
  instructor,

  /// Anything the two above do not cover; an escape hatch so the roster does not
  /// need a schema change per role.
  @JsonValue('other')
  other,
}

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

    /// The organizational roles this person holds. Empty for someone who only
    /// plays markører, since that role is derived from casting rather than stored
    /// here. Additive and defaulted, so a record written before DESIGN-011 reads
    /// back unchanged.
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
