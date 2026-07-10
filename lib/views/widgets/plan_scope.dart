import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:ringdrill/models/drill_variable.dart';

/// Exposes the active plan's declared variables (ADR-0046) to a subtree, so
/// token-aware fields (`RingDrillTextField`/`RingDrillTextArea`) read the
/// registry via [PlanScope.of] instead of being handed a `variables` list
/// through their own constructor.
///
/// Provided in two situations: by an entity editor, seeded from its working
/// registry and rebuilt whenever the author edits it (create, rename,
/// delete, value edit — so the scope always reflects the live, unsaved
/// state, not just what was last saved); and, later, around the
/// program-scoped routes for the live app, so read-only display surfaces
/// can resolve `{{var.name}}` too.
class PlanScope extends InheritedWidget {
  const PlanScope({
    super.key,
    required this.variables,
    this.programName,
    this.programDescription,
    required super.child,
  });

  final List<DrillVariable> variables;

  /// The program's `{{program.name}}`/`{{program.description}}`
  /// cross-reference facets (DESIGN-010's resolve-context cascade — the
  /// program level of the cascade `BriefRenderer`'s `refContext` already
  /// mirrors). Null where the provider has no program in scope to source
  /// them from; the program-scoped route (ADR-0032) always sets both,
  /// since it sits highest in the tree, where the active program is known.
  final String? programName;
  final String? programDescription;

  /// The nearest enclosing [PlanScope], or `null` outside one — for callers
  /// that tolerate having no plan-variable registry available (e.g. the
  /// flag-off legacy path, which never provides a scope at all).
  static PlanScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlanScope>();

  /// The nearest enclosing [PlanScope]. Asserts in debug mode when none is
  /// found — call [maybeOf] instead where the absence of a scope is a
  /// legitimate, handled case rather than a wiring bug.
  static PlanScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(
      scope != null,
      'No PlanScope found in context. A token-aware field must be built '
      'under a PlanScope ancestor.',
    );
    return scope!;
  }

  // Compares by value (DrillVariable has freezed value equality), not
  // identity, so an ancestor rebuild that passes an equal-but-different
  // List instance — e.g. a parent widget rebuilding for an unrelated
  // reason — does not spuriously notify every descendant that reads this
  // scope.
  @override
  bool updateShouldNotify(PlanScope oldWidget) =>
      !listEquals(variables, oldWidget.variables) ||
      programName != oldWidget.programName ||
      programDescription != oldWidget.programDescription;
}
