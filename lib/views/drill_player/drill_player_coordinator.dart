import 'package:flutter/material.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/views/drill_player/player_targets.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/drill_player_sheet.dart';

/// Owns the "open the immersive DrillPlayer" entry point + the narrow-layout
/// "upgrade from modal ContextSheet to fullscreen DrillPlayer when an
/// exercise starts" behaviour.
///
/// Both pieces lived inline in `MainScreen` and grew together as the player
/// flow evolved. Pulling them out:
/// - keeps the upgrade flag and its single-shot guard next to the open call
///   that clears it,
/// - gives a single seam any other shell ([MainScreen], a future test
///   harness, an alternative entry point) can call into without copying the
///   guard logic.
class DrillPlayerCoordinator {
  DrillPlayerCoordinator();

  // Single-shot guard for the ContextSheet → DrillPlayer upgrade. Set
  // synchronously when we schedule the upgrade and cleared when the
  // DrillPlayer route is dismissed, so the per-minute event tick can't
  // re-pop the drill player as a stale "close the context sheet" action.
  bool _upgrading = false;

  /// Opens the immersive DrillPlayer sheet on [target], defaulting to the
  /// currently-running (or last-known) exercise. No-op when no target is given
  /// and [ExerciseService] has no last event.
  ///
  /// [target] may be a station or a roleplay as readily as an exercise: the
  /// player is a host for any of them (ADR-0056), so an item opened while its
  /// exercise is live enters the player at that item rather than in a sheet
  /// beside it.
  Future<void> openDrillPlayer(
    BuildContext context, {
    ContextSheetTarget? target,
  }) {
    final initial = target ?? _lastExerciseTarget();
    if (initial == null) return Future<void>.value();
    // The player hosts its own ContextSheet, opened on the target it is
    // showing. There is only ever one drill player, so switching target from
    // inside it has to swap this body in place: with a local controller in
    // scope, `ContextSheet.of(...)` inside the player finds an *inline*
    // controller and replaces the target instead of stacking a second player
    // (or a modal sheet) over the first.
    //
    // Registering also makes this the `currentController` while the player
    // lives, and disposing unregisters it, restoring the shell's.
    final controller = ContextSheetController()..adoptInlineTarget(initial);
    return showDrillPlayerSheet<void>(
      context: context,
      builder: (_) => ContextSheet(
        controller: controller,
        child: _DrillPlayerHost(controller: controller),
      ),
    ).whenComplete(controller.dispose);
  }

  ContextSheetTarget? _lastExerciseTarget() {
    final last = ExerciseService().last;
    if (last == null) return null;
    return ExerciseSheetTarget(exerciseUuid: last.exercise.uuid);
  }

  /// Hook called from the host shell's ExerciseService listener.
  ///
  /// When an exercise transitions to started while [controller] is showing
  /// the same exercise (or a station/team/role belonging to it) inside a
  /// modal ContextSheet, the draggable bottom sheet would otherwise stay at
  /// 92% height. We close it and push the fullscreen sheet on top in the
  /// same frame, mirroring the wide-layout onPlay flow.
  ///
  /// Master-detail (wide) callers always have `controller.isModal == false`,
  /// so they fall through untouched.
  void maybeUpgradeOnExerciseEvent({
    required BuildContext context,
    required ContextSheetController controller,
    required ExerciseEvent event,
  }) {
    if (event.isDone || _upgrading) return;
    if (!ExerciseService().isStarted) return;
    if (!controller.isModal) return;
    final targetUuid = exerciseUuidOf(controller.target.value);
    if (targetUuid == null || targetUuid != event.exercise.uuid) return;
    _upgrading = true;
    controller.close();
    openDrillPlayer(context).whenComplete(() {
      _upgrading = false;
    });
  }
}

/// Renders whichever target the player's own [ContextSheetController] points
/// at, and lets a horizontal swipe move between that target's siblings.
///
/// Uses the same [defaultContextSheetBody] the shell's sheet host and the
/// master/detail pane use, so exercise, station, roleplay and team are peer
/// *modes* of one player rather than four separate players — and so the player
/// never diverges from what the same target renders as elsewhere.
class _DrillPlayerHost extends StatefulWidget {
  const _DrillPlayerHost({required this.controller});

  final ContextSheetController controller;

  @override
  State<_DrillPlayerHost> createState() => _DrillPlayerHostState();
}

/// Pages across [playerSiblingTargets] of whatever the controller points at.
///
/// Borrowed from the now-playing metaphor DESIGN-001 is built on: swipe moves to
/// the next sibling the way it moves to the next track. Deliberately *within*
/// kind — the picker spans kinds, so paging it flat would change the player's
/// mode mid-gesture. Changing kind stays an explicit act.
///
/// The sequence **wraps**: past the last sibling comes the first, and back from
/// the first comes the last. A `PageView` has no wrap mode, so the page count is
/// left unbounded and the sibling is looked up modulo the sequence length, with
/// the controller starting deep enough in that range to swipe a long way either
/// direction. The alternative — detecting an overscroll and jumping — loses the
/// drag's continuity at exactly the moment the user is watching it.
///
/// Two directions of travel have to be kept from fighting each other:
/// - a swipe reports through `onPageChanged`, which replaces the controller's
///   target, and
/// - an external replace (the picker, a content tap) has to move the page.
///
/// [_page] is what tells them apart: it is updated *before* any programmatic
/// jump, so the resulting `onPageChanged` is recognised as an echo and does not
/// write back. A flag would work too, but `jumpToPage` notifies synchronously,
/// which makes flag lifetime fiddly; comparing state is harder to get wrong.
class _DrillPlayerHostState extends State<_DrillPlayerHost> {
  /// How many times the sequence is laid out either side of the start, so a user
  /// swiping one direction never reaches the end of the page range. 1000 cycles
  /// of even a 2-target sequence is far past any real session.
  static const int _cycles = 1000;

