import 'package:flutter/cupertino.dart';

class PageWidget<T extends ScreenController> extends StatefulWidget {
  const PageWidget({super.key, required this.controller, required this.child});

  final Widget child;
  final T controller;

  @override
  State<PageWidget> createState() => _PageWidgetState<T>();
}

class _PageWidgetState<T extends ScreenController>
    extends State<PageWidget<T>> {
  @override
  Widget build(BuildContext context) {
    return ScreenControllerProvider<T>(
      controller: widget.controller,
      child: widget.child,
    );
  }
}

abstract class ScreenController {
  const ScreenController();

  String title(BuildContext context);
  Widget? buildFAB(BuildContext context, BoxConstraints constraints) {
    return null;
  }

  List<Widget>? buildActions(BuildContext context, BoxConstraints constraints) {
    return null;
  }

  static T of<T extends ScreenController>(BuildContext context) {
    final T? controller = ofNullable<T>(context);
    assert(
      controller != null,
      'No ${ScreenControllerProvider<T>} found in context',
    );
    return controller!;
  }

  static T? ofNullable<T extends ScreenController>(BuildContext context) {
    final ScreenControllerProvider<T>? provider = context
        .dependOnInheritedWidgetOfExactType<ScreenControllerProvider<T>>();
    return provider?.controller;
  }
}

class ScreenControllerProvider<T> extends InheritedWidget {
  final T controller;

  const ScreenControllerProvider({
    required this.controller,
    required super.child,
    super.key,
  });

  @override
  bool updateShouldNotify(ScreenControllerProvider oldWidget) {
    return controller != oldWidget.controller;
  }
}
