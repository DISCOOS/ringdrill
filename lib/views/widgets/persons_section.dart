import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/person.dart';
import 'package:ringdrill/models/role_play.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/person_form_screen.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/widgets/gender_segmented_control.dart';

/// DESIGN-009 "Personer" section (follow-up 3b, card-per-item since prompt
/// 4j): a card per station-owned [Person] (name + age/gender/signalement
/// summary), matching the app's card-per-item list style — bordered,
/// rounded, spaced, with a leading avatar. Tap opens [PersonFormScreen] to
/// edit; swipe-to-dismiss deletes, behind a `confirmDestructive`
/// confirmation (ADR-0031 — no overflow menu, no pencil in the row; edit
/// stays a tap away and delete a swipe, the app's one established
/// row-action pattern); "+ Ny person" opens the same form to add.
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
///
/// Each card also carries its enacting role inline, on the same row as the
/// name (DESIGN-009 prompt 4j): "Spilles av {navn}" when [rolePlayFor]
/// finds one, tapping through to [onOpenRolePlay]; otherwise "Legg til
/// spill" via [onAddRolePlay] — so an author never needs the read-only
/// Post view to build one.
class PersonsSection extends StatefulWidget {
  const PersonsSection({
    super.key,
    required this.persons,
    required this.locations,
    required this.onSave,
    required this.onDelete,
    required this.usagesFor,
    required this.rolePlayFor,
    required this.onOpenRolePlay,
    required this.onAddRolePlay,
  });

  final List<Person> persons;

  /// The station's own locations, offered in [PersonFormScreen]'s location
  /// picker.
  final List<Location> locations;

  /// Called with the saved [Person] from [PersonFormScreen] — a new entry
  /// (add) or the same `slug` (edit) — and, when the form's location picker
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

  /// The [RolePlay] enacting the person at `slug`, if any (DESIGN-009
  /// prompt 4j) — the caller knows the station's linked roleplays, which
  /// this presentation-only section does not.
  final RolePlay? Function(String slug) rolePlayFor;

  /// Opens [rolePlay] in the RolePlay editor.
  final ValueChanged<RolePlay> onOpenRolePlay;

  /// Opens the RolePlay editor with the post and [person] pre-set, for a
  /// person with no enacting marker yet.
  final ValueChanged<Person> onAddRolePlay;

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
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              children: [
                for (final person in visible)
                  _PersonCard(
                    key: ValueKey(person.slug),
                    person: person,
                    rolePlay: widget.rolePlayFor(person.slug),
                    onTap: () => _openForm(context, person),
                    onDelete: () => widget.onDelete(person.slug),
                    onOpenRolePlay: widget.onOpenRolePlay,
                    onAddRolePlay: () => widget.onAddRolePlay(person),
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

/// One card-per-item row (DESIGN-009 prompt 4j, `post-editor-persons.html`):
/// a leading avatar and the name/meta/signalement/marker summary —
/// bordered, rounded, spaced, matching the app's other card lists. Tap
/// opens the person form; swipe deletes, guarded by [usagesFor] (ADR-0031
/// — no overflow menu, no per-row pencil; edit stays a tap and delete a
/// swipe, the app's one established row-action pattern, ADR-0047).
class _PersonCard extends StatelessWidget {
  const _PersonCard({
    super.key,
    required this.person,
    required this.rolePlay,
    required this.onTap,
    required this.onDelete,
    required this.onOpenRolePlay,
    required this.onAddRolePlay,
    required this.usagesFor,
  });

  final Person person;
  final RolePlay? rolePlay;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<RolePlay> onOpenRolePlay;
  final VoidCallback onAddRolePlay;
  final List<String> Function(String slug) usagesFor;

  /// The swipe-to-dismiss guard: a person still referenced (ADR-0047,
  /// DESIGN-009 prompt 5) is blocked with a dialog listing the usages;
  /// otherwise a plain destructive confirmation.
  Future<bool> _confirmDelete(BuildContext context, AppLocalizations l10n) async {
    final displayName = person.name.isEmpty ? person.slug : person.name;
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final displayName = person.name.isEmpty ? person.slug : person.name;
    final genderLabel = genderLabelFor(person.gender, l10n);
    final metaParts = [
      displayName,
      if (person.age != null) '${person.age}',
      ?genderLabel,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(person.slug),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.error,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Icon(Icons.delete, color: theme.colorScheme.onError),
        ),
        confirmDismiss: (_) => _confirmDelete(context, l10n),
        onDismissed: (_) => onDelete(),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      size: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                metaParts.join(' · '),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => rolePlay == null
                                  ? onAddRolePlay()
                                  : onOpenRolePlay(rolePlay!),
                              child: rolePlay == null
                                  ? _AddMarkerRow(
                                      label: l10n.personsSectionAddMarkerAction,
                                    )
                                  : _EnactedByRow(
                                      label: l10n.personsSectionEnactedByAction(
                                        rolePlay!.name,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        if ((person.signalement ?? '').isNotEmpty)
                          Text(
                            person.signalement!,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Spilles av {navn}" inline row on an enacted person's card
/// (DESIGN-009 prompt 4j, `post-editor-persons.html`'s `.mkline`).
class _EnactedByRow extends StatelessWidget {
  const _EnactedByRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.theater_comedy_outlined,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "+ Legg til spill" inline affordance on an unenacted person's card
/// (DESIGN-009 prompt 4j).
class _AddMarkerRow extends StatelessWidget {
  const _AddMarkerRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.add, size: 15, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
