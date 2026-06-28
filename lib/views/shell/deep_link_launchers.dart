import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

/// Drop-in widget used by deep-link routes that should open a
/// [BriefSheetTarget] via the active [ContextSheetController] and then
/// return to a sensible fallback route. Renders nothing — its only job
/// is to schedule [_openSheet] on first frame.
class BriefDeepLinkLauncher extends StatefulWidget {
  const BriefDeepLinkLauncher({
    super.key,
    required this.target,
    required this.fallbackRoute,
  });

  final BriefSheetTarget target;
  final String fallbackRoute;

  @override
  State<BriefDeepLinkLauncher> createState() => _BriefDeepLinkLauncherState();
}

class _BriefDeepLinkLauncherState extends State<BriefDeepLinkLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet());
  }

  Future<void> _openSheet() async {
    if (!mounted) return;
    final controller = ContextSheet.currentController;
    if (controller == null) {
      context.go(widget.fallbackRoute);
      return;
    }
    await controller.show(context, widget.target);
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go(widget.fallbackRoute);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Same shape as [BriefDeepLinkLauncher] but for any non-brief
/// [ContextSheetTarget]. Kept as a separate class because brief targets
/// have their own modal/wide-layout handling inside the controller.
class ContextSheetDeepLinkLauncher extends StatefulWidget {
  const ContextSheetDeepLinkLauncher({
    super.key,
    required this.target,
    required this.fallbackRoute,
  });

  final ContextSheetTarget target;
  final String fallbackRoute;

  @override
  State<ContextSheetDeepLinkLauncher> createState() =>
      _ContextSheetDeepLinkLauncherState();
}

class _ContextSheetDeepLinkLauncherState
    extends State<ContextSheetDeepLinkLauncher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet());
  }

  Future<void> _openSheet() async {
    if (!mounted) return;
    final controller = ContextSheet.currentController;
    if (controller == null) {
      context.go(widget.fallbackRoute);
      return;
    }
    await controller.show(context, widget.target);
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      context.go(widget.fallbackRoute);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
