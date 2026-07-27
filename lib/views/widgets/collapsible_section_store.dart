import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/ui_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted open/closed state for a `CollapsibleSectionCard` (or the
/// position card's own collapse, `PositionCardShell`), keyed by a stable
/// `sectionId` — never the localized card title. Defaults to expanded
/// (not collapsed) when nothing is stored, so a reader who has never
/// touched a section sees it open.
class CollapsibleSectionStore {
  const CollapsibleSectionStore._();

  /// The stored state read synchronously, or null when [UiPrefs] has no bound
  /// instance yet.
  ///
  /// Prefer this over [isCollapsed]: an awaited read costs a frame, and that
  /// frame is visible — the card renders expanded, then jumps closed. Null means
  /// "cannot answer yet", never "not collapsed"; the caller keeps its own
  /// default and catches up via [isCollapsed].
  static bool? isCollapsedNow(String sectionId) {
    final prefs = UiPrefs.instanceOrNull;
    if (prefs == null) return null;
    return prefs.getBool(AppConfig.collapsibleSectionKey(sectionId)) ?? false;
  }

  /// Fallback for when no instance is bound — a widget test, or an entry point
  /// that does not go through `main()`. Deliberately does not bind what it
  /// resolves; see [UiPrefs].
  static Future<bool> isCollapsed(String sectionId) async {
    final prefs =
        UiPrefs.instanceOrNull ?? await SharedPreferences.getInstance();
    return prefs.getBool(AppConfig.collapsibleSectionKey(sectionId)) ?? false;
  }

  static Future<void> setCollapsed(String sectionId, bool collapsed) async {
    final prefs =
        UiPrefs.instanceOrNull ?? await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.collapsibleSectionKey(sectionId), collapsed);
  }
}
