import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/numbering.dart' show StationNumberFormat;
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/shell/master_detail_leading.dart';
import 'package:ringdrill/views/widgets/location_kind_style.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';

/// The effective plan-variable map (ADR-0046) at [station]'s scope: the
/// active plan's declared values overlaid by [exercise]'s overrides, then
/// [station]'s. Empty when there is no active plan.
Map<String, String> _stationOverrides(Exercise exercise, Station station) {
  final plan = PlanService().activePlan;
  if (plan == null) return const {};
  return effectivePlanVariables(plan, exercise: exercise, station: station);
}

/// The app-wide station-position-marker numbering convention, computed
/// once here so every map surface that plots a station's own position
/// agrees: [shortLabel] is the plan number alone ("1.1"/"1a", matching
/// [StationNumberBadge] and `PlanService.getLocations`), [rawLabel] is
/// that number joined with the station's own *unresolved* name ("1.1
/// Turgåer") — the full text a pin shows once zoomed in past
/// [MapConfig.labelDetailZoomFor].
///
/// Deliberately does not resolve plan-variable tokens in [rawLabel] itself
/// — callers substitute with whichever mechanism fits their context
/// ([substitutePlanVariables] with no ambient widget tree,
/// [resolveScopedField]/[resolveModelField] with one), the same split
/// every other caller in this codebase already makes.
({String rawLabel, String shortLabel}) stationNumbering(
  Exercise exercise,
  Station station,
) {
  final service = PlanService();
  final format =
      service.activePlan?.stationNumberFormat ?? StationNumberFormat.dotted;
  final exNum =
      service.loadExercises().indexWhere((e) => e.uuid == exercise.uuid) + 1;
  final exerciseNumber = exNum < 1 ? 1 : exNum;
  return (
    rawLabel: station.numberAndName(format, exerciseNumber: exerciseNumber),
    shortLabel: station.numberLabel(format, exerciseNumber: exerciseNumber),
  );
}

/// One marker for a scenario [Location] (id [id], styled by its
/// [LocationKind] — ADR-0020/DESIGN-009) — the shared shape every map
/// surface that plots a station's scenario locations (Bosted, LKP, ...)
/// uses, so an icon/size/label tweak lands everywhere at once. No
/// [MapMarkerSpec.shortLabel]: locations are few enough per station, and
/// don't need a zoom-tiered short form the way a station's own number does.
///
/// [location.position] must be non-null — callers already filter for that
/// (a `for` loop with `if (point == null) continue`, matching the
/// `Iterable<LatLng>`-poisoning guard the rest of this codebase uses).
MapMarkerSpec<int> locationMarker(
  Location location, {
  required int id,
  double size = 28,
}) {
  final point = location.position;
  assert(point != null, 'locationMarker requires a positioned Location');
  return MapMarkerSpec(
    id: id,
    label: location.label.isEmpty ? location.slug : location.label,
    point: point!,
    child: Icon(location.kind.icon, color: location.kind.color, size: size),
  );
}

/// Markers for [station]'s own administrative position (id `0`, green
/// `Icons.place`, matching every other station marker in the app) plus its
/// scenario `locations` that carry a coordinate (id `index + 1`, via
/// [locationMarker]), visually distinct from the administrative marker. A
/// person's `home` is not iterated separately: it always names a
/// `Location` already in `station.locations`, so it is covered by the
/// same loop.
///
/// A plain top-level function (not private) so tests can assert on the
/// built [MapMarkerSpec] list directly — a marker-spec unit test, rather
/// than pumping a real `flutter_map` widget tree, which nothing else in
/// this codebase does yet.
@visibleForTesting
List<MapMarkerSpec<int>> stationMarkers(Exercise exercise, Station station) {
  final markers = <MapMarkerSpec<int>>[];
  final position = station.position;
  if (position != null) {
    final numbering = stationNumbering(exercise, station);
    markers.add(
      MapMarkerSpec(
        id: 0,
        label: substitutePlanVariables(
          numbering.rawLabel,
          _stationOverrides(exercise, station),
        ),
        shortLabel: numbering.shortLabel,
        point: position,
        child: const Icon(Icons.place, color: Colors.green, size: 32),
      ),
    );
  }
  for (var i = 0; i < station.locations.length; i++) {
    final location = station.locations[i];
    if (location.position == null) continue;
    markers.add(locationMarker(location, id: i + 1));
  }
  return markers;
}

/// The shared "big" station map config — every marker, fully interactive
/// (pan/zoom/tap), used both for the medium/expanded direct embed
/// ([StationMiniMap]'s own `withFullscreen: true` case) and the compact
/// sheet's body ([openStationMapSheet]). Centralised so the two never
/// drift apart the way a hand-duplicated config eventually does.
MapView<int> _interactiveStationMap({
  Key? key,
  required Exercise exercise,
  required Station station,
  required List<MapMarkerSpec<int>> markers,
  required LatLng position,
  bool withFullscreen = false,
}) => MapView<int>(
  key: key,
  layers: MapConfig.layers,
  withZoom: true,
  withCenter: true,
  withToggle: true,
  withClustering: false,
  initialCenter: position,
  // No initialZoom/initialFit: MapView computes its own defaults from
  // `markers` (the station plus any scenario locations) using its own
  // real render size, instead of always centring on the station's own
  // point alone — so a station with off-site locations doesn't preview
  // them out of frame, and a station with none zooms tight enough to show
  // its full name immediately.
  interactionFlags: MapConfig.interactive,
  markers: markers,
  withFullscreen: withFullscreen,
  fullscreenHeader: withFullscreen
      ? _MapSheetHeader(station: station, exercise: exercise)
      : null,
);

