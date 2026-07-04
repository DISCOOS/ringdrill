import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/utils/app_flags.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/markdown_section_field.dart';
import 'package:ringdrill/views/widgets/optional_field_sections.dart';
import 'package:ringdrill/views/widgets/section_navigated_form.dart';

const _kTagMaxLength = 40;

/// Optional addable sections on [Program] beyond name + description.
enum _Section { briefIntro, comms, beforeRound }

/// Edit form for [Program] base fields (name + description) and the
/// addable DESIGN-004 markdown brief sections (`briefIntroMd`, `commsMd`,
/// `beforeRoundMd`).
///
/// Pops with the updated [Program] on save, or `null` on cancel. The
/// caller is responsible for persisting the result through the program
/// save path (e.g. `ProgramService.replaceProgram`).
class ProgramFormScreen extends StatefulWidget {
  const ProgramFormScreen({
    super.key,
    required this.program,
    @visibleForTesting this.debugPlanVariablesOverride,
  });

  final Program program;

  /// Overrides [AppFlags.planVariables] for a test. `bool.fromEnvironment`
  /// is a compile-time const, so a widget test cannot flip it at runtime —
  /// this lets a test render the flag-on section-navigated body without a
  /// `--dart-define`. Production code never sets this; the real flag is
  /// read when it is null.
  @visibleForTesting
  final bool? debugPlanVariablesOverride;

  @override
  State<ProgramFormScreen> createState() => _ProgramFormScreenState();
}

class _ProgramFormScreenState extends State<ProgramFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagInputController = TextEditingController();
  final _tagInputFocus = FocusNode();
  final _briefIntroController = TextEditingController();
  final _commsController = TextEditingController();
  final _beforeRoundController = TextEditingController();

  final _briefIntroFocus = FocusNode();
  final _commsFocus = FocusNode();
  final _beforeRoundFocus = FocusNode();

  late List<String> _tags;
  late Set<_Section> _activeSections;
  late StationNumberFormat _stationNumberFormat;
  String? _languageCode;
  String? _tagError;

  @override
  void initState() {
    super.initState();
    final p = widget.program;
    _nameController.text = p.name;
    _descriptionController.text = p.description;
    _tags = List<String>.from(p.tags);
    _briefIntroController.text = p.briefIntroMd ?? '';
    _commsController.text = p.commsMd ?? '';
    _beforeRoundController.text = p.beforeRoundMd ?? '';
    _stationNumberFormat = p.stationNumberFormat;
    _languageCode = p.metadata.languageCode;
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
      setState(() => _tagError = l.programEditorTagTooLong);
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
      _controllerFor(section).clear();
    });
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
    _Section.briefIntro => l.briefSectionProgramIntro,
    _Section.comms => l.briefSectionProgramComms,
    _Section.beforeRound => l.briefSectionProgramBeforeRound,
  };

  String? _readSection(_Section section) {
    if (!_activeSections.contains(section)) return null;
    final value = _controllerFor(section).text.trim();
    return value.isEmpty ? null : value;
  }

  bool get _planVariablesOn =>
      widget.debugPlanVariablesOverride ?? AppFlags.planVariables;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    if (_planVariablesOn) {
      return _buildSectionNavigated(context, localizations);
    }
    return _buildLegacy(context, localizations);
  }

  /// DESIGN-008 Stage 3, behind `RINGDRILL_PLAN_VARIABLES`. Same controllers,
  /// [_activeSections] and [_save] as the legacy body below — only their
  /// presentation moves into sections. On compact the section switcher
  /// occupies the AppBar title (see [SectionNavigatedForm]), so the
  /// DESIGN-006 quick-rename-from-the-AppBar affordance is not available in
  /// this mode; renaming the plan happens through the name field in the
  /// "Plan" section instead, one tap away.
  Widget _buildSectionNavigated(BuildContext context, AppLocalizations l) {
    final activeMdSections = [
      for (final section in _Section.values)
        if (_activeSections.contains(section))
          FormSection(
            id: section.name,
            label: _labelFor(section, l),
            icon: Icons.description_outlined,
            removable: true,
            builder: (_) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: MarkdownSectionField(
                      controller: _controllerFor(section),
                      focusNode: _focusFor(section),
                      label: _labelFor(section, l),
                      expands: true,
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

    return Form(
      key: _formKey,
      child: SectionNavigatedForm(
        title: l.editProgram,
        initialSectionId: 'plan',
        sections: [
          FormSection(
            id: 'plan',
            label: l.programSectionPlan,
            icon: Icons.assignment_outlined,
            builder: (ctx) => _buildPlanSectionBody(ctx, l),
          ),
          ...activeMdSections,
        ],
        addable: addableSections,
        onAdd: (id) => _addSection(_Section.values.byName(id)),
        onRemove: (id) => _removeSection(_Section.values.byName(id)),
        onSave: _save,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  /// The DESIGN-008 default section for [Program]: the short structural
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
              TextFormField(
                autofocus: true,
                controller: _nameController,
                decoration: InputDecoration(labelText: l.programName),
                validator: (value) => value != null && value.trim().isNotEmpty
                    ? null
                    : l.pleaseEnterAName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l.programDescription,
                  hintText: l.programDescriptionHint,
                  alignLabelWithHint: true,
                ),
              ),
              const Divider(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _StationNumberFormatPicker(
                      value: _stationNumberFormat,
                      onChanged: (f) => setState(() => _stationNumberFormat = f),
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
                label: l.programEditorTagsLabel,
                hint: l.programEditorTagsHint,
                removeTooltip: l.programEditorTagRemoveTooltip,
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegacy(BuildContext context, AppLocalizations localizations) {
    final sectionSpecs = [
      for (final section in _Section.values)
        OptionalFieldSection<_Section>(
          id: section,
          label: _labelFor(section, localizations),
          controller: _controllerFor(section),
          focusNode: _focusFor(section),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: localizations.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(localizations.editProgram),
        actions: [
          ElevatedButton(onPressed: _save, child: Text(localizations.save)),
        ],
        actionsPadding: const EdgeInsets.only(right: 16),
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
                    autofocus: true,
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: localizations.programName,
                    ),
                    validator: (value) =>
                        value != null && value.trim().isNotEmpty
                        ? null
                        : localizations.pleaseEnterAName,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: localizations.programDescription,
                      hintText: localizations.programDescriptionHint,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OptionalFieldSections<_Section>(
                    sections: sectionSpecs,
                    activeIds: _activeSections,
                    onAdd: _addSection,
                    onRemove: _removeSection,
                  ),
                  // Hidden once every optional section has been added: with
                  // no add-buttons left to show, the divider would otherwise
                  // sit directly between two blocks of plain text fields
                  // with nothing distinct to separate.
                  if (_activeSections.length < _Section.values.length)
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
                    onSubmit: () => _submitTag(localizations),
                    onRemove: _removeTag,
                    label: localizations.programEditorTagsLabel,
                    hint: localizations.programEditorTagsHint,
                    removeTooltip: localizations.programEditorTagRemoveTooltip,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final updated = widget.program.copyWith(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      tags: List<String>.unmodifiable(_tags),
      stationNumberFormat: _stationNumberFormat,
      briefIntroMd: _readSection(_Section.briefIntro),
      commsMd: _readSection(_Section.comms),
      beforeRoundMd: _readSection(_Section.beforeRound),
      metadata: widget.program.metadata.copyWith(
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
