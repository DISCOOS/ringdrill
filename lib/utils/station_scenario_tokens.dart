/// Canonical `{{station.loc.<slug>}}` / `{{station.person.<slug>}}` matching
/// and facet resolution (ADR-0047, DESIGN-009 follow-up 4) — the editor-side
/// counterpart to `plan_variables.dart`'s `{{var.<name>}}` pattern, used by
/// `TokenTextEditingController` (chip coloring) and the token insertion menu
/// (preview values).
///
/// `BriefRenderer` (`lib/services/brief/brief_renderer.dart`) already
/// resolves the same tokens server-side for rendering, with its own private
/// pattern and facet logic plus a localized unknown-reference placeholder.
/// This file is a deliberate, independent copy for the editor: follow-up 4
/// is scoped to `lib/views/`, `lib/utils/` and `lib/l10n/` only (no
/// `lib/services/` changes), and the editor's needs are simpler — it never
/// renders a placeholder string, only classifies a match as unknown (null),
/// known-but-empty, or known-with-a-value, to color a chip or preview a
/// picker entry. Unifying the two into one shared resolver is future work
/// once an editor-side change is in scope for `lib/services/` too.
///
/// Pure and Flutter-free, like `plan_variables.dart`.
library;

import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/utils/projection.dart';

/// Matches `{{station.loc.<slug>}}` / `{{station.person.<slug>}}`, with an
/// optional dotted facet path (`.place`, `.utm`, `.loc.utm`, ...). Group 1
/// is `loc`/`person`, group 2 the slug, group 3 the facet path including its
/// leading dots (empty for the bare token). Mirrors
/// `BriefRenderer`'s own (private) pattern of the same shape.
final stationScenarioTokenPattern = RegExp(
  r'\{\{\s*station\.(loc|person)\.([a-z][a-z0-9_]*)((?:\.[a-zA-Z]+)*)\s*\}\}',
);

/// Facet path segments after the slug for a [stationScenarioTokenPattern]
/// match, e.g. `.place` → `['place']`; empty for the bare token.
List<String> stationScenarioTokenFacets(RegExpMatch match) =>
    (match.group(3) ?? '').split('.').where((s) => s.isNotEmpty).toList();

/// `{{station.loc.<slug>[.facet]}}` facet resolution — same shape as
/// `BriefRenderer`'s `_resolveLocationFacet`, minus the markdown inline-code
/// wrapping around `.utm` (an editor chip/preview shows plain text, not
/// rendered markdown).
String resolveLocationFacet(Location location, List<String> facets) {
  switch (facets.isEmpty ? null : facets.first) {
    case 'place':
      return location.place;
    case 'label':
      return location.label;
    case 'utm':
      return _locationUtm(location);
    case 'latlng':
      return locationLatLng(location);
    default:
      return _locationDefault(location);
  }
}

/// `.latlng` facet (DESIGN-008 follow-up 11): the coordinate as a decimal
/// `lat,lng` pair — 6 decimals, `.` separator — pasteable into a GPS.
/// Empty when the location has no position.
String locationLatLng(Location location) {
  final position = location.position;
  if (position == null) return '';
  return '${position.latitude.toStringAsFixed(6)},'
      '${position.longitude.toStringAsFixed(6)}';
}

String _locationUtm(Location location) {
  final position = location.position;
  if (position == null) return '';
  return formatUtm(position);
}

/// Sensible bare-token default: `place`, falling back to the UTM string when
/// there is no place text but a position is set.
String _locationDefault(Location location) {
  if (location.place.isNotEmpty) return location.place;
  return _locationUtm(location);
}

/// Bare display for a location value that renders *both* parts — "place
/// (UTM)" when both are set, otherwise whichever exists (DESIGN-008
/// follow-up 11's bare `{{var.<name>}}` rendering for `location`-typed
/// variables: place + UTM). Plain text, no markdown wrapping — the brief's
/// own code-chip styling stays in `BriefRenderer`.
String locationPlaceUtm(Location location) {
  final utm = _locationUtm(location);
  if (location.place.isEmpty) return utm;
  if (utm.isEmpty) return location.place;
  return '${location.place} ($utm)';
}

/// `{{station.person.<slug>[.facet]}}` facet resolution — same shape as
/// `BriefRenderer`'s `_resolvePersonFacet`. [portrayer] is the effective
/// identity source (a `RolePlay`-shaped record of the fields that can
/// override the [Person]'s own, or null when nothing portrays this person in
/// the caller's context); [stationLocations] resolves `.loc` through
/// [Person.locSlug].
String resolvePersonFacet(
  Person person,
  EffectivePersonIdentity? portrayer,
  List<Location> stationLocations,
  List<String> facets,
) {
  switch (facets.isEmpty ? null : facets.first) {
    case 'age':
      final age = portrayer?.age ?? person.age;
      return age == null ? '' : '$age';
    case 'gender':
      return _effectiveField(portrayer?.gender, person.gender) ?? '';
    case 'description':
      return _effectiveField(portrayer?.description, person.description) ??
          '';
    case 'loc':
      final locSlug = person.locSlug;
      final loc = locSlug == null
          ? null
          : _bySlug(stationLocations, locSlug, (l) => l.slug);
      return loc == null
          ? ''
          : resolveLocationFacet(loc, facets.skip(1).toList());
    case 'name':
    default:
      return _effectiveField(portrayer?.name, person.name) ?? person.name;
  }
}

/// The subset of `RolePlay` identity fields relevant to effective-identity
/// resolution (ADR-0047) — a small projection rather than importing
/// `RolePlay` itself, so this file stays about *tokens*, not the roleplay
/// model's full shape.
class EffectivePersonIdentity {
  const EffectivePersonIdentity({
    this.name,
    this.age,
    this.gender,
    this.description,
  });

  final String? name;
  final int? age;
  final String? gender;
  final String? description;
}

/// The portraying roleplay's value when non-empty, otherwise null (falls
/// back to the person's own value at the call site) — ADR-0047's
/// effective-identity rule.
String? _effectiveField(String? roleplayValue, String? personValue) {
  if (roleplayValue != null && roleplayValue.isNotEmpty) return roleplayValue;
  return personValue;
}

T? _bySlug<T>(List<T> items, String slug, String Function(T item) slugOf) {
  for (final item in items) {
    if (slugOf(item) == slug) return item;
  }
  return null;
}

/// Formats [position] as "32V 0580414E 6552008N" (UTM, easting before
/// northing) — duplicated from `BriefRenderer._formatUtm`/
/// `locations_section.dart._formatUtm` (the latter already duplicates it for
/// the same "no `lib/services/` reuse, and the renderer's own copy is
/// `@visibleForTesting`" reason). Public since DESIGN-008 follow-up 11 so
/// typed `location` variables (`variable_values.dart`) format their
/// coordinate through this same shape instead of a fourth copy.
String formatUtm(LatLng position) {
  final utm = position.utm();
  final e = utm.easting.toStringAsFixed(0).padLeft(7, '0');
  final n = utm.northing.toStringAsFixed(0).padLeft(7, '0');
  return '${utm.zone}${utm.band} ${e}E ${n}N';
}
