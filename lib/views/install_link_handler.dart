import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ringdrill/data/drill_client.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/services/program_service.dart';
import 'package:ringdrill/utils/app_config.dart';

Future<void> handleInstallLink(BuildContext context, String slug) async {
  final localizations = AppLocalizations.of(context)!;
  final cleanSlug = slug.trim();
  if (cleanSlug.isEmpty || cleanSlug.contains('/')) {
    _showSnackBar(context, localizations.libraryErrorLoad);
    return;
  }

  try {
    await ProgramService().installFromCatalog(
      MarketFeedItem(
        programId: '',
        slug: cleanSlug,
        name: cleanSlug,
        tags: const [],
        latestUrl: Uri.parse(
          'https://ringdrill.app/i/${Uri.encodeComponent(cleanSlug)}',
        ),
      ),
      _buildCatalogClient(),
      activate: true,
    );
    if (!context.mounted) return;
    _showSnackBar(context, localizations.installedFromLink);
  } catch (_) {
    if (!context.mounted) return;
    _showSnackBar(context, localizations.libraryErrorLoad);
  }
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
