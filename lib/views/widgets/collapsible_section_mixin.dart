import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/utils/prefs.dart';
import 'package:ringdrill/views/widgets/collapsible_section_store.dart';

/// Shared expand/collapse mechanism for the section cards — the persisted
/// collapsed state ([CollapsibleSectionStore]) plus the vertical-reveal
/// animation. `CollapsibleSectionCard` and `PositionCardShell` both mix this
/// in; each keeps its own layout and builds its own [SizeTransition] from
/// [collapseFactor], so only the state and the animation are shared.
///
/// The host must also mix in [SingleTickerProviderStateMixin] (before this, so
/// this mixin's `on` constraint is satisfied), call [initCollapse] from
/// `initState`, and drive its collapse affordance with [toggleCollapse]. The
/// controller is disposed here — the host must not override `dispose` without
/// chaining `super.dispose()`.
mixin CollapsibleSectionStateMixin<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  bool _collapsed = false;

  /// Whether the section is currently collapsed. Drives the host's own header
  /// chrome (chevron direction, divider, collapsed title/suffix).
  bool get collapsed => _collapsed;

  late final AnimationController _collapseController;

  /// The eased 0..1 reveal factor for the host's [SizeTransition] — 0 fully
  /// collapsed, 1 fully expanded.
  late final Animation<double> collapseFactor;

  /// Builds the controller and animation eagerly, in `initState`. Both are
  /// otherwise only touched from `build` (via [collapseFactor]) — a host that
  /// never ends up building a [SizeTransition] on a given pass (e.g. a
  /// non-collapsible [PositionCardShell]) could then be disposed having never
  /// created `_collapseController`, and `dispose` creating it for the first
  /// time on a deactivated element is what threw "Looking up a deactivated
  /// widget's ancestor is unsafe."
  @override
  @mustCallSuper
  void initState() {
    super.initState();
    _collapseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1, // expanded until the persisted state loads
    );
    collapseFactor = _collapseController.drive(
      CurveTween(curve: Curves.easeInOut),
    );
  }

  /// Reads the persisted collapsed state for [sectionId] and jumps (no
  /// animation) to it. No-op when [sectionId] is null (the section is not
  /// collapsible), leaving it expanded.
  ///
  /// Synchronous, because this runs from `initState`: an awaited read lands one
  /// frame late, so a section stored collapsed painted expanded and then snapped
  /// shut. The app binds [Prefs] in `main` before `runApp`, so the very first
  /// paint is already correct and no `setState` is needed.
  ///
  /// A caller with no binding (a widget test) reads null and keeps the expanded
  /// default — there is no async catch-up, deliberately: the whole point is that
  /// this state is known before the first frame or not at all.
  void initCollapse(String? sectionId) {
    if (sectionId == null) return;
    final stored = CollapsibleSectionStore.isCollapsedNow(sectionId);
    if (stored != null) _applyCollapsed(stored);
  }

  /// Jumps to [collapsed] with no animation. Safe to call from `initState`
  /// (before the first build) as well as inside a `setState`.
  void _applyCollapsed(bool collapsed) {
    _collapsed = collapsed;
    _collapseController.value = collapsed ? 0 : 1;
  }

  /// Flips the collapsed state, animates the reveal, and persists it.
  void toggleCollapse(String sectionId) {
    final next = !_collapsed;
    setState(() => _collapsed = next);
    next ? _collapseController.reverse() : _collapseController.forward();
    unawaited(CollapsibleSectionStore.setCollapsed(sectionId, next));
  }

  @override
  void dispose() {
    _collapseController.dispose();
    super.dispose();
  }
}
