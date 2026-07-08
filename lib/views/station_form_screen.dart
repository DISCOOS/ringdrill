import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/slug.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/plan_additions.dart';
import 'package:ringdrill/views/position_form_field.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/locations_section.dart';
import 'package:ringdrill/views/widgets/persons_section.dart';
import 'package:ringdrill/views/widgets/plan_field_tokens.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_text_field.dart';
import 'package:ringdrill/views/widgets/section_navigated_form.dart';
import 'package:ringdrill/views/widgets/station_scope.dart';
import 'package:ringdrill/views/widgets/token_text_editing_controller.dart';
import 'package:ringdrill/views/widgets/variable_overrides_section.dart';

/// Optional addable markdown sections on [Station] (DESIGN-004).
enum _StationSection {
  equipment,
  situation,
  mission,
  logistics,
  criticalQuestions,
  leaderAnswers,
  directorNotes,
}

/// [StationFormScreen]'s result: the saved [Station] plus any [PlanAdditions]
/// created inline this session (ADR-0047, DESIGN-009 follow-up 4). Only
/// `variables` is ever populated — a station's own new locations/persons go
/// straight into its returned [Station] (it owns them directly), never
/// through the write-back payload.
typedef StationFormResult = ({Station station, PlanAdditions additions});

/// ADR-0046's declared-variable-name rule — see `ExerciseFormScreen`'s own
/// copy of this same one-line RegExp for why it is duplicated per editor.
final _variableSlugPattern = RegExp(r'^[a-z][a-z0-9_]*$');

class StationFormScreen extends StatefulWidget {
  const StationFormScreen({
    super.key,
    required this.station,
    this.markers = const <MapMarkerSpec<(String, int)>>[],
    this.variables = const <DrillVariable>[],
    this.parentExercise,
  });

  final Station station;
  final List<MapMarkerSpec<(String, int)>> markers;

  /// The plan's declared variables (ADR-0046), read-only here — this editor
  /// edits a `Station`, not the `Program` (DESIGN-008 follow-up 07's
  /// settled scope, same as `ExerciseFormScreen`). Every call site passes
  /// `program.variables`.
  final List<DrillVariable> variables;

  /// The enclosing `Exercise`, needed to compute this station's inherited
  /// baseline (ADR-0046): the plan's declared defaults overlaid by this
  /// exercise's overrides. Optional — a station opened without its parent
  /// exercise in context degrades to a program-only baseline.
  final Exercise? parentExercise;

  @override
  State<StationFormScreen> createState() => _StationFormScreenState();
}

