import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/views/widgets/optional_field_sections.dart';

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
  final _briefIntroController = TextEditingController();
  final _commsController = TextEditingController();
  final _beforeRoundController = TextEditingController();

  final _briefIntroFocus = FocusNode();
  final _commsFocus = FocusNode();
  final _beforeRoundFocus = FocusNode();

  late Set<_Section> _activeSections;

  @override
  void initState() {
    super.initState();
    final p = widget.program;
    _nameController.text = p.name;
    _descriptionController.text = p.description;
    _briefIntroController.text = p.briefIntroMd ?? '';
    _commsController.text = p.commsMd ?? '';
    _beforeRoundController.text = p.beforeRoundMd ?? '';
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
    _briefIntroController.dispose();
    _commsController.dispose();
    _beforeRoundController.dispose();
    _briefIntroFocus.dispose();
    _commsFocus.dispose();
    _beforeRoundFocus.dispose();
    super.dispose();
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
      body: SafeArea(
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
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final updated = widget.program.copyWith(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      briefIntroMd: _readSection(_Section.briefIntro),
      commsMd: _readSection(_Section.comms),
      beforeRoundMd: _readSection(_Section.beforeRound),
      metadata: widget.program.metadata.copyWith(updated: DateTime.now()),
    );
    Navigator.of(context).pop(updated);
  }
}
