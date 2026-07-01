import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/numbering.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/optional_field_sections.dart';

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
  const ProgramFormScreen({super.key, required this.program});

  final Program program;

  @override
  State<ProgramFormScreen> createState() => _ProgramFormScreenState();
}

class _ProgramFormScreenState extends State<ProgramFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagInputController = TextEditingController();
  final _briefIntroController = TextEditingController();
  final _commsController = TextEditingController();
  final _beforeRoundController = TextEditingController();

  final _briefIntroFocus = FocusNode();
  final _commsFocus = FocusNode();
  final _beforeRoundFocus = FocusNode();

  late List<String> _tags;
  late Set<_Section> _activeSections;
  late StationNumberFormat _stationNumberFormat;
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
      return;
    }
    setState(() {
      _tags.add(tag);
      _tagError = null;
    });
    _tagInputController.clear();
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
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
                  _TagsEditor(
                    tags: _tags,
                    controller: _tagInputController,
                    errorText: _tagError,
                    onSubmit: () => _submitTag(localizations),
                    onRemove: _removeTag,
                    label: localizations.programEditorTagsLabel,
                    hint: localizations.programEditorTagsHint,
                    removeTooltip: localizations.programEditorTagRemoveTooltip,
                  ),
                  const SizedBox(height: 24),
                  _StationNumberFormatPicker(
                    value: _stationNumberFormat,
                    onChanged: (f) => setState(() => _stationNumberFormat = f),
                  ),
                  const Divider(height: 32),
                  OptionalFieldSections<_Section>(
                    sections: sectionSpecs,
                    activeIds: _activeSections,
                    onAdd: _addSection,
                    onRemove: _removeSection,
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
      metadata: widget.program.metadata.copyWith(updated: DateTime.now()),
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
    required this.onSubmit,
    required this.onRemove,
    required this.label,
    required this.hint,
    required this.removeTooltip,
    this.errorText,
  });

  final List<String> tags;
  final TextEditingController controller;
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

/// Segmented picker for [StationNumberFormat]. Shows a live example next
/// to the label so the format choice is immediately legible.
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
    final example = switch (value) {
      StationNumberFormat.dotted => '1.1, 1.2',
      StationNumberFormat.alpha => '1a, 1b',
    };
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
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<StationNumberFormat>(
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
        ),
        const SizedBox(height: 4),
        Text(
          l10n.stationNumberFormatPreview(example),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
