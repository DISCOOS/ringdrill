// lib/web/pwa_update_web.dart
import 'dart:js_interop';

import 'package:web/web.dart' as web;

typedef OnUpdateReady = void Function(void Function() reloadNow);

void listenForPwaUpdates({required OnUpdateReady onUpdateReady}) {
  final swContainer = web.window.navigator.serviceWorker;

  void wire(web.ServiceWorkerRegistration reg) {
    // 1) Detect a newly found SW
    reg.addEventListener(
      'updatefound',
      ((web.Event _) {
        final installing = reg.installing;
        if (installing == null) return;

        // 2) When its state hits 'installed' and there's a waiter, prompt to reload
        installing.addEventListener(
          'statechange',
          ((web.Event _) {
            if (installing.state == 'installed' && reg.waiting != null) {
              onUpdateReady(() {
                reg.waiting?.postMessage({'type': 'SKIP_WAITING'}.jsify());
              });
            }
          }).toJS,
        );
      }).toJS,
    );

    // 3) When the controller changes, the new SW is active => reload once
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

    // 4) Proactively check for updates at startup
    reg.update();

    // 5) Check when tab becomes visible again
    web.document.addEventListener(
      'visibilitychange',
      (() {
        if (web.document.visibilityState == 'visible') {
          reg.update();
        }
      }).toJS,
    );

    // 6) Check every 6 hours
    web.window.setInterval(
      (() => reg.update()).toJS,
      (6 * 60 * 60 * 1000).toJS,
    );
  }

  // Ready returns a promise -> Future in Dart
  swContainer.ready.toDart.then(wire);
}
