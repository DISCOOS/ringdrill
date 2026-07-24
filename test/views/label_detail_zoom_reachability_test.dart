import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';

/// Regression guard for a bug that has recurred multiple times: a marker's
/// full-label threshold ([MapConfig.labelDetailZoomFor]) must never sit
/// above the zoom ceiling any auto-fit is allowed to reach
/// ([MapConfig.defaultAutoFitMaxZoom]), or that size class's full label can
/// never appear via any auto-fit/"centre" tap — only via a manual pinch
/// past where any built-in view would ever land. Previously true for
/// compact (18 > 16.5), which read as "labels only switch to full text at
/// an unreasonably tight zoom" on phones while medium/expanded looked fine.
void main() {
  test(
    'labelDetailZoomFor never exceeds defaultAutoFitMaxZoom, for every '
    'WindowSizeClass',
    () {
      for (final sizeClass in WindowSizeClass.values) {
        expect(
          MapConfig.labelDetailZoomFor(sizeClass),
          lessThanOrEqualTo(MapConfig.defaultAutoFitMaxZoom),
          reason: '$sizeClass\'s full-label threshold must be reachable '
              'by an auto-fit, which never zooms past defaultAutoFitMaxZoom',
        );
      }
    },
  );
}
