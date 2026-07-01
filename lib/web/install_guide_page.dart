import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/web/web_env.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shareable, install-focused help page.
///
/// Reached from the `/install` route (so the link can be shared), from the
/// "How to install" entries in the drawer and Settings, from the About
/// install-status row, and from the notifications nudge.
///
/// Frames the *native* App Store / Google Play app as the primary option on
/// Apple and Android, with the web app (PWA / add-to-home-screen) as an
/// alternative. On other desktops (Windows/Linux) only the PWA path applies.
/// A page cannot launch an already-installed app, so this only ever links to
/// the stores or explains the manual install steps.
class InstallGuidePage extends StatelessWidget {
  const InstallGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final isApple = WebEnv.isApple;
    final isAndroid = WebEnv.isAndroid;
    final isStandalone = WebEnv.isStandalone;
    final hasInstallPrompt = WebEnv.hasInstallPrompt;

    // Which PWA step list matches this device.
    final ({String title, String steps}) pwaSteps = isApple
        ? (title: l10n.installGuideIosTitle, steps: l10n.installGuideIosSteps)
        : isAndroid
        ? (
            title: l10n.installGuideAndroidTitle,
            steps: l10n.installGuideAndroidSteps,
          )
        : (
            title: l10n.installGuideDesktopTitle,
            steps: l10n.installGuideDesktopSteps,
          );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.cancel,
          // Opened either via a push (drawer/Settings/About/nudge) or cold via
          // the shareable `/install` URL. Pop when there is something to pop,
          // otherwise land on home so we never pop the last page off the
          // go_router stack.
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(l10n.installGuideTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.installGuideIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (isStandalone)
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.installGuideAlreadyInstalled,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!isStandalone) ...[
              // Native app (primary on Apple / Android).
              if (isApple || isAndroid) ...[
                _SectionTitle(
                  isApple
                      ? l10n.installGuideNativeTitle
                      : l10n.installGuidePlayTitle,
                ),
                Text(
                  l10n.installGuideNativeIntro,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (isApple)
                  Align(
                    alignment: Alignment.center,
                    child: FilledButton.icon(
                      onPressed: () => _open(AppConfig.appStoreUrl),
                      icon: const Icon(Icons.apple),
                      label: Text(l10n.installGuideAppStoreButton),
                    ),
                  ),
                if (isAndroid)
                  Align(
                    alignment: Alignment.center,
                    child: FilledButton.icon(
                      onPressed: () => _open(AppConfig.playStoreUrl),
                      icon: const Icon(Icons.shop),
                      label: Text(l10n.installGuidePlayStoreButton),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
              // Web app (PWA) — alternative on Apple/Android, primary on
              // other desktops.
              _SectionTitle(l10n.installGuidePwaTitle),
              const SizedBox(height: 8),
              if (hasInstallPrompt) ...[
                Align(
                  alignment: Alignment.center,
                  child: FilledButton.tonalIcon(
                    onPressed: () => WebEnv.promptInstall(),
                    icon: const Icon(Icons.install_desktop),
                    label: Text(l10n.installGuideInstallButton),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(pwaSteps.title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(pwaSteps.steps, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Best-effort: a failed store launch is non-fatal here.
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
