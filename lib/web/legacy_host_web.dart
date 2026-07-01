import 'package:ringdrill/utils/app_flags.dart';
import 'package:web/web.dart' as web;

/// Whether the migration UI (banner + [LegacyBadge]) should show.
///
/// Any visit to the legacy apex origin (`ringdrill.app`) qualifies, in
/// any display mode. `RINGDRILL_FORCE_LEGACY_HOST` short-circuits so a
/// non-apex dev browser can still exercise the UI.
///
/// An earlier version additionally required `WebEnv.isStandalone` on the
/// theory that browser-tab visitors would migrate via the Astro `/migrate`
/// surface post-Phase 3. That reasoning was wrong: post-Phase 3, fresh
/// browser-tab visits go straight to Cloudflare/Astro and never reach
/// this function. The only visitors who still hit the Flutter build are
/// cached-SW loads on this origin, and they have data to migrate whether
/// their display mode is standalone or a browser tab. `isStandalone`
/// therefore only ever filtered out a subset of the exact audience the
/// banner is meant for. Removed.
bool isLegacyHost() {
  if (AppFlags.migrationDisabled) return false;
  if (AppFlags.forceLegacyHost) return true;
  return checkIsLegacyHostName(web.window.location.hostname);
}

bool checkIsLegacyHostName(String hostname) => hostname == 'ringdrill.app';
