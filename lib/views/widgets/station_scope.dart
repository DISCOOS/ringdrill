import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/utils/station_scenario_tokens.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';

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
    this.name,
    this.stationCode,
    this.description,
    this.variantSuffix,
    this.positionUtm,
    required super.child,
  });

  final List<Location> locations;
  final List<Person> persons;

  /// This station's own cross-reference facets (`station.*`, DESIGN-010's
  /// resolve-context cascade — the same set `BriefRenderer`'s
  /// `stationRefContext` builds) — carried alongside [locations]/[persons]
  /// so a `{{station.name}}`/`{{station.position.utm}}` etc. reference
  /// resolves in preview the same way it does in the brief. A null
  /// [name]/[description]/[variantSuffix]/[positionUtm] resolves to an
  /// empty string, exactly like the brief itself does for a null
  /// `Station.variantSuffix` etc. — this is not a limitation, since a
  /// present-but-null field never throws mustache's "missing" case, only a
  /// genuinely absent `StationScope` (no key at all) does, which leaves
  /// `{{station.*}}` literal (ADR-0048) the same way it would with no
  /// station in scope server-side.
  ///
  /// [stationCode] is the one facet this scope cannot compute the same way:
  /// its brief value needs the exercise's 1-based position in
  /// `Program.exercises` and `Program.stationNumberFormat`, neither of
  /// which any DESIGN-010 scope carries, and the brief itself never leaves
  /// it null. Duplicating `Numbering.station`'s cascade here to recover
  /// them would risk exactly the drift ADR-0048 exists to avoid, so
  /// `{{station.stationCode}}` previews empty and only shows the real code
  /// once the brief itself is generated.
  final String? name;
  final String? stationCode;
  final String? description;
  final String? variantSuffix;
  final String? positionUtm;

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

  /// [locations] projected for the insertion menu (DESIGN-009 follow-up
  /// 4): each entry's [StationLocationToken.preview] is its bare-facet
  /// value, the same default a `{{station.loc.<slug>}}` chip without a
  /// facet path would show.
  List<StationLocationToken> get locationTokens => [
    for (final l in locations)
      StationLocationToken(
        slug: l.slug,
        label: l.label.isEmpty ? l.slug : l.label,
        preview: resolveLocationFacet(l, const []),
      ),
  ];

  /// [persons] projected for the insertion menu, mirroring [locationTokens]
  /// — each entry's preview is the effective (portrayer-aware) bare name.
  List<StationPersonToken> get personTokens => [
    for (final p in persons)
      StationPersonToken(
        slug: p.slug,
        label: p.name.isEmpty ? p.slug : p.name,
        preview: resolvePersonFacet(
          p,
          portrayerOf?.call(p.slug),
          locations,
          const [],
        ),
      ),
  ];

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
      !listEquals(persons, oldWidget.persons) ||
      name != oldWidget.name ||
      stationCode != oldWidget.stationCode ||
      description != oldWidget.description ||
      variantSuffix != oldWidget.variantSuffix ||
      positionUtm != oldWidget.positionUtm;
}

T? _bySlug<T>(List<T> items, String slug, String Function(T item) slugOf) {
  for (final item in items) {
    if (slugOf(item) == slug) return item;
  }
  return null;
}
