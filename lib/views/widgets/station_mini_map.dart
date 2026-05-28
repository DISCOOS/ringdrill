import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';
import 'package:ringdrill/views/widgets/station_code_badge.dart';

/// Static preview of a single station's position. Tapping the preview
/// opens a modal bottom sheet with the interactive variant centred on
/// the same point. Embed this anywhere a station is rendered to get the
/// "tap mini-map → bottom sheet" interaction for free.
class StationMiniMap extends StatelessWidget {
  const StationMiniMap({
    super.key,
    required this.exercise,
    required this.station,
    this.height = 140,
  });

  final Exercise exercise;
  final Station station;
  final double height;

  @override
  Widget build(BuildContext context) {
    final position = station.position;
    if (position == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      // GestureDetector outside, IgnorePointer inside: the wrapper
      // claims all taps within the mini-map bounds, and the
      // IgnorePointer prevents FlutterMap's internal marker and map
      // gestures from competing in the gesture arena. Without that
      // arena suppression, marker GestureDetectors inside MapView win
      // the tap before our outer handler fires, which is why an
      // InkWell-overlay-only approach was failing here.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openStationMapSheet(context, exercise, station),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: IgnorePointer(
            child: MapView(
              layers: MapConfig.layers,
              withToggle: false,
              withClustering: false,
              initialZoom: 15,
              initialCenter: position,
              markers: [
                MapMarkerSpec(
                  id: 0,
                  label: station.name,
                  point: position,
                  child: const Icon(Icons.place, color: Colors.green, size: 32),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the interactive single-station map in a modal bottom sheet.
/// Exposed as a top-level function so other surfaces (e.g. a future
/// list row that does not embed [StationMiniMap]) can trigger the same
/// interaction.
Future<void> openStationMapSheet(
  BuildContext context,
  Exercise exercise,
  Station station,
) {
  final position = station.position;
  if (position == null) {
    return Future.value();
  }
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
              child: MapView(
                layers: MapConfig.layers,
                withZoom: true,
                withCenter: true,
                withToggle: true,
                withClustering: false,
                initialZoom: 16,
                initialCenter: position,
                interactionFlags: MapConfig.interactive,
                markers: [
                  MapMarkerSpec(
                    id: 0,
                    label: station.name,
                    point: position,
                    child: const Icon(
                      Icons.place,
                      color: Colors.green,
                      size: 32,
                    ),
                  ),
                ],
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
    final theme = Theme.of(context);
    // Mirror the leading badge from the Stations list rows so the sheet
    // header reads as "the same station, viewed bigger". The exercise
    // number is the 1-based position in the unfiltered exercises list;
    // fall back to just the station index if the lookup fails.
    final service = ProgramService();
    final exercises = service.loadExercises();
    final exerciseIndex = exercises.indexWhere((e) => e.uuid == exercise.uuid);
    final code = exerciseIndex < 0
        ? '${station.index + 1}'
        : '${exerciseIndex + 1}.${station.index + 1}';
    // Mirror the Stations-tab badge: tertiary swatch when at least one
    // RolePlay ("markør") points at this station, so the map sheet reads
    // the same as the list row it was opened from.
    final hasRoles = service.loadRolePlays().any(
      (r) => r.exerciseUuid == exercise.uuid && r.stationIndex == station.index,
    );
    // Use a real AppBar so the header picks up `AppBarTheme` (brandDeep
    // background, white foreground, elevation) and reads identically to
    // the AppBar atop every viewer-sheet body in the app — the bar that
    // sits inside StationExerciseScreen, RolePlayScreen and so on. The
    // custom Padding/Row this replaced inherited the action sheet's
    // light surface color and looked out of place.
    final fg = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimary;
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 72,
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: StationCodeBadge(code: code, hasRoles: hasRoles),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            station.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            exercise.name,
            style: theme.textTheme.bodySmall?.copyWith(
              color: fg.withValues(alpha: 0.75),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
