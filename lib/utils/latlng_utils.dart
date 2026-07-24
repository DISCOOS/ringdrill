import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/views/map_view.dart';

/// True when both lat and lon are finite (no NaN, no infinity). flutter_map
/// and latlong2 throw `FormatException("LatLng is not finite: ...")` the
/// moment a non-finite point reaches projection, so every extension here
/// filters its input through this gate before touching coordinates.
bool _isFiniteLatLng(LatLng p) => p.latitude.isFinite && p.longitude.isFinite;

/// Public predicate for callers that build [MapMarkerSpec]s outside the
/// [StationLocationX.toMarkerSpecs] convenience (RolePlay markers in
/// `stations_view.dart`, per-station markers in `coordinator_screen.dart`,
/// mini-maps that take a single [LatLng]). Returns true when [p] is non-null
/// and both lat/lon are finite. Use as `if (!p.isFiniteOrNull) continue;`
/// or `.where((m) => m.position.isFiniteOrNull)`.
///
/// A single NaN point poisons the entire [MarkerLayer] build pass — see the
/// crash bundle around commit 5e7cff0 where five Sentry issues turned out to
/// be the same cascade. [MapView] also has a last-line defence, but filtering
/// at the producer keeps the offending entity out of `clusterMarkers.length`
/// counts and search-result lists.
extension LatLngFiniteX on LatLng? {
  bool get isFiniteOrNull {
    final p = this;
    return p != null && _isFiniteLatLng(p);
  }
}

/// A [CameraFit] that computes zoom exactly like flutter_map's own
/// [CameraFit.bounds] (fitting [bounds] into [padding]-reduced container
/// space — real overlay clearance, the FAB command stack, a marker's own
/// label footprint, is still honoured, so nothing clips or gets covered),
/// but always centres the camera on the caller-supplied [center] instead
/// of deriving it from [bounds] plus the padding's own left/right and
/// top/bottom *difference*.
///
/// flutter_map's built-in fits couple those two concerns: asymmetric
/// padding — most commonly a bottom-right FAB command column with no
/// equivalent reserve on top — shifts not just how much room is reserved,
/// but where the fitted content's centre lands on screen. A larger bottom
/// reserve pulls the projected centre up, which (since the *camera*
/// centre is what renders at the exact middle of the full, un-padded
/// viewport) pushes the visible marker cluster toward the top of the
/// screen — reported repeatedly this session even after [centroidFit]'s
/// own symmetric-bounds construction (which only ever fixed the
/// *bounding-box-midpoint-vs-centroid* drift, a different, independent
/// source of bias). This class removes the padding-offset source
/// entirely by never applying it to the centre at all.
///
/// Only handles the non-rotated case — this app never enables map
/// rotation ([MapConfig.interactive]/[MapConfig.static] omit
/// [InteractiveFlag.rotate] and its variants), so [MapCamera.rotation] is
/// always 0 in practice; a rotated camera would need the same rotate/
/// derotate dance flutter_map's own `FitBounds.fit` does.
///
/// [bounds] must have a positive extent (guaranteed by every caller here —
/// [centroidFit] already returns null for degenerate, zero-extent input).
///
/// [markerAnchorHeight] corrects for a second, independent source of
/// visual off-centring: every marker is rendered `Alignment.topCenter`
/// with its *bottom* edge pinned to its geographic point
/// (`_MapViewState._buildMarker`), so its icon/label box only ever extends
/// *upward* from the point, never symmetrically around it. Centring the
/// camera on the raw point centroid — even with zero padding bias — still
/// leaves the rendered *marker graphics* looking shifted up: each marker's
/// own visual centre sits `markerAnchorHeight / 2` above its point, so the
/// average visual centre of the whole group sits that same half-height
/// above the point centroid. [markerAnchorHeight] is the marker's real
/// rendered pixel *screen* height — already scaled by [MapConfig
/// .markerScaleFor] the same way [MapConfig.fitPadding]'s own footprint
/// figure is — this class converts that fixed pixel quantity to world
/// coordinates itself, at the zoom it just computed, so callers never
/// need to guess a zoom level up front. Zero (the default) skips the
/// correction entirely.
@immutable
class _UnbiasedBoundsFit extends CameraFit {
  const _UnbiasedBoundsFit({
    required this.bounds,
    required this.center,
    this.padding = EdgeInsets.zero,
    this.maxZoom,
    this.markerAnchorHeight = 0,
  });

