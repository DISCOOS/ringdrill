import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/person_form_screen.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/widgets/gender_segmented_control.dart';

/// DESIGN-009 "Personer" section (follow-up 3b — full-screen forms,
/// searchable/sortable tile list): a light tile per station-owned [Person]
/// (name + age/gender/signalement summary). Tap opens [PersonFormScreen] to
/// edit; swipe-to-dismiss deletes, behind a `confirmDestructive`
/// confirmation (ADR-0031 — no `⋮` menu now that edit is a tap away);
/// "+ Ny person" opens the same form to add.
///
/// Presentation-only, mirroring `LocationsSection`: [persons] and the
/// mutation callbacks are owned by the caller (`StationFormScreen`), which
/// persists the working list via `Station.copyWith` on save.
///
/// Scope boundary (ADR-0047): this section only adds and edits
/// non-reference fields. Deletion is guarded (DESIGN-009 prompt 5): a
/// person still referenced by a station field, a roleplay field, or a
/// roleplay's `personRef` (portrayal) is blocked with a dialog listing the
/// usages, via [usagesFor]. A person's reference (`slug`) is generated once
/// at creation and never shown; renaming it is out of scope — there is no
/// rename (ADR-0047).
class PersonsSection extends StatefulWidget {
  const PersonsSection({
    super.key,
    required this.persons,
    required this.locations,
    required this.onSave,
    required this.onDelete,
    required this.usagesFor,
  });

  final List<Person> persons;

  /// The station's own locations, offered in [PersonFormScreen]'s home
  /// picker.
  final List<Location> locations;

  /// Called with the saved [Person] from [PersonFormScreen] — a new entry
  /// (add) or the same `slug` (edit) — and, when the form's home picker
  /// created one inline, the new [Location] to add to the station's own
  /// list too. The caller upserts both by `slug`.
  final void Function(Person person, Location? newLocation) onSave;

  /// Called with the `slug` to remove — only once [usagesFor] has already
  /// confirmed it is unreferenced.
  final ValueChanged<String> onDelete;

  /// Human-readable usages of a person's `slug` across the station-and-down
  /// set (DESIGN-009 prompt 5) — the caller (`StationFormScreen`) knows
  /// about its own fields and the linked roleplays' fields/`personRef`,
  /// none of which this presentation-only section has access to. An empty
  /// list means the person is safe to delete.
  final List<String> Function(String slug) usagesFor;

  @override
  State<PersonsSection> createState() => _PersonsSectionState();
}

class _PersonsSectionState extends State<PersonsSection> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Person> get _visiblePersons {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.persons;
    return widget.persons.where((p) {
      final name = p.name.isEmpty ? p.slug : p.name;
      return name.toLowerCase().contains(query) ||
          (p.signalement ?? '').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visible = _visiblePersons;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final person in visible)
                  _PersonTile(
                    key: ValueKey(person.slug),
                    person: person,
                    onTap: () => _openForm(context, person),
                    onDelete: () => widget.onDelete(person.slug),
                    usagesFor: widget.usagesFor,
                  ),
              ],
            ),
          ),
          _SearchAddRow(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            searchHint: l10n.personsSectionSearchHint,
            addLabel: l10n.personsSectionAddAction,
            onAdd: () => _openForm(context, null),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(BuildContext context, Person? person) async {
    final existingSlugs = widget.persons
        .where((p) => p.slug != person?.slug)
        .map((p) => p.slug)
        .toSet();
    final result = await openFormSurface<PersonFormResult>(
      context,
      builder: (_) => PersonFormScreen(
        existingSlugs: existingSlugs,
        locations: widget.locations,
        initial: person,
      ),
    );
    if (result != null) widget.onSave(result.person, result.newLocation);
  }
}

/// Card-based bottom row with a search field and an add-action button,
/// matching the map search field's no-border Card idiom (DESIGN-009
/// follow-up 3c). Duplicated from `locations_section.dart` — both files
/// are presentation-only leaf widgets with no shared library; a shared
/// helper would need its own file and import cycle. Three similar lines
/// beats a premature abstraction for two callers.
class _SearchAddRow extends StatelessWidget {
  const _SearchAddRow({
    required this.controller,
    required this.onChanged,
    required this.searchHint,
    required this.addLabel,
    required this.onAdd,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String searchHint;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: searchHint,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const VerticalDivider(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(addLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    super.key,
    required this.person,
    required this.onTap,
    required this.onDelete,
    required this.usagesFor,
  });

  final Person person;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final List<String> Function(String slug) usagesFor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final displayName = person.name.isEmpty ? person.slug : person.name;
    final genderLabel = genderLabelFor(person.gender, l10n);
    final parts = [
      if (person.age != null) '${person.age}',
      ?genderLabel,
      if ((person.signalement ?? '').isNotEmpty) person.signalement!,
    ];
    return Dismissible(
      key: ValueKey(person.slug),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (_) async {
        final usages = usagesFor(person.slug);
        if (usages.isNotEmpty) {
          await showReferenceGuardDialog(
            context,
            l10n,
            title: l10n.stationReferenceGuardTitle(displayName),
            usages: usages,
          );
          return false;
        }
        return confirmDestructive(
          context,
          title: l10n.confirm,
          message: l10n.personsSectionDeleteConfirmMessage(displayName),
          confirmLabel: l10n.delete,
        );
      },
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.person_outline),
        title: Text(displayName, overflow: TextOverflow.ellipsis),
        subtitle: parts.isEmpty
            ? null
            : Text(parts.join(' · '), overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
