import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/schedule.dart';
import 'package:ringdrill/models/station.dart';
import 'package:ringdrill/services/plan_service.dart';
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
import 'package:ringdrill/views/widgets/rollup.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/utils/exercise_share_format.dart';
import 'package:ringdrill/views/widgets/app_brief_labels.dart';
import 'package:ringdrill/views/widgets/exercise_groups_section.dart';
import 'package:ringdrill/views/widgets/exercise_mode_field.dart';
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

/// [ExerciseFormScreen]'s result — a sealed save/delete, mirroring
/// [StaffFormResult]/`RolePlayFormResult`. Null (cancel) is neither.
sealed class ExerciseFormResult {
  const ExerciseFormResult();
}

/// A save: the edited [Exercise] plus any [PlanAdditions] created inline this
/// session (ADR-0047, DESIGN-009 follow-up 4) — the caller applies both
/// atomically (the exercise to its own owner, the additions' variables to
/// `Plan`).
final class ExerciseFormSave extends ExerciseFormResult {
  const ExerciseFormSave(this.exercise, this.additions);

  final Exercise exercise;
  final PlanAdditions additions;
}

/// A delete: the caller removes [exercise] (`PlanService.deleteExercise`).
final class ExerciseFormDelete extends ExerciseFormResult {
  const ExerciseFormDelete(this.exercise);

  final Exercise exercise;
}

/// ADR-0046's declared-variable-name rule, duplicated from
/// `PlanFormScreen`'s own `_slugPattern`/`VariablesSection`'s
/// `_slugPattern` (each editor validates a name being typed, not an
/// existing token — not worth sharing a one-line RegExp across three files).
final _variableSlugPattern = RegExp(r'^[a-z][a-z0-9_]*$');

class ExerciseFormScreen extends StatefulWidget {
  const ExerciseFormScreen({
    super.key,
    this.exercise,
    this.numberOfTeams,
    this.variables = const <DrillVariable>[],
    this.initialSectionId,
  });

  final Exercise? exercise;
  final int? numberOfTeams;

  /// Section to open on. Null opens the base section, and so does any id that
  /// is not one of the [FormSection]s below — [SectionNavigatedForm] falls back
  /// to the first rather than failing.
  ///
  /// That fallback is what the coordinator's exercise-description card relies
  /// on: it passes the tapped block's own id (`method`, `comms`, …), which are
  /// optional field sections *inside* the base section rather than sections of
  /// their own, so the editor lands on the section that holds them. The station
  /// viewer's description card works the same way against
  /// `StationFormScreen`.
  final String? initialSectionId;

  /// The plan's declared variables (ADR-0046), read-only here — this editor
  /// edits an `Exercise`, not the `Plan`, so it cannot create, rename,
  /// delete or default-edit them (DESIGN-008 follow-up 06's settled scope).
  /// The caller opens this form from a plan context that has the active
  /// `Plan`; every call site passes `plan.variables`.
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

  /// The exercise's conduct mode, and the parallel groups that only `split` uses
  /// (ADR-0062). Held in state rather than read from `widget.exercise` on every
  /// build, because this form rebuilds its exercise from these inputs on save — so
  /// anything not held here is dropped, which is how a split plan edited in the app
  /// would silently revert to a ring route.
  ExerciseMode _mode = ExerciseMode.ring;
  List<ExerciseGroup> _groups = const [];

