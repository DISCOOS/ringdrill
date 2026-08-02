import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/widgets/adaptive_time_picker.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/services/geocoding_service.dart';
import 'package:ringdrill/utils/station_scenario_tokens.dart';
import 'package:ringdrill/utils/variable_values.dart';
import 'package:ringdrill/views/position_form_field.dart';
import 'package:ringdrill/views/widgets/variable_type_labels.dart';

/// Debounce before a typed `place` query reaches the geocoder — same value
/// as `LocationFormScreen`'s (ADR-0047 follow-up 3c).
const _placeSearchDebounce = Duration(milliseconds: 350);

/// Tight prefix/suffix icon box for a field's type icon and clear action —
/// without this, `InputDecoration`'s default 48x48 minimum tap-target box
/// forces the field taller than its own text, throwing the icon and value
/// off-center against each other. `minHeight: 0` is the important part: a
/// non-zero minimum here still out-grows the text's own line height and
/// reintroduces the stretch.
const _iconConstraints = BoxConstraints(minWidth: 24, minHeight: 0);

/// Type-aware input for one plan variable's value (DESIGN-008 follow-up 11),
/// shared by the declaration surface's default-value field and the
/// exercise/station override surfaces' local-value field.
///
/// Scalar types render a single input matched to [type]: free text
/// (`string`), a validated numeric field (`number`), a 24-hour time picker
/// (`time`), a date picker (`date`), a whole-minutes field (`duration`).
/// `location` renders the composite place + coordinate + map-picker input,
/// reusing the DESIGN-009 machinery: `PositionFormField`/`MapPickerScreen`
/// for the map, [GeocodingService] (`osm_nominatim`) for address search and
/// reverse lookup, and `projection.dart`'s lat/lng + UTM parsing for typed
/// or pasted coordinates.
///
/// An invalid value surfaces inline via the field's own validator; the
/// *save gate* itself is state-level in the owning form (a section that is
/// not currently mounted still blocks), see `isVariableValueValid`.
///
/// [value] is the scalar value as last reported (canonical or still-raw
/// user input — canonicalization happens at save); [location] carries the
/// structured value when [type] is [VariableType.location]. Both are owned
/// by the caller; every edit reports the whole new value through
/// [onChanged]. An all-empty value means "no value" — the declaration
/// surface reads that as declared-but-empty (amber, ADR-0046), an override
/// surface as "inherit".
class VariableValueField extends StatefulWidget {
  const VariableValueField({
    super.key,
    required this.type,
    required this.value,
    this.location,
    this.hintText,
    this.accent = false,
    this.geocodingService,
    required this.onChanged,
  });

  final VariableType type;
  final String value;
  final VariableLocation? location;

  /// Placeholder for the empty state (e.g. the override surfaces' "Lokal
  /// verdi").
  final String? hintText;

  /// True when this field is the current scope's local override, not the
  /// inherited default (DESIGN-008 follow-up 12, `variable-overrides.html`):
  /// tints the field's border with the app's accent color so an overridden
  /// row is visually distinct from an inherited one at a glance. The
  /// declaration surface (no such concept) always leaves this false.
  final bool accent;

  /// Geocoder for the location input's place lookups. Defaults to the real
  /// `osm_nominatim`-backed service; tests inject a fake so no test hits
  /// the network.
  final GeocodingService? geocodingService;

  /// Called with the whole new value on every edit. [VariableLocation] is
  /// non-null only for [VariableType.location]; the scalar string is empty
  /// there (a location's value lives in the structured part, ADR-0046
  /// amendment for DESIGN-008 follow-up 11).
  final void Function(String value, VariableLocation? location) onChanged;

  @override
  State<VariableValueField> createState() => _VariableValueFieldState();
}

class _VariableValueFieldState extends State<VariableValueField> {
  late final GeocodingService _geocoder =
      widget.geocodingService ?? NominatimGeocodingService();

  late final TextEditingController _scalarController = TextEditingController(
    text: widget.value,
  );

  // --- location state ---
  late final TextEditingController _placeController = TextEditingController(
    text: widget.location?.place ?? '',
  );
  late final TextEditingController _coordinateController =
      TextEditingController(
        text: _coordinateDisplay(widget.location?.position),
      );
  late LatLng? _position = widget.location?.position;

