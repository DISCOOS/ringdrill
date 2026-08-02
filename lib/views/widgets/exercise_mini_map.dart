import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/exercise_service.dart';
import 'package:ringdrill/services/plan_service.dart';
import 'package:ringdrill/theme.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/round_occupancy.dart';
import 'package:ringdrill/views/drill_player/drill_player_scope.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/shell/master_detail_leading.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';
import 'package:ringdrill/views/widgets/resolve_scoped_field.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:ringdrill/views/widgets/sheet_title.dart';
import 'package:ringdrill/views/widgets/station_mini_map.dart'
    show stationNumbering;

/// Every one of [exercise]'s positioned stations, as the app-wide
/// station-marker convention: number-only [MapMarkerSpec.shortLabel] at
/// overview zooms, the full resolved "number name" as [MapMarkerSpec.label]
/// once zoomed in past [MapConfig.labelDetailZoomFor]. Tapping a pin opens
/// its station detail sheet — the one interaction every all-stations map
/// surface in the app shares ([CoordinatorScreen]'s inline map, this
/// widget's own sheet), so it lives here rather than being reimplemented
/// per caller.
///
/// [liveEvent] highlights whichever station the current round has a team
/// at, in [RingDrillColors.brandAccent] — matching the coordinator's own
/// station list. Null (no running exercise, or a context with no concept
/// of "live") keeps every pin plain green.
List<MapMarkerSpec<int>> exerciseStationMarkers(
  BuildContext context,
  Exercise exercise, {
  ExerciseEvent? liveEvent,
}) {
  final plan = PlanService().activePlan;
  Map<String, String> overridesFor(Station station) => plan == null
      ? const {}
      : effectivePlanVariables(plan, exercise: exercise, station: station);

  final markers = <MapMarkerSpec<int>>[];
  for (
    var stationIndex = 0;
    stationIndex < exercise.stations.length;
    stationIndex++
  ) {
    final station = exercise.stations[stationIndex];
    if (!station.position.isFiniteOrNull) continue;
    final isLive =
        liveEvent != null &&
        liveEvent.isRunning &&
        RoundOccupancy.isActive(exercise, stationIndex, liveEvent.currentRound);
    final numbering = stationNumbering(exercise, station);
    markers.add(
      MapMarkerSpec<int>(
        id: station.index,
        label:
            resolveScopedField(
              context,
              numbering.rawLabel,
              overrides: overridesFor(station),
            ) ??
            numbering.rawLabel,
        shortLabel: numbering.shortLabel,
        point: station.position!,
        highlighted: isLive,
        child: Icon(
          Icons.place,
          color: isLive ? RingDrillColors.brandAccent : Colors.green,
          size: 32,
        ),
        onTap: () => unawaited(
          openContextTarget(
            context,
            StationSheetTarget(
              exerciseUuid: exercise.uuid,
              stationIndex: station.index,
            ),
          ),
        ),
      ),
    );
  }
  return markers;
}

/// The shared "big" exercise map config — every station marker, fully
/// interactive (pan/zoom/tap), used both for the medium/expanded direct
/// embed ([ExerciseMiniMap]'s own `withFullscreen: true` case) and the
/// compact sheet's body ([openExerciseMapSheet]). Centralised so the two
/// never drift apart the way a hand-duplicated config eventually does.
MapView<int> _interactiveExerciseMap({
  Key? key,
  required Exercise exercise,
  required List<MapMarkerSpec<int>> markers,
  bool withFullscreen = false,
}) => MapView<int>(
  key: key,
  layers: MapConfig.layers,
  withZoom: true,
  withCenter: true,
  withToggle: true,
  withClustering: false,
  // No initialZoom/initialFit: MapView computes its own defaults from
  // `markers`, using its own real render size.
  interactionFlags: MapConfig.interactive,
  markers: markers,
  withFullscreen: withFullscreen,
  fullscreenHeader: withFullscreen
      ? ExerciseMapSheetHeader(exercise: exercise)
      : null,
);

/// Every station marker in an exercise, embedded wherever an exercise
/// overview map is shown. By default this is a static preview (the 8px
/// corner radius, [IgnorePointer] gesture suppression, and marker framing
/// every embedded map in the app shares): tapping it opens an interactive
/// variant as a modal bottom sheet (`openExerciseMapSheet`). Pass
/// [interactive] `true` to render the map directly interactive in place
/// instead — the same pan/zoom/tap/FAB-command experience as
/// `CoordinatorScreen`'s all-stations map — with a built-in "expand to
/// fullscreen" command ([MapView.withFullscreen]) for going bigger still.
/// This is the multi-marker sibling of [StationMiniMap] (single station)
/// and [RoleMiniMap] (single role); [interactive] is caller-decided the
/// same way — see [StationMiniMap.interactive]'s doc.
///
/// Renders nothing when [markers] is empty, so callers can drop it into a
/// column without guarding on the marker count themselves.
class ExerciseMiniMap extends StatelessWidget {
  const ExerciseMiniMap({
    super.key,
    required this.exercise,
    required this.markers,
    this.liveEvent,
    this.height = 200,
    this.interactive = false,
    this.mapKey,
  });