  final LatLngBounds bounds;
  final LatLng center;
  final EdgeInsets padding;
  final double? maxZoom;
  final double markerAnchorHeight;

  @override
  MapCamera fit(MapCamera camera) {
    // Mirrors FitBounds._getBoundsZoom: shrink the container by the
    // padding, compare to the bounds' own projected size, derive zoom
    // from whichever axis is tighter.
    final paddingSize = Offset(
      padding.left + padding.right,
      padding.top + padding.bottom,
    );
    var available = camera.nonRotatedSize - paddingSize as Size;
    available = Size(
      math.max(0, available.width),
      math.max(0, available.height),
    );
    final boundsSize = Rect.fromPoints(
      camera.projectAtZoom(bounds.southEast, camera.zoom),
      camera.projectAtZoom(bounds.northWest, camera.zoom),
    ).size;

    final scale = math.min(
      available.width / math.max(boundsSize.width, 1e-9),
      available.height / math.max(boundsSize.height, 1e-9),
    );
    var newZoom = camera.getScaleZoom(scale);

    final minClamp = camera.minZoom ?? 0;
    final maxClamp = math.min(
      camera.maxZoom ?? double.infinity,
      maxZoom ?? double.infinity,
    );
    newZoom = newZoom.clamp(minClamp, maxClamp);

    // The whole point: centre on the true, caller-supplied point — never
    // the padding-shifted projection FitBounds/FitCoordinates would use.
    // markerAnchorHeight then nudges that centre north (screen-up) by half
    // a marker's rendered height, at the zoom just computed — see the
    // class doc for why: a marker's own box only extends upward from its
    // point, so the group's true *visual* centre sits that far above the
    // raw point centroid.
    LatLng adjustedCenter = center;
    if (markerAnchorHeight != 0) {
      final projected = camera.projectAtZoom(center, newZoom);
      final shifted = Offset(
        projected.dx,
        projected.dy - markerAnchorHeight / 2,
      );
      adjustedCenter = camera.unprojectAtZoom(shifted, newZoom);
    }

    return camera.withPosition(center: adjustedCenter, zoom: newZoom);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _UnbiasedBoundsFit &&
          bounds == other.bounds &&
          center == other.center &&
          padding == other.padding &&
          maxZoom == other.maxZoom &&
          markerAnchorHeight == other.markerAnchorHeight;

  @override
  int get hashCode =>
      Object.hash(bounds, center, padding, maxZoom, markerAnchorHeight);
}

extension LatlngListX on Iterable<LatLng> {
  /// Same as the iterable, but with any non-finite [LatLng] removed. Used
  /// to keep NaN coordinates from poisoning [average]/[centroidFit].
  /// Filters defensively rather than at the source so a single bad row in
  /// storage cannot prevent the rest of the map from rendering.
  Iterable<LatLng> get _finite => where(_isFiniteLatLng);

  LatLng average([LatLng? initialCenter]) {
    final pts = _finite.toList(growable: false);
    if (pts.isEmpty) return initialCenter ?? MapConfig.initialCenter;

    double sumLat = 0.0;
    double sumLng = 0.0;

    for (var coordinate in pts) {
      sumLat += coordinate.latitude;
      sumLng += coordinate.longitude;
    }

    double averageLat = sumLat / pts.length;
    double averageLng = sumLng / pts.length;

    return LatLng(averageLat, averageLng);
  }

