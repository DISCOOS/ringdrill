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
