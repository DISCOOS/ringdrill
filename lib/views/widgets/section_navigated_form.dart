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
    this.preview,
    this.onPreviewChanged,
  });

  final String id;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  final bool removable;

  /// Whether this section is currently showing its resolved-markdown
  /// preview instead of the editable field (DESIGN-010). Null — the
  /// default — means this section has no single previewable field (the
  /// default/structural section, Variables, Locations/Persons): the
  /// [SectionNavigatedForm] preview toggle is disabled rather than hidden
  /// for it, matching this widget's existing "always render, disable"
  /// convention for the removable-section overflow action (avoids the
  /// `AppBar.actions` row visibly resizing on every section switch).
  final bool? preview;

  /// Notified with the new preview state when the author taps the toggle.
  /// Non-null exactly when [preview] is non-null — the caller (an entity
  /// editor) owns which section id is currently previewing, remembered for
  /// the session, and passes the same bool back into the markdown field's
  /// own `preview` param so the toggle and the field body agree.
  final ValueChanged<bool>? onPreviewChanged;
}

/// Exposes [SectionNavigatedForm]'s section-selection to any section's own
/// body (DESIGN-010) — a section's `builder` only gets a `BuildContext`, so
/// the default section's read-only rollup reads this to jump to (select)
/// another section when the author taps one of the rollup's rendered
/// blocks ("tap-to-edit"), reusing the same [_selectOrAdd] logic the
/// compact switcher and the wide rail already call.
class SectionNavigator extends InheritedWidget {
  const SectionNavigator({
    super.key,
    required this.selectSection,
    required super.child,
  });

  final ValueChanged<String> selectSection;

  static SectionNavigator? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SectionNavigator>();

  @override
  bool updateShouldNotify(SectionNavigator oldWidget) =>
      selectSection != oldWidget.selectSection;
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
    this.entityName,
  });

  /// Static title shown in the AppBar on the default (first) section.
  final String title;

  /// When non-null, shown in the AppBar instead of [title] on every section
  /// except the default (first) one — so secondary sections like Locations,
  /// Persons, and Variables show the entity being edited rather than a
  /// generic label. Callers that don't pass this see no behaviour change.
  final String? entityName;

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

  /// Steps [current] by [delta] within [widget.sections] — never the
  /// addable ones. Clamped: a step past either end is a no-op rather than
  /// wrapping, so the boundary controls can just be disabled instead of
  /// needing their own guard.
  void _step(FormSection current, int delta) {
    final index = widget.sections.indexOf(current);
    if (index < 0) return;
    final next = index + delta;
    if (next < 0 || next >= widget.sections.length) return;
    setState(() => _selectedId = widget.sections[next].id);
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
    final currentIndex = widget.sections.indexOf(current);
    final hasPrevious = currentIndex > 0;
    final hasNext =
        currentIndex >= 0 && currentIndex < widget.sections.length - 1;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.cancel,
          onPressed: widget.onClose,
        ),
        // Compact used to put the section switcher here, but that left one
        // row hosting close + switcher + overflow + prev/next + Save, so
        // the section name truncated. The whole navigation cluster now
        // lives in the bottom bar below; the top bar is just the entity
        // title and Save on every window size.
        //
        // When [entityName] is provided, non-default sections show it so
        // the author always sees which entity they are editing — the base
        // section keeps [title] since that is where the name is edited.
        title: Text(
          widget.entityName != null && current.id != widget.sections.first.id
              ? widget.entityName!
              : widget.title,
        ),
        actions: [
          // Always rendered, disabled via `onPressed: null` when the current
          // section has no preview state — never conditionally mounted, for
          // the same reason `_CompactBottomBar`'s overflow action is: a
          // fixed-width `AppBar.actions` icon appearing/disappearing on
          // every section switch would make the flexible title visibly jump.
          IconButton(
            icon: Icon(
              current.preview == true
                  ? Icons.edit_outlined
                  : Icons.visibility_outlined,
            ),
            tooltip: current.preview == null
                ? null
                : (current.preview!
                      ? l10n.formSectionEditAction
                      : l10n.formSectionPreviewAction),
            onPressed: current.preview == null
                ? null
                : () => current.onPreviewChanged!(!current.preview!),
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
      bottomNavigationBar: wide
          ? null
          : _CompactBottomBar(
              l10n: l10n,
              current: current,
              hasPrevious: hasPrevious,
              hasNext: hasNext,
              onOpenSwitcher: () => _openSwitcher(l10n),
              onPrevious: () => _step(current, -1),
              onNext: () => _step(current, 1),
              onRemove: () => _removeCurrent(current),
            ),
      body: SectionNavigator(
        selectSection: _selectOrAdd,
        child: wide
            ? _WideBody(
                sections: widget.sections,
                addable: widget.addable,
                current: current,
                onSelect: _selectOrAdd,
                onRemove: () => _removeCurrent(current),
              )
            : SafeArea(child: current.builder(context)),
      ),
    );
  }
}

