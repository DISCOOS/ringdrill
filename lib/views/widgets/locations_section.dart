import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/utils/projection.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/location_form_screen.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/widgets/location_kind_style.dart';

enum _LocationSort { byKind, byLabel }

/// DESIGN-009 "Lokasjoner" section (follow-up 3b — full-screen forms,
/// searchable/sortable tile list): a light tile per station-owned
/// [Location] (kind icon + label + place/UTM summary). Tap opens
/// [LocationFormScreen] to edit; swipe-to-dismiss deletes, behind a
/// `confirmDestructive` confirmation (ADR-0031 — no per-row pencil, and no
/// `⋮` menu now that edit is a tap away); "+ Ny lokasjon" opens the same
/// form to add.
///
/// Presentation-only, mirroring `VariablesSection`: [locations] and the
/// mutation callbacks are owned by the caller (`StationFormScreen`), which
/// persists the working list via `Station.copyWith` on save.
///
/// Scope boundary (ADR-0047): this section only adds, edits non-reference
/// fields, and plain-deletes. A location's reference (`slug`) is generated
/// once at creation and never shown; renaming it and the station-and-down
/// reference-rewrite/delete guard are a future action — intentionally not
/// implemented here.
class LocationsSection extends StatefulWidget {
  const LocationsSection({
    super.key,
    required this.locations,
    required this.onSave,
    required this.onDelete,
  });

  final List<Location> locations;

  /// Called with the saved [Location] from [LocationFormScreen] — a new
  /// entry (add) or the same `slug` (edit). The caller upserts it into its
  /// own working list by `slug`.
  final ValueChanged<Location> onSave;

  /// Called with the `slug` to remove. Plain delete — no reference guard
  /// yet (a future action, ADR-0047).
  final ValueChanged<String> onDelete;

  @override
  State<LocationsSection> createState() => _LocationsSectionState();
}

class _LocationsSectionState extends State<LocationsSection> {
  final _searchController = TextEditingController();
  String _query = '';
  _LocationSort _sort = _LocationSort.byKind;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Location> get _visibleLocations {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.locations
        : widget.locations.where((l) {
            final label = l.label.isEmpty ? l.slug : l.label;
            return label.toLowerCase().contains(query) ||
                l.place.toLowerCase().contains(query);
          }).toList();
    final sorted = [...filtered];
    switch (_sort) {
      case _LocationSort.byKind:
        sorted.sort((a, b) {
          final byKind = a.kind.index.compareTo(b.kind.index);
          return byKind != 0
              ? byKind
              : a.label.toLowerCase().compareTo(b.label.toLowerCase());
        });
      case _LocationSort.byLabel:
        sorted.sort(
          (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
        );
    }
    return sorted;
  }

  void _toggleSort() {
    setState(() {
      _sort = _sort == _LocationSort.byKind
          ? _LocationSort.byLabel
          : _LocationSort.byKind;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final visible = _visibleLocations;
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
                      hintText: l10n.locationsSectionSearchHint,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _toggleSort,
                  icon: const Icon(Icons.sort, size: 18),
                  label: Text(
                    _sort == _LocationSort.byKind
                        ? l10n.locationsSectionSortByKind
                        : l10n.locationsSectionSortByLabel,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final location in visible)
                  _LocationTile(
                    key: ValueKey(location.slug),
                    location: location,
                    onTap: () => _openForm(context, location),
                    onDelete: () => widget.onDelete(location.slug),
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

  Future<void> _openForm(BuildContext context, Location? location) async {
    final existingSlugs = widget.locations
        .where((l) => l.slug != location?.slug)
        .map((l) => l.slug)
        .toSet();
    final saved = await openFormSurface<Location>(
      context,
      builder: (_) =>
          LocationFormScreen(existingSlugs: existingSlugs, initial: location),
    );
    if (saved != null) widget.onSave(saved);
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    super.key,
    required this.location,
    required this.onTap,
    required this.onDelete,
  });

  final Location location;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final displayName = location.label.isEmpty ? location.slug : location.label;
    final subtitle = location.place.isNotEmpty
        ? location.place
        : (location.position == null ? '' : _formatUtm(location.position!));
    return Dismissible(
      key: ValueKey(location.slug),
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
        message: l10n.locationsSectionDeleteConfirmMessage(displayName),
        confirmLabel: l10n.delete,
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onTap,
        leading: Icon(location.kind.icon, color: location.kind.color),
        title: Text(displayName, overflow: TextOverflow.ellipsis),
        subtitle: subtitle.isEmpty
            ? null
            : Text(subtitle, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

/// "32V 0580414E 6552008N" — zone+band, then zero-padded 7-digit easting
/// and northing. Mirrors `BriefRenderer`'s private formatter of the same
/// shape; duplicated rather than reused since that one is
/// `@visibleForTesting` (renderer-internal), matching `UtmWidget`'s own
/// independent formatting of the same coordinate for display.
String _formatUtm(LatLng position) {
  final utm = position.utm();
  final e = utm.easting.toStringAsFixed(0).padLeft(7, '0');
  final n = utm.northing.toStringAsFixed(0).padLeft(7, '0');
  return '${utm.zone}${utm.band} ${e}E ${n}N';
}
