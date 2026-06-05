import 'package:flutter/foundation.dart';
import 'package:ringdrill/utils/app_config.dart';
import 'package:ringdrill/utils/platform_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global, reactive holder for map-related preferences so that any open
/// [MapView] reflects a change the moment the user makes it in settings,
/// rather than only the next time the map screen is rebuilt.
class MapSettings {
  MapSettings._();

  static final MapSettings instance = MapSettings._();

  /// Whether the zoom in/out buttons should be shown on maps that offer
  /// them. Available on every platform: it defaults to on for pointer
  /// devices and off for touch (where pinch-to-zoom makes the buttons
  /// redundant), but touch users can opt in.
  final ValueNotifier<bool> showZoomControls = ValueNotifier<bool>(
    _defaultShowZoomControls,
  );

  /// Platform default used until [load] runs and whenever the user has not
  /// set an explicit preference.
  static bool get _defaultShowZoomControls => !isTouchPlatform;

  /// Loads persisted values. Call once during app start-up so the first
  /// frame already has the user's choice.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    showZoomControls.value =
        prefs.getBool(AppConfig.keyShowMapZoomControls) ??
        _defaultShowZoomControls;
  }

  Future<void> setShowZoomControls(bool value) async {
    showZoomControls.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.keyShowMapZoomControls, value);
  }
}