  Timer? _placeSearchDebounceTimer;
  int _placeSearchGeneration = 0;
  List<GeocodingHit> _placeSuggestions = const [];
  bool _searchingPlace = false;
  String? _lastAppliedPlace;

  /// The scalar value this field last pushed through [widget.onChanged] —
  /// lets [didUpdateWidget] tell "the parent reset/replaced the value from
  /// outside" (re-seed the controller) apart from "the parent echoed my own
  /// edit back" (leave the text being typed alone).
  late String _lastReportedValue = widget.value;

  /// Same outside-change detection for the composite location value,
  /// compared in its canonical encoding: the parent stores/echoes exactly
  /// what [_reportLocation] emitted (possibly trimmed/rounded by the
  /// encoding), so comparing encodings — rather than the raw controller
  /// text — never mistakes a canonicalized echo of our own edit for an
  /// outside change and never rewrites text under the caret.
  late String _lastReportedLocation = encodeLocationValue(
    widget.location ?? const VariableLocation(),
  );

  @override
  void didUpdateWidget(covariant VariableValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _lastReportedValue) {
      _lastReportedValue = widget.value;
      _scalarController.text = widget.value;
    }
    if (widget.type == VariableType.location) {
      final incoming = widget.location ?? const VariableLocation();
      final incomingEncoded = encodeLocationValue(incoming);
      if (incomingEncoded != _lastReportedLocation) {
        _lastReportedLocation = incomingEncoded;
        _position = incoming.position;
        _coordinateController.text = _coordinateDisplay(incoming.position);
        _placeController.text = incoming.place;
      }
    }
  }

  @override
  void dispose() {
    _placeSearchDebounceTimer?.cancel();
    _scalarController.dispose();
    _placeController.dispose();
    _coordinateController.dispose();
    super.dispose();
  }

  static String _coordinateDisplay(LatLng? position) =>
      position == null ? '' : formatUtm(position);

  /// Overlays [widget.accent]'s tinted border onto [decoration] — a plain
  /// [UnderlineInputBorder] in the app's accent color, the same
  /// `colorScheme.primary` role the "Tilbakestill" action and every chip
  /// already use for "this is the active/overridden one", rather than a new
  /// box-style component. Returns [decoration] unchanged when not accented,
  /// so the declaration surface's fields (never accented) keep the app's
  /// default input look exactly as before.
  InputDecoration _accented(InputDecoration decoration, ThemeData theme) {
    if (!widget.accent) return decoration;
    final border = UnderlineInputBorder(
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
    );
    return decoration.copyWith(enabledBorder: border, focusedBorder: border);
  }

  void _reportScalar(String value) {
    _lastReportedValue = value;
    widget.onChanged(value, null);
  }

  void _reportLocation() {
    final place = _placeController.text.trim();
    final location = VariableLocation(place: place, position: _position);
    _lastReportedLocation = encodeLocationValue(location);
    widget.onChanged('', location);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (widget.type) {
      VariableType.string => _buildText(l10n),
      VariableType.number => _buildText(
        l10n,
        keyboardType: const TextInputType.numberWithOptions(
          signed: true,
          decimal: true,
        ),
      ),
      VariableType.duration => _buildText(
        l10n,
        keyboardType: TextInputType.number,
        prefixIcon: widget.type.icon,
        suffixText: 'min',
      ),
      VariableType.time => _buildPicker(l10n, onTap: () => _pickTime(l10n)),
      VariableType.date => _buildPicker(l10n, onTap: () => _pickDate(l10n)),
      VariableType.location => _buildLocation(l10n),
    };
  }

  Widget _buildText(
    AppLocalizations l10n, {
    TextInputType? keyboardType,
    IconData? prefixIcon,
    String? suffixText,
  }) {
    return TextFormField(
      controller: _scalarController,
      keyboardType: keyboardType,
      decoration: _accented(
        InputDecoration(
          hintText: widget.hintText,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 18),
          // Without this, the icon's default 48x48 minimum tap-target box
          // forces the field taller than its text, so the icon sits
          // noticeably off-center against the value — shrink the box to
          // the icon's own size instead.
          prefixIconConstraints: prefixIcon == null ? null : _iconConstraints,
          suffixText: suffixText,
        ),
        Theme.of(context),
      ),
      autovalidateMode: AutovalidateMode.always,
      validator: (_) => _scalarError(l10n),
      onChanged: _reportScalar,
    );
  }

  /// Read-only field driving a picker ([VariableType.time]/[date]): shows
  /// the formatted value (or the raw text when it does not read as the type
  /// — surfaced invalid rather than silently dropped, e.g. after a type
  /// change), with a clear action so a set value can go back to empty.
  Widget _buildPicker(AppLocalizations l10n, {required VoidCallback onTap}) {
    final display = widget.value.isEmpty
        ? ''
        : formatVariableValue(
            DrillVariable(name: 'x', value: widget.value, type: widget.type),
            variableFormatOf(l10n),
          );
    return TextFormField(
      key: ValueKey('${widget.type.name}:${widget.value}'),
      initialValue: display,
      readOnly: true,
      onTap: onTap,
      decoration: _accented(
        InputDecoration(
          hintText: widget.hintText,
          prefixIcon: Icon(widget.type.icon, size: 18),
          // Same fix as `_buildText`'s prefixIcon: shrink both icon boxes to
          // their own size so the field's icons and value text line up on
          // the same baseline instead of the icons' default 48x48
          // tap-target box stretching the row taller than the text.
          prefixIconConstraints: _iconConstraints,
          suffixIconConstraints: _iconConstraints,
          // A bare Icon in an InkWell, not IconButton: IconButton enforces
          // its own ~48px minimum tap target internally regardless of the
          // constraints handed to the outer suffixIcon slot, which was
          // still stretching this field taller than the icon-less ones and
          // vertically centering the text in that extra space instead of
          // sitting it on the underline.
          suffixIcon: widget.value.isEmpty
              ? null
              : Tooltip(
                  message: l10n.variableOverridesSectionResetAction,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _reportScalar(''),
                    child: const Icon(Icons.clear, size: 18),
                  ),
                ),
        ),
        Theme.of(context),
      ),
      autovalidateMode: AutovalidateMode.always,
      validator: (_) => _scalarError(l10n),
    );
  }

  String? _scalarError(AppLocalizations l10n) =>
      isVariableValueValid(widget.type, _currentScalarValue)
      ? null
      : widget.type.invalidValueMessage(l10n);

  String get _currentScalarValue => switch (widget.type) {
    VariableType.time || VariableType.date => widget.value,
    _ => _scalarController.text,
  };

  Future<void> _pickTime(AppLocalizations l10n) async {
    final current = canonicalizeVariableValue(VariableType.time, widget.value);
    TimeOfDay initial = const TimeOfDay(hour: 12, minute: 0);
    if (current != null && current.isNotEmpty) {
      final parts = current.split(':');
      initial = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
    // Through the shared picker, which owns the 24-hour rule (DESIGN-008 follow-up
    // 11) and the Cupertino wheel on iOS. This used to force the format itself and
    // show the Material dialog everywhere, so it was the only surface where the app
    // asked for a time in two different ways depending on where you were.
    final picked = await pickAdaptiveTime(context, initialTime: initial);
    if (picked == null) return;
    _reportScalar(
      '${picked.hour.toString().padLeft(2, '0')}:'
      '${picked.minute.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _pickDate(AppLocalizations l10n) async {
    final current = canonicalizeVariableValue(VariableType.date, widget.value);
    final initial = current == null || current.isEmpty
        ? DateTime.now()
        : DateTime.parse(current);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _reportScalar(
      '${picked.year.toString().padLeft(4, '0')}-'
      '${picked.month.toString().padLeft(2, '0')}-'
      '${picked.day.toString().padLeft(2, '0')}',
    );
  }

  // --- location input (reuses the DESIGN-009 Location machinery) ---

  Widget _buildLocation(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _placeController,
          onChanged: _onPlaceChanged,
          decoration: _accented(
            InputDecoration(
              labelText: l10n.locationsSectionPlaceLabel,
              hintText: l10n.locationsSectionPlaceSearchHint,
              suffixIcon: _searchingPlace
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            theme,
          ),
        ),
        if (_placeSuggestions.isNotEmpty)
          _PlaceSuggestionsList(
            suggestions: _placeSuggestions,
            onSelect: _selectPlaceSuggestion,
          ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _coordinateController,
          onChanged: _onCoordinateChanged,
          decoration: _accented(
            InputDecoration(
              labelText: l10n.variableLocationCoordinateLabel,
              hintText: l10n.variableLocationCoordinateHint,
            ),
            theme,
          ),
          autocorrect: false,
          enableSuggestions: false,
          autovalidateMode: AutovalidateMode.always,
          validator: (_) => _coordinateError(l10n),
        ),
        const SizedBox(height: 8),
        PositionFormField<int>(
          title: l10n.placement,
          key: ValueKey(_position),
          variant: PositionFieldVariant.card,
          showThumbnail: true,
          initialValue: _position,
          onSaved: (_) {},
          onChanged: _onPositionPicked,
        ),
      ],
    );
  }

  String? _coordinateError(AppLocalizations l10n) {
    final text = _coordinateController.text.trim();
    if (text.isEmpty) return null;
    // The field shows the canonical UTM of the current position after a
    // map pick / suggestion — that text is by construction parseable, so
    // only genuinely unreadable input errors here.
    return parseCoordinateInput(text) == null
        ? l10n.variableValueInvalidCoordinate
        : null;
  }

  void _onCoordinateChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _position = null);
      _reportLocation();
      return;
    }
    final parsed = parseCoordinateInput(trimmed);
    // Unparseable text keeps the previous position: it surfaces inline via
    // the validator and blocks save; nothing is silently dropped.
    if (parsed == null) {
      setState(() {});
      return;
    }
    setState(() => _position = parsed);
    _reportLocation();
  }

  void _onPositionPicked(LatLng position) {
    setState(() {
      _position = position;
      _coordinateController.text = _coordinateDisplay(position);
    });
    _reportLocation();
    // Best-effort reverse geocode into an *empty* place, mirroring
    // LocationFormScreen: never overwrites text the author already typed.
    if (_placeController.text.trim().isEmpty) {
      unawaited(_reverseGeocodeInto(position));
    }
  }

  void _onPlaceChanged(String value) {
    _placeSearchDebounceTimer?.cancel();
    _reportLocation();
    if (value == _lastAppliedPlace) {
      setState(() => _placeSuggestions = const []);
      return;
    }
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _placeSuggestions = const [];
        _searchingPlace = false;
      });
      return;
    }
    setState(() => _searchingPlace = true);
    _placeSearchDebounceTimer = Timer(_placeSearchDebounce, () {
      unawaited(_searchPlace(query));
    });
  }

  Future<void> _searchPlace(String query) async {
    final generation = ++_placeSearchGeneration;
    List<GeocodingHit> hits;
    try {
      hits = await _geocoder.search(query, near: _position);
    } catch (_) {
      // Best-effort (ADR-0047 follow-up 3c): offline/error is a silent
      // no-op, same as a zero-result search.
      hits = const [];
    }
    if (!mounted || generation != _placeSearchGeneration) return;
    setState(() {
      _searchingPlace = false;
      _placeSuggestions = hits;
    });
  }

  void _selectPlaceSuggestion(GeocodingHit hit) {
    setState(() {
      _lastAppliedPlace = hit.label;
      _placeController.text = hit.label;
      _position = hit.position;
      _coordinateController.text = _coordinateDisplay(hit.position);
      _placeSuggestions = const [];
    });
    _reportLocation();
  }

  Future<void> _reverseGeocodeInto(LatLng position) async {
    String label;
    try {
      label = await _geocoder.reverse(position);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    // Re-check emptiness at completion time — the author may have typed
    // something while the lookup was in flight.
    if (_placeController.text.trim().isNotEmpty) return;
    setState(() {
      _lastAppliedPlace = label;
      _placeController.text = label;
    });
    _reportLocation();
  }
}

/// Compact suggestion list under the `place` field, rendered inline — same
/// shape as `LocationFormScreen`'s.
class _PlaceSuggestionsList extends StatelessWidget {
  const _PlaceSuggestionsList({
    required this.suggestions,
    required this.onSelect,
  });

  final List<GeocodingHit> suggestions;
  final ValueChanged<GeocodingHit> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final hit in suggestions)
            ListTile(
              dense: true,
              leading: const Icon(Icons.location_on_outlined),
              title: Text(hit.label, overflow: TextOverflow.ellipsis),
              onTap: () => onSelect(hit),
            ),
        ],
      ),
    );
  }
}
