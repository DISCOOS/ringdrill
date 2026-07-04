import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/shell/window_size_class.dart';
import 'package:ringdrill/views/widgets/ringdrill_sheet.dart';

/// Describes one navigable section of a [SectionNavigatedForm] (DESIGN-008).
///
/// [builder] renders the section body on demand — only the selected
/// section's builder is invoked. [removable] gates the section's own
/// overflow "remove" action (ADR-0031: never a per-row pencil); the default
/// section of an entity (e.g. "Plan" for `Program`) is never removable.
class FormSection {
  const FormSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
    this.removable = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  final bool removable;
}

/// Shared DESIGN-008 section-navigated editor shell: a dropdown switcher on
/// compact, a master/detail rail on medium/expanded
/// ([WindowSizeClass.hasMasterDetail], ADR-0030).
///
/// Owns the chrome (close, save, title/switcher) and the selected-section
/// state. The caller owns section content, the active/addable split and
/// persistence — [onAdd]/[onRemove] only notify which section id changed,
/// [sections] is expected to reflect that change on the next build.
///
/// This widget renders its own [Scaffold] and [AppBar] rather than assuming
/// the [openFormSurface] host provides one, mirroring every other entity
/// form (ADR-0030: "form's own AppBar kept" — the host `Dialog` on wide has
/// no chrome of its own).
class SectionNavigatedForm extends StatefulWidget {
  const SectionNavigatedForm({
    super.key,
    required this.title,
    required this.sections,
    required this.addable,
    required this.onAdd,
    required this.onRemove,
    required this.onSave,
    required this.onClose,
    this.initialSectionId,
  });

  /// Static title shown in the wide AppBar. On compact the AppBar title
  /// slot is replaced by the section switcher instead.
  final String title;

  /// Ordered, active sections only.
  final List<FormSection> sections;

  /// Unused optional sections, offered under "Legg til seksjon".
  final List<FormSection> addable;

  /// Notified with a section id from [addable] when the author adds it.
  final ValueChanged<String> onAdd;

  /// Notified with a section id from [sections] when the author removes it.
  /// Only called for sections with [FormSection.removable] true.
  final ValueChanged<String> onRemove;
  final VoidCallback onSave;
  final VoidCallback onClose;
  final String? initialSectionId;

  @override
  State<SectionNavigatedForm> createState() => _SectionNavigatedFormState();
}

class _SectionNavigatedFormState extends State<SectionNavigatedForm> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSectionId ?? widget.sections.first.id;
  }

  FormSection _sectionOrFirst(String id) => widget.sections.firstWhere(
    (s) => s.id == id,
    orElse: () => widget.sections.first,
  );

  /// Selects [id] if it is already active, otherwise treats it as an
  /// [FormSection] from [widget.addable]: activates it via [onAdd] and
  /// selects it, matching "adding one activates it and selects its new
  /// section".
  void _selectOrAdd(String id) {
    if (widget.sections.any((s) => s.id == id)) {
      setState(() => _selectedId = id);
    } else {
      widget.onAdd(id);
      setState(() => _selectedId = id);
    }
  }

  void _removeCurrent(FormSection current) {
    if (!current.removable) return;
    widget.onRemove(current.id);
    // The default section is always first and never removable, so it is
    // always a sensible fallback once the current section is gone.
    setState(() => _selectedId = widget.sections.first.id);
  }

  Future<void> _openSwitcher(AppLocalizations l10n) async {
    final selected = await showRingdrillActionSheet<String>(
      context: context,
      builder: (_) => _SectionSwitcherSheet(
        sections: widget.sections,
        addable: widget.addable,
        selectedId: _selectedId,
      ),
    );
    if (selected != null) _selectOrAdd(selected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = _sectionOrFirst(_selectedId);
    final wide = WindowSizeClass.of(context).hasMasterDetail;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.cancel,
          onPressed: widget.onClose,
        ),
        title: wide
            ? Text(widget.title)
            : Tooltip(
                message: l10n.formSectionSwitcherTooltip,
                child: InkWell(
                  onTap: () => _openSwitcher(l10n),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text(current.label)),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
        actions: [
          if (!wide && current.removable)
            PopupMenuButton<String>(
              onSelected: (_) => _removeCurrent(current),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'remove',
                  child: Text(l10n.formSectionRemoveAction),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 16),
            child: ElevatedButton(
              onPressed: widget.onSave,
              child: Text(l10n.save),
            ),
          ),
        ],
      ),
      body: wide
          ? _WideBody(
              sections: widget.sections,
              addable: widget.addable,
              current: current,
              l10n: l10n,
              onSelect: _selectOrAdd,
              onRemove: () => _removeCurrent(current),
            )
          : SafeArea(child: current.builder(context)),
    );
  }
}

