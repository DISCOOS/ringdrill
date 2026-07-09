import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/utils/projection.dart';
import 'package:ringdrill/views/dialog_widgets.dart';
import 'package:ringdrill/views/location_form_screen.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/views/widgets/location_kind_style.dart';

/// DESIGN-009 "Lokasjoner" section (follow-up 3b, card-per-item since
/// prompt 4j): a card per station-owned [Location] (kind icon + label +
/// place/UTM summary), matching the app's card-per-item list style — the
/// same elevated `Card` (no border) `ExpandableTile` uses elsewhere in the
/// app. Tap opens [LocationFormScreen] to edit; swipe-to-dismiss deletes,
/// behind a `confirmDestructive` confirmation (ADR-0031 — no overflow
/// menu, no per-row pencil, edit stays a tap away); "+ Ny lokasjon" opens
/// the same form to add.
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
  /// (`StationFormScreen`) knows about its own fields, `Person.locSlug`
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
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              children: [
                for (final location in visible)
                  _LocationCard(
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

/// One card-per-item row (DESIGN-009 prompt 4j, `post-editor-persons.html`):
/// a kind-colored icon (matching the map markers, ADR-0020) and the
/// label/place/UTM summary — an elevated `Card` (no border), matching the
/// app's other card lists (`ExpandableTile`), not a hand-decorated
/// bordered `Container`. Tap opens the location form; swipe deletes,
/// guarded by [usagesFor] (ADR-0031 — no overflow menu, no per-row pencil;
/// edit stays a tap and delete a swipe, the app's one established
/// row-action pattern, ADR-0047).
class _LocationCard extends StatelessWidget {
  const _LocationCard({
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

  /// The swipe-to-dismiss guard — mirrors `_PersonCard`'s own copy.
  Future<bool> _confirmDelete(BuildContext context, AppLocalizations l10n) async {
    final displayName = location.label.isEmpty ? location.slug : location.label;
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final displayName = location.label.isEmpty ? location.slug : location.label;
    final subtitle = location.place.isNotEmpty
        ? location.place
        : (location.position == null ? '' : _formatUtm(location.position!));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(location.slug),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.error,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Icon(Icons.delete, color: theme.colorScheme.onError),
        ),
        confirmDismiss: (_) => _confirmDelete(context, l10n),
        onDismissed: (_) => onDelete(),
        // A plain themed [Card] (elevation, no border) rather than a
        // hand-decorated `Container` — the same look every other RingDrill
        // list uses (`ExpandableTile`, itself a `Card`), not a bespoke one.
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      location.kind.icon,
                      size: 19,
                      color: location.kind.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, overflow: TextOverflow.ellipsis),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
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
