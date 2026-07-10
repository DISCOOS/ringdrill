import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/services/geocoding_service.dart';
import 'package:ringdrill/utils/slug.dart';
import 'package:ringdrill/views/position_form_field.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/location_kind_labels.dart';
import 'package:ringdrill/views/widgets/location_kind_style.dart';

/// Debounce before a typed `place` query reaches the geocoder (ADR-0047
/// follow-up 3c) -- long enough to skip a search per keystroke, short
/// enough that suggestions still feel live.
const _placeSearchDebounce = Duration(milliseconds: 350);

/// Self-sufficient full-screen/dialog form for creating or editing a
/// station-owned [Location] (ADR-0047, DESIGN-009 follow-up 3b). Opened via
/// `openFormSurface` by the caller (`LocationsSection`) — full-screen route
/// on narrow, dialog on wide (ADR-0030). Pops with the saved [Location], or
/// null on cancel.
///
/// The reference (`slug`) is never shown: it is a random id generated at
/// creation via [randomSlug] against [existingSlugs] (DESIGN-009 follow-up
/// 4h — derived from no field) and carries through unchanged when [initial]
/// is edited (there is no rename, ADR-0047). `place` is a geocoder-backed search
/// (DESIGN-009 follow-up 3c): typing debounces into a forward-geocode
/// lookup whose suggestions set both `place` and `position`; setting a
/// position with an empty `place` reverse-geocodes to fill it. Both
/// directions are best-effort — offline, an error or no result is a silent
/// no-op and never blocks save — and neither ever overwrites text the
/// author already typed; an explicit reverse-geocode refresh action (a
/// refresh icon over the position card's thumbnail) offers that instead.
class LocationFormScreen extends StatefulWidget {
  const LocationFormScreen({
    super.key,
    required this.existingSlugs,
    this.initial,
    this.geocodingService,
  });

  /// Slugs already used by other locations on the station, so a new
  /// reference never collides. Excludes [initial]'s own slug when editing.
  final Set<String> existingSlugs;

  final Location? initial;

  /// Geocoder for the `place` field's forward/reverse lookups. Defaults to
  /// the real `osm_nominatim`-backed service; tests inject a fake so no
  /// test hits the network.
  final GeocodingService? geocodingService;

  @override
  State<LocationFormScreen> createState() => _LocationFormScreenState();
}

class _LocationFormScreenState extends State<LocationFormScreen> {
  late final GeocodingService _geocoder =
      widget.geocodingService ?? NominatimGeocodingService();

  final _formKey = GlobalKey<FormState>();
  late final _labelController = TextEditingController(
    text: widget.initial?.label ?? '',
  );
  late final _placeController = TextEditingController(
    text: widget.initial?.place ?? '',
  );
  late final _noteController = TextEditingController(
    text: widget.initial?.note ?? '',
  );
  late LocationKind _kind = widget.initial?.kind ?? LocationKind.other;
  late LatLng? _position = widget.initial?.position;

  Timer? _placeSearchDebounceTimer;

  /// Incremented on every place search; a completed lookup is only applied
  /// if it is still the latest one, so a slow response to an earlier
  /// keystroke can never clobber a faster response to a later one.
  int _placeSearchGeneration = 0;
  List<GeocodingHit> _placeSuggestions = const [];
  bool _searchingPlace = false;

  /// True once a place search has completed (successfully or not) with no
  /// hits, so the "no matches" caption only shows after a real attempt —
  /// never for an empty/untouched field.
  bool _placeSearchedEmpty = false;

