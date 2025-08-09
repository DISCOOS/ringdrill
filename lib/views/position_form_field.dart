import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/position_widget.dart';

import 'map_picker_screen.dart';

class PositionFormField<K> extends FormField<LatLng> {
  PositionFormField({
    super.key,
    required FormFieldSetter<LatLng> super.onSaved,
    required super.initialValue,
    super.validator,
    List<(K, String, LatLng)> markers = const [],

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
                       final selected = await Navigator.push<LatLng>(
                         state.context,
                         MaterialPageRoute(
                           builder: (context) => MapPickerScreen(
                             initialCenter:
                                 state.value ?? MapConfig.initialCenter,
                             markers: markers,
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
