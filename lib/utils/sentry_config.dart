import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class SentryConfig {
  static void apply(SentryFlutterOptions options) {
    options.dsn =
        'https://8a23c7176b097c782e43e6d930c4d513@o288287.ingest.us.sentry.io/4509676938395648';
    // Tag every event with `debug` or `production`. The release also goes
    // out for both, but having an explicit `environment` lets Sentry's UI
    // filter on it cheaply (no full-text search) and matches the existing
    // tags Sentry already shows on every event.
    options.environment = kReleaseMode ? 'production' : 'debug';

    // Drop everything that comes out of a dev/debug build. Local hot
    // restarts, asserts in the engine (e.g. "Trying to render a disposed
    // EngineFlutterView" during hot reload) and other transient debug-only
    // noise should never reach the prod project — they bury real reports
    // from users. Keep the SDK initialised so breadcrumbs, replay etc.
    // still work locally, just refuse to ship the event over the wire.
    options.beforeSend = (event, hint) {
      if (!kReleaseMode) return null;
      return event;
    };
    options.beforeSendTransaction = (transaction, hint) {
      if (!kReleaseMode) return null;
      return transaction;
    };

    // Adds request headers and IP for users, for more info visit:
    // https://docs.sentry.io/platforms/dart/guides/flutter/data-management/data-collected/
    options.sendDefaultPii = true;
    // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
    // We recommend adjusting this value in production.
    options.tracesSampleRate = 1.0;
    // The sampling rate for profiling is relative to tracesSampleRate
    // Setting to 1.0 will profile 100% of sampled transactions:
    // ignore: experimental_member_use
    options.profilesSampleRate = 1.0;
    // Configure Session Replay
    options.replay.sessionSampleRate = 0.1;
    options.replay.onErrorSampleRate = 1.0;

    // Filter out well-known noise that we cannot act on. Matched as
    // substrings against the exception value. Anything originating from
    // browser-extension internals (chrome.runtime, WebExtensions messaging)
    // belongs here — RingDrill itself has no access to those APIs, so the
    // call site is always third-party code injected into the page.
    //
    //   "Script error."
    //     Fired by window.onerror when a script from a different origin
    //     throws without CORS headers. In practice this is almost always
    //     a browser extension (ad blocker, password manager, translator,
    //     accessibility tool) — the browser strips the message, line and
    //     stack, so even Sentry only sees `Script error.` at line 0. Not
    //     actionable on our side.
    //
    //   "ResizeObserver loop ..."
    //     Benign Chrome/Edge warning that fires when a ResizeObserver
    //     callback synchronously triggers another layout pass. Has no
    //     user-visible effect; it shows up as an uncaught error simply
    //     because the spec asks the browser to surface it.
    //
    //   "Non-Error promise rejection captured ..."
    //     A `Promise.reject(non-Error)` somewhere in third-party JS.
    //     Without a real Error there is nothing to debug from.
    //
    //   "Invalid call to runtime.sendMessage()" / "Extension context
    //   invalidated" / "message port closed" / "Receiving end does not
    //   exist"
    //     The WebExtensions messaging API. Extensions use these to talk
    //     between content scripts and background pages; when a tab closes
    //     mid-message or the extension is updated/disabled the call
    //     throws. We have no chrome.runtime in app code — every report is
    //     extension-internal noise.
    options.ignoreErrors = const [
      'Script error.',
      'ResizeObserver loop limit exceeded',
      'ResizeObserver loop completed with undelivered notifications',
      'Non-Error promise rejection captured',
      'Invalid call to runtime.sendMessage()',
      'Extension context invalidated',
      'The message port closed before a response was received',
      'Receiving end does not exist',
    ];
  }
}
