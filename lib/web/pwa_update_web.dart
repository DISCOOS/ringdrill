// lib/web/pwa_update_web.dart
import 'dart:js_interop';

import 'package:web/web.dart' as web;

typedef OnUpdateReady = void Function(void Function() reloadNow);

void listenForPwaUpdates({required OnUpdateReady onUpdateReady}) {
  final swContainer = web.window.navigator.serviceWorker;

  void wire(web.ServiceWorkerRegistration reg) {
    void promptIfWaiting() {
      final waiting = reg.waiting;
      if (waiting != null) {
        onUpdateReady(() {
          waiting.postMessage({'type': 'SKIP_WAITING'}.jsify());
        });
      }
    }

    void trackInstalling(web.ServiceWorker installing) {
      installing.addEventListener(
        'statechange',
        ((web.Event _) {
          if (installing.state == 'installed' && reg.waiting != null) {
            promptIfWaiting();
          }
        }).toJS,
      );
    }

    // 1) If a SW is already waiting from a previous session, surface it now.
    //    Without this the snackbar never fires for users who were stuck after
    //    missing the installation moment in an earlier visit.
    promptIfWaiting();

    // 2) If a SW is currently mid-install, wire up its statechange so we
    //    catch the transition to 'installed' that the listener in (3) would
    //    otherwise miss.
    final installing = reg.installing;
    if (installing != null) {
      trackInstalling(installing);
    }

    // 3) Future updates: every new installing worker gets a statechange
    //    listener that triggers the prompt once it reaches 'installed'.
    reg.addEventListener(
      'updatefound',
      ((web.Event _) {
        final inst = reg.installing;
        if (inst != null) trackInstalling(inst);
      }).toJS,
    );

    // 4) When the controller changes, the new SW is active. Reload once.
    var reloaded = false;
    swContainer.addEventListener(
      'controllerchange',
      ((web.Event _) {
        if (!reloaded) {
          reloaded = true;
          web.window.location.reload();
        }
      }).toJS,
    );

    // --- periodic and visibility checks ---

    // 5) Proactively check for updates at startup.
    reg.update();

    // 6) Check when tab becomes visible again.
    web.document.addEventListener(
      'visibilitychange',
      (() {
        if (web.document.visibilityState == 'visible') {
          reg.update();
        }
      }).toJS,
    );

    // 7) Check every 6 hours.
    web.window.setInterval(
      (() => reg.update()).toJS,
      (6 * 60 * 60 * 1000).toJS,
    );
  }

  // Ready returns a promise -> Future in Dart.
  swContainer.ready.toDart.then(wire);
}

/// Plain page reload. Equivalent to `window.location.reload()`; kept in
/// this file so the rest of the app can route the call through the same
/// conditional-import seam used for the other PWA helpers.
void reloadCurrentPage() {
  web.window.location.reload();
}

/// Wipe localStorage (where shared_preferences_web persists everything)
/// then reload. Used as the "nuclear" recovery from the boot-failure
/// screen when a corrupt entry keeps `main()` from completing. Does NOT
/// touch service workers; pair with [forcePwaUpdate] if cache-busting is
/// also required.
Future<void> clearWebStorageAndReload() async {
  try {
    web.window.localStorage.clear();
  } catch (_) {
    // ignore; reload below will still try to start with whatever is left
  }
  web.window.location.reload();
}

/// Last-resort recovery for clients that are stuck on an old build:
/// unregister every service worker for this origin, wipe Cache Storage,
/// then hard-reload. Existing IndexedDB / localStorage is preserved.
Future<void> forcePwaUpdate() async {
  try {
    final regs = await web.window.navigator.serviceWorker
        .getRegistrations()
        .toDart;
    for (final reg in regs.toDart) {
      await reg.unregister().toDart;
    }
  } catch (_) {
    // ignore; we still try the cache wipe and reload below
  }

  try {
    final caches = web.window.caches;
    final keys = (await caches.keys().toDart).toDart;
    for (final key in keys) {
      await caches.delete(key.toDart).toDart;
    }
  } catch (_) {
    // ignore; reload below will still pull a fresh document
  }

  web.window.location.reload();
}
