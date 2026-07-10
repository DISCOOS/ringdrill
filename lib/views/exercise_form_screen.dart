import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/context_extensions.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/utils/variable_values.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/plan_additions.dart';
import 'package:ringdrill/views/widgets/adaptive_time_picker.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/exercise_scope.dart';
import 'package:ringdrill/views/widgets/plan_field_tokens.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_text_field.dart';
import 'package:ringdrill/views/widgets/section_navigated_form.dart';
import 'package:ringdrill/views/widgets/section_rollup.dart';
import 'package:ringdrill/views/widgets/token_text_editing_controller.dart';
import 'package:ringdrill/views/widgets/variable_overrides_section.dart';

/// Optional addable markdown sections on [Exercise] (DESIGN-004).
enum _ExerciseSection {
  method,
  learningGoals,
  trainingFocus,
  orderFormat,
  executionTips,
  comms,
}

/// [ExerciseFormScreen]'s result: the saved [Exercise] plus any [PlanAdditions]
/// created inline this session (ADR-0047, DESIGN-009 follow-up 4) — the
/// caller applies both atomically (the exercise to its own owner, the
/// additions' variables to `Program`).
typedef ExerciseFormResult = ({Exercise exercise, PlanAdditions additions});

/// ADR-0046's declared-variable-name rule, duplicated from
/// `ProgramFormScreen`'s own `_slugPattern`/`VariablesSection`'s
/// `_slugPattern` (each editor validates a name being typed, not an
/// existing token — not worth sharing a one-line RegExp across three files).
final _variableSlugPattern = RegExp(r'^[a-z][a-z0-9_]*$');

class ExerciseFormScreen extends StatefulWidget {
  const ExerciseFormScreen({
    super.key,
    this.exercise,
    this.numberOfTeams,
    this.variables = const <DrillVariable>[],
  });

  final Exercise? exercise;
  final int? numberOfTeams;

  /// The plan's declared variables (ADR-0046), read-only here — this editor
  /// edits an `Exercise`, not the `Program`, so it cannot create, rename,
  /// delete or default-edit them (DESIGN-008 follow-up 06's settled scope).
  /// The caller opens this form from a program context that has the active
  /// `Program`; every call site passes `program.variables`.
  final List<DrillVariable> variables;

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
  static const int _maxCounterValue = 12;

  final _formKey = GlobalKey<FormState>();

  TimeOfDay _startTime = _initStartTime();

  static TimeOfDay _initStartTime() {
    final now = DateTime.now();
    return TimeOfDay(
      hour: now.minute > 30 ? (now.hour + 1) % 24 : now.hour,
      minute: now.minute > 30 ? 0 : 30,
    );
  } // Default start time

  // Form field controllers
  /// Token-aware so `RingDrillTextField(tokenAware: true)` can drive its
  /// chips from [PlanScope] (DESIGN-008 follow-up 09).
  final TextEditingController _nameController = TokenTextEditingController();
  final TextEditingController _numberOfTeamsController = TextEditingController(
    text: "4",
  );
  final TextEditingController _numberOfStationsController =
      TextEditingController(text: "4");
  final TextEditingController _numberOfRoundsController = TextEditingController(
    text: "4",
  );
  final TextEditingController _executionTimeController = TextEditingController(
    text: "15",
  );
  final TextEditingController _evaluationTimeController = TextEditingController(
    text: "10",
  );
  final TextEditingController _rotationTimeController = TextEditingController(
    text: "5",
  );

  bool _stationsTracksTeams = true;
  bool _legacyOversizedCounters = false;

  /// Token-aware so `RingDrillTextArea(tokenAware: true)` can drive its
  /// chips from [PlanScope].
  final Map<_ExerciseSection, TextEditingController> _sectionControllers = {
    for (final s in _ExerciseSection.values) s: TokenTextEditingController(),
  };
  final Map<_ExerciseSection, FocusNode> _sectionFocusNodes = {
    for (final s in _ExerciseSection.values) s: FocusNode(),
  };
  final Set<_ExerciseSection> _activeSections = {};

  /// Section ids currently showing their resolved-markdown preview
  /// (DESIGN-010) rather than the editable chip field — remembered for the
  /// session, per section, not editor-wide (DESIGN-010's settled decisions).
  final Set<String> _previewSections = {};

  /// Whether the default section's read-only rollup is shown (DESIGN-010).
  /// Default off, to keep the default section compact.
  bool _showRollup = false;

