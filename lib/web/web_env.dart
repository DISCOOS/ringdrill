@JS() // optional at file top, fine to keep
import 'dart:js_interop';

// ---- JS externals ----
@JS('window.ringdrillEnv.isMobile')
external JSBoolean? _isMobile();
@JS('window.ringdrillEnv.isAndroid')
external JSBoolean? _isAndroid();
@JS('window.ringdrillEnv.isiOS')
external JSBoolean? _isiOS();
@JS('window.ringdrillEnv.isStandalone')
external JSBoolean? _isStandalone();
@JS('window.ringdrillEnv.isDesktop')
external JSBoolean? _isDesktop();
@JS('window.ringdrillEnv.notifPermission')
external JSString? _notifPermission();
@JS('window.ringdrillEnv.hasInstallPrompt')
external JSBoolean? _hasInstallPrompt();

// NOTE: promise resolves to a JS boolean
@JS('window.ringdrillEnv.promptInstall')
external JSPromise<JSBoolean> _promptInstall();

// Store only strings in localStorage flags
@JS('window.ringdrillEnv.setFlag')
external void _setFlag(String key, String value, int days);
@JS('window.ringdrillEnv.getFlag')
external JSString? _getFlag(String key);

// Helper converters
bool _jsBool(JSBoolean? v) => v?.toDart ?? false;
String _jsString(JSString? v) => v?.toDart ?? '';

class WebEnv {
  static bool get isMobile => _jsBool(_isMobile());
  static bool get isAndroid => _jsBool(_isAndroid());
  static bool get isiOS => _jsBool(_isiOS());
  static bool get isDesktop => _jsBool(_isDesktop());
  static bool get isStandalone => _jsBool(_isStandalone());

  // 'granted' | 'denied' | 'default' | 'unsupported'
  static String get notifPermission => _jsString(_notifPermission());

  static bool get hasInstallPrompt => _jsBool(_hasInstallPrompt());

  static Future<bool> promptInstall() async {
    final jsBool = await _promptInstall().toDart; // JSBoolean
    return jsBool.toDart; // -> bool
  }

  static void setFlag(String key, String value, {int days = 30}) =>
      _setFlag(key, value, days);

  static String? getFlag(String key) {
    final v = _getFlag(key);
    final s = _jsString(v);
    return s.isEmpty ? null : s;
  }
}
