import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/widgets.dart';
import 'package:ringdrill/models/exercise.dart';

/// Exposes the in-scope exercise's cross-reference facets (`exercise.*`,
/// DESIGN-010's resolve-context cascade — the same facet set
/// `PlanFieldTokens.exercise` lists) plus this exercise's own variable
/// overrides (ADR-0046) to a subtree — the `PlanScope`/`StationScope`
/// sibling for the exercise level.
///
/// Provided by the exercise editor, seeded from the exercise being edited
/// (its own facets — name, times, counters — are only as fresh as the last
/// save; `PlanScope`'s live-typing guarantee is about declaring/renaming a
/// *variable*, a different concern) and from the live working copy of
/// [Exercise.variableOverrides], which the author can edit without saving.
///
/// Carries the data only; nothing reads this scope for resolution yet — that
/// starts with DESIGN-010 stage 2. Omitted for a not-yet-saved exercise
/// (nothing to carry) and for editors with no exercise in scope (Program),
/// mirroring [StationScope]'s optional-ancestor pattern.
class ExerciseScope extends InheritedWidget {
  const ExerciseScope({
    super.key,
    required this.exercise,
    required this.variableOverrides,
    required super.child,
  });

  final Exercise exercise;

  /// This exercise's own value overrides for plan-global variables
  /// (ADR-0046), keyed by `DrillVariable.name` — the editor's live working
  /// copy, not necessarily `exercise.variableOverrides` itself.
  final Map<String, String> variableOverrides;

  static ExerciseScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ExerciseScope>();

  @override
  bool updateShouldNotify(ExerciseScope oldWidget) =>
      exercise != oldWidget.exercise ||
      !mapEquals(variableOverrides, oldWidget.variableOverrides);
}
