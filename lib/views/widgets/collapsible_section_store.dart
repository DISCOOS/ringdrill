import 'package:ringdrill/utils/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted open/closed state for a `CollapsibleSectionCard` (or the
/// position card's own collapse, `PositionCardShell`), keyed by a stable
/// `sectionId` — never the localized card title. Defaults to expanded
/// (not collapsed) when nothing is stored, so a reader who has never
/// touched a section sees it open.
class CollapsibleSectionStore {
  static Future<bool> isCollapsed(String sectionId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConfig.collapsibleSectionKey(sectionId)) ?? false;
  }

  static Future<void> setCollapsed(String sectionId, bool collapsed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.collapsibleSectionKey(sectionId), collapsed);
  }
}