  void _togglePreview(String sectionId, bool preview) => setState(() {
    if (preview) {
      _previewSections.add(sectionId);
    } else {
      _previewSections.remove(sectionId);
    }
  });

  /// Working copy of `exercise.variableOverrides` (DESIGN-008 follow-up 06),
  /// edited by [VariableOverridesSection] and read by [_saveExercise].
  late Map<String, String> _workingOverrides;

  /// New plan variables created inline from a token field this session
  /// (ADR-0047, DESIGN-009 follow-up 4 — un-defers DESIGN-008's parked
  /// "create a variable from a sub-editor"). An `Exercise` cannot declare
  /// variables itself; these are returned as [PlanAdditions] for the caller
  /// to apply to `Program` alongside this exercise's own save.
  final List<DrillVariable> _pendingVariables = [];

  @override
  void initState() {
    _workingOverrides = Map<String, String>.of(
      widget.exercise?.variableOverrides ?? const {},
    );
    final e = widget.exercise;
    if (e != null) {
      _startTime = e.startTime.toMaterial();
      _nameController.text = e.name;
      _numberOfTeamsController.text = (widget.numberOfTeams ?? e.numberOfTeams)
          .toString();
      _numberOfStationsController.text = e.stations.length.toString();
      _numberOfRoundsController.text = e.numberOfRounds.toString();
      _executionTimeController.text = e.executionTime.toString();
      _evaluationTimeController.text = e.evaluationTime.toString();
      _rotationTimeController.text = e.rotationTime.toString();
      _stationsTracksTeams = false;
      _legacyOversizedCounters =
          (widget.numberOfTeams ?? e.numberOfTeams) > _maxCounterValue ||
          e.stations.length > _maxCounterValue ||
          e.numberOfRounds > _maxCounterValue;
      _seedSection(_ExerciseSection.method, e.methodMd);
      _seedSection(_ExerciseSection.learningGoals, e.learningGoalsMd);
      _seedSection(_ExerciseSection.trainingFocus, e.trainingFocusMd);
      _seedSection(_ExerciseSection.orderFormat, e.orderFormatMd);
      _seedSection(_ExerciseSection.executionTips, e.executionTipsMd);
      _seedSection(_ExerciseSection.comms, e.commsMd);
    } else {
      _numberOfStationsController.text = _numberOfTeamsController.text;
    }
    super.initState();
  }

  void _seedSection(_ExerciseSection section, String? value) {
    if (value == null) return;
    _activeSections.add(section);
    _sectionControllers[section]!.text = value;
  }

