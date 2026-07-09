import 'package:freezed_annotation/freezed_annotation.dart';

part 'person.freezed.dart';
part 'person.g.dart';

/// A fictional scenario person (missing person, witness, reporter,
/// next-of-kin), owned by a [Station]. No PII: the real human who might
/// enact it, if any, is a separate `Actor` (ADR-0018); this is
/// publishable scenario data (ADR-0047).
///
/// [slug] is the stable reference used by `{{station.person.<slug>}}`
/// (DESIGN-009); it must match `^[a-z][a-z0-9_]*$` and be unique within
/// the station. Slug validation and uniqueness are an editor concern, not
/// enforced by this model.
@freezed
sealed class Person with _$Person {
  const factory Person({
    required String slug,
    @Default('') String name,
    int? age,
    String? gender,
    String? signalement,

    /// References a [Location.slug] on the same station.
    String? locSlug,
    String? notes,
  }) = _Person;

  factory Person.fromJson(Map<String, dynamic> json) =>
      _$PersonFromJson(json);
}
