import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/utils/app_flags.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/position_form_field.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/optional_field_sections.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_text_field.dart';
import 'package:ringdrill/views/widgets/section_navigated_form.dart';
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

class StationFormScreen extends StatefulWidget {
  const StationFormScreen({
    super.key,
    required this.station,
    this.markers = const <MapMarkerSpec<(String, int)>>[],
    this.variables = const <DrillVariable>[],
    this.parentExercise,
    @visibleForTesting this.debugPlanVariablesOverride,
  });

  final Station station;
  final List<MapMarkerSpec<(String, int)>> markers;

  /// The plan's declared variables (ADR-0046), read-only here — this editor
  /// edits a `Station`, not the `Program` (DESIGN-008 follow-up 07's
  /// settled scope, same as `ExerciseFormScreen`). Every call site passes
  /// `program.variables`. Only consulted in the flag-on section-navigated
  /// body.
  final List<DrillVariable> variables;

  /// The enclosing `Exercise`, needed to compute this station's inherited
  /// baseline (ADR-0046): the plan's declared defaults overlaid by this
  /// exercise's overrides. Optional so existing callers that only care
  /// about the legacy flag-off body keep compiling unchanged — the
  /// flag-on body degrades to a program-only baseline when omitted.
  final Exercise? parentExercise;

  /// Overrides [AppFlags.planVariables] for a test. `bool.fromEnvironment`
  /// is a compile-time const, so a widget test cannot flip it at runtime —
  /// this lets a test render the flag-on section-navigated body without a
  /// `--dart-define`. Production code never sets this; the real flag is
  /// read when it is null.
  @visibleForTesting
  final bool? debugPlanVariablesOverride;

  @override
  State<StationFormScreen> createState() => _StationFormScreenState();
}

