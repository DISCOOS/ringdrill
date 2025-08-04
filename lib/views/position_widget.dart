import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/views/utm_widget.dart';

import 'latlng_widget.dart';

enum PositionFormat { utm, latlng }

class PositionWidget extends StatelessWidget {
  const PositionWidget({
    super.key,
    required this.format,
    required this.position,
    this.wrapped = true,
    this.style,
  });

  final LatLng? position;
  final bool wrapped;
  final TextStyle? style;

  final PositionFormat format;

  @override
  Widget build(BuildContext context) {
    return switch (format) {
      PositionFormat.utm => UtmWidget(
        style: style,
        wrapped: wrapped,
        position: position,
      ),
      PositionFormat.latlng => LatLngWidget(
        style: style,
        wrapped: wrapped,
        position: position,
      ),
    };
  }
}
