// pwa_update_web.dart  (web-only)
import 'dart:js_util' as js_util;

import 'package:web/web.dart' as web;

/// Add a JS 'event' listener using allowInterop
void _on(
  web.EventTarget target,
  String type,
  void Function(web.Event) handler,
) {
  js_util.callMethod(target, 'addEventListener', [
    type,
    js_util.allowInterop(handler),
  ]);
}

/// Call at startup on web; fires when a new SW is installed while a controller exists
Future<void> listenForPwaUpdates(void Function() onUpdateReady) async {
  final swc = web.window.navigator.serviceWorker;

  // Use the "ready" registration (Promise -> Future)
  final reg = await js_util.promiseToFuture<web.ServiceWorkerRegistration>(
    swc.ready,
  );

  void watchSW(web.ServiceWorker sw) {
    void maybeNotify() {
      if (sw.state == 'installed' && swc.controller != null) {
        onUpdateReady();
      }
    }

    // In case it's already installed
    maybeNotify();
    _on(sw, 'statechange', (_) => maybeNotify());
  }

  // If there is already a waiting SW (page was backgrounded), watch it
  final waiting = reg.waiting;
  if (waiting != null) watchSW(waiting);

  // When a new one is found, watch the installing worker
  _on(reg, 'updatefound', (_) {
    final installing = reg.installing;
    if (installing != null) watchSW(installing);
  });

  // Optional: nudge the browser to check when window regains focus
  _on(web.window, 'focus', (_) {
    js_util.callMethod(reg, 'update', const []);
  });
}
