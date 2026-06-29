import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/migration_page.dart';
import 'package:ringdrill/views/settings_page.dart'
    show AnalyticsConsentSettings, AppUserRoleSettings;
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/web/pwa_update_web.dart' show forcePwaUpdate;

import 'mobile_app_nudge.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(localizations.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            AppUserRoleSettings(),
            const Divider(),
            AnalyticsConsentSettings(),
            const Divider(),
            // Notifications Settings Section
            Text(
              localizations.notification(2),
              // ADR-0037: themed titleMedium instead of a hardcoded 20.
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16.0),
            Text(localizations.noReliableNotificationsReason),
            const SizedBox(height: 12.0),
            MobileAppNudgeBanner.create(
              always: true,
              onlyOnce: false,
              showDismiss: false,
              showContinueOnWeb: false,
              margins: EdgeInsets.zero,
            ),
            const Divider(),
            const _ForceUpdateTile(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(localizations.migrationSettingsEntry),
              onTap: () => openFormSurface<void>(
                context,
                builder: (_) => const MigrationPage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForceUpdateTile extends StatelessWidget {
  const _ForceUpdateTile();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.refresh),
      title: Text(localizations.forceUpdateTitle),
      subtitle: Text(localizations.forceUpdateSubtitle),
      onTap: () => _confirm(context, localizations),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    AppLocalizations localizations,
  ) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.forceUpdateConfirmTitle),
        content: Text(localizations.forceUpdateConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.forceUpdateConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await forcePwaUpdate();
    }
  }
}
