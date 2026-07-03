import 'package:freezed_annotation/freezed_annotation.dart';

part 'drill_variable.freezed.dart';
part 'drill_variable.g.dart';

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

    /// The global default value substituted when no scope overrides it.
    @Default('') String value,

    /// Optional description shown in the insertion picker.
    String? hint,
  }) = _DrillVariable;

  factory DrillVariable.fromJson(Map<String, dynamic> json) =>
      _$DrillVariableFromJson(json);
}