class _StationFormScreenState extends State<StationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  LatLng? _position;

  // Form field controllers
  final TextEditingController _nameController = TextEditingController(
    text: "Station",
  );
  final TextEditingController _descriptionController = TextEditingController(
    text: "",
  );

  /// A [TokenTextEditingController] in the flag-on path, a plain controller
  /// in the legacy path — same reasoning as `ExerciseFormScreen`'s
  /// controllers.
  late final Map<_StationSection, TextEditingController> _sectionControllers = {
    for (final s in _StationSection.values)
      s: _planVariablesOn
          ? TokenTextEditingController()
          : TextEditingController(),
  };
  final Map<_StationSection, FocusNode> _sectionFocusNodes = {
    for (final s in _StationSection.values) s: FocusNode(),
  };
  final Set<_StationSection> _activeSections = {};

  /// Working copy of `station.variableOverrides` (DESIGN-008 follow-up 07),
  /// edited by [VariableOverridesSection] and read by [_saveStation]. Only
  /// mutated in the flag-on path, so it round-trips unchanged in flag-off.
  late Map<String, String> _workingOverrides;

  bool get _planVariablesOn =>
      widget.debugPlanVariablesOverride ?? AppFlags.planVariables;

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

  /// [_StationSection]s whose text contains an undeclared `{{var.x}}` —
  /// mirrors `ExerciseFormScreen._sectionsWithUndeclaredTokens`.
  List<_StationSection> _sectionsWithUndeclaredTokens() {
    final declared = widget.variables.map((v) => v.name).toSet();
    return [
      for (final section in _StationSection.values)
        if (_activeSections.contains(section) &&
            planVariableTokenPattern
                .allMatches(_sectionControllers[section]!.text)
                .any((m) => !declared.contains(m.group(1))))
          section,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_planVariablesOn) {
      return _buildSectionNavigated(context);
    }
    return _buildLegacy(context);
  }

  /// DESIGN-008 follow-up 07, behind `RINGDRILL_PLAN_VARIABLES`. Same
  /// controllers, [_activeSections] and save path as the legacy body below
  /// — only their presentation moves into sections, plus the override
  /// table on the Variabler section.
  Widget _buildSectionNavigated(BuildContext context) {
    final l = AppLocalizations.of(context)!;

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
                      // No onCreateVariable: Station cannot create plan
                      // variables (DESIGN-008 follow-up 07's settled
                      // scope, matching Exercise).
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
      variables: widget.variables,
      child: Form(
        key: _formKey,
        child: SectionNavigatedForm(
          title: l.editStation,
          initialSectionId: 'station',
          sections: [
            FormSection(
              id: 'station',
              label: l.station(1),
              icon: Icons.place,
              builder: (ctx) => _buildStationSectionBody(ctx, l),
            ),
            ...activeMdSections,
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
    );
  }

  /// The DESIGN-008 default section for [Station]: the short structural
  /// fields that never become their own section (name, position,
  /// description).
  Widget _buildStationSectionBody(BuildContext context, AppLocalizations l) {
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      autofocus: true,
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l.stationName,
                        hintText: l.stationNameHint,
                      ),
                      validator: (value) =>
                          value != null && value.trim().isNotEmpty
                          ? null
                          : l.pleaseEnterAName,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 230,
                    child: Container(
                      decoration: BoxDecoration(
                        border: BoxBorder.all(color: Colors.grey.shade700),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0).copyWith(left: 8.0),
                        child: PositionFormField(
                          initialValue: _position,
                          markers: markers,
                          onSaved: (position) => _position = position,
                          onChanged: (position) =>
                              setState(() => _position = position),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 15,
                decoration: InputDecoration(
                  labelText: l.stationDescription,
                  hintText: l.stationDescriptionHint,
                  hintMaxLines: 10,
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegacy(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    // With a position, show only this station's own pin (unchanged). Without
    // one (new station), pass the sibling stations so the picker frames them
    // and the user places the new pin near the others.
    final markers = _position == null
        ? widget.markers
        : widget.markers.where((e) => e.point == _position).toList();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: localizations.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(localizations.editStation),
        actions: [
          ElevatedButton(
            onPressed: _saveStation,
            child: Text(localizations.save),
          ),
        ],
        actionsPadding: EdgeInsets.only(right: 16.0),
      ),
      body: DismissKeyboard(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Exercise Name
                      Expanded(
                        child: TextFormField(
                          autofocus: true,
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: localizations.stationName,
                            hintText: localizations.stationNameHint,
                          ),
                          validator: (value) =>
                              value != null && value.trim().isNotEmpty
                              ? null
                              : localizations.pleaseEnterAName,
                        ),
                      ),

                      SizedBox(width: 8),

                      // Position
                      SizedBox(
                        width: 230,
                        child: Container(
                          decoration: BoxDecoration(
                            border: BoxBorder.all(color: Colors.grey.shade700),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(
                              4.0,
                            ).copyWith(left: 8.0),
                            child: PositionFormField(
                              initialValue: _position,
                              markers: markers,
                              onSaved: (position) => _position = position,
                              // Without this, `_position` (and therefore the
                              // `markers` filter above, and the map picker's
                              // recentring on reopen) stayed frozen at the
                              // old value until Save — a pick would visibly
                              // "not take" until the form was saved.
                              onChanged: (position) =>
                                  setState(() => _position = position),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: 15,
                    decoration: InputDecoration(
                      labelText: localizations.stationDescription,
                      hintText: localizations.stationDescriptionHint,
                      hintMaxLines: 10,
                      alignLabelWithHint: true,
                    ),
                  ),

                  SizedBox(height: 16),

                  OptionalFieldSections<_StationSection>(
                    sections: [
                      for (final section in _StationSection.values)
                        OptionalFieldSection<_StationSection>(
                          id: section,
                          label: _labelFor(section, localizations),
                          controller: _sectionControllers[section]!,
                          focusNode: _sectionFocusNodes[section],
                        ),
                    ],
                    activeIds: _activeSections,
                    onAdd: _addSection,
                    onRemove: _removeSection,
                  ),
                  // Hidden once every optional section has been added: with
                  // no add-buttons left to show, the divider would sit right
                  // below the last text field with nothing to separate.
                  if (_activeSections.length < _StationSection.values.length)
                    const Divider(height: 32),
                ],
              ),
            ),
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
      // Flag off has no Variabler section and no way to reference an
      // undeclared token in the first place — only the flag-on path can
      // produce one to block on (matches ExerciseFormScreen's rule).
      if (_planVariablesOn) {
        final offending = _sectionsWithUndeclaredTokens();
        if (offending.isNotEmpty) {
          final l = AppLocalizations.of(context)!;
          final sections = offending.map((s) => _labelFor(s, l)).join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.programSaveBlockedUndeclaredVariable(sections)),
            ),
          );
          return;
        }
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
        // The working copy: never mutated in the flag-off path (no
        // VariableOverridesSection mounts there), so this round-trips the
        // original unchanged; in flag-on it carries the author's edits.
        variableOverrides: _workingOverrides,
      );

      Navigator.of(context).pop(newStation);
    }
  }
}
