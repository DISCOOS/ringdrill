/// The flutter-free field resolver (ADR-0048): the token pipeline
/// `{{var.<name>}}` → `{{station.loc/person.<slug>}}` → the mustache
/// cross-reference pass (`program.*`/`exercise.*`/`station.*`/`roleplay.*`),
/// fixpoint-bounded by [maxResolvePasses]. Extracted from `BriefRenderer`,
/// which keeps assembling the resolution context (the effective `vars` map,
/// the `refContext` maps, the optional scenario station/roleplays) exactly as
/// before and delegates each field to [resolveField].
///
/// DESIGN-010's resolve-context scope cascade (`PlanScope` → `ExerciseScope`
/// → `StationScope`) will feed this same function from the widget layer, so
/// an in-editor preview and the brief share one resolver instead of drifting
/// apart. This file stays free of `package:flutter/*` so the CLI and any
/// other pure-Dart caller can resolve fields too (ADR-0005); it only touches
/// `AppLocalizations` and pure model types, the same tolerance the code had
/// inside `BriefRenderer`.
library;

import 'package:latlong2/latlong.dart';
import 'package:mustache_template/mustache_template.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/projection.dart';
import 'package:ringdrill/utils/variable_values.dart';

/// Upper bound on [resolveField]'s fixpoint iterations. Each successful
/// resolution removes tokens, so a well-formed field converges in one or two
/// passes; this cap only bites on a circular reference (e.g. a name that
/// references a description that references the name), guaranteeing
/// termination instead of an infinite loop. Any tokens still present when
/// the cap is reached are left as visible literal text, which surfaces the
/// cycle to the author rather than hanging the render.
const maxResolvePasses = 10;

/// Optional sink for a mustache cross-reference render that [resolveField]
/// caught and fell back on — returning the field with its `{{scope.*}}` tokens
/// left literal (ADR-0048) rather than throwing. Fired at most once per
/// [resolveField] call, carrying the first pass's error.
///
/// Null by default: the CLI and other pure-Dart callers leave it unset, and
/// this file stays flutter-free (ADR-0005). The app wires it (behind the
/// analytics-consent gate) so a field that silently degrades because a resolve
/// scope is missing from the widget tree — the class of bug where a surface
/// forgot to provide, say, an `ExerciseScope` — becomes visible instead of
/// vanishing into the catch. Tests set it to assert no field degrades
/// unexpectedly.
///
/// Caveat for any alerting consumer: the resolver cannot tell an intended
/// literal fallback (a genuinely orphaned `{{station.*}}` in a roleplay with
/// no linked station, honest per ADR-0048) from a missing-scope bug — both
/// land here, so expect some legitimate content-side reports alongside the
/// code bugs.
void Function(Object error, StackTrace stackTrace)? onResolveFieldError;

/// Strategy for rendering a copyable field value (position, phone, address),
/// chosen per output format (ADR-0050). [resolveField] takes one, defaulting
/// to [CopyChipFormatter] so the brief and non-interactive exports (PDF,
/// DOCX) stay unchanged; the app resolvers pass [ActionChipFormatter].
abstract class ChipFormatter {
  const ChipFormatter();

  /// A coordinate value. [display] is the formatted text to show (e.g. a
  /// UTM string); [latLng] is the raw coordinate an action chip needs for its
  /// map link — null degrades every formatter to a plain copy chip of
  /// [display], since there is nothing to link to.
  String position(String display, LatLng? latLng);

  /// A phone number. [display] is the text to show; [number] is the raw
  /// number a `tel:` action chip dials — empty degrades to a plain copy chip.
  String phone(String display, String number);

  /// An address value. Always a copy chip in every formatter — an address
  /// has no reliable launch target (deferred, ADR-0050).
  String address(String value);
}

/// The default [ChipFormatter]: every value is today's plain backtick copy
/// chip ([briefCopyChip]). Used by the brief and the non-interactive exports;
/// `BriefRenderer` never passes another formatter, so this keeps the brief
/// output byte-identical.
class CopyChipFormatter extends ChipFormatter {
  const CopyChipFormatter();

  @override
  String position(String display, LatLng? latLng) => briefCopyChip(display);

  @override
  String phone(String display, String number) => briefCopyChip(display);

  @override
  String address(String value) => briefCopyChip(value);
}

/// The interactive [ChipFormatter] for the app preview (and, later, the HTML
/// brief). A position/phone chip encodes its launch target as a markdown
/// link to an internal `ringdrill://chip` URI — `action=map` with `lat`/`lng`
/// query parameters, or `action=call` with a `tel` query parameter — that the
/// app's markdown renderer (`brief_markdown.dart`) recognizes and wires to a
/// tap action, the copy icon still copying [display]/[number]. The query
/// form (over the original `rdchip:` sentinel) is legible and leaves room for
/// a future `label` parameter and further actions. Degrades to a plain copy
/// chip when there is nothing to act on (no coordinate, empty number). An
/// address stays a copy chip.
class ActionChipFormatter extends ChipFormatter {
  const ActionChipFormatter();

