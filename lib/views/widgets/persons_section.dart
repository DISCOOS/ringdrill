import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/person_form_screen.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/widgets/gender_segmented_control.dart';

enum _PersonSort { byName, byAge }

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
/// Scope boundary (ADR-0047): this section only adds, edits non-reference
/// fields, and plain-deletes. A person's reference (`slug`) is generated
/// once at creation and never shown; renaming it and the station-and-down
/// reference-rewrite/delete guard (including a dangling `homeSlug` after a
/// location delete) are a future action — intentionally not implemented
/// here.
class PersonsSection extends StatefulWidget {
  const PersonsSection({
    super.key,
    required this.persons,
    required this.locations,
    required this.onSave,
    required this.onDelete,
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

  /// Called with the `slug` to remove. Plain delete — no reference guard
  /// yet (a future action, ADR-0047).
  final ValueChanged<String> onDelete;

  @override
  State<PersonsSection> createState() => _PersonsSectionState();
}

class _PersonsSectionState extends State<PersonsSection> {
  final _searchController = TextEditingController();
  String _query = '';
  _PersonSort _sort = _PersonSort.byName;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Person> get _visiblePersons {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.persons
        : widget.persons.where((p) {
            final name = p.name.isEmpty ? p.slug : p.name;
            return name.toLowerCase().contains(query) ||
                (p.signalement ?? '').toLowerCase().contains(query);
          }).toList();
    final sorted = [...filtered];
    switch (_sort) {
      case _PersonSort.byName:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _PersonSort.byAge:
        sorted.sort((a, b) {
          final ageA = a.age;
          final ageB = b.age;
          if (ageA == null && ageB == null) return 0;
          if (ageA == null) return 1;
          if (ageB == null) return -1;
          return ageA.compareTo(ageB);
        });
    }
    return sorted;
  }

  void _toggleSort() {
    setState(() {
      _sort = _sort == _PersonSort.byName
          ? _PersonSort.byAge
          : _PersonSort.byName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final visible = _visiblePersons;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search),
                      hintText: l10n.personsSectionSearchHint,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _toggleSort,
                  icon: const Icon(Icons.sort, size: 18),
                  label: Text(
                    _sort == _PersonSort.byName
                        ? l10n.personsSectionSortByName
                        : l10n.personsSectionSortByAge,
                  ),
                ),
              ],
            ),
          ),
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
                  ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _openForm(context, null),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.personsSectionAddAction,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
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

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    super.key,
    required this.person,
    required this.onTap,
    required this.onDelete,
  });

  final Person person;
  final VoidCallback onTap;
  final VoidCallback onDelete;

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
      confirmDismiss: (_) => confirmDestructive(
        context,
        title: l10n.confirm,
        message: l10n.personsSectionDeleteConfirmMessage(displayName),
        confirmLabel: l10n.delete,
      ),
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
