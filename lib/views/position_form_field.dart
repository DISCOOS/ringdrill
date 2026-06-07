import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/position_widget.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';

import 'map_picker_screen.dart';

class PositionFormField<K> extends FormField<LatLng> {
  PositionFormField({
    super.key,
    required FormFieldSetter<LatLng> super.onSaved,
    required super.initialValue,
    super.validator,
    List<MapMarkerSpec<K>> markers = const [],
    // Called when the user picks a new location on the map. Lets the caller
    // distinguish a manual edit from a programmatic default (e.g. inheriting
    // the station position).
    ValueChanged<LatLng>? onChanged,

    AutovalidateMode super.autovalidateMode = AutovalidateMode.disabled,
  }) : super(
         builder: (FormFieldState<LatLng> state) {
           final position = state.value;
           return Column(
             children: [
               Row(
                 crossAxisAlignment: CrossAxisAlignment.center,
                 children: [
                   Text(AppLocalizations.of(state.context)!.position),
                   Spacer(),
                   if (position == null) ...[
                     Text(AppLocalizations.of(state.context)!.pickALocation),
                   ] else ...[
                     PositionWidget(
                       position: position,
                       format: PositionFormat.utm,
                     ),
                   ],
                   SizedBox(width: 8),
                   IconButton(
                     icon: Icon(Icons.map),
                     onPressed: () async {
                       final selected = await openFormSurface<LatLng>(
                         state.context,
                         builder: (context) => MapPickerScreen(
                           initialCenter: position ?? MapConfig.initialCenter,
                           markers: markers,
                         ),
                       );
                       if (selected != null) {
                         state.didChange(selected);
                         onChanged?.call(selected);
                       }
                     },
                   ),
                 ],
               ),
               if (state.hasError)
                 Padding(
                   padding: const EdgeInsets.only(top: 4),
                   child: Text(
                     state.errorText!,
                     style: TextStyle(color: Colors.red),
                   ),
                 ),
             ],
           );
         },
       );
}
