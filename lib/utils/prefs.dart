import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Synchronous access to the app's [SharedPreferences].
///
/// Only `SharedPreferences.getInstance()` is asynchronous — the getters read an
/// in-memory map, and setters write it synchronously and flush to the platform in
/// the background. `main()` awaits the instance before `runApp`, so by the time
/// any widget builds it already exists, and every `await getInstance()` after
/// that buys a frame of the *default* value for nothing. Those frames are
/// visible: a collapsible card renders expanded and jumps closed, a master pane
/// stored collapsed opens and snaps shut, a role-gated affordance shows under the
/// wrong role.
///
/// So the app binds the instance here once and reads it synchronously.
///
/// **Reads are sync, writes stay async.** A setter has to reach the platform, so
/// it still returns a `Future`; what it does not have to do is wait to *find out*
/// what is stored.
///
/// ## Unbound means "nothing stored"
///
/// Every getter returns null (or the caller's default) when nothing has bound an
/// instance — a widget test, or an entry point that skips `main`. That is
/// deliberate, and it is what keeps this usable from tests: they call
/// `setMockInitialValues` and expect defaults, which is exactly what an unbound
/// read gives them. A test that seeds real values and asserts the app reads them
/// binds explicitly.
///
/// **Only `main` binds.** Nothing else — not even the async fallbacks — writes the
/// binding, deliberately: it is process-wide static state and
/// `setMockInitialValues` builds a *fresh* instance, so a binding acquired during
/// one test would keep serving that test's values to the next one. That is not
/// hypothetical; it is what broke `position_card_collapse_test` the first time
/// this was introduced.
class Prefs {
  const Prefs._();

  static SharedPreferences? _prefs;

  /// Binds an already-resolved instance. Called from `main()` with the instance
  /// it awaited anyway, so binding costs nothing.
  static void bind(SharedPreferences prefs) => _prefs = prefs;

  /// The bound instance, or null when nothing has bound one. Prefer the typed
  /// accessors; this is for the few callers that hand the whole instance to
  /// something else (`PlanRepository`, `NotificationService.initFromPrefs`).
  static SharedPreferences? get instanceOrNull => _prefs;

  /// True once an instance is bound — for a caller that must know the difference
  /// between "nothing stored" and "cannot answer yet".
  static bool get isBound => _prefs != null;

  static String? getString(String key) => _prefs?.getString(key);

  static bool? getBool(String key) => _prefs?.getBool(key);

  static int? getInt(String key) => _prefs?.getInt(key);

  static double? getDouble(String key) => _prefs?.getDouble(key);

  static List<String>? getStringList(String key) => _prefs?.getStringList(key);

  /// Resolves the instance when unbound, so a write from a surface that runs
  /// outside `main` still lands. Does **not** bind — see the class doc.
  static Future<SharedPreferences> _writable() async =>
      _prefs ?? await SharedPreferences.getInstance();

  static Future<void> setString(String key, String value) async =>
      (await _writable()).setString(key, value);

  static Future<void> setBool(String key, bool value) async =>
      (await _writable()).setBool(key, value);

  static Future<void> setInt(String key, int value) async =>
      (await _writable()).setInt(key, value);

  static Future<void> setDouble(String key, double value) async =>
      (await _writable()).setDouble(key, value);

  static Future<void> setStringList(String key, List<String> value) async =>
      (await _writable()).setStringList(key, value);

  static Future<void> remove(String key) async =>
      (await _writable()).remove(key);

  /// Drops the binding. Required in any test that calls [bind], since the
  /// binding outlives the test otherwise — the same trap `PlanService.reset`
  /// exists for.
  @visibleForTesting
  static void reset() => _prefs = null;
}
