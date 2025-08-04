import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/latlng_widget.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/utm_widget.dart';

import 'map_picker_screen.dart';

class PositionFormField extends FormField<LatLng> {
  PositionFormField({
    super.key,
    required FormFieldSetter<LatLng> super.onSaved,
    required super.initialValue,
    super.validator,
    AutovalidateMode super.autovalidateMode = AutovalidateMode.disabled,
  }) : super(
         builder: (FormFieldState<LatLng> state) {
           final position = state.value;
           return Column(
             children: [
               Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(AppLocalizations.of(state.context)!.position),
                   SizedBox(width: 8),
                   UtmWidget(position: position),
                   SizedBox(width: 8),
                   LatLngWidget(position: position),
                   Spacer(),
                   IconButton(
                     icon: Icon(Icons.map),
                     onPressed: () async {
                       final selected = await Navigator.push<LatLng>(
                         state.context,
                         MaterialPageRoute(
                           builder:
                               (context) => MapPickerScreen(
                                 initial:
                                     state.value ?? MapConfig.initialCenter,
                               ),
                         ),
                       );
                       if (selected != null) state.didChange(selected);
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
