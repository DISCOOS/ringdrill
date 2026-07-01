import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ringdrill/data/bulk_export.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/program.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/web/trigger_download_web.dart'
    if (dart.library.io) 'package:ringdrill/web/trigger_download_stub.dart';

/// Full-page migration explainer opened from the "Om migrasjon" /
/// "About the migration" settings entry.
///
/// Renders the explainer with native typography from the app theme rather
/// than via a Markdown widget so the page matches the rest of the app. A
/// re-export button at the bottom triggers the same ZIP export as the
/// MigrationBanner primary action.
class MigrationPage extends StatelessWidget {
  const MigrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.cancel,
          // Reached via push (drawer/Settings) or cold via the shareable
          // `/migrate` URL. Pop when possible, otherwise go home so we never
          // pop the last page off the go_router stack.
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(l10n.migrationSettingsEntry),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  _Section(
                    title: l10n.migrationExplainerWhyTitle,
                    body: l10n.migrationExplainerWhyBody,
                  ),
                  _Section(
                    title: l10n.migrationExplainerChangesTitle,
                    body: l10n.migrationExplainerChangesBody,
                  ),
                  _StepsSection(
                    title: l10n.migrationExplainerStepsTitle,
                    steps: [
                      l10n.migrationExplainerStep1,
                      l10n.migrationExplainerStep2,
                      l10n.migrationExplainerStep3,
                      l10n.migrationExplainerStep4,
                      l10n.migrationExplainerStep5,
                    ],
                  ),
                  _Section(
                    title: l10n.migrationExplainerDataTitle,
                    body: l10n.migrationExplainerDataBody,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Align(
                alignment: Alignment.center,
                child: FilledButton(
                  onPressed: () => _export(context),
                  child: Text(l10n.migrationBannerExport),
                ),
              ),
            ),
          ],
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _StepsSection extends StatelessWidget {
  const _StepsSection({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    child: Text(steps[i], style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
