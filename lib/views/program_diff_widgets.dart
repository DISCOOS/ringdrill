import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';

class DiffGroup extends StatelessWidget {
  const DiffGroup({
    super.key,
    required this.title,
    required this.added,
    required this.removed,
    required this.modified,
  });

  final String title;
  final List<String> added;
  final List<String> removed;
  final List<String> modified;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final rows = [
      (localizations.catalogDiffAdded, added),
      (localizations.catalogDiffRemoved, removed),
      (localizations.catalogDiffModified, modified),
    ].where((row) => row.$2.isNotEmpty).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${row.$1}: ${row.$2.join(', ')}'),
            ),
        ],
      ),
    );
  }
}

/// Renders a single before/after field change (e.g. plan name, description).
/// Renders nothing when both sides are null or equal.
class DiffField extends StatelessWidget {
  const DiffField({
    super.key,
    required this.label,
    required this.local,
    required this.remote,
  });

  final String label;
  final String? local;
  final String? remote;

  @override
  Widget build(BuildContext context) {
    if (local == null && remote == null) return const SizedBox.shrink();
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${localizations.catalogDiffLocal}: ${_present(local)}',
          ),
          Text(
            '${localizations.catalogDiffRemote}: ${_present(remote)}',
          ),
        ],
      ),
    );
  }

  String _present(String? value) {
    if (value == null) return '—';
    final trimmed = value.trim();
    return trimmed.isEmpty ? '—' : trimmed;
  }
}