/// Compact's whole section-navigation cluster, relocated out of the
/// crowded top `AppBar` (DESIGN-008 follow-up 04, superseding follow-up
/// 02's top-bar prev/next placement): the section selector — full label,
/// untruncated — prev/next, and the overflow "remove" action.
///
/// The overflow is always rendered (just disabled via `enabled:` when
/// [current] isn't removable) rather than conditionally mounted, for the
/// same reason follow-up 02's fix applied to the top bar and the wide
/// header: a `Row` with one flexible child (the selector, `Expanded`) and
/// fixed-width trailing children redistributes the leftover space into
/// the flexible child whenever a fixed-width sibling appears or
/// disappears — so a conditionally-mounted overflow would still make
/// prev/next visibly jump sideways when the current section's
/// removability changes, even outside an `AppBar.actions` row.
class _CompactBottomBar extends StatelessWidget {
  const _CompactBottomBar({
    required this.l10n,
    required this.current,
    required this.hasPrevious,
    required this.hasNext,
    required this.onOpenSwitcher,
    required this.onPrevious,
    required this.onNext,
    required this.onRemove,
  });

  final AppLocalizations l10n;
  final FormSection current;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onOpenSwitcher;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: l10n.formSectionSwitcherTooltip,
              child: InkWell(
                onTap: onOpenSwitcher,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(current.icon),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        current.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.formSectionPrevious,
            onPressed: hasPrevious ? onPrevious : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.formSectionNext,
            onPressed: hasNext ? onNext : null,
          ),
          PopupMenuButton<String>(
            enabled: current.removable,
            icon: const Icon(Icons.more_vert),
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

/// Master/detail body for medium/expanded (DESIGN-008 follow-up 12, ADR-0030,
/// `post-editor-wide.html`): a left rail listing sections (~210 logical px,
/// per DESIGN-008's `variables-wide.html` mockup) and a detail pane with no
/// header band — a compact `⋮` section-actions menu appears top-right *only*
/// on a removable section (the base sections carry no action, so they show
/// nothing rather than an empty band). The rail's highlighted item already
/// *is* the title, so the detail pane never repeats it, and the `‹ ›`
/// prev/next controls are dropped too (redundant with the rail,
/// unlike compact where they are the only way to move between sections
/// without opening the switcher sheet).
///
/// [current.builder] gets the full remaining height with no extra outer
/// padding — the same as compact's `SafeArea(child: current.builder(...))`
/// — so a section that renders its own edge-to-edge bottom bar (e.g.
/// `PersonsSection`/`LocationsSection`'s search + "+ Ny …" row) spans the
/// detail pane exactly as it does on compact, instead of floating inset
/// inside a 16px margin.
class _WideBody extends StatelessWidget {
  const _WideBody({
    required this.sections,
    required this.addable,
    required this.current,
    required this.onSelect,
    required this.onRemove,
  });

  final List<FormSection> sections;
  final List<FormSection> addable;
  final FormSection current;
  final ValueChanged<String> onSelect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 210,
          child: Material(
            key: const ValueKey('sectionRailSurface'),
            // The same surface tone `Card`/`BottomAppBar` already use
            // elsewhere in the app (`colorScheme.surface`, not a
            // seed-derived `surfaceContainer*` tone) — "a step off the
            // page background", integrated with the rest of the chrome,
            // rather than the near-black `surfaceContainerLow` this rail
            // used before.
            color: Theme.of(context).colorScheme.surface,
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
          // The section body fills the whole pane; the only header action is
          // "remove", which only a removable section has (the base sections —
          // Plan, Variabler, Personer, Lokasjoner — are never removable). So
          // the ⋮ is *overlaid* in the top-right corner, rendered solely for a
          // removable section, and it costs no header row at all (the base
          // sections used to show an empty "appbar" band with a disabled ⋮,
          // and even a slim conditional row still pushed the content down).
          // The field's own label sits top-left, so the corner is clear.
          child: Stack(
            children: [
              Positioned.fill(child: current.builder(context)),
              if (current.removable)
                Positioned(
                  top: 0,
                  right: 4,
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    tooltip: l10n.formSectionRemoveAction,
                    onSelected: (_) => onRemove(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'remove',
                        child: Text(l10n.formSectionRemoveAction),
                      ),
                    ],
                  ),
                ),
            ],
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
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : null;
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      // Accent-background highlight for the selected section (DESIGN-008
      // follow-up 12): the same `primaryContainer` tint already used
      // elsewhere in the app for "this is the active one"
      // (`VariablesSection`'s type chip, `PersonsSection`'s "enacted by"
      // pill) — not a new color role.
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.5,
      ),
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
