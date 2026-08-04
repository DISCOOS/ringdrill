import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/shell/master_detail_leading.dart';
import 'package:ringdrill/views/widgets/location_kind_style.dart';
import 'package:ringdrill/views/widgets/map_legend.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:ringdrill/views/widgets/role_marker.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';
import 'package:ringdrill/views/widgets/station_mini_map.dart'
    show stationNumbering, locationMarker;

/// The [Location] a role's "following" position was copied from
/// (DESIGN-009): the portrayed person's own `locSlug`, resolved against
/// the station's scenario locations. Null when the role is unlinked, the
/// station is null, or no location matches.
Location? rolePersonLocation(RolePlay rolePlay, Station? station) {
  final personRef = rolePlay.personRef;
  if (station == null || personRef == null) return null;
  final person = station.persons.where((p) => p.slug == personRef).firstOrNull;
  final locSlug = person?.locSlug;
  if (locSlug == null) return null;
  return station.locations.where((l) => l.slug == locSlug).firstOrNull;
}

/// The role's own central position (Del B): its own [RolePlay.position] if
/// set, else the portrayed person's location (DESIGN-009's "following"
/// position, copied from the linked [Person.locSlug]). Null when the role
/// has neither — the map is omitted entirely in that case.
LatLng? roleCentralPosition(RolePlay rolePlay, Station? station) =>
    rolePlay.position ?? rolePersonLocation(rolePlay, station)?.position;

/// ~5.5 m of latitude: context pins are only added when they sit at a
/// visibly distinct spot from the central marker and from each other.
bool _samePlace(LatLng a, LatLng b) {
  const eps = 0.00005;
  return (a.latitude - b.latitude).abs() < eps &&
      (a.longitude - b.longitude).abs() < eps;
}

/// Del B's read-only context pins beside a role's central marker — the
/// parent post's position (green place pin, labelled with its formatted
/// number and name) and the portrayed person's location (kind-styled pin) —
/// each only when it sits at a distinct spot (within ~5 m) from the central
/// marker and from each other. Also returns one matching legend entry per
/// pin; a caller rendering a legend prepends its own entry for the central
/// role marker.
///
/// Shared by `RolePlayScreen`'s position panel (the medium/expanded detail
/// surface) and `RolePlayListView`'s expanded tile (the compact list
/// surface) so both form factors show the same map content — the compact
/// tile previously passed no extras, silently dropping the post pin that
/// the detail view showed.
({List<MapMarkerSpec<int>> markers, List<MapLegendEntry> legend})
roleContextMarkers(
  BuildContext context,
  RolePlay rolePlay,
  Station? station, {
  Map<String, String> overrides = const {},
}) {
  final central = roleCentralPosition(rolePlay, station);
  if (central == null) {
    return (markers: const [], legend: const []);
  }
  final markers = <MapMarkerSpec<int>>[];
  final legend = <MapLegendEntry>[];
  bool distinct(LatLng p) =>
      !_samePlace(p, central) && markers.every((m) => !_samePlace(p, m.point));

  final postPosition = station?.position;
  if (station != null && postPosition != null && distinct(postPosition)) {
    // Number-only at overview zooms (the app-wide station-marker
    // convention via stationNumbering), switching to the full number +
    // name once zoomed in close enough to have room for it
    // (MapConfig.labelDetailZoomFor).
    final exercise = PlanService().getExercise(rolePlay.exerciseUuid)!;
    final numbering = stationNumbering(exercise, station);
    final postLabel =
        resolveScopedField(context, numbering.rawLabel, overrides: overrides) ??
        numbering.rawLabel;
    markers.add(
      MapMarkerSpec(
        id: 1,
        label: postLabel,
        shortLabel: numbering.shortLabel,
        point: postPosition,
        child: const Icon(Icons.place, color: Colors.green, size: 32),
      ),
    );
    legend.add(
      MapLegendEntry(
        color: Colors.green,
        label: postLabel,
        points: [postPosition],
      ),
    );
  }

  final personLocation = rolePersonLocation(rolePlay, station);
  final locPosition = personLocation?.position;
  if (personLocation != null && locPosition != null && distinct(locPosition)) {
    final locMarker = locationMarker(personLocation, id: 2, size: 30);
    markers.add(locMarker);
    legend.add(
      MapLegendEntry(
        color: personLocation.kind.color,
        label: locMarker.label,
        points: [locPosition],
      ),
    );
  }
  return (markers: markers, legend: legend);
}

