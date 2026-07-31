import 'package:flutter/material.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/widgets/map_command.dart';

/// The empty state shown in a map slot when there is no position to plot —
/// a station without a position, an exercise whose stations are all
/// unplaced, a role with no central position. Wraps the shared [EmptyState]
/// (centred icon + caption) in a card-shaped, low-emphasis container that
/// visually matches the actual map card it stands in for, so switching
/// between "has position" and "no position" doesn't read as two different
/// components: same 8px corner radius as `PositionCardShell`, filled with
/// the same tonal map-chrome tone every built-in map control uses
/// ([MapCommandEmphasis.tonal]'s background).
///
/// [height] is nullable: pass an explicit height for a fixed map slot (a
/// scrolling single-column body), or leave it null to fill a height-bounded
/// parent (an `Expanded`/`WideDetailMapSplit.mapPane` slot), where the
/// undecorated box takes the parent's tight height directly.
///
/// [child] replaces the default caption body for a slot that has something more
/// to say — `PositionEmptyState` uses it for the teaching card. The chrome stays
/// here either way: it is the one definition of "a box standing in for the map
/// card", and a second copy of that decoration is how two surfaces start
/// disagreeing about what an empty map looks like.
class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({
    super.key,
    this.height,
    this.icon = Icons.location_off,
    this.message,
    this.child,
  }) : assert(
         child != null || message != null,
         'MapPlaceholder needs a message for its default body, or a child to '
         'replace it',
       );

  final double? height;
  final IconData icon;
  final String? message;

  /// Replaces the default [EmptyState] body, inside the same card chrome.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: MapCommandEmphasis.tonal.background(scheme),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child ?? EmptyState(icon: icon, text: message!),
    );
    return height == null ? box : SizedBox(height: height, child: box);
  }
}
