import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/prefs.dart';

/// Persisted open/closed state for a `CollapsibleSectionCard` (or the
/// position card's own collapse, `PositionCardShell`), keyed by a stable
/// `sectionId` — never the localized card title. Defaults to expanded
/// (not collapsed) when nothing is stored, so a reader who has never
/// touched a section sees it open.
class CollapsibleSectionStore {
  const CollapsibleSectionStore._();

  /// The stored state read synchronously, or null when [Prefs] has no bound
  /// instance yet.
  ///
  /// Null means "cannot answer yet", never "not collapsed" — the caller keeps its
  /// own default. In the app an instance is always bound (`main`), so this is the
  /// only path that runs; a widget test without a binding sees defaults.
  static bool? isCollapsedNow(String sectionId) {
    if (!Prefs.isBound) return null;
    return Prefs.getBool(AppConfig.collapsibleSectionKey(sectionId)) ?? false;
  }

  static Future<void> setCollapsed(String sectionId, bool collapsed) =>
      Prefs.setBool(AppConfig.collapsibleSectionKey(sectionId), collapsed);
}
