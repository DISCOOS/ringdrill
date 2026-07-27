import 'package:flutter/material.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

/// A [State] whose whole surface can be dismissed: a context sheet, a dialog,
/// or a pushed route.
///
/// Only mix this in where dismissing is actually meaningful. A widget embedded
/// in something that must always show *something* (a master/detail list, an
/// inline card) has no surface of its own to close, and should render a
/// placeholder instead of reaching for [close].
mixin ClosableSurface<W extends StatefulWidget> on State<W> {
  /// Dismisses this surface the same master/detail-aware way its AppBar close
  /// button does: inside the wide shell the context sheet retracts (leaving the
  /// detail pane on its own empty state), otherwise the route is popped.
  ///
  /// Always uses this State's own `context`, never one passed in from a
  /// callback: the `mounted` check guards *this* State, and in compact layout a
  /// context handed in from elsewhere may belong to an already-disposed sheet.
  void close() {
    if (!mounted) return;
    if (MasterDetailScope.maybeOf(context) != null) {
      ContextSheet.of(context).close();
    } else {
      Navigator.pop(context);
    }
  }
}
