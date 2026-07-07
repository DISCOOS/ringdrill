import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/utils/slug.dart';
import 'package:ringdrill/views/position_form_field.dart';
import 'package:ringdrill/views/widgets/location_kind_labels.dart';

/// DESIGN-009 "Lokasjoner" section: a row per station-owned [Location] with
/// a `⋮` menu for edit/delete (ADR-0031 — never a per-row pencil), a
/// "+ Ny lokasjon" action, and the existing coordinate/map-pick affordance
/// ([PositionFormField]) live on each row.
///
/// Presentation-only, mirroring `VariablesSection`: [locations] and the
/// mutation callbacks are owned by the caller (`StationFormScreen`), which
/// persists the working list via `Station.copyWith` on save.
///
/// Scope boundary (DESIGN-009 prompt 3): this section only adds, edits
/// non-slug fields, and plain-deletes. A location's `slug` is fixed at
/// creation; renaming it and the station-and-down reference-rewrite/delete
/// guard are DESIGN-009 prompt 5 — intentionally not implemented here.
class LocationsSection extends StatelessWidget {
  const LocationsSection({
    super.key,
    required this.locations,
    required this.onAdd,
    required this.onEdit,
    required this.onPositionChanged,
    required this.onDelete,
  });

  final List<Location> locations;

  /// Called with a new, validated [Location] from the "+ Ny lokasjon"
  /// dialog. The caller appends it to its own working list.
  final ValueChanged<Location> onAdd;

  /// Called with the updated [Location] (same `slug`) after the edit
  /// dialog (label/kind/place/note) is confirmed.
  final ValueChanged<Location> onEdit;

  /// Called with a location's `slug` and its newly picked position, from
  /// the row's own [PositionFormField] — kept separate from [onEdit] since
  /// it fires immediately from the row, not from a dialog confirm.
  final void Function(String slug, LatLng position) onPositionChanged;

  /// Called with the `slug` to remove. Plain delete — no reference guard
  /// yet (prompt 5).
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final location in locations)
            _LocationRow(
              key: ValueKey(location.slug),
              location: location,
              onEdit: () => _handleEdit(context, location),
              onPositionChanged: (p) => onPositionChanged(location.slug, p),
              onDelete: () => onDelete(location.slug),
            ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _handleAdd(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.locationsSectionAddAction,
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

  Future<void> _handleAdd(BuildContext context) async {
    final created = await showDialog<Location>(
      context: context,
      builder: (dialogContext) => _LocationFormDialog(
        existingSlugs: locations.map((l) => l.slug).toSet(),
      ),
    );
    if (created != null) onAdd(created);
  }

  Future<void> _handleEdit(BuildContext context, Location location) async {
    final updated = await showDialog<Location>(
      context: context,
      builder: (dialogContext) => _LocationFormDialog(
        existingSlugs: locations.map((l) => l.slug).toSet(),
        initial: location,
      ),
    );
    if (updated != null) onEdit(updated);
  }
}

enum _LocationRowAction { edit, delete }

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    super.key,
    required this.location,
    required this.onEdit,
    required this.onPositionChanged,
    required this.onDelete,
  });

  final Location location;
  final VoidCallback onEdit;
  final ValueChanged<LatLng> onPositionChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  location.label.isEmpty ? location.slug : location.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _KindChip(text: location.kind.label(l10n)),
              PopupMenuButton<_LocationRowAction>(
                tooltip: '',
                onSelected: (action) => switch (action) {
                  _LocationRowAction.edit => onEdit(),
                  _LocationRowAction.delete => onDelete(),
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _LocationRowAction.edit,
                    child: Text(l10n.locationsSectionEditAction),
                  ),
                  PopupMenuItem(
                    value: _LocationRowAction.delete,
                    child: Text(l10n.locationsSectionDeleteAction),
                  ),
                ],
              ),
            ],
          ),
          if (location.place.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                location.place,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          PositionFormField<int>(
            initialValue: location.position,
            onSaved: (_) {},
            onChanged: onPositionChanged,
          ),
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Shared label/kind/place/note form used by both the add-location and
/// edit-location dialogs. The reference (`slug`) is never shown or typed —
/// it is generated from the label at creation via [generateSlug] and stays
/// fixed after that (a reference *rename* is a future action, ADR-0047).
/// [initial]'s slug and position carry through unchanged on edit — position
/// is edited directly on the row via its own [PositionFormField], not here.
class _LocationFormDialog extends StatefulWidget {
  const _LocationFormDialog({required this.existingSlugs, this.initial});

  final Set<String> existingSlugs;
  final Location? initial;

  @override
  State<_LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<_LocationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _labelController = TextEditingController(
    text: widget.initial?.label ?? '',
  );
  late final _placeController = TextEditingController(
    text: widget.initial?.place ?? '',
  );
  late final _noteController = TextEditingController(
    text: widget.initial?.note ?? '',
  );
  late LocationKind _kind = widget.initial?.kind ?? LocationKind.other;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _labelController.dispose();
    _placeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final note = _noteController.text.trim();
    final slug =
        widget.initial?.slug ??
        generateSlug(
          _labelController.text.trim(),
          widget.existingSlugs.contains,
        );
    Navigator.of(context).pop(
      Location(
        slug: slug,
        label: _labelController.text.trim(),
        kind: _kind,
        place: _placeController.text.trim(),
        position: widget.initial?.position,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _isEdit
        ? l10n.locationsSectionEditAction
        : l10n.locationsSectionAddAction;
    return AlertDialog(
      title: Text(title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _labelController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.locationsSectionLabelLabel,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<LocationKind>(
                initialValue: _kind,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.locationsSectionKindLabel,
                ),
                items: [
                  for (final kind in LocationKind.values)
                    DropdownMenuItem(
                      value: kind,
                      child: Text(kind.label(l10n)),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _kind = value ?? LocationKind.other),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _placeController,
                decoration: InputDecoration(
                  labelText: l10n.locationsSectionPlaceLabel,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.locationsSectionNoteLabel,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(title)),
      ],
    );
  }
}
