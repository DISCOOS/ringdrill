import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/services/plan_service.dart';

/// Exposes the active plan's declared variables (ADR-0046) to a subtree, so
/// token-aware fields (`RingDrillTextField`/`RingDrillTextArea`) read the
/// registry via [PlanScope.of] instead of being handed a `variables` list
/// through their own constructor.
///
/// Provided in two situations: by an entity editor, seeded from its working
/// registry and rebuilt whenever the author edits it (create, rename,
/// delete, value edit — so the scope always reflects the live, unsaved
/// state, not just what was last saved); and, later, around the
/// plan-scoped routes for the live app, so read-only display surfaces
/// can resolve `{{var.name}}` too.
class PlanScope extends InheritedWidget {
  const PlanScope({
    super.key,
    required this.variables,
    this.planName,
    this.planDescription,
    required super.child,
  });

  final List<DrillVariable> variables;

  /// The plan's `{{plan.name}}`/`{{plan.description}}`
  /// cross-reference facets (DESIGN-010's resolve-context cascade — the
  /// plan level of the cascade `BriefRenderer`'s `refContext` already
  /// mirrors). Null where the provider has no plan in scope to source
  /// them from; the plan-scoped route (ADR-0032) always sets both,
  /// since it sits highest in the tree, where the active plan is known.
  final String? planName;
  final String? planDescription;

  /// Seeds a scope from [PlanService]'s active plan, for a **route** choke
  /// point.
  ///
  /// `showModalBottomSheet` / `showDialog` / `Navigator.push` mount onto the
  /// Navigator's `Overlay`, a sibling of `MainScreen` rather than a descendant,
  /// so the `PlanScope` wrapping `MainScreen` never reaches anything opened that
  /// way (DESIGN-008 follow-up 11). Every such choke point has to seed one, and
  /// this is the shared way to do it — `showRingdrillViewerSheet` and its
  /// siblings, and `showDrillPlayerSheet`.
  ///
  /// Missing it is *not* limited to `{{var.*}}` going unresolved:
  /// `RingDrillText` returns its text verbatim when there is no scope at all, so
  /// a subtree without one renders **every** token literally — `{{station.*}}`
  /// and `{{exercise.*}}` included, even where those scopes are present. That is
  /// how the drill player's station/roleplay/team modes shipped showing raw
  /// tokens: the player renders its body on a modal route, and only
  /// `CoordinatorScreen` — the one body it used to have — happens to seed a
  /// scope of its own.
  ///
  /// Seeds the plan *facets* as well as the variable registry: without
  /// `variables` a `{{var.*}}` renders the unknown-variable placeholder, and
  /// without `planName`/`planDescription` a `{{plan.*}}` renders empty. Harmless
  /// for a cross-plan surface, which simply never reads the scope.
  static Widget fromActivePlan({Key? key, required Widget child}) {
    final plan = PlanService().activePlan;
    return PlanScope(
      key: key,
      variables: plan?.variables ?? const [],
      planName: plan?.name,
      planDescription: plan?.description,
      child: child,
    );
  }

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
      planName != oldWidget.planName ||
      planDescription != oldWidget.planDescription;
}
