import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/utils/station_scenario_tokens.dart';

/// Exposes the in-scope station's [Location]s/[Person]s (ADR-0047,
/// DESIGN-009 follow-up 4) to a subtree, so token-aware fields
/// (`RingDrillTextField`/`RingDrillTextArea`) can resolve
/// `{{station.loc.<slug>}}` / `{{station.person.<slug>}}` chips and offer
/// them in the insertion menu — the `PlanScope` sibling for the
/// station-and-down scope ADR-0047 defines.
///
/// Provided by the station editor (its own `locations`/`persons`, working
/// copy) and by the roleplay editor (the linked station's `locations`/
/// `persons`, plus its own pending inline-created ones — a roleplay does
/// not own a station's collections, so it always reads someone else's).
/// Omitted (no ancestor) for editors with no station in scope (Program,
/// Exercise) — a field's `StationScope.maybeOf` lookup returning null means
/// "no station tokens here", not an error, mirroring how `PlanScope` is
/// mandatory but this one is optional.
class StationScope extends InheritedWidget {
  const StationScope({
    super.key,
    required this.locations,
    required this.persons,
    this.portrayerOf,
    required super.child,
  });

  final List<Location> locations;
  final List<Person> persons;

  /// Given a person's slug, returns the effective-identity source that
  /// overrides that [Person]'s own fields (ADR-0047) — e.g. the currently
  /// open `RolePlay` when it portrays that person, or another roleplay on
  /// the same station found via `personRef`. Null (the default) means no
  /// override source is available in this editor's context, so every
  /// person resolves to its own bare fields — the correct behaviour for
  /// the station editor, which does not track roleplays at all.
  final EffectivePersonIdentity? Function(String personSlug)? portrayerOf;

  static StationScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StationScope>();

  /// Resolves a `{{station.(loc|person).<slug>(.facet)*}}` match to its
  /// effective displayed value, or `null` when `slug` is not one of
  /// [locations]/[persons] — the three-way signal
  /// `TokenTextEditingController` needs to color a chip red (`null`), amber
  /// (empty string) or blue (non-empty).
  String? resolve(String kind, String slug, List<String> facets) {
    if (kind == 'loc') {
      final location = _bySlug(locations, slug, (l) => l.slug);
      return location == null ? null : resolveLocationFacet(location, facets);
    }
    final person = _bySlug(persons, slug, (p) => p.slug);
    if (person == null) return null;
    return resolvePersonFacet(
      person,
      portrayerOf?.call(slug),
      locations,
      facets,
    );
  }

  // Compares by value, not identity, matching `PlanScope.updateShouldNotify`
  // — an ancestor rebuild that passes equal-but-different List instances
  // (Location/Person are freezed) should not spuriously notify.
  @override
  bool updateShouldNotify(StationScope oldWidget) =>
      !listEquals(locations, oldWidget.locations) ||
      !listEquals(persons, oldWidget.persons);
}

T? _bySlug<T>(List<T> items, String slug, String Function(T item) slugOf) {
  for (final item in items) {
    if (slugOf(item) == slug) return item;
  }
  return null;
}
