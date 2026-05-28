/// V1 of DESIGN-001 (Exercise Player / DrillPlayer).
///
/// Opens an immersive, non-dismissible fullscreen bottom sheet for the running
/// exercise. Used by [MainScreen] (via [DrillMiniPlayer.onOpen]) and by
/// [ProgramView] when the live exercise card is tapped. The sheet body is
/// provided by the caller — today always [CoordinatorScreen].
///
/// Differences from the sibling [showRingdrillViewerSheet] helpers:
/// - No drag handle.
/// - [enableDrag] and [isDismissible] are both false.
/// - Hides Android system UI via [SystemUiMode.immersiveSticky] while open;
///   restored to [SystemUiMode.edgeToEdge] on close.
/// - A chevron-down [IconButton] at the top-left closes the sheet without
///   stopping the exercise.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';

/// Opens a fullscreen, non-dismissible DrillPlayer sheet over [context].
///
/// The [builder] receives the sheet's [BuildContext] and should return the
/// player body (e.g. `CoordinatorScreen(uuid: ...)`).
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
    constraints: BoxConstraints(
      minHeight: screenHeight,
      maxWidth: double.infinity,
    ),
    builder: (sheetContext) => _DrillPlayerSheetBody(
      builder: builder,
      sheetContext: sheetContext,
    ),
  );
}

// ---------------------------------------------------------------------------
// Private sheet body — handles immersive mode lifecycle + close button
// ---------------------------------------------------------------------------

class _DrillPlayerSheetBody extends StatefulWidget {
  const _DrillPlayerSheetBody({
    required this.builder,
    required this.sheetContext,
  });

  final WidgetBuilder builder;

  /// The [BuildContext] scoped to the modal route, used for [Navigator.pop].
  final BuildContext sheetContext;

  @override
  State<_DrillPlayerSheetBody> createState() => _DrillPlayerSheetBodyState();
}

class _DrillPlayerSheetBodyState extends State<_DrillPlayerSheetBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _enterImmersive());
  }

  @override
  void dispose() {
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
    final localizations = AppLocalizations.of(context)!;
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                tooltip: localizations.drillPlayerClose,
                onPressed: () => Navigator.of(widget.sheetContext).pop(),
              ),
            ],
          ),
        ),
        Expanded(
          child: SafeArea(
            top: false,
            child: widget.builder(context),
          ),
        ),
      ],
    );
  }
}
