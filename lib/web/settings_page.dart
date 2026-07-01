import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/settings_page.dart'
    show AnalyticsConsentSettings, AppUserRoleSettings;
import 'package:ringdrill/web/legacy_host_web.dart';
import 'package:ringdrill/web/pwa_update_web.dart' show forcePwaUpdate;
import 'package:ringdrill/web/web_env.dart';

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
            // Explanation only. The install action lives once, in the Web-app
            // section below, so we do not repeat the nudge banner here. The
            // shell keeps its own (Android) nudge, untouched.
            Text(localizations.noReliableNotificationsReason),
            const Divider(),
            // Consolidated web-app / PWA section: install status, install
            // guide, migration explainer (legacy only), and force update.
            Text(
              localizations.settingsWebAppSection,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            _InstallStatusTile(),
            if (!WebEnv.isStandalone)
              ListTile(
                leading: const Icon(Icons.install_mobile),
                title: Text(localizations.installGuideEntry),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/install'),
              ),
            if (isLegacyHost())
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: Text(localizations.migrationSettingsEntry),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/migrate'),
              ),
            const _ForceUpdateTile(),
          ],
        ),
      ),
    );
  }
}

/// Read-only info row confirming the app runs as an installed PWA. Only
/// shown when actually installed — "installed as app" makes no sense in a
/// browser tab, and the row is deliberately non-interactive so it reads as
/// status, not an action. In a browser the section shows the "how to
/// install" action instead.
class _InstallStatusTile extends StatelessWidget {
  const _InstallStatusTile();

  @override
  Widget build(BuildContext context) {
    if (!WebEnv.isStandalone) return const SizedBox.shrink();
    final localizations = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.check_circle_outline),
      title: Text(localizations.installStatusTitle),
      subtitle: Text(localizations.installStatusInstalled),
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
