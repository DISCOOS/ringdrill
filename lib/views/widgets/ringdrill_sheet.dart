import 'package:flutter/material.dart';

Future<T?> showRingdrillViewerSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext, ScrollController) builder,
  String? title,
  List<Widget>? actions,
  VoidCallback? onClose,
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
            title: title,
            actions: actions,
            onClose: onClose,
            builder: builder,
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
    this.title,
    this.actions,
    this.onClose,
  });

  final ScrollController scrollController;
  final Widget Function(BuildContext, ScrollController) builder;
  final String? title;
  final List<Widget>? actions;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final child = builder(context, scrollController);
    final width = MediaQuery.sizeOf(context).width;
    final body = width >= 600
        ? Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: child,
            ),
          )
        : child;

    return Column(
      children: [
        const _DragHandle(),
        _ViewerHeader(title: title, actions: actions, onClose: onClose),
        Expanded(child: body),
      ],
    );
  }
}

class _ViewerHeader extends StatelessWidget {
  const _ViewerHeader({this.title, this.actions, this.onClose});

  final String? title;
  final List<Widget>? actions;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final close = onClose ?? () => Navigator.of(context).pop();
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
      child: Row(
        children: [
          Expanded(
            child: title == null
                ? const SizedBox.shrink()
                : Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          ...?actions,
          IconButton(icon: const Icon(Icons.close), onPressed: close),
        ],
      ),
    );
  }
}