  @override
  String position(String display, LatLng? latLng) {
    if (latLng == null) return briefCopyChip(display);
    final uri = Uri(
      scheme: 'ringdrill',
      host: 'chip',
      queryParameters: {
        'action': 'map',
        'lat': '${latLng.latitude}',
        'lng': '${latLng.longitude}',
      },
    );
    return '[$display]($uri)';
  }

  @override
  String phone(String display, String number) {
    if (number.isEmpty) return briefCopyChip(display);
    // Dial value carries only `+` and digits — a formatted [display]
    // (spaces, parentheses, dashes) would make the `tel:` URI malformed and
    // fail to launch on a real device. The chip still *shows* [display].
    final dialable = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (dialable.isEmpty) return briefCopyChip(display);
    final uri = Uri(
      scheme: 'ringdrill',
      host: 'chip',
      queryParameters: {'action': 'call', 'tel': dialable},
    );
    return '[$display]($uri)';
  }

  @override
  String address(String value) => briefCopyChip(value);
}

/// Coordinate display format for the `position` facet (ADR-0050), unifying
/// the former flat `utm`/`latlng` facets into one format-agnostic
/// `position`. Ships with UTM only — [format] is the seam for MGRS, the
/// degree variants (DD/DM/DMS) and raw LatLng later, à la
/// [ADR-0034](../../../docs/adrs/0034-configurable-numbering-formats.md)'s
/// configurable numbering.
enum CoordinateFormat {
  utm;

  /// Formats [latLng] per this format. Empty string when [latLng] is null.
  String format(LatLng? latLng) => switch (this) {
    CoordinateFormat.utm => formatUtm(latLng),
  };
}

/// Resolves a markdown field for rendering by running the full token
/// pipeline — `{{var.<name>}}`, then (when [scenarioStation] is given)
/// `{{station.loc/person.<slug>}}`, then the mustache cross-reference pass
/// against [refContext] — repeatedly until the string stops changing
/// (bounded by [maxResolvePasses]).
///
/// The loop is what makes *nested* tokens resolve: any of the three systems
/// can inject a value that itself contains further tokens. A `{{var.year}}`
/// living inside `program.name` and reached through `{{program.name}}`, or a
/// `{{program.name}}` living inside `program.description` and reached through
/// `{{program.description}}`, only appears in the text after the pass that
/// injected it, so a single pass would leave it literal. Re-running the
/// whole pipeline on each pass' output resolves the next layer down. This
/// also means the cross-reference source values in the various `refContext`
/// maps can stay raw (unresolved) — the following pass' `{{var.*}}`
/// substitution catches whatever they inject.
///
/// [scenarioStation] is omitted (null) for program- and exercise-scope
/// fields, which have no station in scope and so never resolve
/// `station.loc.*`/`station.person.*`; only station and roleplay fields pass
/// it, both scoped to that same station's `locations`/`persons`.
String? resolveField(
  String? content, {
  required Map<String, DrillVariable> vars,
  required AppLocalizations l10n,
  Map<String, dynamic> refContext = const {},
  Station? scenarioStation,
  List<RolePlay> scenarioRolePlays = const [],
  ChipFormatter chips = const CopyChipFormatter(),
  CoordinateFormat format = CoordinateFormat.utm,
}) {
  if (content == null) return null;
  var current = content;
  Object? firstError;
  StackTrace? firstStack;
  for (var pass = 0; pass < maxResolvePasses; pass++) {
    final next = _resolveFieldOnce(
      current,
      vars: vars,
      l10n: l10n,
      refContext: refContext,
      scenarioStation: scenarioStation,
      scenarioRolePlays: scenarioRolePlays,
      chips: chips,
      format: format,
      onError: (error, stackTrace) {
        // Keep only the first pass's failure: a persistent missing-scope
        // token throws on every pass, but it is one problem, reported once.
        firstError ??= error;
        firstStack ??= stackTrace;
      },
    );
    final converged = next == current;
    current = next;
    if (converged) break;
  }
  if (firstError != null) {
    onResolveFieldError?.call(firstError!, firstStack ?? StackTrace.current);
  }
  return current;
}

