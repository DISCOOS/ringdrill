import 'package:flutter/widgets.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/web/install_guide_page.dart';
import 'package:ringdrill/web/web_env.dart';

/// Whether to offer an "install the app" entry. True on the web when the
/// app is not already running as an installed PWA.
bool get canShowInstallEntry => !WebEnv.isStandalone;

/// Opens the install guide on the appropriate surface for the current
/// window size class: as a modal dialog on wide layouts (per ADR-0030)
/// and as a full-page route on narrow layouts. Direct URL visits to
/// `/install` still resolve to the full-page route via `app_router.dart`,
/// so shareable links remain intact.
void openInstallGuide(BuildContext context) {
  openFormSurface<void>(context, builder: (_) => const InstallGuidePage());
}
