import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/web/web_env.dart';

/// About-page row about the app's install state.
///
/// When installed as a PWA it is a non-interactive info row confirming so.
/// In a browser tab it is instead an action row linking to the install
/// guide — "installed as app" is never claimed in a browser.
///
/// Web-only; the native build gets the stub in `views/pwa_status_tile_io.dart`
/// which renders nothing (the concept does not apply off the web).
class PwaStatusTile extends StatelessWidget {
  const PwaStatusTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final installed = WebEnv.isStandalone;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(),
        if (installed)
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(l10n.installStatusTitle),
            subtitle: Text(l10n.installStatusInstalled),
          )
        else
          ListTile(
            leading: const Icon(Icons.install_mobile),
            title: Text(l10n.installGuideEntry),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/install'),
          ),
      ],
    );
  }
}
