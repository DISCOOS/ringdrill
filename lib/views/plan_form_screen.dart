import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/plan.dart';
import 'package:ringdrill/utils/plan_variable_refs.dart';
import 'package:ringdrill/utils/plan_variables.dart';
import 'package:ringdrill/utils/variable_values.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/plan_field_tokens.dart';
import 'package:ringdrill/views/widgets/plan_scope.dart';
import 'package:ringdrill/views/widgets/ringdrill_text_field.dart';
import 'package:ringdrill/views/widgets/section_navigated_form.dart';
import 'package:ringdrill/views/widgets/token_text_editing_controller.dart';
import 'package:ringdrill/views/widgets/variables_section.dart';

const _kTagMaxLength = 40;

/// ADR-0046 variable-name slug rule, enforced by [VariablesSection] itself
/// on create/rename — re-checked here for [_PlanFormScreenState]'s
/// `_createVariableInline`, whose candidate name comes from the insertion
/// menu's looser `\w*` filter capture, not user-typed dialog input.
final _slugPattern = RegExp(r'^[a-z][a-z0-9_]*$');

/// The shared `{{var.<name>[.facet]}}` shape — imported rather than
/// duplicated so a faceted token (`{{var.x.utm}}`, DESIGN-008 follow-up 11)
/// on an undeclared name is caught by the save gate too.
final _varTokenPattern = planVariableTokenPattern;

/// Turns a [PlanVariableReference] — deliberately unlocalized, since
/// `plan_variable_refs.dart` stays Flutter-free — into a display string for
/// [VariablesSection]'s delete-blocked usage list, e.g. "Øvelse 3 › Metode"
/// or "Post 1.1 › Situasjon". Reuses the field labels already declared for
/// the brief template sections rather than adding a parallel set, plus
/// `l10n.exercise(1)`/`l10n.station(1)` for the bare singular "Øvelse"/
/// "Post" prefix.
String _describeReference(PlanVariableReference ref, AppLocalizations l) {
  final fieldLabel = switch (ref.field) {
    PlanVariableField.planName => l.planName,
    PlanVariableField.planDescription => l.planDescription,
    PlanVariableField.planBriefIntro => l.briefSectionPlanIntro,
    PlanVariableField.planComms => l.briefSectionPlanComms,
    PlanVariableField.planBeforeRound => l.briefSectionPlanBeforeRound,
    PlanVariableField.exerciseName => l.exerciseName,
    PlanVariableField.exerciseMethod => l.briefSectionExerciseMethod,
    PlanVariableField.exerciseLearningGoals =>
      l.briefSectionExerciseLearningGoals,
    PlanVariableField.exerciseTrainingFocus =>
      l.briefSectionExerciseTrainingFocus,
    PlanVariableField.exerciseOrderFormat => l.briefSectionExerciseOrderFormat,
    PlanVariableField.exerciseExecutionTips =>
      l.briefSectionExerciseExecutionTips,
    PlanVariableField.exerciseComms => l.briefSectionExerciseComms,
    PlanVariableField.exerciseOverride => l.variablesSectionOverrideFieldLabel,
    PlanVariableField.stationName => l.stationName,
    PlanVariableField.stationDescription => l.stationDescription,
    PlanVariableField.stationEquipment => l.briefSectionStationEquipment,
    PlanVariableField.stationSituation => l.briefSectionStationSituation,
    PlanVariableField.stationMission => l.briefSectionStationMission,
    PlanVariableField.stationLogistics => l.briefSectionStationLogistics,
    PlanVariableField.stationCriticalQuestions =>
      l.briefSectionStationCriticalQuestions,
    PlanVariableField.stationLeaderAnswers =>
      l.briefSectionStationLeaderAnswers,
    PlanVariableField.stationDirectorNotes =>
      l.briefSectionStationDirectorNotes,
    PlanVariableField.stationOverride => l.variablesSectionOverrideFieldLabel,
    PlanVariableField.roleplayNameField => l.roleName,
    PlanVariableField.roleplayBehavior => l.roleBehavior,
    PlanVariableField.roleplayBackground => l.roleBackground,
    PlanVariableField.roleplayProps => l.catalogDiffFieldProps,
  };

  if (ref.roleplayName != null) return '${ref.roleplayName} › $fieldLabel';
  if (ref.stationCode != null) {
    return '${l.station(1)} ${ref.stationCode} › $fieldLabel';
  }
  if (ref.exerciseNumber != null) {
    return '${l.exercise(1)} ${ref.exerciseNumber} › $fieldLabel';
  }
  return fieldLabel;
}