  PageController? _pages;
  List<ContextSheetTarget> _siblings = const [];

  /// Bumped whenever [_pages] is replaced, and used as the `PageView`'s key.
  ///
  /// Load-bearing: handing a `Scrollable` a *new* `ScrollController` does not
  /// restart it — `ScrollPosition.absorb` carries the old pixel offset across, so
  /// `initialPage` is ignored. After a sequence-length change that offset means a
  /// different sibling (old page 1500 modulo a new length of 2 is index 0), which
  /// showed the wrong target. A new key builds a new element, hence a new
  /// position, which does honour `initialPage`.
  int _generation = 0;

  /// The *absolute* page — not the sibling index. `_page % _siblings.length` is
  /// the sibling it shows.
  int _page = 0;

  /// False until the route's entry transition has finished — see [build].
  bool _entered = false;

  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    widget.controller.target.addListener(_onTargetChanged);
    _resync(rebuildController: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_onRouteAnimation);
    _routeAnimation = animation;
    if (animation == null || animation.isCompleted) {
      _entered = true;
      return;
    }
    animation.addStatusListener(_onRouteAnimation);
  }

  void _onRouteAnimation(AnimationStatus status) {
    if (!status.isCompleted || _entered || !mounted) return;
    setState(() => _entered = true);
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimation);
    widget.controller.target.removeListener(_onTargetChanged);
    _pages?.dispose();
    super.dispose();
  }

  void _onTargetChanged() {
    if (!mounted) return;
    setState(() => _resync());
  }

  /// Installs [next] and disposes the outgoing controller *after* the frame.
  ///
  /// Disposing it inline looks right but is not: this runs inside `setState`, so
  /// the currently-mounted `PageView` still holds the old controller until the
  /// rebuild swaps it, and tearing down an attached `ScrollController`'s position
  /// under it leaves the pager unresponsive — silently, with no exception.
  void _swapController(PageController next) {
    final previous = _pages;
    _pages = next;
    _generation++;
    if (previous == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
  }

  /// The absolute page showing sibling [index], nearest to [from].
  ///
  /// Anchored to the current page rather than restarting at the middle, so an
  /// external replace does not throw away how far the user has already paged.
  int _pageFor(int index, {required int from}) {
    final count = _siblings.length;
    if (count == 0) return 0;
    return from - (from % count) + index;
  }

  /// Recomputes the sibling sequence for the current target and lines the pager
  /// up with it.
  ///
  /// The sequence is rebuilt from scratch each time rather than cached: a target
  /// change can also mean the plan changed underneath (a station deleted while
  /// the player is up), and a stale sequence would page to something gone.
  void _resync({bool rebuildController = false}) {
    final target = widget.controller.target.value;
    if (target == null) {
      _siblings = const [];
      _page = 0;
      return;
    }
    final siblings = playerSiblingTargets(target);
    final index = playerSiblingIndex(siblings, target);
    // A different kind (or a changed plan) means a different sequence length,
    // which the modulo depends on and PageController cannot be told about — so
    // replace it.
    final lengthChanged = siblings.length != _siblings.length;
    _siblings = siblings;
    if (rebuildController || lengthChanged || _pages == null) {
      _page = siblings.length * (_cycles ~/ 2) + index;
      _swapController(PageController(initialPage: _page));
      return;
    }
    final pages = _pages!;
    final wanted = _pageFor(index, from: _page);
    if (wanted == _page) return;
    _page = wanted;
    if (!pages.hasClients) {
      // Not laid out yet: the field write above is what the builder reads, so
      // there is nothing to jump.
      return;
    }
    pages.jumpToPage(wanted);
  }

  void _onPageChanged(int page) {
    // Equal means this is the echo of a jump we just made, not a swipe.
    if (page == _page || _siblings.isEmpty) return;
    _page = page;
    widget.controller.replace(_siblings[page % _siblings.length]);
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    if (_siblings.isEmpty || pages == null) return const SizedBox.shrink();
    final count = _siblings.length;
    // No pager for a target with nowhere to swipe — chiefly exercise mode, the
    // player's root. Wrapping a single view in a PageView bought nothing and cost
    // the entry animation: one laid out while the sheet is still sliding settles
    // its horizontal offset over the following frames, so the player appeared to
    // arrive from the side and painted late. Rendering directly is both simpler
    // and immediate.
    //
    // The same reason defers the pager in the modes that *do* page until the
    // route's entry transition has finished.
    if (count == 1 || !_entered) {
      final target = _siblings[_page % count];
      return KeyedSubtree(
        key: ValueKey(target),
        child: defaultContextSheetBody(context, target),
      );
    }
    return PageView.builder(
      key: ValueKey(_generation),
      controller: pages,
      onPageChanged: _onPageChanged,
      itemCount: null,
      itemBuilder: (context, page) {
        final target = _siblings[page % count];
        // Keyed on the target: these screens resolve their entity once, in
        // `initState`, so reusing an element across a target change would keep
        // showing the previous one. Targets have no `==`, so every distinct
        // target is a distinct key — and the same target only recurs a whole
        // cycle away, never adjacent, so no two live pages share a key.
        return KeyedSubtree(
          key: ValueKey(target),
          child: defaultContextSheetBody(context, target),
        );
      },
    );
  }
}
