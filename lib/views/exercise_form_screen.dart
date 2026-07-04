import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_flags.dart';
import 'package:ringdrill/utils/context_extensions.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/time_utils.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/widgets/adaptive_time_picker.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/optional_field_sections.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_text_field.dart';
import 'package:ringdrill/views/widgets/section_navigated_form.dart';
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

class ExerciseFormScreen extends StatefulWidget {
  const ExerciseFormScreen({
    super.key,
    this.exercise,
    this.numberOfTeams,
    this.variables = const <DrillVariable>[],
    @visibleForTesting this.debugPlanVariablesOverride,
  });

  final Exercise? exercise;
  final int? numberOfTeams;

  /// The plan's declared variables (ADR-0046), read-only here — this editor
  /// edits an `Exercise`, not the `Program`, so it cannot create, rename,
  /// delete or default-edit them (DESIGN-008 follow-up 06's settled scope).
  /// The caller opens this form from a program context that has the active
  /// `Program`; every call site passes `program.variables`. Only consulted
  /// in the flag-on section-navigated body.
  final List<DrillVariable> variables;

  /// Overrides [AppFlags.planVariables] for a test. `bool.fromEnvironment`
  /// is a compile-time const, so a widget test cannot flip it at runtime —
  /// this lets a test render the flag-on section-navigated body without a
  /// `--dart-define`. Production code never sets this; the real flag is
  /// read when it is null.
  @visibleForTesting
  final bool? debugPlanVariablesOverride;

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
  final TextEditingController _nameController = TextEditingController(text: "");
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

  /// A [TokenTextEditingController] in the flag-on path, so
  /// `RingDrillTextArea(tokenAware: true)` can drive its chips from
  /// [PlanScope]; a plain controller in the legacy path. `_planVariablesOn`
  /// is constant for the screen's lifetime, so exactly one of
  /// `_buildSectionNavigated`/`_buildLegacy` ever actually renders these
  /// (same reasoning as `ProgramFormScreen`'s markdown controllers).
  late final Map<_ExerciseSection, TextEditingController> _sectionControllers =
      {
        for (final s in _ExerciseSection.values)
          s: _planVariablesOn
              ? TokenTextEditingController()
              : TextEditingController(),
      };
  final Map<_ExerciseSection, FocusNode> _sectionFocusNodes = {
    for (final s in _ExerciseSection.values) s: FocusNode(),
  };
  final Set<_ExerciseSection> _activeSections = {};

  /// Working copy of `exercise.variableOverrides` (DESIGN-008 follow-up 06),
  /// edited by [VariableOverridesSection] and read by [_saveExercise]. Only
  /// mutated in the flag-on path — the legacy body never mounts the override
  /// table — so it round-trips unchanged in the flag-off path.
  late Map<String, String> _workingOverrides;

  bool get _planVariablesOn =>
      widget.debugPlanVariablesOverride ?? AppFlags.planVariables;

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

  @override
  Widget build(BuildContext context) {
    if (_planVariablesOn) {
      return _buildSectionNavigated(context);
    }
    return _buildLegacy(context);
  }