/// Optional addable sections on [Plan] beyond name + description.
enum _Section { briefIntro, comms, beforeRound }

/// Edit form for [Plan] base fields (name + description) and the
/// addable DESIGN-004 markdown brief sections (`briefIntroMd`, `commsMd`,
/// `beforeRoundMd`).
///
/// Pops with the updated [Plan] on save, or `null` on cancel. The
/// caller is responsible for persisting the result through the plan
/// save path (e.g. `PlanService.replacePlan`).
class PlanFormScreen extends StatefulWidget {
  const PlanFormScreen({super.key, required this.plan});

  final Plan plan;

  @override
  State<PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanFormScreenState extends State<PlanFormScreen> {
  final _formKey = GlobalKey<FormState>();

  /// Token-aware so `RingDrillTextField(tokenAware: true)` can drive its
  /// chips from [PlanScope] (DESIGN-008 follow-up 09).
  final TextEditingController _nameController = TokenTextEditingController();
  final TextEditingController _descriptionController =
      TokenTextEditingController();
  final _tagInputController = TextEditingController();
  final _tagInputFocus = FocusNode();

  /// Token-aware so `RingDrillTextArea(tokenAware: true)` can drive its
  /// chips from [PlanScope].
  final TextEditingController _briefIntroController =
      TokenTextEditingController();
  final TextEditingController _commsController = TokenTextEditingController();
  final TextEditingController _beforeRoundController =
      TokenTextEditingController();

  final _briefIntroFocus = FocusNode();
  final _commsFocus = FocusNode();
  final _beforeRoundFocus = FocusNode();

  late List<String> _tags;
  late Set<_Section> _activeSections;

  /// Section ids currently showing their resolved-markdown preview
  /// (DESIGN-010) rather than the editable chip field — remembered for the
  /// session, per section, not editor-wide (DESIGN-010's settled decisions).
  final Set<String> _previewSections = {};

  late StationNumberFormat _stationNumberFormat;
  String? _languageCode;
  String? _tagError;

  /// Working plan-variable registry (DESIGN-008 Stage 5), edited by
  /// [VariablesSection] and read by [_save].
  late List<DrillVariable> _variables;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _nameController.text = p.name;
    _descriptionController.text = p.description;
    _tags = List<String>.from(p.tags);
    _briefIntroController.text = p.briefIntroMd ?? '';
    _commsController.text = p.commsMd ?? '';
    _beforeRoundController.text = p.beforeRoundMd ?? '';
    _stationNumberFormat = p.stationNumberFormat;
    _languageCode = p.metadata.languageCode;
    _variables = List<DrillVariable>.from(p.variables);
    _activeSections = {
      if (p.briefIntroMd != null) _Section.briefIntro,
      if (p.commsMd != null) _Section.comms,
      if (p.beforeRoundMd != null) _Section.beforeRound,
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagInputController.dispose();
    _tagInputFocus.dispose();
    _briefIntroController.dispose();
    _commsController.dispose();
    _beforeRoundController.dispose();
    _briefIntroFocus.dispose();
    _commsFocus.dispose();
    _beforeRoundFocus.dispose();
    super.dispose();
  }

  void _submitTag(AppLocalizations l) {
    final raw = _tagInputController.text;
    final tag = raw.trim().toLowerCase();
    if (tag.isEmpty) return;
    if (tag.length > _kTagMaxLength) {
      setState(() => _tagError = l.planEditorTagTooLong);
      return;
    }
    if (_tags.contains(tag)) {
      _tagInputController.clear();
      _tagInputFocus.requestFocus();
      return;
    }
    setState(() {
      _tags.add(tag);
      _tagError = null;
    });
    _tagInputController.clear();
    // Submitting (Enter or the add button) drops focus on some platforms
    // since the field's textInputAction is "done". Re-request it so users
    // can add several tags back-to-back without tapping the field again.
    _tagInputFocus.requestFocus();
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  void _addSection(_Section section) {
    setState(() => _activeSections.add(section));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusFor(section).requestFocus();
    });
  }

  void _removeSection(_Section section) {
    setState(() {
      _activeSections.remove(section);
      _previewSections.remove(section.name);
      _controllerFor(section).clear();
    });
  }

