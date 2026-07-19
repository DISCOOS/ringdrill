import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/lat_lng_converter.dart';

part 'drill_variable.freezed.dart';
part 'drill_variable.g.dart';

/// The declared value type of a [DrillVariable] (DESIGN-008 follow-up 11).
/// Drives the type-aware editor input, validation and the canonical stored
/// encoding of [DrillVariable.value]; [string] is the back-compatible
/// default, so a variable written before this field existed loads and
/// renders exactly as before. The JSON value is a stable wire slug; an
/// unknown value (e.g. written by a newer client) decodes to [string] so
/// older clients stay forward-compatible when a type is added later.
enum VariableType {
  /// Free text — no validation, no formatting. The default.
  string,

  /// Integer or decimal. Canonical: a decimal string with `.` separator.
  number,

  /// 24-hour clock time. Canonical: `HH:MM`.
  time,

  /// Calendar date. Canonical: ISO `yyyy-MM-dd`; rendered localized.
  date,

  /// A time span. Canonical: whole minutes as an integer string; rendered
  /// "45 min" / "1 t 30 min".
  duration,

  /// A place with a coordinate — the geo shape of a `Location` (DESIGN-009)
  /// minus `kind`. The value lives in [DrillVariable.location], not in the
  /// string [DrillVariable.value]; it exposes the `.place`/`.position`
  /// facets (ADR-0050), and the bare token renders place + position.
  location,
}

/// The structured value of a [VariableType.location] variable: the place
/// text plus the canonical coordinate (ADR-0046, DESIGN-008 follow-up 11).
/// Mirrors `Location`'s geo shape (`place` + `position`) without `kind`.
@freezed
sealed class VariableLocation with _$VariableLocation {
  const factory VariableLocation({
    @Default('') String place,
    @NullableLatLngJsonConverter() LatLng? position,
  }) = _VariableLocation;

  factory VariableLocation.fromJson(Map<String, dynamic> json) =>
      _$VariableLocationFromJson(json);
}

/// An author-defined value declared once on the plan and referenced from
/// markdown fields as `{{var.<name>}}`. See ADR-0046 and DESIGN-008.
///
/// Identity is plan-global: a variable is declared only on [Program].
/// [Exercise] and [Station] override the value for their subtree via a
/// `variableOverrides` map keyed by [name]; they never declare new names.
@freezed
sealed class DrillVariable with _$DrillVariable {
  const factory DrillVariable({
    /// Slug, unique within the plan. Must match `^[a-z][a-z0-9_]*$`.
    /// This is the reference key used in `{{var.<name>}}`.
    required String name,

    /// The global default value substituted when no scope overrides it,
    /// canonically encoded per [type] (DESIGN-008 follow-up 11). Unused
    /// (kept empty) when [type] is [VariableType.location] — that type's
    /// value is [location].
    @Default('') String value,

    /// Optional description shown in the insertion picker.
    String? hint,

    /// The declared value type (DESIGN-008 follow-up 11). Additive with a
    /// back-compatible default: a 1.0–1.2 archive without the key — or one
    /// with a type this client does not know — loads as [VariableType.string]
    /// and behaves exactly as before typed variables existed.
    @Default(VariableType.string)
    @JsonKey(unknownEnumValue: VariableType.string)
    VariableType type,

    /// Structured value used only when [type] is [VariableType.location]:
    /// the place text plus the canonical `LatLng`. Additive (absent key
    /// loads as null); ignored for every other [type].
    VariableLocation? location,
  }) = _DrillVariable;

  factory DrillVariable.fromJson(Map<String, dynamic> json) =>
      _$DrillVariableFromJson(json);
}
