/// V1 of DESIGN-001 (Exercise Player / DrillPlayer).
///
/// Opens a fullscreen, non-dismissible bottom sheet for the running exercise.
/// The sheet is a true fullscreen route. It does not render its own close
/// chrome — the wrapped body (today: [CoordinatorScreen]) provides its own
/// AppBar with a close affordance. This file owns only the modal-route
/// configuration and the Android immersive-mode lifecycle.
///
/// Differences from the sibling [showRingdrillViewerSheet] helpers:
/// - No drag handle.
/// - [enableDrag] and [isDismissible] are both false.
/// - Square corners — no rounded-top sheet edge.
/// - Hides Android system UI via [SystemUiMode.immersiveSticky] while open;
///   restored to [SystemUiMode.edgeToEdge] on close.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/services/exercise_service.dart';

/// Opens a fullscreen, non-dismissible DrillPlayer sheet over [context].
///
/// The [builder] receives the sheet's [BuildContext] and should return the
/// player body (e.g. `CoordinatorScreen(uuid: ...)`). The body is responsible
/// for its own close affordance (e.g. an AppBar with an X button).
Future<T?> showDrillPlayerSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final screenHeight = MediaQuery.sizeOf(context).height;
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: false,
    isScrollControlled: true,
    enableDrag: false,
    isDismissible: false,
    backgroundColor: Theme.of(context).colorScheme.surface,
    // Square corners — no rounded-top edge leaking through.
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    constraints: BoxConstraints(
      minHeight: screenHeight,
      maxHeight: screenHeight,
      maxWidth: double.infinity,
    ),
    builder: (sheetContext) =>
        _DrillPlayerSheetBody(builder: builder, sheetContext: sheetContext),
  );
}

// ---------------------------------------------------------------------------
// Private sheet body — handles immersive mode lifecycle only; no close chrome
// ---------------------------------------------------------------------------

class _DrillPlayerSheetBody extends StatefulWidget {
  const _DrillPlayerSheetBody({
    required this.builder,
    required this.sheetContext,
  });

  final WidgetBuilder builder;

  /// The [BuildContext] scoped to the modal route. Kept for parity with the
  /// previous implementation; currently unused since the body provides its
  /// own close affordance.
  final BuildContext sheetContext;

  @override
  State<_DrillPlayerSheetBody> createState() => _DrillPlayerSheetBodyState();
}

class _DrillPlayerSheetBodyState extends State<_DrillPlayerSheetBody> {
  StreamSubscription<ExerciseEvent>? _exerciseSubscription;

  @override
  void initState() {
    super.initState();
    _exerciseSubscription = ExerciseService().events.listen((event) {
      if (!mounted || !event.isDone) return;
      Navigator.of(context).pop();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _enterImmersive());
  }

  @override
  void dispose() {
    _exerciseSubscription?.cancel();
    _exitImmersive();
    super.dispose();
  }

  void _enterImmersive() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _exitImmersive() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The fullscreen sheet is presented with `useSafeArea: false`, so
    // showModalBottomSheet wraps the body in `MediaQuery.removePadding(
    // removeTop: true)`. That call zeroes BOTH `padding.top` AND
    // `viewPadding.top` (it subtracts the removed padding from viewPadding),
    // so the wrapped CoordinatorScreen AppBar reads a 0 status-bar inset,
    // paints from y=0 and its title collides with the system clock (the bug).
    //
    // Read the true inset straight off the FlutterView — it is unaffected by
    // any `removePadding` ancestor, and correctly reports 0 on Android once
    // immersive mode hides the status bar. Re-inject it as `padding.top` so
    // the AppBar insets below the status bar like a normal route while still
    // painting its background up under it. No chevron, no SafeArea wrapper —
    // CoordinatorScreen's AppBar provides the sole close affordance.
    final mediaQuery = MediaQuery.of(context);
    final physicalTop = MediaQueryData.fromView(View.of(context)).padding.top;
    return MediaQuery(
      data: mediaQuery.copyWith(
        padding: mediaQuery.padding.copyWith(top: physicalTop),
      ),
      child: widget.builder(context),
    );
  }
}