/// A single station's position, embedded anywhere a station is rendered.
/// By default this is a static preview: tapping it opens an interactive
/// variant as a modal bottom sheet ([openStationMapSheet]). Pass
/// [interactive] `true` to render the map directly interactive in place
/// instead — the same pan/zoom/tap/FAB-command experience as
/// `CoordinatorScreen`'s all-stations map — with a built-in "expand to
/// fullscreen" command ([MapView.withFullscreen]) for going bigger still.
///
/// [interactive] is the caller's decision, not something this widget
/// guesses from its own render size: an embed's local width/height can be
/// misleading (e.g. `WideDetailMapSplit`'s fixed-width left column leaves
/// the map pane itself narrower than the *screen's* own breakpoint would
/// suggest), so `StationPositionPanel` forwards its own `fillHeight` —
/// already the caller's considered answer to "do I have room for this" —
/// straight through as `interactive`, rather than this widget re-deriving
/// the same answer from constraints that don't actually tell the whole
/// story. See [MapConfig.minInteractiveHeight] for the height a caller
/// should have available before opting in.
class StationMiniMap extends StatelessWidget {
  const StationMiniMap({
    super.key,
    required this.exercise,
    required this.station,
    this.height = 140,
    this.interactive = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.markers,
  });

  final Exercise exercise;
  final Station station;
  final double height;

  /// Render directly interactive (pan/zoom/tap, own FAB stack) instead of
  /// the default static tap-to-expand preview. See the class doc for why
  /// this is caller-decided rather than self-detected.
  final bool interactive;

  /// Overrides the default administrative-only [stationMarkers] with a
  /// richer scenario set (DESIGN-010's Post viewer: the station's own
  /// position plus its [Location]s, `LocationKind`-styled). Null (the
  /// default) keeps every other call site's existing behaviour.
  final List<MapMarkerSpec<int>>? markers;

  /// Rounds the preview's own corners. `StationPositionPanel` passes a
  /// top-only radius when embedding this as a card's thumbnail — the map
  /// sits flush against the coordinate bar below it, so its bottom
  /// corners must stay square or they'd cut a rounded notch into the
  /// card at that seam, exposing the background behind it.
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final position = station.position;
    if (position == null) {
      return const SizedBox.shrink();
    }
    final markerList = markers ?? stationMarkers(exercise, station);
    final content = interactive
        ? ClipRRect(
            borderRadius: borderRadius,
            child: _interactiveStationMap(
              exercise: exercise,
              station: station,
              markers: markerList,
              position: position,
              withFullscreen: true,
            ),
          )
        // GestureDetector outside, IgnorePointer inside: the wrapper
        // claims all taps within the mini-map bounds, and the
        // IgnorePointer prevents FlutterMap's internal marker and map
        // gestures from competing in the gesture arena. Without that
        // arena suppression, marker GestureDetectors inside MapView win
        // the tap before our outer handler fires, which is why an
        // InkWell-overlay-only approach was failing here.
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openStationMapSheet(context, exercise, station),
            child: ClipRRect(
              borderRadius: borderRadius,
              child: IgnorePointer(
                child: MapView(
                  layers: MapConfig.layers,
                  withToggle: false,
                  withClustering: false,
                  initialCenter: position,
                  markers: markerList,
                ),
              ),
            ),
          );
    return SizedBox(height: height, width: double.infinity, child: content);
  }
}

/// Opens the interactive single-station map as a modal bottom sheet —
/// compact windows only; medium/expanded windows show the same map
/// directly interactive in place instead (see [StationMiniMap]). Exposed
/// as a top-level function so other surfaces (e.g. a future list row that
/// does not embed [StationMiniMap]) can trigger the same interaction.
Future<void> openStationMapSheet(
  BuildContext context,
  Exercise exercise,
  Station station,
) {
  final position = station.position;
  if (position == null) {
    return Future.value();
  }
  final markers = stationMarkers(exercise, station);

  return showRingdrillActionSheet<void>(
    context: context,
    builder: (sheetContext) {
      // The shared action-sheet shell is wrap-content, so this map sheet
      // needs an explicit finite height before the Expanded MapView lays out.
      return SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.88,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            _MapSheetHeader(station: station, exercise: exercise),
            Expanded(
              child: _interactiveStationMap(
                exercise: exercise,
                station: station,
                markers: markers,
                position: position,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _MapSheetHeader extends StatelessWidget implements PreferredSizeWidget {
  const _MapSheetHeader({required this.station, required this.exercise});

  final Station station;
  final Exercise exercise;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    // Mirrors StationScreen's own AppBar exactly (station_screen.dart)
    // — same MasterDetailLeading close-X, same toolbarHeight/SheetTitle
    // shape, the formatted post number folded into the primary text rather
    // than a separate badge widget — so the map sheet reads as "the same
    // station header, viewed bigger" instead of inventing its own chrome.
    // This map sheet is always a modal (dialog or bottom sheet), never an
    // inline MasterDetailPane body, so `onClose` always just pops it.
    final service = PlanService();
    final plan = service.activePlan;
    final exerciseNumber =
        service.loadExercises().indexWhere((e) => e.uuid == exercise.uuid) + 1;
    return AppBar(
      leading: MasterDetailLeading(onClose: () => Navigator.of(context).pop()),
      toolbarHeight: 72,
      title: SheetTitle(
        primary: station.numberAndName(
          plan?.stationNumberFormat ?? StationNumberFormat.dotted,
          exerciseNumber: exerciseNumber < 1 ? 1 : exerciseNumber,
        ),
        secondary: exercise.name,
        primaryOverrides: _stationOverrides(exercise, station),
        secondaryOverrides: plan == null
            ? const {}
            : effectivePlanVariables(plan, exercise: exercise),
      ),
    );
  }
}
