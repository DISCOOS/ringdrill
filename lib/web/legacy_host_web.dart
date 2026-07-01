import 'package:ringdrill/utils/app_flags.dart';
import 'package:ringdrill/web/web_env.dart';
import 'package:web/web.dart' as web;

/// Whether the migration UI (banner + [LegacyBadge]) should show.
///
/// Only relevant for an *installed* PWA on the legacy apex origin. A plain
/// browser tab on `ringdrill.app` needs no in-app banner: after the ADR-0039
/// Phase 3 cutover a fresh browser visit fails over to the Astro site, which
/// prompts migration via `/migrate`. So we additionally require standalone
/// display mode ([WebEnv.isStandalone] — matchMedia `display-mode: standalone`
/// plus `navigator.standalone` on iOS).
///
/// `RINGDRILL_FORCE_LEGACY_HOST` short-circuits before the standalone check
/// so a normal (non-installed) dev browser can still exercise the migration
/// UI.
bool isLegacyHost() {
  if (AppFlags.migrationDisabled) return false;
  if (AppFlags.forceLegacyHost) return true;
  return checkIsLegacyHostName(web.window.location.hostname) &&
      WebEnv.isStandalone;
}

bool checkIsLegacyHostName(String hostname) => hostname == 'ringdrill.app';
