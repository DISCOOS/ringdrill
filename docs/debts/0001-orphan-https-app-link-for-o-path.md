---
status: open
severity: low
discovered: 2026-05-22
resolved: null
related_adrs: ["ADR-0015"]
---

# DEBT-0001: Orphan HTTPS App-Link for `/o` path

## What

[`AndroidManifest.xml`](../../android/app/src/main/AndroidManifest.xml) declares an `autoVerify="true"` App-Link intent filter for `https://ringdrill.app/o` (exact path match), but no code path consumes it. A click on the URL opens the app and lands on the default route because GoRouter has no handler for `/o` exact.

## Where

* `android/app/src/main/AndroidManifest.xml` lines 98–106 (the intent filter declaration).
* Verified against `https://ringdrill.app/.well-known/assetlinks.json`, which is served correctly. The verification infrastructure is in place; only the consumer is missing.

## Why it is debt

The filter triggers App-Link verification at every install and every app update. A verification failure (for example after a key rotation in `assetlinks.json`) is silently logged and never surfaced, because nothing actually depends on the App-Link working. Future readers can easily confuse this declaration with:

* The Android ACTION_SEND share mechanism (different intent filter, MIME-based, lower down in the same file). That is the actual "share-to-RingDrill" flow used by `SharedFileChannel`.
* The internal Flutter route `/o/<filepath>` used by `SharedFileChannel` to dispatch the open-file bottom sheet. That route consumes a device filesystem path, not an HTTPS URL.
* The `/i/<slug>` install path proposed by [ADR-0015](../adrs/0015-shareable-install-links.md), which is the catalog-share entry point.

The risk is that a future change extends the `/o` App-Link to "do something useful" without realizing it sits between three unrelated mechanisms.

## Suggested fix

Two reasonable directions, pick one as part of a deliberate decision:

* **Remove the intent filter.** No use case exists today. `flutter_deeplinking_enabled` and the ACTION_SEND filter cover the share-to-RingDrill flow without it.
* **Repurpose `/o` for a specific HTTPS entry point** (for example, an "open last shared file" or "open by code" surface). This needs a new ADR explaining what the path means, what GoRouter does with it, and how it relates to `/i/<slug>` from ADR-0015.

Until one is done, leave the manifest alone and let this entry serve as the breadcrumb.

## Links

* Related ADRs: [ADR-0015](../adrs/0015-shareable-install-links.md)
* Related code: `android/app/src/main/AndroidManifest.xml`, `lib/services/shared_file_channel.dart`, `lib/views/shared_file_widget.dart`, `lib/views/main_screen.dart` (`buildRouter` redirect for `/o/`).
