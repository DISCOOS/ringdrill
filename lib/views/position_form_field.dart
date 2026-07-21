import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/latlng_utils.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/widgets/position_card.dart';

import 'map_picker_screen.dart';

export 'package:ringdrill/views/widgets/position_card.dart'
    show PositionFieldVariant;

/// Position pick field (docs/prompts/position-card-reflow.md). Renders the
/// shared [PositionCard] surface in either [PositionFieldVariant] and wires
/// it into [FormField] save/validate. Every position-editing form (station,
/// team, location, roleplay) now uses [PositionFieldVariant.card] for visual
/// consistency; [PositionFieldVariant.row] remains available for a caller
/// that needs the more compact horizontal layout. Tapping anywhere on the
/// surface opens [MapPickerScreen]; there is no separate map icon.
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
    PositionFieldVariant variant = PositionFieldVariant.row,
    bool showThumbnail = true,
    List<Widget> overlayActions = const [],
    // Optional leading title stacked above the coordinate in the `card`
    // variant's bar (e.g. the roleplay editor shows the followed location's
    // name, or "Own position" for an override). Null keeps the bar showing
    // just the coordinate, as every other caller does.
    String? title,
    // Optional leading title stacked above the coordinate in the `card`
    // variant's bar (e.g. the roleplay editor shows the followed location's
    // name, or "Own position" for an override). Null keeps the bar showing
    // just the coordinate, as every other caller does.
    String? emptyLabel,
    // Optional leading widget in the `card` variant's bar.
    Widget? barLeading,
    // Optional label widget in the `card` variant's bar
    Widget? barLabel,
    // Optional trailing widget in the `card` variant's bar, replacing the
    // default `chevron_right`. Its own tap target.
    Widget? barTrailing,
    AutovalidateMode super.autovalidateMode = AutovalidateMode.disabled,
  }) : super(
         builder: (FormFieldState<LatLng> state) {
           final position = state.value;
           final theme = Theme.of(state.context);
           final l10n = AppLocalizations.of(state.context)!;

           Future<void> openPicker() async {
             // With a position, open on it. Without one, frame the picker on
             // the surrounding markers (e.g. sibling stations) instead of
             // the global default centre, so the user places the new point
             // near its context.
             final points = markers.map((m) => m.point).toList(growable: false);
             final LatLng center;
             CameraFit? fit;
             if (position != null) {
               center = position;
             } else if (points.isEmpty) {
               center = MapConfig.initialCenter;
             } else if (points.length == 1) {
               center = points.first;
             } else {
               center = points.average();
               fit =
                   points.centroidFit() ??
                   CameraFit.coordinates(coordinates: points);
             }
             final selected = await openFormSurface<LatLng>(
               state.context,
               builder: (context) => MapPickerScreen(
                 initialCenter: center,
                 initialFit: fit,
                 markers: markers,
               ),
             );
             if (selected != null) {
               state.didChange(selected);
               onChanged?.call(selected);
             }
           }

           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               if (title?.isNotEmpty == true) ...[
                 Text(
                   title!,
                   style: theme.textTheme.labelSmall?.copyWith(
                     color: theme.colorScheme.onSurfaceVariant,
                   ),
                 ),
                 const SizedBox(height: 6),
               ],
               ClipRRect(
                 borderRadius: BorderRadius.circular(8),
                 child: Container(
                   decoration: BoxDecoration(
                     border: Border.all(
                       color: theme.colorScheme.outlineVariant,
                     ),
                     borderRadius: BorderRadius.circular(8),
                   ),
                   child: PositionCard<K>(
                     elevation: 0,
                     variant: variant,
                     markers: markers,
                     onTap: openPicker,
                     position: position,
                     overlayActions: overlayActions,
                     emptyLabel: emptyLabel ?? l10n.pickALocation,
                     barLabel:
                         barLabel ??
                         (position != null ? Text(l10n.editPlacement) : null),
                     barLeading: barLeading,
                     barTrailing:
                         barTrailing ??
                         Icon(
                           Icons.chevron_right,
                           color: theme.colorScheme.onSurfaceVariant,
                         ),
                   ),
                 ),
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
