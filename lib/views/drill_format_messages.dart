import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/l10n/app_localizations.dart';

/// Maps a [DrillFormatReason] to the localized message the UI should show
/// in a snackbar (or a bundle's per-file skipped-entry list).
///
/// Centralized here so [OpenFileWidget], the picker-driven flow in
/// `active_plan_actions.dart`, and the bundle-import skipped-entry list in
/// `library_view.dart` all give identical wording for the same failure
/// mode. The fallback for an unknown reason is [openFailure], which
/// preserves today's "Open … failed. Please try again." text.
///
/// These messages are intentionally non-actionable beyond "this file is
/// the problem" because the user cannot do anything inside the app to
/// salvage a broken `.drill` — re-downloading or asking the sender to
/// re-export is the real fix.
String drillFormatMessage(
  AppLocalizations l10n,
  String fileName,
  DrillFormatReason reason,
) {
  switch (reason) {
    case DrillFormatReason.empty:
      return l10n.openEmptyDrill(fileName);
    case DrillFormatReason.notArchive:
      return l10n.openInvalidDrill(fileName);
    case DrillFormatReason.missingProgram:
    case DrillFormatReason.corruptManifest:
      return l10n.openCorruptDrill(fileName);
    case DrillFormatReason.schemaUnsupported:
      return l10n.openUnsupportedSchema(fileName);
  }
}