/// The role's own marker: its resolved name at [roleCentralPosition] —
/// resolved via [resolveModelField] when [exercise] is known (handles
/// `{{station.*}}`/`{{exercise.*}}` cross-references in the role's name,
/// like every other imperatively-built marker label in this codebase),
/// falling back to the raw [RolePlay.name] when it is not (a stale
/// roleplay whose parent exercise could not be resolved). Null when there
/// is no central position to plot.
///
/// [id] is generic so this single builder serves both the single-role
/// views in this file (`int`, always `0`) and `stations_view.dart`'s
/// all-exercises map (`(String, int)`, keyed by exercise + roleplay
/// index) — the same marker shape and label-resolution policy either way,
/// rather than each surface reimplementing its own.
MapMarkerSpec<K>? roleMarker<K>(
  BuildContext context,
  RolePlay rolePlay,
  Station? station, {
  required K id,
  Exercise? exercise,
  Map<String, String> overrides = const {},
  Object? clusterGroup,
  VoidCallback? onTap,
}) {
  final position = roleCentralPosition(rolePlay, station);
  if (position == null) return null;
  final label = exercise == null
      ? rolePlay.name
      : resolveModelField(
              context,
              rolePlay.name,
              exercise: exercise,
              station: station,
              roleplay: rolePlay,
              overrides: overrides,
              selfScope: 'roleplay',
            ) ??
            rolePlay.name;
  return MapMarkerSpec(
    id: id,
    label: label,
    point: position,
    child: const RoleMarker(),
    clusterGroup: clusterGroup,
    onTap: onTap,
  );
}

/// The shared "big" role map config — every marker, fully interactive
/// (pan/zoom/tap), used both for the medium/expanded direct embed
/// ([RoleMiniMap]'s own `withFullscreen: true` case) and the compact
/// sheet's body ([openRoleMapSheet]). Centralised so the two never drift
/// apart the way a hand-duplicated config eventually does.
MapView<int> _interactiveRoleMap({
  required Exercise exercise,
  required RolePlay rolePlay,
  required List<MapMarkerSpec<int>> markers,
  required LatLng position,
  Map<String, String> overrides = const {},
  bool withFullscreen = false,
}) => MapView<int>(
  layers: MapConfig.layers,
  withZoom: true,
  withCenter: true,
  withToggle: true,
  initialCenter: position,
  // No initialZoom/initialFit: MapView computes its own defaults from
  // `markers` (the role plus any extraMarkers — parent post, portrayed
  // person) using its own real render size, instead of always centring on
  // the role's own point alone — so an off-site extra marker doesn't
  // preview out of frame, and a role with no extra markers zooms tight
  // enough to show its full name immediately.
  interactionFlags: MapConfig.interactive,
  markers: markers,
  withFullscreen: withFullscreen,
  fullscreenHeader: withFullscreen
      ? _RoleMapSheetHeader(
          exercise: exercise,
          rolePlay: rolePlay,
          overrides: overrides,
        )
      : null,
);

/// A single role's position, embedded anywhere a role is rendered. By
/// default this is a static preview: tapping it opens an interactive
/// variant as a modal bottom sheet ([openRoleMapSheet]). Pass [interactive]
/// `true` to render the map directly interactive in place instead — the
/// same pan/zoom/tap/FAB-command experience as `CoordinatorScreen`'s
/// all-stations map — with a built-in "expand to fullscreen" command
/// ([MapView.withFullscreen]) for going bigger still. Takes the domain
/// objects directly (exercise, roleplay, and the station it's placed at)
/// rather than pre-computed label/subtitle strings, so every number, name
/// and override lives in one place instead of being threaded through each
/// caller.
///
/// [interactive] is the caller's decision, not something this widget
/// guesses from its own render size — see [StationMiniMap]'s doc for why.
/// `RolePositionPanel` forwards its own `fillHeight` straight through.
///
/// Used in both [RolePlayScreen] (detail view) and the [RolePlayListView]
/// expandable tile body.
class RoleMiniMap extends StatelessWidget {
  const RoleMiniMap({
    super.key,
    required this.exercise,
    required this.rolePlay,
    this.station,
    this.height = 200,
    this.interactive = false,
    this.extraMarkers = const [],
    this.overrides = const {},
  });

  final Exercise exercise;
  final RolePlay rolePlay;

  /// The station [rolePlay] is placed at, if any (null for an unassigned
  /// role) — needed both to resolve the person-location fallback in
  /// [roleCentralPosition] and to number the role in the map sheet's header.
  final Station? station;

  final double height;

  /// Render directly interactive (pan/zoom/tap, own FAB stack) instead of
  /// the default static tap-to-expand preview. See [StationMiniMap.interactive].
  final bool interactive;