  /// The exercise these [markers] belong to — used both to open the
  /// bigger interactive map on tap (static mode) and to build the richer,
  /// tappable marker set the [interactive] embed needs directly
  /// ([exerciseStationMarkers] rather than reusing [markers], which are
  /// plain previews with no `onTap`).
  final Exercise exercise;

  /// Station locations to plot. Typically
  /// `exercise.getNumberedLocations(exerciseNumber:, format:)`, so each
  /// pin carries the app-wide station-marker number chip (via its
  /// `shortLabel`) — showing the number at overview zooms keeps close-together
  /// stations from overlapping unreadably the way plain names would.
  final List<StationLocation> markers;

  /// Forwarded to the opened sheet's marker set, so a live round's
  /// active station is highlighted there the same way the coordinator's
  /// own inline map shows it. Null in contexts with no running-exercise
  /// concept (e.g. the Øvelser tab's exercise list).
  final ExerciseEvent? liveEvent;

  /// Fixed preview height. Defaults to the 200px used by the exercise
  /// card; pass a smaller value for tighter embeddings.
  final double height;

  /// Render directly interactive (pan/zoom/tap, own FAB stack) instead of
  /// the default static tap-to-expand preview. See [StationMiniMap.interactive].
  final bool interactive;

  /// Optional key forwarded to the embedded [MapView]. Use a stable
  /// [ValueKey] when several previews share a parent so each keeps its
  /// own camera state instead of recycling a sibling's.
  final Key? mapKey;

  @override
  Widget build(BuildContext context) {
    if (markers.isEmpty) return const SizedBox.shrink();
    final Widget content;
    if (interactive) {
      final richMarkers = exerciseStationMarkers(
        context,
        exercise,
        liveEvent: liveEvent,
      );
      if (richMarkers.isEmpty) return const SizedBox.shrink();
      content = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _interactiveExerciseMap(
          key: mapKey,
          exercise: exercise,
          markers: richMarkers,
          withFullscreen: true,
        ),
      );
    } else {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            openExerciseMapSheet(context, exercise, liveEvent: liveEvent),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: IgnorePointer(
            child: MapView<(String, int)>(
              key: mapKey,
              layers: MapConfig.layers,
              withToggle: false,
              withClustering: false,
              markers: markers.toMarkerSpecs(),
              // No initialFit: MapView computes its own default fit
              // from `markers`, using its own real render size.
              initialCenter: markers.average(),
            ),
          ),
        ),
      );
    }
    return SizedBox(height: height, width: double.infinity, child: content);
  }
}

/// Opens the interactive all-stations map for [exercise] as a modal bottom
/// sheet — compact windows only; medium/expanded windows show the same
/// map directly interactive in place instead (see [ExerciseMiniMap]).
/// Mirrors `openStationMapSheet`/`openRoleMapSheet`. Returns immediately,
/// doing nothing, when no station has a position.
Future<void> openExerciseMapSheet(
  BuildContext context,
  Exercise exercise, {
  ExerciseEvent? liveEvent,
}) {
  final markers = exerciseStationMarkers(
    context,
    exercise,
    liveEvent: liveEvent,
  );
  if (markers.isEmpty) return Future.value();

  return showRingdrillActionSheet<void>(
    context: context,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.88,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          ExerciseMapSheetHeader(exercise: exercise),
          Expanded(
            child: _interactiveExerciseMap(
              exercise: exercise,
              markers: markers,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Mirrors `_MapSheetHeader`/`_RoleMapSheetHeader`: the header computes its
/// own exercise number and title from [exercise] alone via
/// [PlanService]. Public (not the private `_ExerciseMapSheetHeader` this
/// started as) — `coordinator_screen.dart`'s inline map needs it too, for
/// its own `MapView.fullscreenHeader`.
class ExerciseMapSheetHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const ExerciseMapSheetHeader({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final plan = PlanService().activePlan;
    final overrides = plan == null
        ? const <String, String>{}
        : effectivePlanVariables(plan, exercise: exercise);
    return AppBar(
      leading: MasterDetailLeading(onClose: () => Navigator.of(context).pop()),
      toolbarHeight: 72,
      title: SheetTitle(
        // Plain exercise.name, matching coordinator_screen.dart's own
        // AppBar title and _MapSheetHeader/_RoleMapSheetHeader's exercise
        // subtitle — no computed number prefix. exercise.name already
        // carries whatever numbering convention the plan uses; prepending
        // one here duplicated it (e.g. "#1 #1 Søk og redning").
        // SheetTitle's own RingDrillText.plain resolves {{var.*}} tokens
        // via primaryOverrides — matching _MapSheetHeader/_RoleMapSheetHeader,
        // neither pre-resolves before handing text to SheetTitle either.
        primary: exercise.name,
        primaryOverrides: overrides,
      ),
    );
  }
}
