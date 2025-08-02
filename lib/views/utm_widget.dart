import 'package:coordinate_converter/coordinate_converter.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class UtmWidget extends StatelessWidget {
  const UtmWidget({
    super.key,
    required this.position,
    this.wrapped = true,
    this.style,
  });

  final LatLng? position;
  final bool wrapped;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final UTMCoordinates? utmCoords =
        position != null
            ? UTMCoordinates.fromDD(
              DDCoordinates(
                latitude: position!.latitude,
                longitude: position!.longitude,
              ),
            )
            : null;
    return SelectableText(
      style: style,
      textAlign: TextAlign.right,
      "${utmCoords != null ? "${utmCoords.zoneNumber}${_getUtmZoneLetter(position!.latitude)}" : "?"} "
      "${utmCoords?.yToStringAsFixed(0).padLeft(7, '0') ?? '?'}N${wrapped ? "\n" : " "}"
      "${utmCoords?.xToStringAsFixed(0).padLeft(7, '0') ?? '?'}E",
    );
  }

  String _getUtmZoneLetter(double latitude) {
    const letters = 'CDEFGHJKLMNPQRSTUVWX'; // I and O are excluded
    if (latitude < -80 || latitude > 84) return '?';
    final index = ((latitude + 80) ~/ 8).clamp(0, 19);
    return letters[index];
  }
}
