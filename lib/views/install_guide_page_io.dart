import 'package:flutter/material.dart';
import 'package:ringdrill/l10n/app_localizations.dart';

/// Native (non-web) stub for the install guide. The `/install` route and its
/// entry points are web-only, so this is never reached on iOS/Android/desktop
/// native builds. It exists only so the conditional import in the router and
/// the entry points compiles off the web.
class InstallGuidePage extends StatelessWidget {
  const InstallGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.installGuideTitle),
      ),
      body: Center(child: Text(l10n.installGuideAlreadyInstalled)),
    );
  }
}