  void _addSection(_ExerciseSection section) {
    setState(() => _activeSections.add(section));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sectionFocusNodes[section]?.requestFocus();
    });
  }

  void _removeSection(_ExerciseSection section) {
    setState(() {
      _activeSections.remove(section);
      _sectionControllers[section]?.clear();
    });
  }

  String _labelFor(_ExerciseSection section, AppLocalizations l) =>
      switch (section) {
        _ExerciseSection.method => l.briefSectionExerciseMethod,
        _ExerciseSection.learningGoals => l.briefSectionExerciseLearningGoals,
        _ExerciseSection.trainingFocus => l.briefSectionExerciseTrainingFocus,
        _ExerciseSection.orderFormat => l.briefSectionExerciseOrderFormat,
        _ExerciseSection.executionTips => l.briefSectionExerciseExecutionTips,
        _ExerciseSection.comms => l.briefSectionExerciseComms,
      };

  String? _readSection(_ExerciseSection section) {
    if (!_activeSections.contains(section)) return null;
    final value = _sectionControllers[section]!.text.trim();
    return value.isEmpty ? null : value;
  }

  /// Wired to every token-aware field's `onCreateVariable` hook (ADR-0047,
  /// DESIGN-009 follow-up 4 — mirrors `ProgramFormScreen._createVariableInline`):
  /// the insertion menu already inserted `{{var.<name>}}` before calling
  /// this, so all that's left is declaring it, empty, in [_pendingVariables]
  /// so the chip resolves live (amber) via the merged [PlanScope] below.
  /// `name` came from the menu's `\w*` filter capture, looser than the
  /// ADR-0046 slug rule — validate before declaring; an invalid name is
  /// left as an undeclared (red) token for save-time validation to catch.
  void _createVariableInline(String name) {
    if (!_variableSlugPattern.hasMatch(name)) return;
    final alreadyDeclared = widget.variables.any((v) => v.name == name);
    final alreadyPending = _pendingVariables.any((v) => v.name == name);
    if (alreadyDeclared || alreadyPending) return;
    setState(() {
      _pendingVariables.add(DrillVariable(name: name, value: ''));
    });
  }

  @override
  Widget build(BuildContext context) {
    return _buildSectionNavigated(context);
  }

  /// DESIGN-008 follow-up 06.
  Widget _buildSectionNavigated(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Program cascades into exercise scope in brief_renderer.dart, so both
    // sets resolve here (DESIGN-009 follow-up 4b).
    final planFields = [
      ...PlanFieldTokens.program(l),
      ...PlanFieldTokens.exercise(l),
    ];

    final activeMdSections = [
      for (final section in _ExerciseSection.values)
        if (_activeSections.contains(section))
          FormSection(
            id: section.name,
            label: _labelFor(section, l),
            icon: Icons.description_outlined,
            removable: true,
            preview: _previewSections.contains(section.name),
            onPreviewChanged: (value) => _togglePreview(section.name, value),
            // Keyed by section so switching sections always mounts a fresh
            // field — see ProgramFormScreen's identical reasoning.
            builder: (_) => Padding(
              key: ValueKey(section.name),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: RingDrillTextArea(
                      controller: _sectionControllers[section]!,
                      focusNode: _sectionFocusNodes[section],
                      // No label: the section switcher (compact dropdown /
                      // wide rail) already names this section, so a field
                      // label equal to the section name only duplicates it.
                      expands: true,
                      tokenAware: true,
                      overrides: _workingOverrides,
                      planFields: planFields,
                      preview: _previewSections.contains(section.name),
                      // An Exercise cannot declare a plan variable itself
                      // (DESIGN-008 follow-up 06's settled scope), but can
                      // now create one inline for the write-back
                      // `PlanAdditions` carries up to Program (ADR-0047,
                      // DESIGN-009 follow-up 4 — un-defers DESIGN-008's
                      // parked sub-editor variable creation).
                      onCreateVariable: _createVariableInline,
                    ),
                  ),
                ],
              ),
            ),
          ),
    ];
    final addableSections = [
      for (final section in _ExerciseSection.values)
        if (!_activeSections.contains(section))
          FormSection(
            id: section.name,
            label: _labelFor(section, l),
            icon: Icons.description_outlined,
            removable: true,
            // Never rendered: a section only appears in `addable`, whose
            // builder is never invoked by SectionNavigatedForm.
            builder: (_) => const SizedBox.shrink(),
          ),
    ];

    // The program-declared default is this scope's inherited baseline: an
    // Exercise sits directly under Program in ADR-0046's chain, with no
    // intermediate scope, so "no local override" always falls back to
    // exactly the declared value — in the type's canonical string encoding
    // (a location default encodes place + coordinate, DESIGN-008 follow-up
    // 11).
    final inherited = {
      for (final v in widget.variables) v.name: canonicalVariableValue(v),
    };

    final form = Form(
      key: _formKey,
      child: SectionNavigatedForm(
        title: widget.exercise == null ? l.createExercise : l.editExercise,
        initialSectionId: 'exercise',
        sections: [
          FormSection(
            id: 'exercise',
            label: l.exercise(1),
            icon: Icons.update,
            builder: (ctx) => _buildExerciseSectionBody(ctx, l),
          ),
          ...activeMdSections,
          // Last, matching ProgramFormScreen: Variabler reads better as
          // the section you land on after the fields you reference
          // {{var.<name>}} from, not before.
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
        onAdd: (id) => _addSection(_ExerciseSection.values.byName(id)),
        onRemove: (id) => _removeSection(_ExerciseSection.values.byName(id)),
        onSave: _saveExercise,
        onClose: () => Navigator.of(context).pop(),
      ),
    );

    // Only a saved exercise has facets worth carrying (DESIGN-010's
    // resolve-context cascade) — a brand-new exercise has no {{exercise.*}}
    // yet for a later field to reference.
    final existingExercise = widget.exercise;
    final scoped = existingExercise == null
        ? form
        : ExerciseScope(
            exercise: existingExercise,
            variableOverrides: _workingOverrides,
            child: form,
          );

    // Forwards the ambient PlanScope's program facets (DESIGN-010) — this
    // editor shadows PlanScope with its own (for the live variables list),
    // which would otherwise strand {{program.name}} at null below here.
    final ambientPlan = PlanScope.maybeOf(context);

    return PlanScope(
      // Declared variables plus anything created inline this session, so a
      // just-created {{var.x}} chip resolves live (amber) instead of red
      // (ADR-0047, DESIGN-009 follow-up 4).
      variables: [...widget.variables, ..._pendingVariables],
      programName: ambientPlan?.programName,
      programDescription: ambientPlan?.programDescription,
      child: scoped,
    );
  }

  /// The DESIGN-008 default section for [Exercise]: the short structural
  /// fields that never become their own section (name, start time, the
  /// scheduling counters).
  Widget _buildExerciseSectionBody(BuildContext context, AppLocalizations l) {
    final planFields = [
      ...PlanFieldTokens.program(l),
      ...PlanFieldTokens.exercise(l),
    ];
    final fields = SafeArea(
      child: DismissKeyboard(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RingDrillTextField(
                      controller: _nameController,
                      label: l.exerciseName,
                      autofocus: true,
                      tokenAware: true,
                      overrides: _workingOverrides,
                      planFields: planFields,
                      onCreateVariable: _createVariableInline,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? l.pleaseEnterAName
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  IntrinsicWidth(child: _buildStartTimeField(context, l)),
                ],
              ),
              const SizedBox(height: 16.0),
              _buildTimeSection(context, l),
              const SizedBox(height: 16.0),
              if (_legacyOversizedCounters) ...[
                MaterialBanner(
                  content: Text(l.legacyOversizedExerciseNotice),
                  actions: const [SizedBox.shrink()],
                  padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
                  leading: const Icon(Icons.info_outline),
                ),
                const SizedBox(height: 16.0),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _numberOfTeamsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l.numberOfTeams),
                      onChanged: (value) {
                        if (_stationsTracksTeams) {
                          _numberOfStationsController.text = value;
                        }
                        setState(() {});
                      },
                      validator: (value) {
                        final counterError = _validateCounter(value, l);
                        if (counterError != null) return counterError;
                        if (_isValidNumber(_numberOfStationsController.text) &&
                            int.parse(value!) >
                                int.parse(_numberOfStationsController.text)) {
                          return l.mustBeEqualToOrLessThanNumberOf(
                            l.station(2).toLowerCase(),
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: TextFormField(
                      controller: _numberOfStationsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l.numberOfStations,
                      ),
                      onChanged: (_) {
                        _stationsTracksTeams = false;
                        setState(() {});
                      },
                      validator: (value) {
                        final counterError = _validateCounter(value, l);
                        if (counterError != null) return counterError;
                        if (_isValidNumber(_numberOfTeamsController.text) &&
                            int.parse(value!) <
                                int.parse(_numberOfTeamsController.text)) {
                          return l.mustBeEqualToOrGreaterThanNumberOf(
                            l.team(2).toLowerCase(),
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: TextFormField(
                      controller: _numberOfRoundsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l.numberOfRounds),
                      onChanged: (_) => setState(() {}),
                      validator: (value) => _validateCounter(value, l),
                    ),
                  ),
                ],
              ),
              ?_buildStationsRoundNote(l),
            ],
          ),
        ),
      ),
    );

    return withSectionRollup(
      context: context,
      fields: fields,
      rollupSections: [
        for (final section in _ExerciseSection.values)
          if (_activeSections.contains(section))
            RollupSection(
              id: section.name,
              label: _labelFor(section, l),
              controller: _sectionControllers[section]!,
              overrides: _workingOverrides,
            ),
      ],
      showRollup: _showRollup,
      onShowRollupChanged: (value) => setState(() => _showRollup = value),
    );
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

  /// [_ExerciseSection]s whose text contains an undeclared `{{var.x}}` —
  /// mirrors `ProgramFormScreen._sectionsWithUndeclaredTokens`, scoped to
  /// only the fields this editor edits. Declared-but-empty never blocks;
  /// only an undeclared name does, matching the Program editor's rule.
  List<_ExerciseSection> _sectionsWithUndeclaredTokens() {
    final declared = _declaredVariableNames;
    return [
      for (final section in _ExerciseSection.values)
        if (_activeSections.contains(section) &&
            planVariableTokenPattern
                .allMatches(_sectionControllers[section]!.text)
                .any((m) => !declared.contains(m.group(1))))
          section,
    ];
  }

  /// Whether the base section's name field (DESIGN-008 follow-up 09) has a
  /// `{{var.<name>}}` token not declared in [_declaredVariableNames]. Name
  /// is unconditionally present, unlike [_ExerciseSection], so this is a
  /// short parallel check rather than another enum member.
  bool _nameHasUndeclaredTokens() {
    final declared = _declaredVariableNames;
    return planVariableTokenPattern
        .allMatches(_nameController.text)
        .any((m) => !declared.contains(m.group(1)));
  }

  /// The three duration fields (execution, evaluation, rotation) always
  /// share one row — short minute values, mirroring the teams/stations/
  /// rounds row below. The start-time picker sits beside the exercise name
  /// instead of in this row.
  Widget _buildTimeSection(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildDurationField(
            controller: _executionTimeController,
            label: localizations.executionTime,
            localizations: localizations,
          ),
        ),
        const SizedBox(width: 16.0),
        Expanded(
          child: _buildDurationField(
            controller: _evaluationTimeController,
            label: localizations.evaluationTime,
            localizations: localizations,
          ),
        ),
        const SizedBox(width: 16.0),
        Expanded(
          child: _buildDurationField(
            controller: _rotationTimeController,
            label: localizations.rotationTime,
            localizations: localizations,
          ),
        ),
      ],
    );
  }

  /// Start-time picker styled as a tappable [InputDecorator] so it reads
  /// like the sibling [TextFormField]s. Sits beside the exercise-name field,
  /// wrapped in [IntrinsicWidth] by the caller so it sizes to its own
  /// content instead of stretching.
  Widget _buildStartTimeField(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return InkWell(
      onTap: _pickStartTime,
      borderRadius: BorderRadius.circular(4.0),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: localizations.startTime,
          suffixIcon: const Icon(Icons.access_time),
        ),
        child: Text(
          // ADR-0037: themed bodyLarge instead of a hardcoded size.
          _startTime.formal(),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _buildDurationField({
    required TextEditingController controller,
    required String label,
    required AppLocalizations localizations,
  }) {
    return TextFormField(
      controller: controller,
      // Whole minutes only: digits keyboard plus an input formatter that
      // drops anything non-numeric, so the field can never hold a value the
      // validator would reject. The validator still guards paste/edge cases.
      keyboardType: const TextInputType.numberWithOptions(
        decimal: false,
        signed: false,
      ),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
      validator: (value) =>
          _isValidNumber(value) ? null : localizations.pleaseEnterAValidTime,
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await pickAdaptiveTime(context, initialTime: _startTime);
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  // Validate and add the exercise
  Future<void> _saveExercise() async {
    final String? validationError = ExerciseX.sanitizeExerciseName(
      _nameController.text,
    );

    if (validationError != null) {
      // Show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          showCloseIcon: true,
          dismissDirection: DismissDirection.endToStart,
          content: Text(validationError),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      final l = AppLocalizations.of(context)!;
      final offending = [
        if (_nameHasUndeclaredTokens()) l.exerciseName,
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

      // An invalid typed override blocks save exactly as an unknown token
      // does (DESIGN-008 follow-up 11). State-level, not just the Form
      // validators: the Variabler section may not be the mounted one.
      final declaredTypes = {for (final v in widget.variables) v.name: v.type};
      final invalidOverrides = [
        for (final entry in _workingOverrides.entries)
          if (!isVariableValueValid(
            declaredTypes[entry.key] ?? VariableType.string,
            entry.value,
          ))
            entry.key,
      ];
      if (invalidOverrides.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l.variableSaveBlockedInvalidValue(invalidOverrides.join(', ')),
            ),
          ),
        );
        return;
      }
      // Overrides may still be raw user input (e.g. "3,14"); store the
      // canonical encoding now that validation has passed.
      _workingOverrides = {
        for (final entry in _workingOverrides.entries)
          entry.key:
              canonicalizeVariableValue(
                declaredTypes[entry.key] ?? VariableType.string,
                entry.value,
              ) ??
              entry.value,
      };

      final name = _nameController.text.trim();
      final numberOfTeams = int.parse(_numberOfTeamsController.text);
      final numberOfStations = int.parse(_numberOfStationsController.text);
      final numberOfRounds = int.parse(_numberOfRoundsController.text);
      final executionTime = int.parse(_executionTimeController.text);
      final evaluationTime = int.parse(_evaluationTimeController.text);
      final rotationTime = int.parse(_rotationTimeController.text);
      final localizations = context.l10n;

      final existingExercise = widget.exercise;
      if (existingExercise != null &&
          numberOfStations < existingExercise.stations.length) {
        final droppedStations = existingExercise.stations.asMap().entries.where(
          (entry) => entry.key >= numberOfStations,
        );
        final dropsUserVisibleContent = droppedStations.any((entry) {
          final station = entry.value;
          final defaultName = '${localizations.station(1)} ${entry.key + 1}';
          return station.name != defaultName ||
              (station.description?.isNotEmpty ?? false) ||
              station.position != null;
        });

        if (dropsUserVisibleContent) {
          final confirmed = await confirmDestructive(
            context,
            title: localizations.confirmReduceStationsTitle,
            message: localizations.confirmReduceStationsBody(
              existingExercise.stations.length - numberOfStations,
            ),
            confirmLabel: localizations.yes,
          );
          if (!mounted) return;
          if (!confirmed) {
            return;
          }
        }
      }

      // Generate exercise with user input
      final newExercise = ProgramService.generateSchedule(
        name: name,
        startTime: _startTime,
        uuid: widget.exercise?.uuid,
        numberOfTeams: numberOfTeams,
        numberOfStations: numberOfStations,
        numberOfRounds: numberOfRounds,
        executionTime: executionTime,
        evaluationTime: evaluationTime,
        rotationTime: rotationTime,
        stations: widget.exercise?.stations ?? [],
        localizations: localizations,
        // The working copy, not widget.exercise?.variableOverrides directly:
        // carries whatever VariableOverridesSection's author edits produced.
        variableOverrides: _workingOverrides,
      );

      // generateSchedule rebuilds the Exercise from its scalar inputs, so any
      // field not derived from those inputs is dropped unless we put it back
      // via copyWith. The sidecar markdown brief fields (outside JSON per
      // ADR-0022) and the ordering index (ADR-0035) are both rebuild-agnostic:
      // preserve the existing index on edit so the exercise keeps its place in
      // the list; a new exercise keeps the default and gets its index assigned
      // on save.
      final withBrief = newExercise.copyWith(
        index: existingExercise?.index ?? newExercise.index,
        methodMd: _readSection(_ExerciseSection.method),
        learningGoalsMd: _readSection(_ExerciseSection.learningGoals),
        trainingFocusMd: _readSection(_ExerciseSection.trainingFocus),
        orderFormatMd: _readSection(_ExerciseSection.orderFormat),
        executionTipsMd: _readSection(_ExerciseSection.executionTips),
        commsMd: _readSection(_ExerciseSection.comms),
      );

      // Return the exercise to the previous screen
      Navigator.of(context).pop((
        exercise: withBrief,
        additions: variableAdditions(_pendingVariables),
      ));
    }
  }

  bool _isValidNumber(String? value) {
    return value != null && int.tryParse(value) != null && int.parse(value) > 0;
  }

  String? _validateCounter(String? value, AppLocalizations localizations) {
    if (!_isValidNumber(value)) {
      return localizations.pleaseEnterAValidNumber;
    }
    if (int.parse(value!) > _maxCounterValue) {
      return localizations.mustBeEqualToOrLessThanNumberOf(
        _maxCounterValue.toString(),
      );
    }
    return null;
  }

  Widget? _buildStationsRoundNote(AppLocalizations localizations) {
    final numberOfRounds = int.tryParse(_numberOfRoundsController.text);
    final numberOfStations = int.tryParse(_numberOfStationsController.text);
    if (numberOfRounds == null ||
        numberOfStations == null ||
        numberOfRounds <= 0 ||
        numberOfStations <= 0 ||
        numberOfRounds == numberOfStations) {
      return null;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final text = numberOfRounds > numberOfStations
        ? localizations.stationsRevisitNote(numberOfRounds, numberOfStations)
        : localizations.stationsUnderCoverageNote(
            numberOfRounds,
            numberOfStations,
          );
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.tertiary),
      ),
    );
  }

  @override
  void dispose() {
    _numberOfRoundsController.dispose();
    _numberOfTeamsController.dispose();
    _numberOfStationsController.dispose();
    _nameController.dispose();
    _evaluationTimeController.dispose();
    _rotationTimeController.dispose();
    _executionTimeController.dispose();
    for (final c in _sectionControllers.values) {
      c.dispose();
    }
    for (final f in _sectionFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }
}
