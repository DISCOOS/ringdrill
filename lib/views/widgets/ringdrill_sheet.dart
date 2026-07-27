import 'package:flutter/material.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';

/// Seeds a [PlanScope] from the active plan for a sheet/dialog choke point
/// (DESIGN-008 follow-up 11): `showModalBottomSheet`/`showDialog` push onto
/// the Navigator's `Overlay`, a sibling of — not a descendant of —
/// `MainScreen`, so the `PlanScope` wrapping `MainScreen` never reaches
/// anything opened this way without this. Harmless for a cross-plan
/// picker: it simply never reads the scope (follow-up 09).
///
/// Seeds the plan *facets* as well as the variable registry. Both halves of the
/// plan level of the cascade are needed: without `variables` a `{{var.*}}`
/// renders the unknown-variable placeholder, and without
/// `planName`/`planDescription` a `{{plan.*}}` renders empty. Anything opened
/// through here that forwards the ambient scope onward (every form screen does)
/// inherits whichever half is missing, so seeding only one left `{{plan.*}}`
/// silently blank several layers down.
Widget _withDefaultPlanScope(Widget child) {
  final plan = PlanService().activePlan;
  return PlanScope(
    variables: plan?.variables ?? const [],
    planName: plan?.name,
    planDescription: plan?.description,
    child: child,
  );
}

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
          return _withDefaultPlanScope(_RingdrillSheetSurface(child: body));
        },
      );
    },
  );
}

/// [isDismissible] false blocks every implicit way out — barrier tap, drag
/// down, system back — so only the sheet's own action buttons can close it
/// (used by the catalog conflict sheet). The drag handle is hidden too,
/// since it would advertise a gesture that no longer works.
Future<T?> showRingdrillActionSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    shape: null,
    constraints: const BoxConstraints(maxWidth: double.infinity),
    builder: (context) {
      return PopScope(
        canPop: isDismissible,
        child: _withDefaultPlanScope(
          _RingdrillSheetSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDismissible)
                  const _DragHandle()
                else
                  const SizedBox(height: 16),
                // Flexible (not Expanded) so a short sheet still wraps its
                // content, but a tall one is bounded to the available height
                // instead of overflowing. Builders that size themselves to a
                // fraction of the full screen (e.g. the open-plan picker at
                // 0.88×height) would otherwise overflow once the drag handle
                // and the bottom safe-area inset are added on top. Their own
                // scroll areas absorb the clamp.
                Flexible(child: SafeArea(top: false, child: builder(context))),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Shared rounded-`Dialog` chrome (clip, corner radius, elevation, inset
/// padding) for every "modal dialog on medium/expanded" surface — forms
/// via [showRingdrillFormDialog] and the picker primitive's wide path
/// (ADR-0049, `showRingdrillPicker`), which just cap [maxWidth] and
/// [maxHeightFraction] narrower/shorter for a list instead of a form.
Future<T?> showRingdrillDialogShell<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required double maxWidth,
  required double maxHeightFraction,
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
        // Scope a ScaffoldMessenger to the dialog so a form's SnackBar (e.g.
        // "Velg en person") shows only inside the dialog's own Scaffold. The
        // root messenger otherwise displays it in every registered Scaffold
        // at once — both here and on the main screen behind the barrier.
        child: ScaffoldMessenger(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: viewport.height * maxHeightFraction,
            ),
            child: _withDefaultPlanScope(builder(context)),
          ),
        ),
      );
    },
  );
}

Future<T?> showRingdrillFormDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showRingdrillDialogShell<T>(
    context: context,
    builder: builder,
    maxWidth: 720,
    maxHeightFraction: 0.88,
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
