import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:ringdrill/data/bulk_export.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/web/trigger_download_web.dart'
    if (dart.library.io) 'package:ringdrill/web/trigger_download_stub.dart';

/// Full-page migration explainer opened from the "Om migrasjon" /
/// "About the migration" settings entry.
///
/// Loads locale-specific markdown from the bundled asset files and renders
/// it via [MarkdownWidget]. A re-export button at the bottom lets the user
/// trigger the same ZIP export as the [MigrationBanner] primary action.
class MigrationPage extends StatelessWidget {
  const MigrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final assetPath = locale.languageCode == 'nb'
        ? 'lib/l10n/migration_explainer_nb.md'
        : 'lib/l10n/migration_explainer_en.md';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.migrationSettingsEntry),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: DefaultAssetBundle.of(context).loadString(assetPath),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                Expanded(
                  child: MarkdownWidget(
                    data: snapshot.data!,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    config: isDark
                        ? MarkdownConfig.darkConfig
                        : MarkdownConfig.defaultConfig,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _export(context),
                      child: Text(l10n.migrationBannerExport),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final shells = ProgramService().listPrograms();
    final programs = shells
        .map((s) => ProgramService().loadProgram(s.uuid))
        .whereType<Program>()
        .toList();
    final bytes = exportAllPrograms(programs);
    await triggerDownload(bulkExportFileName(DateTime.now()), bytes);
  }
}
