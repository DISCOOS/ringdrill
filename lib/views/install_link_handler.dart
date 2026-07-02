import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/views/app_routes.dart';
import 'package:ringdrill/views/open_file_widget.dart';

/// Handles a `/i/<slug>` App Link (or a shared catalog link routed here via
/// [SharedFileChannel.links]). Shows the same Open/Import bottom sheet a
/// local `.drill` file gets via `/o/`, rather than silently installing and
/// activating — the latter used to be this handler's whole job, but that
/// gave the user no way to merge a shared plan into the one they're already
/// running instead of replacing it.
Future<void> handleInstallLink(BuildContext context, String slug) async {
  final localizations = AppLocalizations.of(context)!;
  final cleanSlug = slug.trim();
  if (cleanSlug.isEmpty || cleanSlug.contains('/')) {
    _showSnackBar(context, localizations.libraryErrorLoad);
    return;
  }

  final client = _buildCatalogClient();
  final item = MarketFeedItem(
    programId: '',
    slug: cleanSlug,
    name: cleanSlug,
    tags: const [],
    latestUrl: Uri.parse(
      'https://ringdrill.app/i/${Uri.encodeComponent(cleanSlug)}',
    ),
  );

  // Memoized so the "Open" and "Import" buttons in the sheet share one
  // download instead of each triggering their own network fetch.
  Future<DrillDownloadResponse>? cachedDownload;
  Future<DrillDownloadResponse> download() =>
      cachedDownload ??= client.download(cleanSlug);

  showOpenFileBottomSheet(
    context,
    OpenFileWidget(
      fileName: '$cleanSlug.${DrillFile.drillExtension}',
      loadFile: () async => (await download()).file,
      // installFromCatalogFile (not plain installFromFile) so the result
      // keeps its catalog-source tag (slug/etag) for later "refresh from
      // catalog" — see ProgramService.installFromCatalogFile.
      openProgram: (_) async => ProgramService().installFromCatalogFile(
        item,
        await download(),
        activate: true,
      ),
      isOnline: true,
      location: routeProgram,
    ),
  );
}

DrillClient _buildCatalogClient() {
  final baseUrl = AppConfig.catalogBaseUrl(
    isWeb: kIsWeb,
    isRelease: kReleaseMode,
    isDebug: kDebugMode,
  );
  return DrillClient(
    baseUrl: baseUrl,
    functionsBasePath: AppConfig.functionsBasePathFor(baseUrl),
    deepLinkBasePath: AppConfig.deepLinkBasePathFor(baseUrl),
  );
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      showCloseIcon: true,
      dismissDirection: DismissDirection.endToStart,
    ),
  );
}
