import 'package:flutter/material.dart';

/// Opens a draggable viewer sheet with the standard Ringdrill chrome (drag
/// handle, rounded top corners, surface background).
///
/// [maxBodyWidth] caps the body width on wide screens so column-based content
/// stays readable. Default 720 matches the original behaviour. Pass
/// [double.infinity] to let the body fill the full sheet width — used by the
/// brief sheet so its wide-layout TOC sidebar gets the room it needs.
Future<T?> showRingdrillViewerSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext, ScrollController) builder,
  double maxBodyWidth = 720,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    isScrollControlled: true,
    shape: null,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        expand: false,
        builder: (context, scrollController) {
          final body = _ViewerBody(
            scrollController: scrollController,
            builder: builder,
            maxBodyWidth: maxBodyWidth,
          );
          return _RingdrillSheetSurface(child: body);
        },
      );
    },
  );
}

Future<T?> showRingdrillActionSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    isScrollControlled: true,
    shape: null,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    builder: (context) {
      return _RingdrillSheetSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _DragHandle(),
            SafeArea(top: false, child: builder(context)),
          ],
        ),
      );
    },
  );
}

Future<T?> showRingdrillFormDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final viewport = MediaQuery.sizeOf(context);
  return showDialog<T>(
    context: context,
    builder: (context) {
      return Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720,
            maxHeight: viewport.height * 0.88,
          ),
          child: builder(context),
        ),
      );
    },
  );
}

class _RingdrillSheetSurface extends StatelessWidget {
  const _RingdrillSheetSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: child,
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Center(
        child: Container(
          key: const Key('ringdrill-sheet-drag-handle'),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _ViewerBody extends StatelessWidget {
  const _ViewerBody({
    required this.scrollController,
    required this.builder,
    required this.maxBodyWidth,
  });

  final ScrollController scrollController;
  final Widget Function(BuildContext, ScrollController) builder;

  /// Caps the body width on wide screens. [double.infinity] disables the cap
  /// and lets the body fill the full sheet width.
  final double maxBodyWidth;

  @override
  Widget build(BuildContext context) {
    final child = builder(context, scrollController);
    final width = MediaQuery.sizeOf(context).width;
    // Skip the centering wrapper entirely when no cap is requested so the
    // body's own LayoutBuilder sees the full host width (the brief sheet
    // needs this to trigger its wide-layout TOC sidebar at >= 900px).
    final body = (maxBodyWidth.isFinite && width >= 600)
        ? Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBodyWidth),
              child: child,
            ),
          )
        : child;

    return Column(
      children: [
        const _DragHandle(),
        Expanded(child: body),
      ],
    );
  }
}