  /// CameraFit that keeps the *centroid* (arithmetic mean of all points)
  /// at the exact centre of the viewport, while still including every
  /// point. flutter_map's [CameraFit.coordinates] centres on the
  /// bounding-box midpoint instead, which drifts toward outliers when
  /// the points are unevenly distributed. We build symmetric bounds
  /// around the centroid with the largest lat/lng delta, so all points
  /// stay visible *and* the centroid is dead centre.
  ///
  /// Always returns a usable fit — 0, 1 or many points are the same
  /// computation, not three different code paths. Zero points centres on
  /// [fallbackCenter] (or [MapConfig.initialCenter]); one point, or several
  /// that happen to coincide, yields a zero-extent bounds box, which
  /// [_UnbiasedBoundsFit]'s own scale math floors at a tiny epsilon —
  /// producing an enormous scale that immediately clamps down to [maxZoom]
  /// — so "nothing to fit, just frame this point" falls out of the same
  /// bounds-fit formula instead of needing its own branch. Callers used to
  /// each re-derive their own 0/1/2+ handling around a `null` return here;
  /// that duplicated, inconsistently-thresholded (`< 2` in some places,
  /// separate `isEmpty`/`length == 1` branches in others) logic is gone.
  ///
  /// [markerAnchorHeight] additionally corrects for the *rendered marker
  /// graphics'* own centre, not just the raw points — see
  /// [_UnbiasedBoundsFit]'s doc for the full reasoning. Pass the same
  /// scaled pixel footprint [MapConfig.fitPadding] reserves for a
  /// marker's own box; 0 (the default) skips the correction.
  CameraFit centroidFit([
    EdgeInsets padding = const EdgeInsets.all(72),
    double? maxZoom,
    double markerAnchorHeight = 0,
    LatLng? fallbackCenter,
  ]) {
    final pts = _finite.toList(growable: false);
    final centroid = pts.average(fallbackCenter);
    double maxLatDelta = 0;
    double maxLngDelta = 0;
    for (final p in pts) {
      maxLatDelta = math.max(
        maxLatDelta,
        (p.latitude - centroid.latitude).abs(),
      );
      maxLngDelta = math.max(
        maxLngDelta,
        (p.longitude - centroid.longitude).abs(),
      );
    }

    final bounds = LatLngBounds(
      LatLng(centroid.latitude - maxLatDelta, centroid.longitude - maxLngDelta),
      LatLng(centroid.latitude + maxLatDelta, centroid.longitude + maxLngDelta),
    );
    // _UnbiasedBoundsFit, not CameraFit.bounds: the bounds above are
    // already symmetric around centroid, but flutter_map's own FitBounds
    // still shifts the *rendered* centre away from centroid by the
    // padding's own left/right and top/bottom difference (e.g. a
    // bottom-only FAB reserve pushes the visible cluster toward the top
    // of the screen). Centre explicitly on centroid instead, so the only
    // thing padding affects here is zoom, never position.
    return _UnbiasedBoundsFit(
      bounds: bounds,
      center: centroid,
      padding: padding,
      maxZoom: maxZoom,
      markerAnchorHeight: markerAnchorHeight,
    );
  }
}

extension StationLocationX on Iterable<StationLocation> {
  LatLng average([LatLng? initialCenter]) {
    return map((e) => e.$3).average(initialCenter);
  }

  /// Converts each location to a [MapMarkerSpec] with the standard green
  /// station icon. Optional [clusterGroup] and [onTap] factory are forwarded.
  /// Locations whose point is not finite are dropped: a NaN point would
  /// throw on the next projection pass and take the whole map with it.
  ///
  /// Locations whose id is in [activeIds] are rendered in [activeColor]
  /// (falling back to [color] when null) and flagged
  /// [MapMarkerSpec.highlighted] so their cluster reads as live too. The
  /// default keeps every station the original green.
  List<MapMarkerSpec<(String, int)>> toMarkerSpecs({
    Object? clusterGroup,
    void Function((String, int) id)? onTap,
    Set<(String, int)> activeIds = const <(String, int)>{},
    Color color = Colors.green,
    Color? activeColor,
  }) => where((m) => _isFiniteLatLng(m.$3)).map((m) {
    final isActive = activeIds.contains(m.$1);
    return MapMarkerSpec<(String, int)>(
      id: m.$1,
      label: m.$2,
      shortLabel: m.$4,
      point: m.$3,
      child: Icon(
        Icons.place,
        color: isActive ? (activeColor ?? color) : color,
        size: 32,
      ),
      clusterGroup: clusterGroup,
      highlighted: isActive,
      onTap: onTap == null ? null : () => onTap(m.$1),
    );
  }).toList();
}
