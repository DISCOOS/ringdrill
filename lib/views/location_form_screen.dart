import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/services/geocoding_service.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/slug.dart';
import 'package:ringdrill/utils/station_scenario_tokens.dart';
import 'package:ringdrill/views/plan_additions.dart';
import 'package:ringdrill/views/position_form_field.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/editor_token.dart';
import 'package:ringdrill/views/widgets/location_kind_labels.dart';
import 'package:ringdrill/views/widgets/location_kind_style.dart';
import 'package:ringdrill/views/widgets/plan_field_tokens.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_text_field.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';
import 'package:ringdrill/views/widgets/token_text_editing_controller.dart';

/// Debounce before a typed `place` query reaches the geocoder (ADR-0047
/// follow-up 3c) -- long enough to skip a search per keystroke, short
/// enough that suggestions still feel live.
const _placeSearchDebounce = Duration(milliseconds: 350);

/// A declared plan variable name (ADR-0046) -- mirrors
/// `StationFormScreen`'s/`RolePlayFormScreen`'s own copy of this pattern.
final _variableSlugPattern = RegExp(r'^[a-z][a-z0-9_]*$');

/// [LocationFormScreen]'s result: the saved [Location] plus any
/// [PlanAdditions] created inline this session from its own token-aware
/// `place`/`note` fields (ADR-0047, DESIGN-009 follow-up 4/"Inline creation
/// and write-back") -- a new `var.*` (-> `Program`) or a sibling
/// `station.loc.*`/`station.person.*` (-> the station this [Location]
/// itself joins, which this form does not own and never writes to
/// directly). The caller applies both together in one save.
typedef LocationFormResult = ({Location location, PlanAdditions additions});