class _StationFormScreenState extends State<StationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  LatLng? _position;

  // Form field controllers
  /// Token-aware so `RingDrillTextField`/`RingDrillTextArea`
  /// (`tokenAware: true`) can drive their chips from [PlanScope]
  /// (DESIGN-008 follow-up 09).
  final TextEditingController _nameController = TokenTextEditingController(
    text: "Station",
  );
  final TextEditingController _descriptionController =
      TokenTextEditingController();

  /// Token-aware so `RingDrillTextArea(tokenAware: true)` can drive its
  /// chips from [PlanScope].
  final Map<_StationSection, TextEditingController> _sectionControllers = {
    for (final s in _StationSection.values) s: TokenTextEditingController(),
  };
  final Map<_StationSection, FocusNode> _sectionFocusNodes = {
    for (final s in _StationSection.values) s: FocusNode(),
  };
  final Set<_StationSection> _activeSections = {};

  /// Working copy of `station.variableOverrides` (DESIGN-008 follow-up 07),
  /// edited by [VariableOverridesSection] and read by [_saveStation].
  late Map<String, String> _workingOverrides;

  /// Working copies of `station.locations`/`persons` (DESIGN-009 prompt 3),
  /// edited by [LocationsSection]/[PersonsSection] and read by
  /// [_saveStation]. A person's `homeSlug` can be left dangling by deleting
  /// the location it points at — that guard is DESIGN-009 prompt 5, not
  /// implemented here.
  late List<Location> _workingLocations;
  late List<Person> _workingPersons;

  /// New plan variables created inline from a token field this session
  /// (ADR-0047, DESIGN-009 follow-up 4 — un-defers DESIGN-008's parked
  /// "create a variable from a sub-editor"). A `Station` cannot declare
  /// variables itself; these are returned as [PlanAdditions] for the caller
  /// to apply to `Program` alongside this station's own save.
  final List<DrillVariable> _pendingVariables = [];

  /// This station's inherited baseline (ADR-0046): the plan's declared
  /// defaults overlaid by [StationFormScreen.parentExercise]'s overrides —
  /// mirrors `effectivePlanVariables(program, exercise: parentExercise)`,
  /// computed directly since this editor only has the declared list and the
  /// parent `Exercise`, not the whole `Program` (same reasoning as
  /// `ExerciseFormScreen`'s simpler one-level version).
  Map<String, String> get _inheritedAtExerciseScope {
    final vars = {for (final v in widget.variables) v.name: v.value};
    final exercise = widget.parentExercise;
    if (exercise != null) {
      for (final entry in exercise.variableOverrides.entries) {
        if (vars.containsKey(entry.key)) vars[entry.key] = entry.value;
      }
    }
    return vars;
  }

  /// The full effective map at this station's own scope: [_inheritedAtExerciseScope]
  /// overlaid by this station's own working overrides. Passed as the
  /// token-aware fields' `overrides:` (not [_workingOverrides] alone) so a
  /// field resolves the whole ADR-0046 cascade — station override shadows
  /// exercise override shadows program default — even for a variable this
  /// station does not itself override.
  Map<String, String> get _effectiveAtStationScope {
    final vars = Map<String, String>.of(_inheritedAtExerciseScope);
    for (final entry in _workingOverrides.entries) {
      if (vars.containsKey(entry.key)) vars[entry.key] = entry.value;
    }
    return vars;
  }

  @override
  void initState() {
    _workingOverrides = Map<String, String>.of(
      widget.station.variableOverrides,
    );
    _workingLocations = List<Location>.of(widget.station.locations);
    _workingPersons = List<Person>.of(widget.station.persons);
    _nameController.text = widget.station.name;
    _descriptionController.text = widget.station.description?.toString() ?? "";
    _position = widget.station.position;
    final s = widget.station;
    _seedSection(_StationSection.equipment, s.equipmentMd);
    _seedSection(_StationSection.situation, s.situationMd);
    _seedSection(_StationSection.mission, s.missionMd);
    _seedSection(_StationSection.logistics, s.logisticsMd);
    _seedSection(_StationSection.criticalQuestions, s.criticalQuestionsMd);
    _seedSection(_StationSection.leaderAnswers, s.leaderAnswersMd);
    _seedSection(_StationSection.directorNotes, s.directorNotesMd);
    super.initState();
  }

  void _seedSection(_StationSection section, String? value) {
    if (value == null) return;
    _activeSections.add(section);
    _sectionControllers[section]!.text = value;
  }

  void _addSection(_StationSection section) {
    setState(() => _activeSections.add(section));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sectionFocusNodes[section]?.requestFocus();
    });
  }

  void _removeSection(_StationSection section) {
    setState(() {
      _activeSections.remove(section);
      _sectionControllers[section]?.clear();
    });
  }

  /// Upserts [location] into [_workingLocations] by `slug` — a new slug
  /// (add) appends, an existing one (edit) replaces in place, so
  /// [LocationsSection] can drive both through a single `onSave` callback
  /// (DESIGN-009 follow-up 3b: add/edit both open the same
  /// `LocationFormScreen`).
  void _upsertLocation(Location location) {
    setState(() {
      final exists = _workingLocations.any((l) => l.slug == location.slug);
      _workingLocations = exists
          ? [
              for (final l in _workingLocations)
                if (l.slug == location.slug) location else l,
            ]
          : [..._workingLocations, location];
    });
  }

  /// Same upsert-by-slug as [_upsertLocation], for [_workingPersons]. Also
  /// the target for a [Location] created inline from
  /// [PersonsSection]'s home picker (via [_upsertLocation]) — see
  /// `PersonsSection.onSave`.
  void _upsertPerson(Person person) {
    setState(() {
      final exists = _workingPersons.any((p) => p.slug == person.slug);
      _workingPersons = exists
          ? [
              for (final p in _workingPersons)
                if (p.slug == person.slug) person else p,
            ]
          : [..._workingPersons, person];
    });
  }

  /// Wired to a token-aware field's `onCreateLocation` hook (ADR-0047,
  /// DESIGN-009 follow-up 4): the insertion menu needs the generated slug
  /// synchronously to embed in the token it is about to insert, so this
  /// both creates the entry (label-only, like a bare "+ Ny lokasjon" would)
  /// and returns it in the same call. Unlike the roleplay editor, a station
  /// owns its own locations directly — straight into [_workingLocations],
  /// no write-back needed.
  String _createLocationInline(String label) {
    final slug = generateSlug(
      label,
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

  /// [_createLocationInline]'s [_workingPersons] counterpart.
  String _createPersonInline(String label) {
    final slug = generateSlug(
      label,
      (candidate) => _workingPersons.any((p) => p.slug == candidate),
    );
    setState(() {
      _workingPersons = [..._workingPersons, Person(slug: slug, name: label)];
    });
    return slug;
  }

  /// Wired to every token-aware field's `onCreateVariable` hook (ADR-0047,
  /// DESIGN-009 follow-up 4 — mirrors `ExerciseFormScreen`'s own copy): the
  /// menu already inserted `{{var.<name>}}`; this only needs to declare it,
  /// empty, in [_pendingVariables] so the chip resolves live (amber) via the
  /// merged [PlanScope] below.
  void _createVariableInline(String name) {
    if (!_variableSlugPattern.hasMatch(name)) return;
    final alreadyDeclared = widget.variables.any((v) => v.name == name);
    final alreadyPending = _pendingVariables.any((v) => v.name == name);
    if (alreadyDeclared || alreadyPending) return;
    setState(() {
      _pendingVariables.add(DrillVariable(name: name, value: ''));
    });
  }

  String _labelFor(_StationSection section, AppLocalizations l) =>
      switch (section) {
        _StationSection.equipment => l.briefSectionStationEquipment,
        _StationSection.situation => l.briefSectionStationSituation,
        _StationSection.mission => l.briefSectionStationMission,
        _StationSection.logistics => l.briefSectionStationLogistics,
        _StationSection.criticalQuestions =>
          l.briefSectionStationCriticalQuestions,
        _StationSection.leaderAnswers => l.briefSectionStationLeaderAnswers,
        _StationSection.directorNotes => l.briefSectionStationDirectorNotes,
      };

  String? _readSection(_StationSection section) {
    if (!_activeSections.contains(section)) return null;
    final value = _sectionControllers[section]!.text.trim();
    return value.isEmpty ? null : value;
  }

  /// Names declared for this editor's save-time undeclared-token check: the
  /// plan's own registry plus anything created inline this session
  /// (ADR-0047, DESIGN-009 follow-up 4) — a variable the author just
  /// declared via the picker must not immediately block save as
  /// "undeclared".
  Set<String> get _declaredVariableNames => {
    for (final v in widget.variables) v.name,
    for (final v in _pendingVariables) v.name,
  };

  /// [_StationSection]s whose text contains an undeclared `{{var.x}}` —
  /// mirrors `ExerciseFormScreen._sectionsWithUndeclaredTokens`.
  List<_StationSection> _sectionsWithUndeclaredTokens() {
    final declared = _declaredVariableNames;
    return [
      for (final section in _StationSection.values)
        if (_activeSections.contains(section) &&
            planVariableTokenPattern
                .allMatches(_sectionControllers[section]!.text)
                .any((m) => !declared.contains(m.group(1))))
          section,
    ];
  }

  /// Base section field labels (name/description, DESIGN-008 follow-up 09)
  /// whose text has a `{{var.<name>}}` token not declared in
  /// [_declaredVariableNames]. Unconditionally present, unlike
  /// [_StationSection], so this is a short parallel check rather than
  /// another enum member.
  List<String> _baseFieldLabelsWithUndeclaredTokens(AppLocalizations l) {
    final declared = _declaredVariableNames;
    bool hasUndeclared(String text) => planVariableTokenPattern
        .allMatches(text)
        .any((m) => !declared.contains(m.group(1)));
    return [
      if (hasUndeclared(_nameController.text)) l.stationName,
      if (hasUndeclared(_descriptionController.text)) l.stationDescription,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return _buildSectionNavigated(context);
  }

  /// DESIGN-008 follow-up 07.
  Widget _buildSectionNavigated(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Additive to the station.loc/person entries StationScope already
    // supplies (DESIGN-009 follow-up 4) — those come through StationScope,
    // not planFields, so both coexist (follow-up 4b).
    final planFields = [
      ...PlanFieldTokens.program(l),
      ...PlanFieldTokens.exercise(l),
      ...PlanFieldTokens.station(l),
    ];

    final activeMdSections = [
      for (final section in _StationSection.values)
        if (_activeSections.contains(section))
          FormSection(
            id: section.name,
            label: _labelFor(section, l),
            icon: Icons.description_outlined,
            removable: true,
            builder: (_) => Padding(
              key: ValueKey(section.name),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: RingDrillTextArea(
                      controller: _sectionControllers[section]!,
                      focusNode: _sectionFocusNodes[section],
                      label: _labelFor(section, l),
                      expands: true,
                      tokenAware: true,
                      overrides: _effectiveAtStationScope,
                      planFields: planFields,
                      // A Station cannot declare a plan variable itself
                      // (DESIGN-008 follow-up 07's settled scope, matching
                      // Exercise), but can now create one inline for the
                      // write-back PlanAdditions carries up to Program
                      // (ADR-0047, DESIGN-009 follow-up 4). Location/person
                      // creation needs no write-back — the station owns
                      // both directly.
                      onCreateVariable: _createVariableInline,
                      onCreateLocation: _createLocationInline,
                      onCreatePerson: _createPersonInline,
                    ),
                  ),
                ],
              ),
            ),
          ),
    ];
    final addableSections = [
      for (final section in _StationSection.values)
        if (!_activeSections.contains(section))
          FormSection(
            id: section.name,
            label: _labelFor(section, l),
            icon: Icons.description_outlined,
            removable: true,
            builder: (_) => const SizedBox.shrink(),
          ),
    ];

    final inherited = _inheritedAtExerciseScope;

    return PlanScope(
      // Declared variables plus anything created inline this session, so a
      // just-created {{var.x}} chip resolves live (amber) instead of red
      // (ADR-0047, DESIGN-009 follow-up 4).
      variables: [...widget.variables, ..._pendingVariables],
      child: StationScope(
        // The station editor owns its locations/persons directly (unlike
        // the roleplay editor's linked-station copy), so it needs no
        // `portrayerOf` — every person here resolves to its own bare
        // fields; the effective-identity override only matters where a
        // roleplay's fields might differ from the Person's (ADR-0047).
        locations: _workingLocations,
        persons: _workingPersons,
        child: Form(
          key: _formKey,
          child: SectionNavigatedForm(
            title: l.editStation,
            entityName: _nameController.text.trim().isNotEmpty
                ? _nameController.text.trim()
                : null,
            initialSectionId: 'station',
            sections: [
              // Base section: structural fields (name, position, description).
              FormSection(
                id: 'station',
                label: l.station(1),
                icon: Icons.place,
                builder: (ctx) => _buildStationSectionBody(ctx, l),
              ),
              // Persons before Locations so the author can name the subject
              // before declaring where they were last seen (DESIGN-009 3c).
              FormSection(
                id: 'persons',
                label: l.personsSectionTitle,
                icon: Icons.people_alt_outlined,
                builder: (_) => PersonsSection(
                  persons: _workingPersons,
                  locations: _workingLocations,
                  onSave: (person, newLocation) {
                    if (newLocation != null) _upsertLocation(newLocation);
                    _upsertPerson(person);
                  },
                  onDelete: (slug) => setState(
                    () => _workingPersons = _workingPersons
                        .where((p) => p.slug != slug)
                        .toList(),
                  ),
                ),
              ),
              FormSection(
                id: 'locations',
                label: l.locationsSectionTitle,
                icon: Icons.location_on_outlined,
                builder: (_) => LocationsSection(
                  locations: _workingLocations,
                  onSave: _upsertLocation,
                  onDelete: (slug) => setState(
                    () => _workingLocations = _workingLocations
                        .where((l) => l.slug != slug)
                        .toList(),
                  ),
                ),
              ),
              // Markdown sections: the narrative fields that reference
              // {{var.<name>}}, {{loc.<slug>}}, and {{person.<slug>}} — so
              // they come after Persons and Locations, not before.
              ...activeMdSections,
              // Last: Variabler, matching Program and Exercise — the section
              // you land on after the fields that reference variables.
              FormSection(
                id: 'variables',
                label: l.variablesSectionTitle,
                icon: Icons.data_object,
                builder: (_) => VariableOverridesSection(
                  variables: widget.variables,
                  inherited: inherited,
                  overrides: _workingOverrides,
                  onChanged: (updated) =>
                      setState(() => _workingOverrides = updated),
                ),
              ),
            ],
            addable: addableSections,
            onAdd: (id) => _addSection(_StationSection.values.byName(id)),
            onRemove: (id) => _removeSection(_StationSection.values.byName(id)),
            onSave: _saveStation,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  /// The DESIGN-008 default section for [Station]: the short structural
  /// fields that never become their own section (name, position,
  /// description).
  Widget _buildStationSectionBody(BuildContext context, AppLocalizations l) {
    final planFields = [
      ...PlanFieldTokens.program(l),
      ...PlanFieldTokens.exercise(l),
      ...PlanFieldTokens.station(l),
    ];
    final markers = _position == null
        ? widget.markers
        : widget.markers.where((e) => e.point == _position).toList();
    return SafeArea(
      child: DismissKeyboard(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RingDrillTextField(
                controller: _nameController,
                label: l.stationName,
                hintText: l.stationNameHint,
                autofocus: true,
                tokenAware: true,
                overrides: _workingOverrides,
                planFields: planFields,
                onCreateVariable: _createVariableInline,
                onCreateLocation: _createLocationInline,
                onCreatePerson: _createPersonInline,
                validator: (value) => value != null && value.trim().isNotEmpty
                    ? null
                    : l.pleaseEnterAName,
              ),
              const SizedBox(height: 16),
              PositionFormField(
                variant: PositionFieldVariant.row,
                initialValue: _position,
                markers: markers,
                onSaved: (position) => _position = position,
                onChanged: (position) =>
                    setState(() => _position = position),
              ),
              const SizedBox(height: 16),
              RingDrillTextArea(
                controller: _descriptionController,
                label: l.stationDescription,
                hintText: l.stationDescriptionHint,
                hintMaxLines: 10,
                minLines: 1,
                maxLines: 15,
                tokenAware: true,
                overrides: _workingOverrides,
                planFields: planFields,
                onCreateVariable: _createVariableInline,
                onCreateLocation: _createLocationInline,
                onCreatePerson: _createPersonInline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (final c in _sectionControllers.values) {
      c.dispose();
    }
    for (final f in _sectionFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _saveStation() {
    if (_formKey.currentState?.validate() ?? false) {
      final l = AppLocalizations.of(context)!;
      final offending = [
        ..._baseFieldLabelsWithUndeclaredTokens(l),
        ..._sectionsWithUndeclaredTokens().map((s) => _labelFor(s, l)),
      ];
      if (offending.isNotEmpty) {
        final sections = offending.join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.programSaveBlockedUndeclaredVariable(sections)),
          ),
        );
        return;
      }

      _formKey.currentState!.save();
      final name = _nameController.text.trim();
      final description = _descriptionController.text;

      final newStation = widget.station.copyWith(
        name: name,
        position: _position,
        description: description.isEmpty ? null : description,
        equipmentMd: _readSection(_StationSection.equipment),
        situationMd: _readSection(_StationSection.situation),
        missionMd: _readSection(_StationSection.mission),
        logisticsMd: _readSection(_StationSection.logistics),
        criticalQuestionsMd: _readSection(_StationSection.criticalQuestions),
        leaderAnswersMd: _readSection(_StationSection.leaderAnswers),
        directorNotesMd: _readSection(_StationSection.directorNotes),
        // The working copy: carries VariableOverridesSection's edits.
        variableOverrides: _workingOverrides,
        // The working copies: carry LocationsSection's/PersonsSection's edits.
        locations: _workingLocations,
        persons: _workingPersons,
      );

      Navigator.of(context).pop((
        station: newStation,
        additions: variableAdditions(_pendingVariables),
      ));
    }
  }
}
