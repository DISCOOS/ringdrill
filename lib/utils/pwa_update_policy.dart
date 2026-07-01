/// Pure decision logic for applying a pending PWA update.
///
/// Extracted from `lib/web/pwa_update_web.dart` and `lib/main.dart` so the
/// rules can be unit-tested on the Dart VM. The surrounding service-worker
/// plumbing (detecting a waiting worker, posting `SKIP_WAITING`, reloading on
/// `controllerchange`) is browser-only and lives in `pwa_update_web.dart`;
/// this file deliberately imports nothing web-specific.

/// Whether a pending update is safe to apply automatically, without asking.
///
/// True only when the worker was already waiting at page load ([atStartup] —
/// a refresh, not a mid-session surprise) AND the device is [isOnline].
/// Activating a new Flutter service worker triggers its offline precache, so
/// doing it offline risks stranding the app without assets the new build
/// needs. See `pwa_update_web.dart`.
bool computeCanAutoApply({required bool atStartup, required bool isOnline}) =>
    atStartup && isOnline;

/// What to do with a ready update.
enum PwaUpdateAction {
  /// Switch to the new build immediately (reload).
  autoApply,

  /// Keep the current, fully cached build and let the user choose ("Restart
  /// now").
  prompt,
}

/// Decide how to apply a ready update.
///
/// Auto-applies only when [canAutoApply] (safe from the SW/network view) and
/// no drill is running ([isExerciseRunning]) — a reload would interrupt a
/// live exercise. Everything else prompts.
PwaUpdateAction decidePwaUpdateAction({
  required bool canAutoApply,
  required bool isExerciseRunning,
}) => (canAutoApply && !isExerciseRunning)
    ? PwaUpdateAction.autoApply
    : PwaUpdateAction.prompt;