  /// Applies a mode change, confirming first when it would throw authored work away.
  ///
  /// Leaving `split` is the only destructive direction: `ring` and `together` generate
  /// their assignment, so there is nowhere for hand-placed teams to go. The other
  /// directions store nothing the author typed, so they need no dialog — one generic
  /// "are you sure" on every switch would train the author to dismiss the one that
  /// matters.
  Future<void> _onModeChanged(ExerciseMode next) async {
    final l10n = AppLocalizations.of(context)!;
    if (_mode == ExerciseMode.split &&
        next != ExerciseMode.split &&
        _groups.isNotEmpty) {
      final confirmed = await confirmDestructive(
        context,
        title: l10n.exerciseModeSwitchTitle,
        message: l10n.exerciseModeSwitchDiscardsGroups,
        confirmLabel: l10n.exerciseMode,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _mode = next;
      // The groups belong to `split` alone; keeping them for a mode that ignores
      // them would make them reappear on a switch back, having silently gone stale
      // against whatever the stations did in between.
      if (next != ExerciseMode.split) _groups = const [];
    });
  }

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
  /// to apply to `Plan` alongside this exercise's own save.
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
      _mode = e.mode;
      _groups = e.groups;
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
  /// DESIGN-009 follow-up 4 — mirrors `PlanFormScreen._createVariableInline`):
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
    // Plan cascades into exercise scope in brief_renderer.dart, so both
    // sets resolve here (DESIGN-009 follow-up 4b).
    final planFields = [
      ...PlanFieldTokens.plan(l),
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
            // field — see PlanFormScreen's identical reasoning.
            builder: (_) => Padding(
              key: ValueKey(section.name),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: RingDrillTextArea(
                      controller: _sectionControllers[section]!,
                      focusNode: _sectionFocusNodes[section],
                      // Shown, matching the roleplay editor's own markdown
                      // sections (e.g. "Bakgrunn") — consistent chrome
                      // across every section-navigated editor, not just the
                      // ones whose author happened to pass a label.
                      label: _labelFor(section, l),
                      expands: true,
                      tokenAware: true,
                      overrides: _workingOverrides,
                      planFields: planFields,
                      preview: _previewSections.contains(section.name),
                      // An Exercise cannot declare a plan variable itself
                      // (DESIGN-008 follow-up 06's settled scope), but can
                      // now create one inline for the write-back
                      // `PlanAdditions` carries up to Plan (ADR-0047,
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

    // The plan-declared default is this scope's inherited baseline: an
    // Exercise sits directly under Plan in ADR-0046's chain, with no
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
        initialSectionId: widget.initialSectionId ?? 'exercise',
        sections: [
          FormSection(
            id: 'exercise',
            label: l.exercise(1),
            icon: Icons.update,
            // The base section's app-bar eye swaps the whole section between
            // its fields and the rollup preview (DESIGN-010, revised
            // 2026-07-10) — same toggle the markdown sections use.
            preview: _showRollup,
            onPreviewChanged: (value) => setState(() => _showRollup = value),
            builder: (ctx) => _buildExerciseSectionBody(ctx, l),
          ),
          ...activeMdSections,
          // Last, matching PlanFormScreen: Variabler reads better as
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
        onDelete: widget.exercise != null ? _confirmDeleteExercise : null,
        deleteTooltip: l.deleteExercise,
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

    // Forwards the ambient PlanScope's plan facets (DESIGN-010) — this
    // editor shadows PlanScope with its own (for the live variables list),
    // which would otherwise strand {{plan.name}} at null below here.
    final ambientPlan = PlanScope.maybeOf(context);

    return PlanScope(
      // Declared variables plus anything created inline this session, so a
      // just-created {{var.x}} chip resolves live (amber) instead of red
      // (ADR-0047, DESIGN-009 follow-up 4).
      variables: [...widget.variables, ..._pendingVariables],
      planName: ambientPlan?.planName,
      planDescription: ambientPlan?.planDescription,
      planCounts: ambientPlan?.planCounts,
      child: scoped,
    );
  }

  /// The DESIGN-008 default section for [Exercise]: the short structural
  /// fields that never become their own section (name, start time, the
  /// scheduling counters).
  Widget _buildExerciseSectionBody(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final planFields = [
      ...PlanFieldTokens.plan(l10n),
      ...PlanFieldTokens.exercise(l10n),
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
                      label: l10n.exerciseName,
                      autofocus: true,
                      tokenAware: true,
                      overrides: _workingOverrides,
                      planFields: planFields,
                      onCreateVariable: _createVariableInline,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? l10n.pleaseEnterAName
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  IntrinsicWidth(child: _buildStartTimeField(context, l10n)),
                ],
              ),
              const SizedBox(height: 16.0),
              _buildTimeSection(context, l10n),
              const SizedBox(height: 16.0),
              if (_legacyOversizedCounters) ...[
                MaterialBanner(
                  content: Text(l10n.legacyOversizedExerciseNotice),
                  actions: const [SizedBox.shrink()],
                  padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
                  leading: const Icon(Icons.info_outline),
                ),
                const SizedBox(height: 16.0),
              ],
              // Above the counters, because it decides what they mean: outside a ring
              // route the round count is derived rather than authored (ADR-0062).
              //
              // The gap is here rather than in the field: a framed box between two rows
              // of underlined ones needs room to read as its own thing, and that is a
              // fact about this layout, not about the control.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: ExerciseModeField(
                  mode: _mode,
                  onChanged: _onModeChanged,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _numberOfTeamsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.numberOfTeams,
                      ),
                      onChanged: (value) {
                        if (_stationsTracksTeams) {
                          _numberOfStationsController.text = value;
                        }
                        setState(() {});
                      },
                      validator: (value) {
                        final counterError = _validateCounter(value, l10n);
                        if (counterError != null) return counterError;
                        if (_isValidNumber(_numberOfStationsController.text) &&
                            int.parse(value!) >
                                int.parse(_numberOfStationsController.text)) {
                          return l10n.mustBeEqualToOrLessThanNumberOf(
                            l10n.station(2).toLowerCase(),
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
                        labelText: l10n.numberOfStations,
                      ),
                      onChanged: (_) {
                        _stationsTracksTeams = false;
                        setState(() {});
                      },
                      validator: (value) {
                        final counterError = _validateCounter(value, l10n);
                        if (counterError != null) return counterError;
                        if (_isValidNumber(_numberOfTeamsController.text) &&
                            int.parse(value!) <
                                int.parse(_numberOfTeamsController.text)) {
                          return l10n.mustBeEqualToOrGreaterThanNumberOf(
                            l10n.team(2).toLowerCase(),
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                  // A round count is an input in a ring route and a consequence
                  // everywhere else — `together` runs one round per station and `split`
                  // one per parallel group (ADR-0062). So outside ring the field is not
                  // shown at all: a disabled input reads as something the app has
                  // broken, and the number belongs with the other things the form
                  // derives from these counters, in the note below.
                  if (_mode == ExerciseMode.ring) ...[
                    const SizedBox(width: 16.0),
                    Expanded(
                      child: TextFormField(
                        controller: _numberOfRoundsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.numberOfRounds,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (value) => _validateCounter(value, l10n),
                      ),
                    ),
                  ],
                ],
              ),
              ?_buildRoundsNote(l10n),
              // Only in split: the other modes generate their grouping, so there is
              // nothing here for an author to decide (ADR-0062).
              if (_mode == ExerciseMode.split) ...[
                const SizedBox(height: 8),
                ExerciseGroupsSection(
                  groups: _groups,
                  stations: widget.exercise?.stations ?? const [],
                  teams: PlanService().activePlan?.teams ?? const [],
                  numberOfTeams:
                      int.tryParse(_numberOfTeamsController.text) ?? 1,
                  exerciseNumber: (widget.exercise?.index ?? 0) + 1,
                  stationNumberFormat:
                      PlanService().activePlan?.stationNumberFormat ??
                      StationNumberFormat.dotted,
                  onChanged: (groups) => setState(() => _groups = groups),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (!_showRollup) return fields;

    return RollupCard.withScrollable(
      context: context,
      sections: [
        // The derived timetable, first, from the values in the form right now — not
        // from the last save (ADR-0062, mockup panel 3). This is the answer to "what
        // does this mode actually produce": the author reads the round table instead
        // of working the clock out, and reads it here because the preview is where the
        // brief's own rendering of it lives. Rendered by the same markdown path, from
        // the same `rotationRoundTable` the brief calls.
        ?_roundTablePreview(l10n),
        for (final section in _ExerciseSection.values)
          if (_activeSections.contains(section))
            RollupSection(
              id: section.name,
              label: _labelFor(section, l10n),
              text: _sectionControllers[section]!.text,
              overrides: _workingOverrides,
            ),
      ],
    );
  }

  /// The round table for the values currently in the form, or null when they do not
  /// yet describe a schedule.
  ///
  /// Built through `generateSchedule`, the same derivation save uses, so the preview
  /// cannot disagree with what saving would produce. Null rather than a partial table
  /// while the counters are mid-edit: `generateSchedule` asserts a ring route has at
  /// least one station per team, and an author halfway through typing "4" over "1"
  /// briefly does not.
  RollupSection? _roundTablePreview(AppLocalizations l10n) {
    final teams = int.tryParse(_numberOfTeamsController.text);
    final stations = int.tryParse(_numberOfStationsController.text);
    final rounds = _effectiveRounds();
    final execution = int.tryParse(_executionTimeController.text);
    final evaluation = int.tryParse(_evaluationTimeController.text);
    final rotation = int.tryParse(_rotationTimeController.text);
    if (teams == null ||
        stations == null ||
        rounds == null ||
        execution == null ||
        evaluation == null ||
        rotation == null ||
        teams < 1 ||
        stations < 1 ||
        rounds < 1 ||
        (_mode == ExerciseMode.ring && teams > stations)) {
      return null;
    }
    final preview = PlanService.generateSchedule(
      name: _nameController.text,
      startTime: _startTime,
      numberOfTeams: teams,
      numberOfStations: stations,
      numberOfRounds: rounds,
      executionTime: execution,
      evaluationTime: evaluation,
      rotationTime: rotation,
      localizations: l10n,
      mode: _mode,
      groups: _groups,
      stations: widget.exercise?.stations ?? const [],
    );
    // The same two plan-level facts `ExerciseGroupsSection` above reads, so the
    // Station column's codes in a `split` round table match the codes the author
    // just placed the teams against.
    final table = rotationRoundTable(
      preview,
      l10n.brief,
      stationNumberFormat:
          PlanService().activePlan?.stationNumberFormat ??
          StationNumberFormat.dotted,
      exerciseNumber: (widget.exercise?.index ?? 0) + 1,
    );
    if (table.isEmpty) return null;
    return RollupSection(id: 'roundTable', label: l10n.roundTable, text: table);
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
  /// mirrors `PlanFormScreen._sectionsWithUndeclaredTokens`, scoped to
  /// only the fields this editor edits. Declared-but-empty never blocks;
  /// only an undeclared name does, matching the Plan editor's rule.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimeRow(localizations),
        ?_buildStationOverrideNote(localizations),
      ],
    );
  }

  /// Says so when the stations have taken these three over.
  ///
  /// Without it these fields quietly stop describing the exercise: a station may own
  /// any of the three (ADR-0062), so an author reading "15 | 10 | 5" here and 135-minute
  /// rounds in the table below has no way to connect them. Null when no station
  /// overrides anything, which is almost every exercise.
  Widget? _buildStationOverrideNote(AppLocalizations localizations) {
    final stations = widget.exercise?.stations ?? const <Station>[];
    final overriding = stations
        .where(
          (s) =>
              s.executionTime != null ||
              s.evaluationTime != null ||
              s.rotationTime != null,
        )
        .length;
    if (overriding == 0) return null;

    final execution = int.tryParse(_executionTimeController.text);
    final evaluation = int.tryParse(_evaluationTimeController.text);
    final rotation = int.tryParse(_rotationTimeController.text);
    final rounds = _effectiveRounds();
    if (execution == null ||
        evaluation == null ||
        rotation == null ||
        rounds == null ||
        rounds < 1) {
      return null;
    }

    // Through the same derivation the schedule uses, so this note cannot claim a length
    // the exercise does not have.
    final fallback = (
      execution: execution,
      evaluation: evaluation,
      rotation: rotation,
    );
    final totals = ExerciseSchedule.phaseMinutesFor(
      mode: _mode,
      numberOfRounds: rounds,
      fallback: fallback,
      stationMinutes: ExerciseSchedule.stationMinutesFrom(
        stations: stations,
        fallback: fallback,
      ),
      groups: [
        for (final group in _groups)
          [for (final slot in group.stations) slot.stationIndex],
      ],
    ).map((p) => p.execution + p.evaluation + p.rotation).toList()..sort();
    if (totals.isEmpty) return null;

    final text = totals.first == totals.last
        ? localizations.exerciseStationsOverrideUniform(
            overriding,
            totals.first,
          )
        : localizations.exerciseStationsOverrideRange(
            overriding,
            totals.first,
            totals.last,
          );
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.tertiary,
        ),
      ),
    );
  }

  Widget _buildTimeRow(AppLocalizations localizations) {
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
            content: Text(l.planSaveBlockedUndeclaredVariable(sections)),
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
      // Not `int.parse` of the controller: the field is absent outside a ring route, so
      // its text is only as good as the last save — and can be empty, if the author
      // cleared it in ring and then changed the mode.
      final numberOfRounds =
          _effectiveRounds() ?? int.parse(_numberOfStationsController.text);
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
      final newExercise = PlanService.generateSchedule(
        mode: _mode,
        groups: _groups,
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
      Navigator.of(
        context,
      ).pop(ExerciseFormSave(withBrief, variableAdditions(_pendingVariables)));
    }
  }

  /// Confirms and returns an [ExerciseFormDelete] (the "Slett øvelse" AppBar
  /// action, shown only when editing an existing exercise).
  Future<void> _confirmDeleteExercise() async {
    final exercise = widget.exercise;
    if (exercise == null) return;
    final l = context.l10n;
    final confirmed = await confirmDestructive(
      context,
      title: l.deleteExercise,
      message: l.confirmDeleteExercise,
      confirmLabel: l.delete,
    );
    if (confirmed && mounted) {
      Navigator.of(context).pop(ExerciseFormDelete(exercise));
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

  /// The round count the schedule will actually have, from the form as it stands.
  ///
  /// Only a ring route takes this from the author. `together` runs one round per
  /// station and `split` one per parallel group, so there the controller holds whatever
  /// was last saved and nothing keeps it true — which is how the form came to report
  /// four rounds for a split whose groups derive three. Null while the counters are
  /// mid-edit.
  int? _effectiveRounds() {
    final authored = int.tryParse(_numberOfRoundsController.text);
    if (_mode == ExerciseMode.ring) return authored;
    final stations = int.tryParse(_numberOfStationsController.text);
    if (stations == null || stations < 1) return null;
    // `roundsForMode` falls back to the station count for a split with no groups yet.
    // True, but not a rule to teach: the groups section below is already asking for the
    // first group, so the note stays quiet until there is one.
    if (_mode == ExerciseMode.split && _groups.isEmpty) return null;
    return ExerciseSchedule.roundsForMode(
      mode: _mode,
      numberOfRounds: authored ?? stations,
      numberOfStations: stations,
      numberOfGroups: _groups.length,
    );
  }

  /// What the counters above imply, in one line: how the rounds and the stations
  /// divide up in a ring route, and where the round count came from in the modes that
  /// derive it.
  Widget? _buildRoundsNote(AppLocalizations localizations) {
    final numberOfRounds = _effectiveRounds();
    final numberOfStations = int.tryParse(_numberOfStationsController.text);
    if (numberOfRounds == null ||
        numberOfStations == null ||
        numberOfRounds <= 0 ||
        numberOfStations <= 0) {
      return null;
    }

    final String text;
    switch (_mode) {
      case ExerciseMode.ring:
        // Revisits and under-coverage are ring-route facts — they compare a rotation's
        // length against the stations it rotates through. Outside ring there is no
        // rotation to be short of, so this stays where it belongs.
        if (numberOfRounds == numberOfStations) return null;
        text = numberOfRounds > numberOfStations
            ? localizations.stationsRevisitNote(
                numberOfRounds,
                numberOfStations,
              )
            : localizations.stationsUnderCoverageNote(
                numberOfRounds,
                numberOfStations,
              );
      case ExerciseMode.together:
        text = localizations.exerciseRoundsDerivedPerStation(numberOfRounds);
      case ExerciseMode.split:
        text = localizations.exerciseRoundsDerivedPerGroup(numberOfRounds);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.tertiary,
        ),
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