  /// DESIGN-008 follow-up 06, behind `RINGDRILL_PLAN_VARIABLES`. Same
  /// controllers, [_activeSections] and save path as the legacy body below
  /// — only their presentation moves into sections, plus the override table
  /// on the Variabler section.
  Widget _buildSectionNavigated(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final activeMdSections = [
      for (final section in _ExerciseSection.values)
        if (_activeSections.contains(section))
          FormSection(
            id: section.name,
            label: _labelFor(section, l),
            icon: Icons.description_outlined,
            removable: true,
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
                      label: _labelFor(section, l),
                      expands: true,
                      tokenAware: true,
                      overrides: _workingOverrides,
                      // No onCreateVariable: Exercise cannot create plan
                      // variables (DESIGN-008 follow-up 06's settled
                      // scope) — an unknown {{var.x}} typed here stays a
                      // red, save-blocking token until it is declared in
                      // the Program editor or removed.
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
    // exactly the declared value.
    final inherited = {for (final v in widget.variables) v.name: v.value};

    return PlanScope(
      variables: widget.variables,
      child: Form(
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
      ),
    );
  }

  /// The DESIGN-008 default section for [Exercise]: the short structural
  /// fields that never become their own section (name, start time, the
  /// scheduling counters).
  Widget _buildExerciseSectionBody(BuildContext context, AppLocalizations l) {
    return SafeArea(
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
                    child: TextFormField(
                      autofocus: true,
                      controller: _nameController,
                      decoration: InputDecoration(labelText: l.exerciseName),
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
  }

  /// [_ExerciseSection]s whose text contains an undeclared `{{var.x}}` —
  /// mirrors `ProgramFormScreen._sectionsWithUndeclaredTokens`, scoped to
  /// only the fields this editor edits. Declared-but-empty never blocks;
  /// only an undeclared name does, matching the Program editor's rule.
  List<_ExerciseSection> _sectionsWithUndeclaredTokens() {
    final declared = widget.variables.map((v) => v.name).toSet();
    return [
      for (final section in _ExerciseSection.values)
        if (_activeSections.contains(section) &&
            planVariableTokenPattern
                .allMatches(_sectionControllers[section]!.text)
                .any((m) => !declared.contains(m.group(1))))
          section,
    ];
  }

  Widget _buildLegacy(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: localizations.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.exercise == null
              ? localizations.createExercise
              : localizations.editExercise,
        ),
        actions: [
          ElevatedButton(
            onPressed: _saveExercise,
            child: Text(localizations.save),
          ),
        ],
        actionsPadding: EdgeInsets.only(right: 16.0),
      ),
      body: DismissKeyboard(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Exercise Name, with the start-time picker beside it —
                  // sized to its own content (IntrinsicWidth) rather than
                  // stretched, so the name field keeps most of the row.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          autofocus: true,
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: localizations.exerciseName,
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? localizations.pleaseEnterAName
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      IntrinsicWidth(
                        child: _buildStartTimeField(context, localizations),
                      ),
                    ],
                  ),

                  SizedBox(height: 16.0),

                  // The three duration fields (execution, evaluation,
                  // rotation) share one row — short minute values, mirroring
                  // the teams/stations/rounds row below.
                  _buildTimeSection(context, localizations),

                  SizedBox(height: 16.0),

                  if (_legacyOversizedCounters) ...[
                    MaterialBanner(
                      content: Text(
                        localizations.legacyOversizedExerciseNotice,
                      ),
                      actions: const [SizedBox.shrink()],
                      padding: const EdgeInsetsDirectional.only(
                        start: 16,
                        end: 8,
                      ),
                      leading: const Icon(Icons.info_outline),
                    ),
                    SizedBox(height: 16.0),
                  ],

                  Row(
                    children: [
                      // Number of Teams
                      Expanded(
                        child: TextFormField(
                          controller: _numberOfTeamsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: localizations.numberOfTeams,
                          ),
                          onChanged: (value) {
                            if (_stationsTracksTeams) {
                              _numberOfStationsController.text = value;
                            }
                            setState(() {});
                          },
                          validator: (value) {
                            final counterError = _validateCounter(
                              value,
                              localizations,
                            );
                            if (counterError != null) return counterError;
                            if (_isValidNumber(
                                  _numberOfStationsController.text,
                                ) &&
                                int.parse(value!) >
                                    int.parse(
                                      _numberOfStationsController.text,
                                    )) {
                              return localizations
                                  .mustBeEqualToOrLessThanNumberOf(
                                    localizations.station(2).toLowerCase(),
                                  );
                            }
                            return null;
                          },
                        ),
                      ),

                      SizedBox(width: 16.0),

                      // Number of Stations
                      Expanded(
                        child: TextFormField(
                          controller: _numberOfStationsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: localizations.numberOfStations,
                          ),
                          onChanged: (_) {
                            _stationsTracksTeams = false;
                            setState(() {});
                          },
                          validator: (value) {
                            final counterError = _validateCounter(
                              value,
                              localizations,
                            );
                            if (counterError != null) return counterError;
                            if (_isValidNumber(_numberOfTeamsController.text) &&
                                int.parse(value!) <
                                    int.parse(_numberOfTeamsController.text)) {
                              return localizations
                                  .mustBeEqualToOrGreaterThanNumberOf(
                                    localizations.team(2).toLowerCase(),
                                  );
                            }
                            return null;
                          },
                        ),
                      ),

                      SizedBox(width: 16.0),

                      // Number of Rounds
                      Expanded(
                        child: TextFormField(
                          controller: _numberOfRoundsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: localizations.numberOfRounds,
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) =>
                              _validateCounter(value, localizations),
                        ),
                      ),
                    ],
                  ),
                  ?_buildStationsRoundNote(localizations),

                  SizedBox(height: 16.0),

                  OptionalFieldSections<_ExerciseSection>(
                    sections: [
                      for (final section in _ExerciseSection.values)
                        OptionalFieldSection<_ExerciseSection>(
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
                  if (_activeSections.length < _ExerciseSection.values.length)
                    const Divider(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
      // Flag off has no Variabler section and no way to reference an
      // undeclared token in the first place (RingDrillTextArea's chip
      // rendering, and therefore the red/unknown state, only mounts in the
      // flag-on path) — only the flag-on path can produce one to block on.
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
        // in the flag-off path it is never mutated so this round-trips the
        // original unchanged; in the flag-on path it carries whatever
        // VariableOverridesSection's author edits produced.
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
      Navigator.of(context).pop(withBrief);
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
