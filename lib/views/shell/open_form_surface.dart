import 'package:flutter/material.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';

Future<T?> openFormSurface<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  if (WindowSizeClass.of(context).hasMasterDetail) {
    return showRingdrillFormDialog<T>(context: context, builder: builder);
  }
  return Navigator.of(
    context,
  ).push<T>(MaterialPageRoute(builder: (_) => builder(context)));
}