/// One iteration of the [resolveField] pipeline: `{{var.<name>}}`
/// substitution, then optional `{{station.loc/person.<slug>}}` resolution,
/// then the mustache cross-reference pass. Falls back to the (variable- and
/// scenario-substituted, but not mustache-rendered) content if that pass
/// throws — the same fallback behaviour the renderer had before variable
/// substitution was introduced.
String _resolveFieldOnce(
  String content, {
  required Map<String, DrillVariable> vars,
  required AppLocalizations l10n,
  required Map<String, dynamic> refContext,
  Station? scenarioStation,
  List<RolePlay> scenarioRolePlays = const [],
  ChipFormatter chips = const CopyChipFormatter(),
  CoordinateFormat format = CoordinateFormat.utm,
  void Function(Object error, StackTrace stackTrace)? onError,
}) {
  final withVars = substituteTypedVariables(
    content,
    vars,
    l10n,
    chips: chips,
    format: format,
  );
  final withScenario = scenarioStation == null
      ? withVars
      : _resolveStationScenarioTokens(
          withVars,
          station: scenarioStation,
          rolePlays: scenarioRolePlays,
          l10n: l10n,
          chips: chips,
          format: format,
        );
  try {
    return Template(
      withScenario,
      htmlEscapeValues: false,
    ).renderString(refContext);
  } catch (error, stackTrace) {
    onError?.call(error, stackTrace);
    return withScenario;
  }
}

/// Replaces every `{{var.<name>}}` token in [content] with its value in
/// [vars], or with the localized unknown-variable placeholder when
/// `<name>` is not a key of [vars]. The plain string-map substitution —
/// `BriefRenderer.substituteVariables` — resolves through this typed path
/// internally.
///
/// Runs before the mustache pass (see [resolveField]), so cross-references
/// like `{{station.position}}` are still handled by the subsequent
/// mustache pass against `refContext`. A variable *value* that itself
/// contains `{{...}}` is inserted literally here and picked up by a later
/// pass of [resolveField]'s fixpoint loop: a `{{var.*}}` value resolves on
/// the next iteration, a cross-reference token in it on the mustache pass. A
/// self- or mutually-referential value never converges and is left literal
/// once the loop's cap is hit.
String substituteTypedVariables(
  String content,
  Map<String, DrillVariable> vars,
  AppLocalizations l10n, {
  ChipFormatter chips = const CopyChipFormatter(),
  CoordinateFormat format = CoordinateFormat.utm,
}) {
  return resolveTypedPlanVariables(
    content,
    vars,
    format: VariableFormat(
      localeName: l10n.localeName,
      hourUnit: l10n.variableDurationHourUnit,
    ),
    onUnknown: (name) => l10n.briefUnknownVariable(name),
    locationFacetResolver: (location, facets) =>
        _resolveLocationFacet(location, facets, chips, format),
  );
}

/// Matches `{{station.loc.<slug>}}` / `{{station.person.<slug>}}`, with an
/// optional dotted facet path (`.place`, `.utm`, `.loc.utm`, ...). Group 1
/// is `loc`/`person`, group 2 the slug, group 3 the facet path including its
/// leading dots (empty for the bare token).
final _stationScenarioTokenPattern = RegExp(
  r'\{\{\s*station\.(loc|person)\.([a-z][a-z0-9_]*)((?:\.[a-zA-Z]+)*)\s*\}\}',
);

/// Replaces every `{{station.loc.<slug>}}` / `{{station.person.<slug>}}`
/// token (with facets) in [content] against [station]'s own
/// `locations`/`persons` — the station-and-down scope ADR-0047 defines.
/// [rolePlays] are the roleplays on this same station, used to resolve a
/// person facet's effective (denormalized) identity. An unknown slug
/// renders the same kind of visible, localized placeholder an undeclared
/// `{{var.x}}` does; a known slug with an empty facet renders empty, which
/// is a valid authoring state, not an error.
///
/// Runs pre-mustache, alongside `{{var.<name>}}` substitution — this is a
/// second registry-like lookup, not mustache's fixed derived context, so it
/// stays on the same pre-pass rather than growing a second parser. The
/// remaining `{{station.position}}` etc. are untouched here and still
/// resolved by the subsequent mustache pass against `refContext`.
String _resolveStationScenarioTokens(
  String content, {
  required Station station,
  required List<RolePlay> rolePlays,
  required AppLocalizations l10n,
  ChipFormatter chips = const CopyChipFormatter(),
  CoordinateFormat format = CoordinateFormat.utm,
}) {
  return content.replaceAllMapped(_stationScenarioTokenPattern, (match) {
    final kind = match.group(1)!;
    final slug = match.group(2)!;
    final facets = (match.group(3) ?? '')
        .split('.')
        .where((s) => s.isNotEmpty)
        .toList();
    if (kind == 'loc') {
      final location = _bySlug(station.locations, slug, (l) => l.slug);
      if (location == null) {
        return l10n.briefUnknownReference('station.loc.$slug');
      }
      return _resolveLocationFacet(location, facets, chips, format);
    }
    final person = _bySlug(station.persons, slug, (p) => p.slug);
    if (person == null) {
      return l10n.briefUnknownReference('station.person.$slug');
    }
    final portrayer = _bySlug(rolePlays, slug, (rp) => rp.personRef ?? '');
    return _resolvePersonFacet(
      person,
      portrayer,
      station,
      facets,
      chips,
      format,
    );
  });
}