  void _togglePreview(String sectionId, bool preview) => setState(() {
    if (preview) {
      _previewSections.add(sectionId);
    } else {
      _previewSections.remove(sectionId);
    }
  });

  /// The in-memory [Plan] as the editor currently stands — every
  /// controller's live text plus [_variables] — not [widget.plan], which
  /// is the value the editor was *opened* with. `plan_variable_refs.dart`'s
  /// rename/reference-count helpers need this live snapshot: a variable
  /// just typed into a section, or a rename not yet saved, must still be
  /// accounted for correctly while the editor is open.
  Plan _workingPlan() => widget.plan.copyWith(
    briefIntroMd: _readSection(_Section.briefIntro),
    commsMd: _readSection(_Section.comms),
    beforeRoundMd: _readSection(_Section.beforeRound),
    variables: _variables,
  );

  void _addVariable(DrillVariable variable) {
    setState(() => _variables = [..._variables, variable]);
  }

  /// Runs the ADR-0046 plan-wide rewrite over the live working plan (not
  /// just [_variables]): every markdown field's `{{var.<oldName>}}` becomes
  /// `{{var.<newName>}}`, every `variableOverrides` key is renamed, and the
  /// registry entry itself is renamed. The rewritten markdown then has to
  /// flow back into this editor's own controllers — `renameVariable`
  /// returns a whole new `Plan`, but `_briefIntroController` etc. are
  /// what the section fields actually read. The renamed registry itself
  /// reaches every field automatically through [PlanScope] once this
  /// `setState` rebuild runs — no separate controller push needed.
  void _renameVariablePlanWide(String oldName, String newName) {
    final renamed = renameVariable(_workingPlan(), oldName, newName);
    setState(() {
      _briefIntroController.text = renamed.briefIntroMd ?? '';
      _commsController.text = renamed.commsMd ?? '';
      _beforeRoundController.text = renamed.beforeRoundMd ?? '';
      _variables = renamed.variables;
    });
  }

  void _deleteVariable(String name) {
    setState(
      () => _variables = _variables.where((v) => v.name != name).toList(),
    );
  }

  /// Replaces the matching entry (name unchanged, no plan-wide rewrite
  /// needed — `{{var.<name>}}` tokens stay valid) — the single sink for the
  /// declaration cards' inline value edits, type changes and hint edits
  /// (DESIGN-008 follow-up 11). The `setState` rebuild passes the updated
  /// registry down through [PlanScope], so a now-non-empty variable's chips
  /// re-resolve from amber to blue without losing focus, the same refresh
  /// path `_addVariable`/`_renameVariablePlanWide` already rely on.
  void _updateVariable(DrillVariable updated) {
    setState(() {
      _variables = [
        for (final v in _variables)
          if (v.name == updated.name) updated else v,
      ];
    });
  }

  /// Wired to the token-aware fields' dormant `onCreateVariable` hook
  /// (DESIGN-008 Stage 4): the insertion menu already inserted
  /// `{{var.<name>}}` before calling this, so all that's left is declaring
  /// it, empty, in the registry — an amber (declared-but-empty) chip is the
  /// intended nudge to fill in a value, not an error. `name` came from the
  /// menu's `\w*` filter capture, which is looser than the ADR-0046 slug
  /// rule (it also allows a leading digit or uppercase) — validate before
  /// declaring; an invalid name is left as an undeclared (red) token for
  /// save-time validation to catch, rather than silently declaring
  /// something that cannot be typed by hand elsewhere.
  void _createVariableInline(String name) {
    if (!_slugPattern.hasMatch(name)) return;
    if (_variables.any((v) => v.name == name)) return;
    _addVariable(DrillVariable(name: name, value: ''));
  }

  /// Plan-scope markdown sections' `{{var.<name>}}` tokens where `name`
  /// is not declared in [_variables] — Stage 5's save-blocking scope is
  /// deliberately just the fields *this* editor edits, not the whole plan
  /// (blocking save over an undeclared token in a station field the user
  /// cannot see or fix here would be a dead end). Rename/delete integrity
  /// (ADR-0046) still walks the whole plan; only this check is scoped down.
  /// Declared-but-empty (amber) never blocks — only undeclared (red) does,
  /// matching the Stage 4 chip-state semantics.
  List<_Section> _sectionsWithUndeclaredTokens() {
    final declared = _variables.map((v) => v.name).toSet();
    return [
      for (final section in _Section.values)
        if (_activeSections.contains(section) &&
            _varTokenPattern
                .allMatches(_controllerFor(section).text)
                .any((m) => !declared.contains(m.group(1))))
          section,
    ];
  }

