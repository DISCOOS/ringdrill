import 'package:flutter/material.dart';
import 'package:ringdrill/data/bulk_export.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/views/migration_page.dart';
import 'package:ringdrill/views/shell/open_form_surface.dart';
import 'package:ringdrill/web/trigger_download_web.dart'
    if (dart.library.io) 'package:ringdrill/web/trigger_download_stub.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ringdrill/web/legacy_host_web.dart'
    if (dart.library.io) 'package:ringdrill/web/legacy_host_stub.dart';

/// Signal that re-surfaces the [MigrationBanner] on demand, even after the
/// user has dismissed it for the 24-hour window. The [LegacyBadge] bumps
/// this tick on tap; the banner listens and clears its dismiss state.
///
/// A shared [ValueNotifier] (the same idiom as `stationsTabReselectTick`)
/// keeps the ambient badge and the banner decoupled — the badge does not
/// need a reference to the banner's state. See ADR-0042 "Persistent legacy
/// marker".
final ValueNotifier<int> migrationBannerForceShowTick = ValueNotifier<int>(0);

/// Whether the [MigrationBanner] is currently on screen. The `LegacyBadge`
/// listens to this and hides itself while the banner is visible, so the two
/// legacy surfaces are mutually exclusive and never overlap. The banner
/// keeps this in sync as it loads, is dismissed, or is force-shown.
final ValueNotifier<bool> migrationBannerVisible = ValueNotifier<bool>(false);

/// Banner shown at the top of the app on every screen when the PWA is
/// running on the legacy apex origin (`ringdrill.app`). Prompts the user
/// to export all plans and open the new app at `web.ringdrill.app`.
///
/// The banner is dismissable per-session: a tap on the close button writes
/// a timestamp to [SharedPreferences]; the banner reappears after 24 hours.
class MigrationBanner extends StatefulWidget {
  const MigrationBanner({
    super.key,
    @visibleForTesting this.isLegacyHostOverride,
    @visibleForTesting this.nowOverride,
    @visibleForTesting this.onExportOverride,
    @visibleForTesting this.onOpenNewAppOverride,
    @visibleForTesting this.onReadMoreOverride,
  });

  final bool Function()? isLegacyHostOverride;
  final DateTime Function()? nowOverride;

  /// If set, replaces the real export+download logic in tests.
  final Future<void> Function()? onExportOverride;

  /// If set, replaces `launchUrl` in tests.
  final Future<void> Function(Uri)? onOpenNewAppOverride;

  /// If set, replaces opening the [MigrationPage] explainer in tests.
  final void Function()? onReadMoreOverride;

  @override
  State<MigrationBanner> createState() => _MigrationBannerState();
}

class _MigrationBannerState extends State<MigrationBanner> {
  bool _dismissed = false;
  bool _loaded = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadDismissState();
    migrationBannerForceShowTick.addListener(_onForceShow);
  }

  @override
  void dispose() {
    migrationBannerForceShowTick.removeListener(_onForceShow);
    // The banner is leaving the tree, so it is no longer visible. Let the
    // LegacyBadge take over.
    migrationBannerVisible.value = false;
    super.dispose();
  }

  bool get _isLegacy =>
      widget.isLegacyHostOverride?.call() ?? isLegacyHost();

  /// Publish whether the banner is currently on screen so the [LegacyBadge]
  /// can hide itself while the banner is showing (mutually exclusive).
  void _syncVisible() {
    migrationBannerVisible.value = _isLegacy && _loaded && !_dismissed;
  }

  /// Re-surface the banner on demand (tapped from the [LegacyBadge]).
  /// Clears both the in-memory dismiss flag and the stored 24-hour
  /// timestamp so the banner stays visible until the user dismisses it
  /// again. Normal dismiss behaviour is otherwise unchanged.
  Future<void> _onForceShow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.keyMigrationBannerDismissedAt);
    if (mounted) setState(() => _dismissed = false);
    _syncVisible();
  }

  Future<void> _loadDismissState() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(AppConfig.keyMigrationBannerDismissedAt);
    if (!mounted) return;
    if (ts != null) {
      final dismissedAt = DateTime.fromMillisecondsSinceEpoch(ts);
      final now = widget.nowOverride?.call() ?? DateTime.now();
      _dismissed = now.difference(dismissedAt) < const Duration(hours: 24);
    }
    setState(() => _loaded = true);
    _syncVisible();
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    final now = widget.nowOverride?.call() ?? DateTime.now();
    await prefs.setInt(
      AppConfig.keyMigrationBannerDismissedAt,
      now.millisecondsSinceEpoch,
    );
    if (mounted) setState(() => _dismissed = true);
    _syncVisible();
  }

  Future<void> _export() async {
    if (widget.onExportOverride != null) {
      await widget.onExportOverride!();
      return;
    }
    setState(() => _exporting = true);
    try {
      final shells = ProgramService().listPrograms();
      final programs = shells
          .map((s) => ProgramService().loadProgram(s.uuid))
          .whereType<Program>()
          .toList();
      final bytes = exportAllPrograms(programs);
      final now = widget.nowOverride?.call() ?? DateTime.now();
      await triggerDownload(bulkExportFileName(now), bytes);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openNewApp() async {
    final uri = Uri.parse('https://web.ringdrill.app/');
    if (widget.onOpenNewAppOverride != null) {
      await widget.onOpenNewAppOverride!(uri);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _readMore() {
    if (widget.onReadMoreOverride != null) {
      widget.onReadMoreOverride!();
      return;
    }
    openFormSurface<void>(context, builder: (_) => const MigrationPage());
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLegacy || !_loaded || _dismissed) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return ColoredBox(
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.migrationBannerHeading,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSecondaryContainer,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.migrationBannerBody,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSecondaryContainer,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilledButton(
                        onPressed: _exporting ? null : _export,
                        child: Text(l10n.migrationBannerExport),
                      ),
                      OutlinedButton(
                        onPressed: _openNewApp,
                        child: Text(l10n.migrationBannerOpenNewApp),
                      ),
                      TextButton(
                        onPressed: _readMore,
                        child: Text(l10n.migrationBannerReadMore),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _dismiss,
            ),
          ],
        ),
      ),
    );
  }
}
