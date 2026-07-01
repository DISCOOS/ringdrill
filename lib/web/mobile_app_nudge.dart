// lib/mobile_app_nudge.dart
import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/web/install_actions.dart' show openInstallGuide;

import 'web_env.dart';

const _kDismissKey = 'ringdrill.mobile_app_cta.dismissed';
const _kDismissValue = '1';

class MobileAppNudgeController {
  MobileAppNudgeController({
    this.always = false,
    this.onlyOnce = true,
    this.hideInPwa = true,
    required this.showOniOS,
    required this.showOnDesktop,
    required this.showOnAndroid,
  });

  final bool always;
  final bool onlyOnce;
  final bool hideInPwa;
  final bool showOniOS;
  final bool showOnDesktop;
  final bool showOnAndroid;

  bool _sessionShown = false;

  Future<bool> shouldShow() async {
    if (always) return true;
    if (onlyOnce && _sessionShown) return false;

    if (WebEnv.getFlag(_kDismissKey) == _kDismissValue) return false;

    if (!showOniOS && WebEnv.isiOS) return false;
    if (!showOnAndroid && WebEnv.isAndroid) return false;
    if (WebEnv.isStandalone && hideInPwa) return false;
    if (!showOnDesktop && WebEnv.isDesktop) return false;

    // Show if notifications are not robust on this platform
    final perm = WebEnv.notifPermission; // granted/denied/default/unsupported
    final lacksReliableNotifications =
        perm != 'granted' || perm == 'unsupported';

    return lacksReliableNotifications;
  }

  void markShown() => _sessionShown = true;

  void dismiss({int days = 30}) {
    WebEnv.setFlag(_kDismissKey, _kDismissValue, days: days);
  }
}

class MobileAppNudgeBanner extends StatefulWidget {
  const MobileAppNudgeBanner({
    super.key,
    required this.controller,
    required this.playStoreUrl, // e.g. https://play.google.com/store/apps/details?id=org.discoos.ringdrill
    required this.intentUrlBuilder, // builds android-intent://... for current context/route if you wish
    this.onGetApp,
    this.onOpenInApp,
    this.showDismiss = true,
    this.showContinueOnWeb = true,
    EdgeInsets? margins,
  }) : margins = margins ?? const EdgeInsets.only(left: 8, right: 8, bottom: 8);

  final bool showDismiss;
  final bool showContinueOnWeb;
  final String playStoreUrl;
  final VoidCallback? onGetApp;
  final VoidCallback? onOpenInApp;
  final EdgeInsets margins;
  final String Function() intentUrlBuilder;
  final MobileAppNudgeController controller;

  factory MobileAppNudgeBanner.create({
    bool showContinueOnWeb = true,
    bool always = false,
    bool onlyOnce = true,
    bool showDismiss = true,
    EdgeInsets? margins,
  }) {
    return MobileAppNudgeBanner(
      margins: margins,
      showDismiss: showDismiss,
      showContinueOnWeb: showContinueOnWeb,
      controller: MobileAppNudgeController(
        always: always,
        onlyOnce: onlyOnce,
        showOnAndroid: true,
        // iOS (and iPadOS) app is live in the App Store, so promote it here
        // too. The non-Android button opens the install guide, which offers
        // the App Store link on Apple. The Smart App Banner in web/index.html
        // additionally offers "Open"/"Get" from Safari.
        showOniOS: true,
        // No native desktop app to promote yet; desktop users get the PWA
        // via the install guide.
        showOnDesktop: false,
      ),
      playStoreUrl:
          'https://play.google.com/store/apps/details?id=org.discoos.ringdrill',
      intentUrlBuilder: () {
        // Build an intent URL with Play Store fallback.
        // This opens the app if installed; otherwise, it opens the store.
        final store = Uri.encodeComponent(
          'https://play.google.com/store/apps/details?id=org.discoos.ringdrill',
        );
        // If you have a current route (e.g., with go_router), you can append it to keep context.
        // final path = router.location; // e.g. '/exercise/123'
        // return 'intent://ringdrill.app$path#Intent;scheme=https;package=org.discoos.ringdrill;S.browser_fallback_url=$store;end';

        // Simple, robust form:
        return 'android-intent://open/ringdrill#Intent;'
            'scheme=https;'
            'package=org.discoos.ringdrill;'
            'S.browser_fallback_url=$store;'
            'end';
      },
    );
  }

  @override
  State<MobileAppNudgeBanner> createState() => _MobileAppNudgeBannerState();
}

class _MobileAppNudgeBannerState extends State<MobileAppNudgeBanner> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    if (await widget.controller.shouldShow()) {
      setState(() {
        _visible = true;
      });
      widget.controller.markShown();
    }
  }

  void _dismiss() {
    widget.controller.dismiss(days: 30);
    setState(() => _visible = false);
  }

  /// Opens the install guide via the shared helper, which uses the
  /// same modal-on-wide / full-page-on-narrow surface as About. Direct
  /// URL visits to `/install` still resolve as a full page via the
  /// router, so shareable links remain intact.
  void _openInstallGuide(BuildContext context) => openInstallGuide(context);

  void _continueOnWeb() => _dismiss();

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    return SafeArea(
      minimum: widget.margins,
      child: SizedBox(
        height: 110,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: const Icon(Icons.notifications_active),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.getReliableNotifications,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          localizations.useMobileAppNudge,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.end,
                          children: [
                            // Android can open the installed app directly (or
                            // fall back to Play). Every other platform routes
                            // to the install guide, which offers the App Store
                            // / Play native app and the PWA steps. A browser
                            // tab cannot launch an already-installed app, so we
                            // never pretend to "open" it elsewhere.
                            if (WebEnv.isAndroid)
                              FilledButton(
                                onPressed: _getOnAndroid,
                                child: Text(localizations.openInApp),
                              )
                            else
                              FilledButton(
                                onPressed: () => _openInstallGuide(context),
                                child: Text(localizations.installGuideEntry),
                              ),
                            if (widget.showContinueOnWeb)
                              TextButton(
                                onPressed: _continueOnWeb,
                                child: Text(localizations.continueOnWeb),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Spacer(),
                    if (widget.showDismiss)
                      IconButton(
                        tooltip: localizations.dismiss,
                        onPressed: _dismiss,
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _getOnAndroid() {
    // One click: app if installed, else Play Store (via fallback)
    final url = WebEnv.isAndroid
        ? widget.intentUrlBuilder()
        : widget.playStoreUrl;
    _launch(url);
    // no further logic needed; Chrome handles the fallback
  }
}

// Minimal launcher using an <a> tag to avoid extra deps.
@JS('window.open')
external void _jsOpen(String url, String target);

void _launch(String url) {
  try {
    _jsOpen(url, '_self'); // no .toJS
  } catch (_) {}
}