  /// The label most recently applied by [_selectPlaceSuggestion] — lets
  /// [_onPlaceChanged] tell "the author picked a suggestion" (skip
  /// re-searching the exact text just applied) apart from "the author kept
  /// typing" (search again), without depending on whether setting
  /// `TextEditingController.text` itself re-fires `onChanged`.
  String? _lastAppliedPlace;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _placeSearchDebounceTimer?.cancel();
    _labelController.dispose();
    _placeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onPlaceChanged(String value) {
    _placeSearchDebounceTimer?.cancel();
    if (value == _lastAppliedPlace) {
      setState(() => _placeSuggestions = const []);
      return;
    }
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _placeSuggestions = const [];
        _placeSearchedEmpty = false;
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
      _placeSearchedEmpty = hits.isEmpty;
    });
  }

  void _selectPlaceSuggestion(GeocodingHit hit) {
    setState(() {
      _lastAppliedPlace = hit.label;
      _placeController.text = hit.label;
      _position = hit.position;
      _placeSuggestions = const [];
      _placeSearchedEmpty = false;
    });
  }

  /// Wired to the position field's `onChanged` (map-pick or forward-geocode
  /// pick). Reverse-geocodes to fill an *empty* place; a non-empty place is
  /// never overwritten automatically (`_updatePlaceFromMap` is the explicit
  /// opt-in for that).
  void _onPositionChanged(LatLng position) {
    setState(() => _position = position);
    if (_placeController.text.trim().isEmpty) {
      unawaited(_reverseGeocodeInto(position));
    }
  }

  Future<void> _updatePlaceFromMap() async {
    final position = _position;
    if (position == null) return;
    await _reverseGeocodeInto(position, force: true);
  }

  Future<void> _reverseGeocodeInto(LatLng position, {bool force = false}) async {
    String label;
    try {
      label = await _geocoder.reverse(position);
    } catch (_) {
      // Best-effort: offline/error is a silent no-op.
      return;
    }
    if (!mounted) return;
    // Re-check emptiness at completion time, not just at call time: the
    // author may have typed something while the lookup was in flight.
    if (!force && _placeController.text.trim().isNotEmpty) return;
    setState(() {
      _lastAppliedPlace = label;
      _placeController.text = label;
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();
    final note = _noteController.text.trim();
    final slug = widget.initial?.slug ?? randomSlug(widget.existingSlugs.contains);
    Navigator.of(context).pop(
      Location(
        slug: slug,
        label: _labelController.text.trim(),
        kind: _kind,
        place: _placeController.text.trim(),
        position: _position,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _isEdit
        ? l10n.locationsSectionEditAction
        : l10n.locationsSectionAddAction;
    final place = _placeController.text.trim();
    final canUpdateFromMap = _position != null && place.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title),
        actions: [
          FilledButton(onPressed: _save, child: Text(l10n.save)),
          const SizedBox(width: 16),
        ],
      ),
      body: DismissKeyboard(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _labelController,
                    autofocus: !_isEdit,
                    decoration: InputDecoration(
                      labelText: l10n.locationsSectionLabelLabel,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _KindCategoryGrid(
                    value: _kind,
                    onChanged: (kind) => setState(() => _kind = kind),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _placeController,
                    onChanged: _onPlaceChanged,
                    decoration: InputDecoration(
                      labelText: l10n.locationsSectionPlaceLabel,
                      hintText: l10n.locationsSectionPlaceSearchHint,
                      suffixIcon: _searchingPlace
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (_placeSuggestions.isNotEmpty)
                    _PlaceSuggestionsList(
                      suggestions: _placeSuggestions,
                      onSelect: _selectPlaceSuggestion,
                    )
                  else if (_placeSearchedEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.locationsSectionPlaceNoResults,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  PositionFormField<int>(
                    key: ValueKey(_position),
                    variant: PositionFieldVariant.card,
                    showThumbnail: true,
                    initialValue: _position,
                    onSaved: (value) => _position = value,
                    onChanged: _onPositionChanged,
                    overlayActions: [
                      if (canUpdateFromMap)
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: l10n.locationsSectionUpdatePlaceFromMapAction,
                          onPressed: _updatePlaceFromMap,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.locationsSectionNoteLabel,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact suggestion list under the `place` field, rendered inline (not an
/// overlay) since the field lives in a `SingleChildScrollView`, not a
/// `Stack` like the map's own search box.
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

/// `label`/`kind` category grid: 2-up cards, the current [value] highlighted.
/// Starts collapsed to a short, commonly-used subset (plus [value] itself,
/// so an unusual existing kind is never hidden), with a "Vis alle N
/// kategorier" expansion to the full [LocationKind] set.
class _KindCategoryGrid extends StatefulWidget {
  const _KindCategoryGrid({required this.value, required this.onChanged});

  final LocationKind value;
  final ValueChanged<LocationKind> onChanged;

  @override
  State<_KindCategoryGrid> createState() => _KindCategoryGridState();
}

class _KindCategoryGridState extends State<_KindCategoryGrid> {
  static const _collapsedKinds = [
    LocationKind.rendezvous,
    LocationKind.home,
    LocationKind.observation,
    LocationKind.lkp,
  ];

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final visible = _expanded
        ? LocationKind.values
        : {..._collapsedKinds, widget.value}.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.locationsSectionKindLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Width-robust: tiles keep a fixed size and the column count grows
          // with the available width, instead of two fixed columns whose
          // fixed aspect ratio ballooned the tile height inside the wide
          // `showRingdrillFormDialog` (maxWidth 720) surface. Same component
          // now renders identically on narrow and wide.
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 48,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          children: [
            for (final kind in visible)
              _KindCard(
                kind: kind,
                selected: kind == widget.value,
                onTap: () => widget.onChanged(kind),
              ),
          ],
        ),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _expanded
                  ? l10n.locationsSectionShowFewerKinds
                  : l10n.locationsSectionShowAllKinds(
                      LocationKind.values.length,
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final LocationKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(kind.icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                kind.label(l10n),
                style: theme.textTheme.bodySmall?.copyWith(color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