  /// The base section's name/description labels (DESIGN-008 follow-up 09)
  /// whose text has a `{{var.<name>}}` token not declared in [_variables].
  /// Name/description are unconditionally present, unlike [_Section], so
  /// this is a short parallel check rather than another enum member.
  List<String> _baseFieldLabelsWithUndeclaredTokens(AppLocalizations l) {
    final declared = _variables.map((v) => v.name).toSet();
    bool hasUndeclared(String text) => _varTokenPattern
        .allMatches(text)
        .any((m) => !declared.contains(m.group(1)));
    return [
      if (hasUndeclared(_nameController.text)) l.planName,
      if (hasUndeclared(_descriptionController.text)) l.planDescription,
    ];
  }

  FocusNode _focusFor(_Section section) => switch (section) {
    _Section.briefIntro => _briefIntroFocus,
    _Section.comms => _commsFocus,
    _Section.beforeRound => _beforeRoundFocus,
  };

  TextEditingController _controllerFor(_Section section) => switch (section) {
    _Section.briefIntro => _briefIntroController,
    _Section.comms => _commsController,
    _Section.beforeRound => _beforeRoundController,
  };

  String _labelFor(_Section section, AppLocalizations l) => switch (section) {
    _Section.briefIntro => l.briefSectionPlanIntro,
    _Section.comms => l.briefSectionPlanComms,
    _Section.beforeRound => l.briefSectionPlanBeforeRound,
  };

  String? _readSection(_Section section) {
    if (!_activeSections.contains(section)) return null;
    final value = _controllerFor(section).text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return _buildSectionNavigated(context, localizations);
  }

