import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class LatLngWidget extends StatelessWidget {
  const LatLngWidget({
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
    return SelectableText(
      style: style,
      textAlign: TextAlign.right,
      "${position?.latitude.toStringAsFixed(4) ?? '?'}N${wrapped ? "\n" : " "}"
      "${position?.longitude.toStringAsFixed(4) ?? '?'}E",
    );
  }
}
