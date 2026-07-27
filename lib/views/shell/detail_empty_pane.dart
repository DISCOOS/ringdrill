import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';

class ExerciseDetailEmpty extends StatelessWidget {
  const ExerciseDetailEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return _DetailEmptyPane(
      icon: Icons.update,
      label: AppLocalizations.of(context)!.detailEmptyExercise,
    );
  }
}

class StationDetailEmpty extends StatelessWidget {
  const StationDetailEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return _DetailEmptyPane(
      icon: Icons.place,
      label: AppLocalizations.of(context)!.detailEmptyStation,
    );
  }
}

class RolePlayDetailEmpty extends StatelessWidget {
  const RolePlayDetailEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return _DetailEmptyPane(
      icon: Icons.theater_comedy,
      label: AppLocalizations.of(context)!.detailEmptyRolePlay,
    );
  }
}

class TeamDetailEmpty extends StatelessWidget {
  const TeamDetailEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return _DetailEmptyPane(
      icon: Icons.group,
      label: AppLocalizations.of(context)!.detailEmptyTeam,
    );
  }
}

class RosterDetailEmpty extends StatelessWidget {
  const RosterDetailEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return _DetailEmptyPane(
      icon: Icons.badge,
      label: AppLocalizations.of(context)!.detailEmptyRoster,
    );
  }
}

/// The detail body for something that was opened but no longer exists —
/// deleted from another pane, or reached through a stale link.
///
/// Distinct from the `*DetailEmpty` panes above: those mean "nothing selected
/// yet", an ordinary resting state. This one means "what you asked for is
/// gone", so it explains itself and offers [onClose] rather than dismissing
/// the surface out from under the reader, who would otherwise see a view
/// vanish with no idea why.
class DetailGonePane extends StatelessWidget {
  const DetailGonePane({
    super.key,
    required this.icon,
    required this.message,
    required this.onClose,
  });

  final IconData icon;
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: onClose,
              child: Text(AppLocalizations.of(context)!.briefClose),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailEmptyPane extends StatelessWidget {
  const _DetailEmptyPane({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