  /// DESIGN-008 Stage 3. On compact the section switcher occupies the
  /// AppBar title (see [SectionNavigatedForm]), so the DESIGN-006
  /// quick-rename-from-the-AppBar affordance is not available in this mode;
  /// renaming the plan happens through the name field in the "Plan" section
  /// instead, one tap away.
  Widget _buildSectionNavigated(BuildContext context, AppLocalizations l) {
    // The plan editor only ever resolves plan.* (DESIGN-009 follow-up
    // 4b) — PlanFieldTokens.plan(l) is the single source of truth shared
    // with every other editor.
    final planFields = PlanFieldTokens.plan(l);

    final activeMdSections = [
      for (final section in _Section.values)
        if (_activeSections.contains(section))
          FormSection(
            id: section.name,
            label: _labelFor(section, l),
            icon: Icons.description_outlined,
            removable: true,
            preview: _previewSections.contains(section.name),
            onPreviewChanged: (value) => _togglePreview(section.name, value),
            // Keyed by section so switching sections always mounts a fresh
            // field: without a distinguishing key, two sections with the
            // same widget shape at the same tree slot can make Flutter
            // reuse the previous section's State instead of remounting.
            builder: (_) => Padding(
              key: ValueKey(section.name),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: RingDrillTextArea(
                      controller: _controllerFor(section),
                      focusNode: _focusFor(section),
                      // Shown, matching the roleplay editor's own markdown
                      // sections (e.g. "Bakgrunn") — consistent chrome
                      // across every section-navigated editor, not just the
                      // ones whose author happened to pass a label.
                      label: _labelFor(section, l),
                      expands: true,
                      tokenAware: true,
                      planFields: planFields,
                      preview: _previewSections.contains(section.name),
                      onCreateVariable: _createVariableInline,
                    ),
                  ),
                ],
              ),
            ),
          ),
    ];
    final addableSections = [
      for (final section in _Section.values)
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

    // Plan scope has no overrides (ADR-0046), so every RingDrillTextArea
    // above leaves its `overrides` param at the default empty map — a
    // variable's effective value here is always its declared default.
    // Rebuilt from _variables (not widget.plan.variables) on every
    // build, so add/rename/delete/value-edit all flow straight into every
    // live token field automatically: each one reads this scope on its own
    // build, so there is no separate "push the rebuilt list by hand" step
    // (Stages 4-5's approach before PlanScope existed).
    return PlanScope(
      variables: _variables,
      // This editor edits plan.name/description directly (DESIGN-010):
      // its own live controllers are the plan facets, not the ambient
      // PlanScope's last-saved ones, so a {{plan.name}} reference in
      // e.g. briefIntroMd previews the name as it is currently being typed.
      planName: _nameController.text,
      planDescription: _descriptionController.text,
      // The counts have no live controller to read, unlike name and description:
      // this editor cannot add or remove an exercise, so the plan being edited is
      // already the current answer.
      planCounts: PlanScope.countsOf(widget.plan),
      child: Form(
        key: _formKey,
        child: SectionNavigatedForm(
          title: l.editPlan,
          initialSectionId: 'plan',
          sections: [
            FormSection(
              id: 'plan',
              label: l.planSectionPlan,
              icon: Icons.assignment_outlined,
              builder: (ctx) => _buildPlanSectionBody(ctx, l),
            ),
            ...activeMdSections,
            // Last: the markdown sections above are what authors reference
            // {{var.<name>}} from, so Variabler reads better as the section
            // you land on after them, not before.
            FormSection(
              id: 'variables',
              label: l.variablesSectionTitle,
              icon: Icons.data_object,
              builder: (_) => VariablesSection(
                variables: _variables,
                onAdd: _addVariable,
                onRename: _renameVariablePlanWide,
                onDelete: _deleteVariable,
                onUpdate: _updateVariable,
                referenceCount: (name) =>
                    variableReferenceCount(_workingPlan(), name),
                referenceDescriptions: (name) => [
                  for (final ref in variableReferences(_workingPlan(), name))
                    _describeReference(ref, l),
                ],
              ),
            ),
          ],
          addable: addableSections,
          onAdd: (id) => _addSection(_Section.values.byName(id)),
          onRemove: (id) => _removeSection(_Section.values.byName(id)),
          onSave: _save,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// The DESIGN-008 default section for [Plan]: the short structural
  /// fields that never become their own section (name, description,
  /// station-number-format, language, tags).
  Widget _buildPlanSectionBody(BuildContext context, AppLocalizations l) {
    return SafeArea(
      child: DismissKeyboard(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RingDrillTextField(
                controller: _nameController,
                label: l.planName,
                autofocus: true,
                tokenAware: true,
                validator: (value) => value != null && value.trim().isNotEmpty
                    ? null
                    : l.pleaseEnterAName,
              ),
              const SizedBox(height: 16),
              RingDrillTextArea(
                controller: _descriptionController,
                label: l.planDescription,
                hintText: l.planDescriptionHint,
                minLines: 1,
                maxLines: 4,
                tokenAware: true,
              ),
              const Divider(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _StationNumberFormatPicker(
                      value: _stationNumberFormat,
                      onChanged: (f) =>
                          setState(() => _stationNumberFormat = f),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _LanguagePicker(
                    value: _languageCode,
                    onChanged: (v) => setState(() => _languageCode = v),
                  ),
                ],
              ),
              const Divider(height: 32),
              _TagsEditor(
                tags: _tags,
                controller: _tagInputController,
                focusNode: _tagInputFocus,
                errorText: _tagError,
                onSubmit: () => _submitTag(l),
                onRemove: _removeTag,
                label: l.planEditorTagsLabel,
                hint: l.planEditorTagsHint,
                removeTooltip: l.planEditorTagRemoveTooltip,
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l = AppLocalizations.of(context)!;
    final offending = [
      ..._baseFieldLabelsWithUndeclaredTokens(l),
      ..._sectionsWithUndeclaredTokens().map((s) => _labelFor(s, l)),
    ];
    if (offending.isNotEmpty) {
      final sections = offending.join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.planSaveBlockedUndeclaredVariable(sections))),
      );
      return;
    }
    // An invalid typed value blocks save exactly as an unknown token does
    // (DESIGN-008 follow-up 11). State-level, not just the Form validators:
    // the Variabler section may not be mounted (SectionNavigatedForm shows
    // one section at a time), and an invalid default — e.g. after a type
    // change — must still block.
    final invalidNames = [
      for (final v in _variables)
        if (!isVariableValueValid(v.type, v.value)) v.name,
    ];
    if (invalidNames.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.variableSaveBlockedInvalidValue(invalidNames.join(', ')),
          ),
        ),
      );
      return;
    }
    final updated = widget.plan.copyWith(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      tags: List<String>.unmodifiable(_tags),
      stationNumberFormat: _stationNumberFormat,
      briefIntroMd: _readSection(_Section.briefIntro),
      commsMd: _readSection(_Section.comms),
      beforeRoundMd: _readSection(_Section.beforeRound),
      // Values may still be raw user input (e.g. "3,14"); store the
      // canonical encoding now that validation has passed.
      variables: List<DrillVariable>.unmodifiable([
        for (final v in _variables)
          v.copyWith(
            value: canonicalizeVariableValue(v.type, v.value) ?? v.value,
          ),
      ]),
      metadata: widget.plan.metadata.copyWith(
        updated: DateTime.now(),
        languageCode: _languageCode,
      ),
    );
    Navigator.of(context).pop(updated);
  }
}

