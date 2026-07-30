/// Typed plan-variable values (DESIGN-008 follow-up 11, ADR-0046): the
/// canonical string encoding per [VariableType], input canonicalization and
/// validation for the type-aware editors, override application, and the
/// canonical → formatted display rendering shared by the editor previews,
/// the override tables' parenthesized defaults and `BriefRenderer`.
///
/// Pure and Flutter-free, like `plan_variables.dart`: `BriefRenderer` (and,
/// transitively, the CLI at `bin/ringdrill.dart`) may depend on this, so it
/// must never import `package:flutter/*`. Localized bits (the duration hour
/// unit, the locale name for date/number rendering) are injected via
/// [VariableFormat] by callers that own an `AppLocalizations`.
library;

import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/utils/projection.dart';
import 'package:ringdrill/utils/station_scenario_tokens.dart';

/// Locale-dependent formatting inputs for [formatVariableValue], built by a
/// caller with an `AppLocalizations` (`localeName` = `l10n.localeName`,
/// `hourUnit` = the ARB'd short hour unit, "t" in nb / "h" in en).
class VariableFormat {
  const VariableFormat({required this.localeName, required this.hourUnit});

  final String localeName;
  final String hourUnit;
}

final _timePattern = RegExp(r'^(\d{1,2})[:.](\d{2})$');
final _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _latLngPattern = RegExp(
  r'^(-?\d{1,3}(?:\.\d+)?)\s*[,;\s]\s*(-?\d{1,3}(?:\.\d+)?)$',
);

/// Canonicalizes raw editor [input] for [type], or returns null when the
/// input cannot be read as a value of that type. The empty string is always
/// valid ("declared but empty" is a legal authoring state, ADR-0046) and
/// canonicalizes to itself. [VariableType.location] values are composite
/// (see [decodeLocationValue]) and always canonicalizable — their coordinate
/// *input field* is validated separately via [parseCoordinateInput].
String? canonicalizeVariableValue(VariableType type, String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '';
  switch (type) {
    case VariableType.string:
      return trimmed;
    case VariableType.number:
      // Accept a typed decimal comma (nb keyboards); canonical is `.`.
      final normalized = trimmed.replaceAll(',', '.');
      final parsed = num.tryParse(normalized);
      if (parsed == null || !parsed.isFinite) return null;
      return parsed % 1 == 0 && !normalized.contains('e')
          ? parsed.toInt().toString()
          : normalized;
    case VariableType.time:
      final match = _timePattern.firstMatch(trimmed);
      if (match == null) return null;
      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      if (hour > 23 || minute > 59) return null;
      return '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}';
    case VariableType.date:
      final match = _datePattern.firstMatch(trimmed);
      if (match == null) return null;
      final parsed = DateTime.tryParse(trimmed);
      // DateTime.parse rolls an impossible date over (2026-02-30 becomes
      // 2026-03-02); requiring the round-trip to reproduce the input
      // rejects those instead of silently accepting a different date.
      if (parsed == null || _isoDate(parsed) != trimmed) return null;
      return trimmed;
    case VariableType.duration:
      final minutes = int.tryParse(trimmed);
      if (minutes == null || minutes < 0) return null;
      return minutes.toString();
    case VariableType.location:
      return encodeLocationValue(decodeLocationValue(trimmed));
  }
}

/// True when [value] (a stored canonical value, or a raw override string)
/// reads as a value of [type] — the save gate: an invalid value blocks save
/// exactly as an unknown token does (DESIGN-008 follow-up 11). Empty is
/// valid. Used both for the editors' own inputs and to re-validate existing
/// defaults/overrides after a type change.
bool isVariableValueValid(VariableType type, String value) =>
    canonicalizeVariableValue(type, value) != null;

/// The canonical string encoding of [variable]'s own declared default —
/// [DrillVariable.value] for scalar types, the encoded [DrillVariable.location]
/// for [VariableType.location]. This is the string shape `variableOverrides`
/// maps carry for the type (ADR-0046's value-only override maps predate
/// typed variables, so a location override is carried in this encoding).
String canonicalVariableValue(DrillVariable variable) =>
    variable.type == VariableType.location
    ? encodeLocationValue(variable.location ?? const VariableLocation())
    : variable.value;

/// Encodes a location value as its canonical string: `lat,lng` (6-decimal,
/// `.` separator) followed by a space and the place text when both are set;
/// just the coordinate, or just the place text, when only one is. Chosen to
/// stay human-readable where an older client substitutes it literally.
String encodeLocationValue(VariableLocation location) {
  final position = location.position;
  final place = location.place.trim();
  if (position == null) return place;
  final coordinate =
      '${position.latitude.toStringAsFixed(6)},'
      '${position.longitude.toStringAsFixed(6)}';
  return place.isEmpty ? coordinate : '$coordinate $place';
}

