import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

/// A handle on one map's camera, for widgets rendered *beside* that map rather
/// than inside it — a `MapLegend` under a `PositionCardShell`'s thumbnail is a
/// sibling of the `MapView`, so it has no other way to reach it.
///
/// The link carries the map's *focus operation*, not its `MapController`, on
/// purpose. Framing a set of points well is `MapView`'s own knowledge: its real
/// laid-out viewport (which is not the window's size in a sheet, a side pane or
/// a thumbnail), which overlay commands it draws, and its markers' rendered
/// label footprint — every input `MapConfig.fitPadding` takes. A sibling holding
/// a raw controller would have to re-derive all of that and would drift from it.
///
/// It also keeps the coupling loose in both directions: a legend renders fine
/// with no map attached (its entries are simply not tappable), and a map renders
/// fine with no scope above it.
class MapCameraLink {
  void Function(List<LatLng> points)? _focus;

  /// Whether a map has attached itself. False both before the map's element
  /// mounts and for a scope that happens to have no map under it.
  bool get isAttached => _focus != null;

  /// Called by the map. Last one wins — a scope is expected to have exactly one
  /// map under it, and a rebuild that swaps the map for another should leave the
  /// newest attached.
  void attach(void Function(List<LatLng> points) focus) => _focus = focus;

  /// Called by the map on dispose. Guarded on identity so a detach arriving
  /// after another map already attached (dispose order is not attach order)
  /// cannot clear the live one.
  void detach(void Function(List<LatLng> points) focus) {
    if (_focus == focus) _focus = null;
  }

  /// Move the attached map so [points] are in view: centred at the current zoom
  /// for a single point, fitted for several.
  ///
  /// A no-op when nothing is attached, which is why a caller can wire this up
  /// without knowing whether the surface it sits on actually has a map.
  void focusOn(List<LatLng> points) {
    if (points.isEmpty) return;
    _focus?.call(points);
  }
}

/// Publishes a [MapCameraLink] to a subtree holding both a map and the widgets
/// that drive it. Provided by `PositionCardShell` around its thumbnail and
/// legend slots; any other surface that composes a map with a sibling legend can
/// do the same.
class MapCameraScope extends InheritedWidget {
  const MapCameraScope({super.key, required this.link, required super.child});

  final MapCameraLink link;

  /// Null when there is no scope above [context] — the caller is then on a
  /// surface with no map to drive, and should render its non-interactive form.
  static MapCameraLink? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MapCameraScope>()?.link;

  @override
  bool updateShouldNotify(MapCameraScope oldWidget) => link != oldWidget.link;
}
