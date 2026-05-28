import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

typedef DetailEmptyPaneBuilder = Widget Function(BuildContext context);

class MasterDetailScope
    extends InheritedNotifier<ValueNotifier<ContextSheetTarget?>> {
  const MasterDetailScope({
    super.key,
    required ValueNotifier<ContextSheetTarget?> target,
    required this.emptyPaneBuilder,
    this.bodyBuilder,
    required super.child,
  }) : super(notifier: target);

  /// Builds the placeholder shown when no detail target is selected.
  ///
  /// The caller owns the active-tab decision so the shell can provide
  /// tab-specific empty states and the Map tab can intentionally provide none.
  final DetailEmptyPaneBuilder emptyPaneBuilder;
  final ContextSheetBodyBuilder? bodyBuilder;

  static MasterDetailScope? maybeOf(BuildContext context) {
    return context
            .getElementForInheritedWidgetOfExactType<MasterDetailScope>()
            ?.widget
        as MasterDetailScope?;
  }

  static MasterDetailScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<MasterDetailScope>();
    assert(scope != null, 'No MasterDetailScope found in context');
    return scope!;
  }

  ValueListenable<ContextSheetTarget?> get target => notifier!;

  void setTarget(ContextSheetTarget? target) {
    notifier!.value = target;
  }
}

class MasterDetailPane extends StatelessWidget {
  const MasterDetailPane({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = MasterDetailScope.of(context);
    return ValueListenableBuilder<ContextSheetTarget?>(
      valueListenable: scope.target,
      builder: (context, target, _) {
        if (target == null) {
          // TODO(adr-0030): replace with tab-specific empty pane widgets.
          return scope.emptyPaneBuilder(context);
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          child: PrimaryScrollController(
            key: ValueKey(target),
            controller: ScrollController(),
            child:
                scope.bodyBuilder?.call(context, target) ??
                defaultContextSheetBody(context, target),
          ),
        );
      },
    );
  }
}
