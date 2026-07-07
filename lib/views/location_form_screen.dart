import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/utils/slug.dart';
import 'package:ringdrill/views/map_view.dart';
import 'package:ringdrill/views/position_form_field.dart';
import 'package:ringdrill/views/widgets/dismiss_keyboard.dart';
import 'package:ringdrill/views/widgets/location_kind_labels.dart';
import 'package:ringdrill/views/widgets/location_kind_style.dart';

/// Self-sufficient full-screen/dialog form for creating or editing a
/// station-owned [Location] (ADR-0047, DESIGN-009 follow-up 3b). Opened via
/// `openFormSurface` by the caller (`LocationsSection`) — full-screen route
/// on narrow, dialog on wide (ADR-0030). Pops with the saved [Location], or
/// null on cancel.
///
/// The reference (`slug`) is never shown: it is generated from [label] at
/// creation via [generateSlug] against [existingSlugs] and carries through
/// unchanged when [initial] is edited (a reference rename is a future
/// action, ADR-0047 — not built here). `place` is plain text; geocoding is
/// a separate follow-up.
class LocationFormScreen extends StatefulWidget {
  const LocationFormScreen({
    super.key,
    required this.existingSlugs,
    this.initial,
  });

  /// Slugs already used by other locations on the station, so a new
  /// reference never collides. Excludes [initial]'s own slug when editing.
  final Set<String> existingSlugs;

  final Location? initial;

  @override
  State<LocationFormScreen> createState() => _LocationFormScreenState();
}

class _LocationFormScreenState extends State<LocationFormScreen> {
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
  LatLng? _position;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _labelController.dispose();
    _placeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();
    final note = _noteController.text.trim();
    final slug =
        widget.initial?.slug ??
        generateSlug(_labelController.text.trim(), widget.existingSlugs.contains);
    Navigator.of(context).pop(
      Location(
        slug: slug,
        label: _labelController.text.trim(),
        kind: _kind,
        place: _placeController.text.trim(),
        position: _position,
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title),
        actions: [
          FilledButton(onPressed: _save, child: Text(l10n.save)),
          const SizedBox(width: 16),
        ],
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
                    controller: _labelController,
                    autofocus: !_isEdit,
                    decoration: InputDecoration(
                      labelText: l10n.locationsSectionLabelLabel,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _KindCategoryGrid(
                    value: _kind,
                    onChanged: (kind) => setState(() => _kind = kind),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _placeController,
                    decoration: InputDecoration(
                      labelText: l10n.locationsSectionPlaceLabel,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _LocationPositionField(
                    initialValue: widget.initial?.position,
                    onSaved: (value) => _position = value,
                  ),
                  const SizedBox(height: 16),
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
        ),
      ),
    );
  }
}

/// `label`/`kind` category grid: 2-up cards, the current [value] highlighted.
/// Starts collapsed to a short, commonly-used subset (plus [value] itself,
/// so an unusual existing kind is never hidden), with a "Vis alle N
/// kategorier" expansion to the full [LocationKind] set.
class _KindCategoryGrid extends StatefulWidget {
  const _KindCategoryGrid({required this.value, required this.onChanged});

  final LocationKind value;
  final ValueChanged<LocationKind> onChanged;

  @override
  State<_KindCategoryGrid> createState() => _KindCategoryGridState();
}

class _KindCategoryGridState extends State<_KindCategoryGrid> {
  static const _collapsedKinds = [
    LocationKind.rendezvous,
    LocationKind.home,
    LocationKind.observation,
    LocationKind.lkp,
  ];

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final visible = _expanded
        ? LocationKind.values
        : {..._collapsedKinds, widget.value}.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.locationsSectionKindLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 3.6,
          children: [
            for (final kind in visible)
              _KindCard(
                kind: kind,
                selected: kind == widget.value,
                onTap: () => widget.onChanged(kind),
              ),
          ],
        ),
        if (!_expanded)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _expanded = true),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.locationsSectionShowAllKinds(LocationKind.values.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final LocationKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(kind.icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                kind.label(l10n),
                style: theme.textTheme.bodySmall?.copyWith(color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Position field with a live mini-preview above the existing
/// [PositionFormField] pick affordance (map icon button + UTM readout) —
/// the only new piece here is the preview; the pick/readout themselves are
/// the same widget every other position field in the app uses.
class _LocationPositionField extends StatefulWidget {
  const _LocationPositionField({
    required this.initialValue,
    required this.onSaved,
  });

  final LatLng? initialValue;
  final FormFieldSetter<LatLng> onSaved;

  @override
  State<_LocationPositionField> createState() =>
      _LocationPositionFieldState();
}

class _LocationPositionFieldState extends State<_LocationPositionField> {
  late LatLng? _preview = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 92,
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            child: _preview == null
                ? Center(
                    child: Icon(
                      Icons.place_outlined,
                      size: 28,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : IgnorePointer(
                    child: MapView(
                      layers: MapConfig.layers,
                      withToggle: false,
                      withClustering: false,
                      initialZoom: 15,
                      initialCenter: _preview!,
                      markers: [
                        MapMarkerSpec(
                          id: 0,
                          label: '',
                          point: _preview!,
                          child: const Icon(
                            Icons.place,
                            color: Colors.green,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        PositionFormField<int>(
          initialValue: widget.initialValue,
          onSaved: widget.onSaved,
          onChanged: (position) => setState(() => _preview = position),
        ),
      ],
    );
  }
}