T? _bySlug<T>(List<T> items, String slug, String Function(T item) slugOf) {
  for (final item in items) {
    if (slugOf(item) == slug) return item;
  }
  return null;
}

/// `{{station.loc.<slug>[.facet]}}` facet resolution — also reused for
/// `location`-typed `{{var.<name>[.facet]}}` tokens (DESIGN-008 follow-up
/// 11), which project onto the same `Location` shape. The bare/default and
/// `position` forms render the coordinate (formatted per [format]) as inline
/// code (backtick-wrapped) or, under [ActionChipFormatter], a `ringdrill:`
/// chip link; empty when the location has no position. Replaces the former flat
/// `utm`/`latlng` facets (ADR-0050) — a field still using one of those old
/// tokens falls through to the bare default, same as any unrecognized facet.
String _resolveLocationFacet(
  Location location,
  List<String> facets,
  ChipFormatter chips,
  CoordinateFormat format,
) {
  switch (facets.isEmpty ? null : facets.first) {
    case 'place':
      return chips.address(location.place);
    case 'label':
      return location.label;
    case 'position':
      return chips.position(
        format.format(location.position),
        location.position,
      );
    default:
      return _locationDefault(location, chips, format);
  }
}

/// Wraps a copyable field value (coordinate, address, phone) in a backtick
/// code span so the brief renders it as a copy chip. Empty stays empty.
String briefCopyChip(String value) => value.isEmpty ? '' : '`$value`';

/// Sensible bare-token default: the address as its own copy chip plus, when a
/// position is set, the coordinate chip (formatted per [format]) wrapped in
/// parentheses — two chips side by side, e.g. `[Meiselen 14] ([32V …])`.
String _locationDefault(
  Location location,
  ChipFormatter chips,
  CoordinateFormat format,
) {
  final position = format.format(location.position);
  if (location.place.isEmpty) {
    return chips.position(position, location.position);
  }
  if (position.isEmpty) return chips.address(location.place);
  // The parentheses are folded into the position chip; the chip renderer
  // draws them just outside its pill (so "(", pill and ")" stay together) and
  // excludes them from the copied coordinate.
  return '${chips.address(location.place)} '
      '${chips.position('($position)', location.position)}';
}

/// `{{station.person.<slug>[.facet]}}` facet resolution. [portrayer] is the
/// roleplay on [station] whose `personRef` names this person, if any — its
/// identity fields take precedence over [person]'s own when set (the
/// effective, denormalized identity from ADR-0047); `.loc` resolves
/// [Person.locSlug] to a location on the same station and applies the
/// remaining facet path to it.
String _resolvePersonFacet(
  Person person,
  RolePlay? portrayer,
  Station station,
  List<String> facets,
  ChipFormatter chips,
  CoordinateFormat format,
) {
  switch (facets.isEmpty ? null : facets.first) {
    case 'age':
      final age = portrayer?.age ?? person.age;
      return age == null ? '' : '$age';
    case 'gender':
      return _effectiveField(portrayer?.gender, person.gender) ?? '';
    case 'signalement':
      return _effectiveField(portrayer?.signalement, person.signalement) ?? '';
    case 'loc':
      final locSlug = person.locSlug;
      final loc = locSlug == null
          ? null
          : _bySlug(station.locations, locSlug, (l) => l.slug);
      return loc == null
          ? ''
          : _resolveLocationFacet(loc, facets.skip(1).toList(), chips, format);
    case 'name':
    default:
      return _effectivePersonName(person, portrayer);
  }
}

String _effectivePersonName(Person person, RolePlay? portrayer) =>
    _effectiveField(portrayer?.name, person.name) ?? '';

/// The portraying roleplay's value when non-empty, otherwise the person's
/// own value (ADR-0047's effective-identity rule).
String? _effectiveField(String? roleplayValue, String? personValue) {
  if (roleplayValue != null && roleplayValue.isNotEmpty) return roleplayValue;
  return personValue;
}

/// Formats [latLng] as "32V 0580414E 6552008N" (UTM, easting before
/// northing). Returns empty string when [latLng] is null. Named the same as
/// `station_scenario_tokens.dart`'s non-nullable `formatUtm` (a deliberate,
/// independent editor-side copy, per that file's own doc comment) — the two
/// never share an unqualified import, so the names do not collide.
String formatUtm(LatLng? latLng) {
  if (latLng == null) return '';
  final utm = latLng.utm();
  final e = utm.easting.toStringAsFixed(0).padLeft(7, '0');
  final n = utm.northing.toStringAsFixed(0).padLeft(7, '0');
  return '${utm.zone}${utm.band} ${e}E ${n}N';
}
