import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Synchronous access to [SharedPreferences], for UI state that has to be right
/// on the *first* frame.
///
/// Only `SharedPreferences.getInstance()` is asynchronous — every getter on the
/// resolved instance reads an in-memory map, and setters write it synchronously
/// and flush to the platform in the background. So awaiting `getInstance()` in
/// an `initState` costs a frame for no reason, and that frame is visible: a
/// collapsible card renders its default state, then jumps to the stored one; a
/// master pane stored collapsed paints expanded and snaps shut.
///
/// `main()` resolves the instance before `runApp`, so it binds it here and every
/// widget built afterwards can read it synchronously.
///
/// **Only `main` binds.** Nothing else — not even the async fallbacks that read
/// through `getInstance()` — writes the binding, deliberately: it is process-wide
/// static state, and `SharedPreferences.setMockInitialValues` builds a *fresh*
/// instance, so a binding acquired during one test would keep serving that
/// test's values to the next one. Widget tests therefore see [instanceOrNull]
/// null by default and take the async path, which is the behaviour they always
/// had. A test that wants the synchronous path binds explicitly and resets after
/// (see [reset]).
///
/// Not a general prefs facade: services with their own async lifecycle
/// (`PlanService`, `MapSettings`, the settings page) keep using `getInstance()`
/// directly. This is for the narrow case of "render the stored value on the
/// first frame or not at all".
class UiPrefs {
  const UiPrefs._();

  static SharedPreferences? _prefs;

  /// Binds an already-resolved instance. Called from `main()` with the instance
  /// it awaited anyway, so binding costs nothing.
  static void bind(SharedPreferences prefs) => _prefs = prefs;

  /// The bound instance, or null when nothing has bound one. Callers must treat
  /// null as "use your default and catch up asynchronously", never as "no value
  /// is stored".
  static SharedPreferences? get instanceOrNull => _prefs;

  /// Drops the binding. Required in any test that calls [bind], since the
  /// binding outlives the test otherwise — the same trap `PlanService.reset`
  /// exists for.
  @visibleForTesting
  static void reset() => _prefs = null;
}
