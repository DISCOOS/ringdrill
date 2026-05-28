import 'package:flutter/material.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';

/// Shows [builder] either as a [Dialog] (wide form factor) or as a modal
/// bottom sheet (narrow form factor).
///
/// Mirrors the responsive pattern used by `showOpenPlanDialog` so the
/// library, export, send and import flows look consistent across phone,
/// tablet and desktop. Pass [maximizeHeight] when the body has an
/// `Expanded`/scrollable list that needs a bounded parent; leave it `false`
/// for compact dialogs (e.g. file-name + buttons) so the surface shrinks to
/// its content.
Future<T?> showResponsiveSheetOrDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool maximizeHeight = false,
  double widthBreakpoint = 600.0,
  double dialogMaxWidth = 560.0,
  double dialogMinWidth = 460.0,
  double dialogMaxHeight = 560.0,
  double bottomSheetHeightFraction = 0.88,
}) {
  final mediaSize = MediaQuery.sizeOf(context);
  if (mediaSize.width > widthBreakpoint) {
    return showDialog<T>(
      context: context,
      builder: (context) {
        final body = builder(context);
        return Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogMaxWidth,
              maxHeight: dialogMaxHeight,
              minWidth: dialogMinWidth,
            ),
            child: maximizeHeight
                ? SizedBox(height: dialogMaxHeight, child: body)
                : body,
          ),
        );
      },
    );
  }

  return showRingdrillActionSheet<T>(
    context: context,
    builder: (context) {
      final body = builder(context);
      if (maximizeHeight) {
        return SizedBox(
          height: mediaSize.height * bottomSheetHeightFraction,
          child: body,
        );
      }
      return body;
    },
  );
}

/// Footer row used at the bottom of a tab in modal dialogs.
///
/// Shows an info icon plus a contextual description on the left. An optional
/// [trailing] widget docks at the right (e.g. status indicator + refresh
/// button on the catalog tab). Maintains a consistent 48px min-height so
/// tabs without trailing controls match the height of tabs that have them.
class TabFooter extends StatelessWidget {
  const TabFooter({super.key, required this.subtitle, this.trailing});

  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      padding: EdgeInsets.fromLTRB(16, 4, trailing == null ? 16 : 4, 4),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: mutedColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Centered empty-state widget used inside dialog tabs.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
