import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/projection.dart';
import 'package:universal_io/io.dart';

class UtmWidget extends StatelessWidget {
  const UtmWidget({
    super.key,
    required this.position,
    this.wrapped = true,
    this.useETRS89 = false,
    this.style,
  });

  final bool wrapped;
  final bool useETRS89;
  final LatLng? position;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final utm = position?.utm(useETRS89: useETRS89);
    final widget = utm == null
        ? Text(AppLocalizations.of(context)!.noLocation)
        : SelectableText(
            style: style,
            // TODO: Remove workaround for
            //  https://github.com/flutter/flutter/issues/169001
            //  when in stable
            selectionControls: Platform.isIOS || Platform.isMacOS
                ? EmptyTextSelectionControls()
                : null,
            textAlign: TextAlign.right,
            "${utm.zone}${utm.band} "
            "${utm.northing.toStringAsFixed(0).padLeft(7, '0')}N${wrapped ? "\n" : " "}"
            "${utm.easting.toStringAsFixed(0).padLeft(7, '0')}E",
          );
    return useETRS89
        ? Row(
            children: [
              widget,
              SizedBox(width: 4),
              Text(
                "(${utm?.toRefString()})",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          )
        : widget;
  }
}
