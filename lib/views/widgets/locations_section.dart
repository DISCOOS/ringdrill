import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/utils/projection.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/location_form_screen.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/widgets/location_kind_style.dart';

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
/// Scope boundary (ADR-0047): this section only adds and edits
/// non-reference fields. Deletion is guarded (DESIGN-009 prompt 5): a
/// location still referenced by a station field, a person's home, or a
/// roleplay is blocked with a dialog listing the usages, via [usagesFor].
/// A location's reference (`slug`) is generated once at creation and never
/// shown; renaming it is out of scope — there is no rename (ADR-0047).
class LocationsSection extends StatefulWidget {
  const LocationsSection({
    super.key,
    required this.locations,
    required this.onSave,
    required this.onDelete,
    required this.usagesFor,
  });

  final List<Location> locations;

  /// Called with the saved [Location] from [LocationFormScreen] — a new
  /// entry (add) or the same `slug` (edit). The caller upserts it into its
  /// own working list by `slug`.
  final ValueChanged<Location> onSave;

  /// Called with the `slug` to remove — only once [usagesFor] has already
  /// confirmed it is unreferenced.
  final ValueChanged<String> onDelete;

  /// Human-readable usages of a location's `slug` across the
  /// station-and-down set (DESIGN-009 prompt 5) — the caller
  /// (`StationFormScreen`) knows about its own fields, `Person.homeSlug`
  /// and the linked roleplays, none of which this presentation-only
  /// section has access to. An empty list means the location is safe to
  /// delete.
  final List<String> Function(String slug) usagesFor;

  @override
  State<LocationsSection> createState() => _LocationsSectionState();
}

class _LocationsSectionState extends State<LocationsSection> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Location> get _visibleLocations {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.locations;
    return widget.locations.where((l) {
      final label = l.label.isEmpty ? l.slug : l.label;
      return label.toLowerCase().contains(query) ||
          l.place.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visible = _visibleLocations;
    return SafeArea(
      child: Column(
        children: [
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
                    usagesFor: widget.usagesFor,
                  ),
              ],
            ),
          ),
          _SearchAddRow(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            searchHint: l10n.locationsSectionSearchHint,
            addLabel: l10n.locationsSectionAddAction,
            onAdd: () => _openForm(context, null),
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

/// A single bottom row used by both [LocationsSection] and [PersonsSection]
/// (imported from their own files, or inlined here since it is private).
/// Matches the map search field's Card-based, no-border idiom: a [Card]
/// wrapping the search field and the add action, separated by a divider.
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

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    super.key,
    required this.location,
    required this.onTap,
    required this.onDelete,
    required this.usagesFor,
  });

  final Location location;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final List<String> Function(String slug) usagesFor;

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
      confirmDismiss: (_) async {
        final usages = usagesFor(location.slug);
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
          message: l10n.locationsSectionDeleteConfirmMessage(displayName),
          confirmLabel: l10n.delete,
        );
      },
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
