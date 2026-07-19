import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/role_play.dart';

/// Exposes the in-scope roleplay's own cross-reference facets (`roleplay.*`,
/// DESIGN-010's resolve-context cascade) to a subtree — the `PlanScope` /
/// `ExerciseScope` / `StationScope` sibling for the roleplay level.
///
/// Like the other scopes, this carries the raw facet values (not a pre-built
/// map); `resolveScopedField` assembles the `{{roleplay.*}}` context from them
/// (`_roleplayFacets`, mirroring `_stationFacets`). Only the currently-open
/// roleplay's own identity is ever in play, so one scope per roleplay surface
/// is enough. The viewer seeds it from the saved [RolePlay]; the editor seeds
/// a live working copy so `{{roleplay.name}}` previews the identity as it is
/// being typed. A field with no `RoleplayScope` ancestor resolves
/// `{{roleplay.*}}` to a literal token (ADR-0048), never a crash.
class RoleplayScope extends InheritedWidget {
  const RoleplayScope({
    super.key,
    required this.name,
    this.age,
    this.signalement,
    this.position,
    required super.child,
  });

  /// This roleplay's own facets — mirroring [StationScope]'s raw fields.
  final String name;
  final int? age;
  final String? signalement;

  /// The roleplay's raw coordinate (like [StationScope.position]) — formatted
  /// and, in the app, wired to a tappable map action at resolve time
  /// (`resolveScopedField`), not here (ADR-0050).
  final LatLng? position;

  /// Wraps [child] in a scope derived from [rolePlay] — the single source of
  /// the `{{roleplay.*}}` field set, so the viewer and the editor can never
  /// drift. The editor passes a live working copy.
  static Widget forRoleplay(
    RolePlay rolePlay, {
    Key? key,
    required Widget child,
  }) {
    return RoleplayScope(
      key: key,
      name: rolePlay.name,
      age: rolePlay.age,
      signalement: rolePlay.signalement,
      position: rolePlay.position,
      child: child,
    );
  }

  static RoleplayScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RoleplayScope>();

  @override
  bool updateShouldNotify(RoleplayScope oldWidget) =>
      name != oldWidget.name ||
      age != oldWidget.age ||
      signalement != oldWidget.signalement ||
      position != oldWidget.position;
}