/// Chip-style tag editor. Existing tags are shown as deletable chips above a
/// text input. Pressing Enter or the submit action on the keyboard adds the
/// tag.
class _TagsEditor extends StatelessWidget {
  const _TagsEditor({
    required this.tags,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onRemove,
    required this.label,
    required this.hint,
    required this.removeTooltip,
    this.errorText,
  });

  final List<String> tags;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final ValueChanged<String> onRemove;
  final String label;
  final String hint;
  final String removeTooltip;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final tag in tags)
                Chip(
                  label: Text(tag),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  deleteButtonTooltipMessage: removeTooltip,
                  onDeleted: () => onRemove(tag),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              tooltip: hint,
              onPressed: onSubmit,
            ),
          ),
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => onSubmit(),
        ),
      ],
    );
  }
}

/// Segmented picker for [StationNumberFormat]. Each segment's own label
/// ("1.1, 1.2" / "1a, 1b") already shows the format's example, so no
/// separate preview is rendered here — this sits beside [_LanguagePicker]
/// in a two-column row to use less vertical space.
class _StationNumberFormatPicker extends StatelessWidget {
  const _StationNumberFormatPicker({
    required this.value,
    required this.onChanged,
  });

  final StationNumberFormat value;
  final ValueChanged<StationNumberFormat> onChanged;

  // exerciseNumberFormat only has one value today; a picker for it will
  // be added when a second ExerciseNumberFormat value is introduced.

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.stationNumberFormatLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<StationNumberFormat>(
          expandedInsets: EdgeInsets.zero,
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: StationNumberFormat.dotted,
              label: Text(l10n.stationNumberFormatDotted),
            ),
            ButtonSegment(
              value: StationNumberFormat.alpha,
              label: Text(l10n.stationNumberFormatAlpha),
            ),
          ],
          selected: {value},
          onSelectionChanged: (selected) => onChanged(selected.single),
        ),
      ],
    );
  }
}

/// Display name per ISO 639-1 code, scoped to the locales the app's own UI
/// currently supports ([AppLocalizations.supportedLocales]). Extend this —
/// and `site/src/lib/languages.ts`'s `LANGUAGE_NAMES` — whenever a new UI
/// locale (ARB file) is added.
const kPlanLanguageNames = <String, String>{'nb': 'Norsk', 'en': 'English'};

/// Dropdown for the plan's *content* language (ADR-0007 addendum) — what
/// language the plan's own name/briefs/exercises are written in, distinct
/// from the app's UI locale. Options come from
/// [AppLocalizations.supportedLocales] so a future third ARB locale extends
/// this picker with no code change here.
///
/// Sits beside the plan-name field, so it is sized to its content rather
/// than stretched full-width: `isExpanded: false` lets the closed-state
/// button size itself to the widest item's text (the underlying
/// [DropdownButton] lays out every item — plus [hint] — to pick that
/// width), instead of jumping in width as the selection changes. Wrapped
/// in [IntrinsicWidth] because a non-expanded [DropdownButtonFormField]
/// placed directly in a [Row] would otherwise receive an unbounded
/// main-axis constraint, which [InputDecorator] asserts against.
///
/// Selecting a language is required: [value] starts `null` only for a
/// plan that predates this field, and [hint] (rather than a selectable
/// "not set" item) prompts the user to choose one before the form can be
/// saved.
class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return IntrinsicWidth(
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        decoration: InputDecoration(labelText: l10n.planLanguageLabel),
        hint: Text(l10n.planLanguageChooseHint),
        items: [
          for (final locale in AppLocalizations.supportedLocales)
            DropdownMenuItem<String?>(
              value: locale.languageCode,
              child: Text(
                kPlanLanguageNames[locale.languageCode] ?? locale.languageCode,
              ),
            ),
        ],
        onChanged: onChanged,
        validator: (v) => v == null ? l10n.pleaseSelectALanguage : null,
      ),
    );
  }
}