  /// Additional read-only markers (the parent post's position, the portrayed
  /// person's location) shown alongside this role's own central marker — the
  /// caller only includes ones that sit at a distinct spot. Empty for the
  /// RolePlayListView tile.
  final List<MapMarkerSpec<int>> extraMarkers;

  /// Effective plan-variable overrides (ADR-0046) at this role's scope,
  /// substituted into [RolePlay.name] for the marker's own label and the
  /// map sheet header's title/subtitle.
  final Map<String, String> overrides;

  @override
  Widget build(BuildContext context) {
    final marker = roleMarker<int>(
      context,
      rolePlay,
      station,
      id: 0,
      exercise: exercise,
      overrides: overrides,
    );
    if (marker == null) return const SizedBox.shrink();
    final markers = [marker, ...extraMarkers];
    final content = interactive
        ? _interactiveRoleMap(
            exercise: exercise,
            rolePlay: rolePlay,
            markers: markers,
            position: marker.point,
            overrides: overrides,
            withFullscreen: true,
          )
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openRoleMapSheet(
              context,
              exercise,
              rolePlay,
              station: station,
              extraMarkers: extraMarkers,
              overrides: overrides,
            ),
            child: IgnorePointer(
              child: MapView(
                layers: MapConfig.layers,
                withToggle: false,
                initialCenter: marker.point,
                markers: markers,
              ),
            ),
          );
    return SizedBox(height: height, width: double.infinity, child: content);
  }
}

/// Opens the interactive single-role map as a modal bottom sheet —
/// compact windows only; medium/expanded windows show the same map
/// directly interactive in place instead (see [RoleMiniMap]). Exposed as a
/// top-level function (mirrors `openStationMapSheet` in
/// `station_mini_map.dart`) so callers that don't embed [RoleMiniMap]
/// itself can trigger the same interaction. Returns immediately, doing
/// nothing, when the role has no central position to plot.
Future<void> openRoleMapSheet(
  BuildContext context,
  Exercise exercise,
  RolePlay rolePlay, {
  Station? station,
  List<MapMarkerSpec<int>> extraMarkers = const [],
  Map<String, String> overrides = const {},
}) {
  final marker = roleMarker<int>(
    context,
    rolePlay,
    station,
    id: 0,
    exercise: exercise,
    overrides: overrides,
  );
  if (marker == null) return Future.value();
  final markers = [marker, ...extraMarkers];

  return showRingdrillActionSheet<void>(
    context: context,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.88,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          _RoleMapSheetHeader(
            exercise: exercise,
            rolePlay: rolePlay,
            overrides: overrides,
          ),
          Expanded(
            child: _interactiveRoleMap(
              exercise: exercise,
              rolePlay: rolePlay,
              markers: markers,
              position: marker.point,
              overrides: overrides,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Mirrors `_MapSheetHeader` in `station_mini_map.dart`: the header computes
/// its own numbering and title from the domain objects it's given
/// ([exercise], [rolePlay]) via [PlanService], the same way
/// `_MapSheetHeader` derives a station's number from `exercise`+`station`
/// alone — no pre-formatted label/subtitle string is threaded in from the
/// caller. Same `MasterDetailLeading` close-X, same
/// `toolbarHeight`/`SheetTitle` shape as `RolePlayScreen`'s own AppBar, so
/// the map sheet reads as "the same role header, viewed bigger" instead of
/// inventing its own chrome. This map sheet is always a modal (dialog or
/// bottom sheet), never an inline MasterDetailPane body, so `onClose`
/// always just pops it.
class _RoleMapSheetHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const _RoleMapSheetHeader({
    required this.exercise,
    required this.rolePlay,
    this.overrides = const {},
  });

  final Exercise exercise;
  final RolePlay rolePlay;
  final Map<String, String> overrides;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final service = PlanService();
    final plan = service.activePlan;
    final exerciseNumber = service.getExerciseNumber(exercise.uuid);
    final stationIndex = rolePlay.stationIndex;
    final roleNumber = stationIndex == null
        ? 0
        : service.roleNumberAtStation(rolePlay, stationIndex);
    final roleLabel = rolePlay.numberLabel(
      plan?.stationNumberFormat ?? StationNumberFormat.dotted,
      exerciseNumber: exerciseNumber < 1 ? 1 : exerciseNumber,
      roleNumber: roleNumber,
    );
    return AppBar(
      leading: MasterDetailLeading(onClose: () => Navigator.of(context).pop()),
      toolbarHeight: 72,
      title: SheetTitle(
        primary: '$roleLabel ${rolePlay.name}',
        secondary: exercise.name,
        primaryOverrides: overrides,
        secondaryOverrides: overrides,
      ),
    );
  }
}
