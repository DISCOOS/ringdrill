import 'package:flutter/material.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/views/map_view.dart';
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
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      // FractionallySizedBox with heightFactor 1.0 fills the maximum
      // height the bottom sheet can take, which (with useSafeArea +
      // isScrollControlled) is the screen minus the system insets.
      return FractionallySizedBox(
        heightFactor: 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            _MapSheetHeader(station: station, exercise: exercise),
            const Divider(height: 1),
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
                    child: const Icon(Icons.place, color: Colors.green, size: 32),
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

class _MapSheetHeader extends StatelessWidget {
  const _MapSheetHeader({required this.station, required this.exercise});

  final Station station;
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Mirror the leading badge from the Stations list rows so the sheet
    // header reads as "the same station, viewed bigger". The exercise
    // number is the 1-based position in the unfiltered exercises list;
    // fall back to just the station index if the lookup fails.
    final exercises = ProgramService().loadExercises();
    final exerciseIndex = exercises.indexWhere(
      (e) => e.uuid == exercise.uuid,
    );
    final code = exerciseIndex < 0
        ? '${station.index + 1}'
        : '${exerciseIndex + 1}.${station.index + 1}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          StationCodeBadge(code: code),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  station.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  exercise.name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