/// Self-sufficient full-screen/dialog form for creating or editing a
/// station-owned [Location] (ADR-0047, DESIGN-009 follow-up 3b). Opened via
/// `openFormSurface` by the caller (`LocationsSection`) — full-screen route
/// on narrow, dialog on wide (ADR-0030). Pops with a [LocationFormResult],
/// or null on cancel.
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
  late final _placeController = TokenTextEditingController(
    text: widget.initial?.place ?? '',
  );
  late final _noteController = TokenTextEditingController(
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

  /// Working copies of the ambient `StationScope`'s `locations`/`persons`
  /// (ADR-0047, DESIGN-009 "Inline creation and write-back") -- this form
  /// does not own the station a sibling `station.loc.*`/`station.person.*`
  /// created inline from `place`/`note` would join, so it tracks one here
  /// (seeded once in [didChangeDependencies], the same "editor resolves
  /// against a working copy it holds" pattern `RolePlayFormScreen` already
  /// uses) and diffs against [_originalLocationSlugs]/[_originalPersonSlugs]
  /// at save time to carry only the new ones up as a write-back addition.
  late List<Location> _workingLocations;
  late List<Person> _workingPersons;
  late Set<String> _originalLocationSlugs;
  late Set<String> _originalPersonSlugs;

  /// The ambient `PlanScope`'s declared variables as of open time -- this
  /// form does not own `Program.variables` either, so a `var.*` created
  /// inline is tracked in [_pendingVariables] instead and carried up the
  /// same way.
  late List<DrillVariable> _declaredVariables;
  final List<DrillVariable> _pendingVariables = [];

  bool _scopesSeeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scopesSeeded) return;
    _scopesSeeded = true;
    final stationScope = StationScope.maybeOf(context);
    _workingLocations = List<Location>.of(stationScope?.locations ?? const []);
    _workingPersons = List<Person>.of(stationScope?.persons ?? const []);
    _originalLocationSlugs = _workingLocations.map((l) => l.slug).toSet();
    _originalPersonSlugs = _workingPersons.map((p) => p.slug).toSet();
    _declaredVariables = List<DrillVariable>.of(
      PlanScope.of(context).variables,
    );
  }

  @override
  void dispose() {
    _placeSearchDebounceTimer?.cancel();
    _labelController.dispose();
    _placeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Wired to a token-aware field's `onCreateLocation` hook (ADR-0047,
  /// DESIGN-009 follow-up 4/4e): the insertion menu needs the generated
  /// slug synchronously to embed in the token it is about to insert. The new
  /// [Location] joins the same station this [Location] itself joins, which
  /// this form does not own -- [_save] diffs [_workingLocations] against
  /// [_originalLocationSlugs] to carry it up as a write-back.
  String _createStationLocation(String label) {
    final slug = randomSlug(
      (candidate) => _workingLocations.any((l) => l.slug == candidate),
    );
    setState(() {
      _workingLocations = [
        ..._workingLocations,
        Location(slug: slug, label: label),
      ];
    });
    return slug;
  }

  /// [_createStationLocation]'s [_workingPersons] counterpart.
  String _createStationPerson(String label) {
    final slug = randomSlug(
      (candidate) => _workingPersons.any((p) => p.slug == candidate),
    );
    setState(() {
      _workingPersons = [..._workingPersons, Person(slug: slug, name: label)];
    });
    return slug;
  }

  /// Wired to every token-aware field's `onCreateVariable` hook: the menu
  /// already inserted `{{var.<name>}}`; this only needs to declare it,
  /// empty, in [_pendingVariables] so the chip resolves live (amber) via the
  /// merged [PlanScope] this form provides in [build].
  void _createVariableInline(String name) {
    if (!_variableSlugPattern.hasMatch(name)) return;
    final alreadyDeclared = _declaredVariables.any((v) => v.name == name);
    final alreadyPending = _pendingVariables.any((v) => v.name == name);
    if (alreadyDeclared || alreadyPending) return;
    setState(() {
      _pendingVariables.add(DrillVariable(name: name, value: ''));
    });
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

  Future<void> _reverseGeocodeInto(
    LatLng position, {
    bool force = false,
  }) async {
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

  /// This form's own token-aware fields, paired with their display label
  /// (DESIGN-009 follow-up 4e) — mirrors `StationFormScreen`'s own base-field
  /// scan, scoped down to `place`/`note`.
  Iterable<(String label, String text)> _tokenAwareFields(
    AppLocalizations l10n,
  ) sync* {
    yield (l10n.locationsSectionPlaceLabel, _placeController.text);
    yield (l10n.locationsSectionNoteLabel, _noteController.text);
  }

  /// Field labels with an undeclared `{{var.x}}` token — checked against
  /// [_declaredVariables]/[_pendingVariables] (this session's working set,
  /// including anything just created inline), not the ambient `PlanScope`
  /// directly: a variable created inline from one of these fields must not
  /// immediately block save as "undeclared" — mirrors
  /// `StationFormScreen._baseFieldLabelsWithUndeclaredTokens`.
  List<String> _fieldLabelsWithUndeclaredVariable(AppLocalizations l10n) {
    final declared = {
      for (final v in _declaredVariables) v.name,
      for (final v in _pendingVariables) v.name,
    };
    bool hasUndeclared(String text) => planVariableTokenPattern
        .allMatches(text)
        .any((m) => !declared.contains(m.group(1)));
    return [
      for (final (label, text) in _tokenAwareFields(l10n))
        if (hasUndeclared(text)) label,
    ];
  }

  /// The `station.loc.<slug>`/`station.person.<slug>` references in [text]
  /// whose slug is absent from [_workingLocations]/[_workingPersons] (this
  /// session's working set, same reasoning as [_fieldLabelsWithUndeclaredVariable]
  /// -- a sibling entity created inline from one of these fields must not
  /// immediately block save as "unresolved") — mirrors
  /// `StationFormScreen._unresolvedReferencesIn`.
  Iterable<String> _unresolvedReferencesIn(String text) {
    return stationScenarioTokenPattern
        .allMatches(text)
        .where((m) {
          final slug = m.group(2)!;
          return m.group(1) == 'loc'
              ? !_workingLocations.any((loc) => loc.slug == slug)
              : !_workingPersons.any((p) => p.slug == slug);
        })
        .map((m) => 'station.${m.group(1)}.${m.group(2)}');
  }

  List<String> _fieldLabelsWithUnresolvedReference(AppLocalizations l10n) {
    return [
      for (final (label, text) in _tokenAwareFields(l10n))
        if (_unresolvedReferencesIn(text).isNotEmpty) label,
    ];
  }

  Set<String> _unresolvedReferences(AppLocalizations l10n) {
    final refs = <String>{};
    for (final (_, text) in _tokenAwareFields(l10n)) {
      refs.addAll(_unresolvedReferencesIn(text));
    }
    return refs;
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;

    final undeclared = _fieldLabelsWithUndeclaredVariable(l10n);
    if (undeclared.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.programSaveBlockedUndeclaredVariable(undeclared.join(', ')),
          ),
        ),
      );
      return;
    }

    final unresolved = _fieldLabelsWithUnresolvedReference(l10n);
    if (unresolved.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.saveBlockedUnresolvedReference(
              unresolved.join(', '),
              _unresolvedReferences(l10n).join(', '),
            ),
          ),
        ),
      );
      return;
    }

    _formKey.currentState!.save();
    final note = _noteController.text.trim();
    final slug =
        widget.initial?.slug ?? randomSlug(widget.existingSlugs.contains);
    // Write-back (ADR-0047, DESIGN-009 "Inline creation and write-back"):
    // only entries created this session -- beyond what the ambient
    // StationScope already had when this form opened -- need to be carried
    // up; the rest already live on the station this form itself does not
    // own.
    final newLocations = [
      for (final location in _workingLocations)
        if (!_originalLocationSlugs.contains(location.slug)) location,
    ];
    final newPersons = [
      for (final person in _workingPersons)
        if (!_originalPersonSlugs.contains(person.slug)) person,
    ];
    Navigator.of(context).pop((
      location: Location(
        slug: slug,
        label: _labelController.text.trim(),
        kind: _kind,
        place: _placeController.text.trim(),
        position: _position,
        note: note.isEmpty ? null : note,
      ),
      additions: (
        variables: _pendingVariables,
        stationLocations: newLocations,
        stationPersons: newPersons,
        rolePlays: const <RolePlay>[],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _isEdit
        ? l10n.locationsSectionEditAction
        : l10n.locationsSectionAddAction;
    final place = _placeController.text.trim();
    final canUpdateFromMap = _position != null && place.isNotEmpty;
    // Resolvable at station scope and below (DESIGN-009 follow-up 4e) —
    // never `PlanFieldTokens.roleplay`, which only resolves inside a
    // roleplay's own scope, not a station-owned Location's.
    final planFields = [
      ...PlanFieldTokens.program(l10n),
      ...PlanFieldTokens.exercise(l10n),
      ...PlanFieldTokens.station(l10n),
    ];
    // Null for a new location (not yet part of the ambient StationScope, so
    // it cannot appear as a self-reference candidate anyway) — see
    // SelfTokenExclusion.
    final selfSlug = widget.initial?.slug;
    // Captured before this form re-wraps PlanScope/StationScope below (for
    // its own inline-created working copies, ADR-0047) -- `context` here is
    // this State's own, an ancestor of what this build() returns, so it
    // always resolves to the *ambient* scope from `openFormSurface`, never
    // this form's own re-provided one (same reasoning `RolePlayFormScreen`'s
    // own `build` documents).
    final ambientPlan = PlanScope.of(context);
    final ambientStation = StationScope.maybeOf(context);
    return PlanScope(
      variables: [..._declaredVariables, ..._pendingVariables],
      programName: ambientPlan.programName,
      programDescription: ambientPlan.programDescription,
      child: StationScope(
        locations: _workingLocations,
        persons: _workingPersons,
        portrayerOf: ambientStation?.portrayerOf,
        name: ambientStation?.name,
        stationCode: ambientStation?.stationCode,
        description: ambientStation?.description,
        variantSuffix: ambientStation?.variantSuffix,
        positionUtm: ambientStation?.positionUtm,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.cancel,
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(title),
            actions: [
              // "Ferdig"/"Done" when this form only folds its result into a
              // parent's own unsaved working copy (DESIGN-010's
              // FormSurfaceScope) — this form has its own AppBar rather than
              // `SectionNavigatedForm`'s, so it reads the scope directly.
              FilledButton(
                onPressed: _save,
                child: Text(
                  FormSurfaceScope.of(context)
                      ? l10n.formDoneAction
                      : l10n.save,
                ),
              ),
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
                      RingDrillTextField(
                        controller: _placeController,
                        label: l10n.locationsSectionPlaceLabel,
                        hintText: l10n.locationsSectionPlaceSearchHint,
                        tokenAware: true,
                        planFields: planFields,
                        selfLocation: selfSlug == null
                            ? null
                            : SelfTokenExclusion(
                                slug: selfSlug,
                                excludeBare: true,
                                excludedFacet: 'place',
                              ),
                        onCreateVariable: _createVariableInline,
                        onCreateLocation: _createStationLocation,
                        onCreatePerson: _createStationPerson,
                        onChanged: _onPlaceChanged,
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                              tooltip:
                                  l10n.locationsSectionUpdatePlaceFromMapAction,
                              onPressed: _updatePlaceFromMap,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      RingDrillTextArea(
                        controller: _noteController,
                        label: l10n.locationsSectionNoteLabel,
                        minLines: 1,
                        maxLines: 3,
                        tokenAware: true,
                        planFields: planFields,
                        onCreateVariable: _createVariableInline,
                        onCreateLocation: _createStationLocation,
                        onCreatePerson: _createStationPerson,
                      ),
                    ],
                  ),
                ),
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
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
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