/// Decodes [encodeLocationValue]'s canonical string. A leading `lat,lng`
/// (within range) becomes the position and the remainder the place text; a
/// string with no readable coordinate is all place text, mirroring a
/// `Location` whose `position` is unset.
VariableLocation decodeLocationValue(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return const VariableLocation();
  final match = RegExp(
    r'^(-?\d{1,3}(?:\.\d+)?),(-?\d{1,3}(?:\.\d+)?)(?:\s+(.*))?$',
  ).firstMatch(trimmed);
  if (match != null) {
    final lat = double.parse(match.group(1)!);
    final lng = double.parse(match.group(2)!);
    if (lat.abs() <= 90 && lng.abs() <= 180) {
      return VariableLocation(
        place: (match.group(3) ?? '').trim(),
        position: LatLng(lat, lng),
      );
    }
  }
  return VariableLocation(place: trimmed);
}

/// Parses free coordinate input — a decimal `lat,lng` pair or a UTM string,
/// typed or pasted — to a [LatLng], or null when it reads as neither.
/// Reuses the DESIGN-009 UTM parse (`projection.dart`'s `toLatLngFromUtm`)
/// rather than reimplementing it.
LatLng? parseCoordinateInput(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final match = _latLngPattern.firstMatch(trimmed);
  if (match != null) {
    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180) {
      return LatLng(lat, lng);
    }
    return null;
  }
  // The app's own UTM display ("32V 0580414E 6552008N") suffixes easting/
  // northing with E/N; `toLatLngFromUtm`'s grammar takes bare numbers, so a
  // string pasted straight out of a brief needs those stripped first.
  final normalized = trimmed
      .replaceAll(RegExp(r'(?<=\d)\s*[eE](?=[\s,]|$)'), '')
      .replaceAll(RegExp(r'(?<=\d)\s*[nN](?=[\s,]|$)'), '');
  final fromUtm = normalized.toLatLngFromUtm();
  if (fromUtm != null &&
      fromUtm.latitude.isFinite &&
      fromUtm.longitude.isFinite) {
    return fromUtm;
  }
  return null;
}

/// Applies a scope's string [override] to the declared [variable] (ADR-0046
/// value-only overrides): scalar types replace [DrillVariable.value], a
/// location override decodes into [DrillVariable.location]. Null (no
/// override at this scope) returns [variable] unchanged.
DrillVariable applyVariableOverride(DrillVariable variable, String? override) {
  if (override == null) return variable;
  if (variable.type == VariableType.location) {
    return variable.copyWith(location: decodeLocationValue(override));
  }
  return variable.copyWith(value: override);
}

/// Renders [variable]'s effective value for display (canonical → formatted,
/// DESIGN-008 follow-up 11): a number in the locale's decimal notation
/// (grouping off — `2026` stays `2026`), a time as `HH:MM`, a date as a
/// localized long date, a duration as "45 min" / "1 t 30 min", a location
/// as place + UTM (the bare-token rendering). A value that does not read as
/// its declared type — e.g. after a type change — renders as its raw text
/// rather than being dropped. Strings render as-is.
String formatVariableValue(DrillVariable variable, VariableFormat format) {
  switch (variable.type) {
    case VariableType.string:
      return variable.value;
    case VariableType.number:
      return _formatNumber(variable.value, format);
    case VariableType.time:
      return canonicalizeVariableValue(VariableType.time, variable.value) ??
          variable.value;
    case VariableType.date:
      return _formatDate(variable.value, format);
    case VariableType.duration:
      return _formatDuration(variable.value, format);
    case VariableType.location:
      return locationPlaceUtm(variableLocationAsLocation(variable));
  }
}

/// [variable]'s location value projected onto the `Location` model shape
/// (slug = the variable name, kind left at its default), so the DESIGN-009
/// location facet code (`resolveLocationFacet`, UTM formatting) is reused
/// for `{{var.<name>.place/.position}}` instead of being forked.
Location variableLocationAsLocation(DrillVariable variable) {
  final location = variable.location ?? const VariableLocation();
  return Location(
    slug: variable.name,
    place: location.place,
    position: location.position,
  );
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _formatNumber(String canonical, VariableFormat format) {
  final value = canonicalizeVariableValue(VariableType.number, canonical);
  if (value == null || value.isEmpty) return canonical;
  final parsed = num.parse(value);
  try {
    // Grouping off: a year-like 2026 must render "2026", not "2 026"; the
    // locale only contributes its decimal separator ("3,14" in nb).
    final pattern = NumberFormat.decimalPattern(format.localeName)
      ..turnOffGrouping()
      ..maximumFractionDigits = 10;
    return pattern.format(parsed);
  } catch (_) {
    // Unknown locale (e.g. a bare-Dart context without the locale's number
    // symbols) — the canonical string is already readable.
    return value;
  }
}

String _formatDate(String canonical, VariableFormat format) {
  final value = canonicalizeVariableValue(VariableType.date, canonical);
  if (value == null || value.isEmpty) return canonical;
  final parsed = DateTime.parse(value);
  try {
    return DateFormat.yMMMMd(format.localeName).format(parsed);
  } catch (_) {
    // Date symbols for the locale not loaded (bare-Dart context, e.g. the
    // CLI) — fall back to the canonical ISO date rather than throwing.
    return value;
  }
}

String _formatDuration(String canonical, VariableFormat format) {
  final value = canonicalizeVariableValue(VariableType.duration, canonical);
  if (value == null || value.isEmpty) return canonical;
  final minutes = int.parse(value);
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '$hours ${format.hourUnit}';
  return '$hours ${format.hourUnit} $rest min';
}