/// The compact section switcher, rendered inside [showRingdrillActionSheet].
/// A flat list of active sections, then (if any exist) a "Legg til seksjon"
/// entry that reveals the addable ones below it in place.
class _SectionSwitcherSheet extends StatefulWidget {
  const _SectionSwitcherSheet({
    required this.sections,
    required this.addable,
    required this.selectedId,
  });

  final List<FormSection> sections;
  final List<FormSection> addable;
  final String selectedId;

  @override
  State<_SectionSwitcherSheet> createState() => _SectionSwitcherSheetState();
}

class _SectionSwitcherSheetState extends State<_SectionSwitcherSheet> {
  bool _showAddable = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      shrinkWrap: true,
      children: [
        for (final section in widget.sections)
          ListTile(
            leading: Icon(section.icon),
            title: Text(section.label),
            trailing: section.id == widget.selectedId
                ? const Icon(Icons.check)
                : null,
            onTap: () => Navigator.pop(context, section.id),
          ),
        if (widget.addable.isNotEmpty) ...[
          const Divider(height: 1),
          ListTile(
            leading: Icon(_showAddable ? Icons.expand_less : Icons.add),
            title: Text(l10n.formSectionAddAction),
            onTap: () => setState(() => _showAddable = !_showAddable),
          ),
          if (_showAddable)
            for (final section in widget.addable)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 32, right: 16),
                leading: Icon(section.icon),
                title: Text(section.label),
                onTap: () => Navigator.pop(context, section.id),
              ),
        ],
      ],
    );
  }
}

/// Master/detail body for medium/expanded: a left rail listing sections
/// (~210 logical px, per DESIGN-008's `variables-wide.html` mockup) and a
/// detail pane with its own header (label + overflow remove) above the
/// current section's body.
class _WideBody extends StatelessWidget {
  const _WideBody({
    required this.sections,
    required this.addable,
    required this.current,
    required this.l10n,
    required this.onSelect,
    required this.onRemove,
  });

  final List<FormSection> sections;
  final List<FormSection> addable;
  final FormSection current;
  final AppLocalizations l10n;
  final ValueChanged<String> onSelect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 210,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: _SectionRail(
              sections: sections,
              addable: addable,
              selectedId: current.id,
              onSelect: onSelect,
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        current.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (current.removable)
                      PopupMenuButton<String>(
                        onSelected: (_) => onRemove(),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'remove',
                            child: Text(l10n.formSectionRemoveAction),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(child: current.builder(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionRail extends StatefulWidget {
  const _SectionRail({
    required this.sections,
    required this.addable,
    required this.selectedId,
    required this.onSelect,
  });

  final List<FormSection> sections;
  final List<FormSection> addable;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  State<_SectionRail> createState() => _SectionRailState();
}

class _SectionRailState extends State<_SectionRail> {
  bool _showAddable = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      children: [
        for (final section in widget.sections)
          _SectionRailTile(
            section: section,
            selected: section.id == widget.selectedId,
            onTap: () => widget.onSelect(section.id),
          ),
        if (widget.addable.isNotEmpty) ...[
          const Divider(height: 17),
          ListTile(
            dense: true,
            leading: Icon(_showAddable ? Icons.expand_less : Icons.add),
            title: Text(l10n.formSectionAddAction),
            onTap: () => setState(() => _showAddable = !_showAddable),
          ),
          if (_showAddable)
            for (final section in widget.addable)
              _SectionRailTile(
                section: section,
                selected: false,
                onTap: () => widget.onSelect(section.id),
              ),
        ],
      ],
    );
  }
}

class _SectionRailTile extends StatelessWidget {
  const _SectionRailTile({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final FormSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Theme.of(context).colorScheme.primary : null;
    return ListTile(
      dense: true,
      leading: Icon(section.icon, color: color),
      title: Text(
        section.label,
        style: TextStyle(
          color: color,
          fontWeight: selected ? FontWeight.w600 : null,
        ),
      ),
      selected: selected,
      onTap: onTap,
    );
  }
}
