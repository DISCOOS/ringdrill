---
status: accepted
date: 2026-06-25
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0038: Gate first-launch consent and rationale behind a four-stage onboarding

## Context and problem statement

RingDrill collects two pieces of optional user permission on first launch:

1. **Analytics consent** for Sentry, gated by [ADR-0006](./0006-sentry-behind-consent-gate.md). The gate defaults to off; the user has to opt in.
2. **Notification permission** for exercise transition alerts (rotation, round change, auto-stop). iOS surfaces a one-shot system dialog the first time `requestPermissions` is called, and a user who taps "Don't Allow" without context can only recover from OS Settings.

Until 1.0.3 these two consent choices were collected in two different ways. Analytics consent was a barrier-modal `AlertDialog` shown from `MainScreen.initState` — after the user had already tapped through `ConceptPrimerScreen`. Notification permission was requested implicitly at boot from `RingDrillAppState._startNotificationService`, so the iOS system dialog popped before any RingDrill UI had rendered.

A first iteration of this ADR moved both consents into `ConceptPrimerScreen.initState` as chained barrier-modal dialogs on top of the primer. It worked but felt like popup-spam during boot, the dialogs had no room for rationale or visuals beyond three lines of body text, and the visual weight of "Allow" (`ElevatedButton`) versus "Decline" (`TextButton`) biased the choice. We need a presentation that treats the two consents as first-class steps of the first-launch flow, not as interruptions on top of it.

## Decision drivers

* Cohesive first-launch experience that does not feel like popup-spam.
* Each consent choice gets full-screen room for rationale + visuals, not three lines in an `AlertDialog`.
* "Allow" and "Skip for now" presented as equal-weight buttons, so the user makes an active choice rather than reflexively tapping the primary CTA.
* No one-tap bypass. The user walks through each stage. This protects [ADR-0006] (opt-in analytics) and the notification rationale equally.
* Defer the iOS notification permission prompt until after the user has actively chosen "Allow" on RingDrill's own copy. A user who taps "Skip for now" never sees the OS dialog, which means iOS does not record a permanent denial that only the OS Settings app can reverse.
* Recoverable. A user who skipped must be able to re-enable from inside RingDrill, not just from OS Settings — surface a Settings-screen affordance.

## Considered options

* **A. Modal dialogs on top of primer (the first iteration of this ADR).** `ConceptPrimerScreen.initState` chains `showAnalyticsConsentDialog` then `maybeShowNotificationConsentPrompt`. Both barrier-modal.
* **B. Four-stage `PageView` onboarding.** `ConceptPrimerScreen` becomes a stateful host that drives a horizontal `PageView` of four widgets: welcome → analytics consent → notification consent → start (open example / start empty).
* **C. Deep-linkable consent routes.** Each consent gets its own `GoRoute` so URLs like `/welcome/analytics` are addressable.

## Decision outcome

Chosen option: **B — four-stage `PageView` onboarding**, because it gives both consents full-screen room for rationale, removes the popup-on-popup feel, and presents Allow vs. Skip-for-now as equal-weight choices.

Concretely:

* `ConceptPrimerScreen` becomes a `StatefulWidget` that hosts a `PageController`-driven `PageView` with four pages, in order: `WelcomeStage` (the existing `ConceptPrimerContent`), `AnalyticsConsentStage`, `NotificationConsentStage`, `StartStage` (Skip / Start empty / Open example).
* Stages are forward-only — no swipe-back, no system back. A stage indicator (four dots) sits at the bottom so the user knows how far they are.
* Stage state lives in `_ConceptPrimerScreenState`. Each stage exposes an `onNext` callback that advances the page and persists the per-stage outcome. There is no global form state.
* Persistence stays where it is: `AppConfig.keyAnalyticsConsent` for analytics, `AppConfig.keyNotificationConsentAsked` + `NotificationService.initFromPrefs` for notifications. The stage widgets call into the same prefs writes the dialog helpers used to do — the helpers (`lib/views/widgets/analytics_consent_dialog.dart`, `lib/views/widgets/notification_consent_dialog.dart`) are deleted in the move.
* `isFirstLaunch` continues to gate the stage flow: when false, `ConceptPrimerScreen` skips the consent stages and mounts `WelcomeStage` + `StartStage` only (or, if `isOnboardingSeen` is already true, the router never routes to `/welcome` in the first place).
* The OS notification permission prompt is still deferred — `RingDrillAppState._startNotificationService` calls `NotificationService.init(requestPermissions: keyNotificationConsentAsked)` at boot. `NotificationConsentStage`'s "Allow" tap is the place where `requestPermissions: true` runs.
* `NotificationService.permissionState` (`granted` / `denied` / `pluginFailed` / `unknown`) drives the re-engagement affordance on the Settings page, deep-linking to OS Settings via `Geolocator.openAppSettings()` (reused; its implementation is platform-generic, only the name is geolocator-shaped).

### Consequences

* Good: Each consent has full-screen real estate for rationale + visuals.
* Good: Forward-only flow with equal-weight buttons removes the implicit "tap Allow to dismiss" reflex.
* Good: Reuses the analytics consent flow within the same chrome as notification consent, presenting them as a coherent set rather than two unrelated dialogs.
* Good: Same prefs flags still gate Sentry init and the OS notification prompt, so the service contracts in [ADR-0006] and the notification service are unchanged.
* Bad: `ConceptPrimerScreen` grows from a single screen to a stage host. Primer content moves into one of four widgets.
* Bad: Forward-only means a user who accidentally taps "Skip for now" cannot return without going to Settings later. Acceptable — Settings is the established recovery path and is signposted from the skip helper text.
* Bad: Existing 1.0.3 installs already have `isOnboardingSeen: true`. They will never see the new stages and have to use Settings to flip notifications. Acceptable: the first iteration of this ADR already had this gap, and the Settings deep-link is the recovery path.

## Pros and cons of the options

### A. Modal dialogs on top of primer (initial iteration)
* Good: Smallest implementation. Worked end-to-end.
* Bad: Popup-on-popup feel during boot.
* Bad: Limited room for rationale — three lines max in an `AlertDialog`.
* Bad: Dialog `ElevatedButton` for "Allow" vs `TextButton` for "Decline" biases the choice toward the primary.

### B. Four-stage `PageView` (chosen)
* Good: Full screen per consent.
* Good: "Allow" and "Skip for now" visually equal.
* Good: Stage indicator shows progress, no surprises.
* Good: PageView is a small, stateless-feeling abstraction — no new router state, no `GoRoute` proliferation.
* Bad: More code, more state in `_ConceptPrimerScreenState`.

### C. Deep-linkable routes
* Good: Could be A/B-tested by linking into a specific consent stage.
* Bad: We do not need URL-addressable consent. Adds router complexity for no win.
* Bad: System back from the third route exits the consent step entirely, which is a fragile failure mode for a first-launch flow.

## Links

* Related ADRs: [ADR-0006](./0006-sentry-behind-consent-gate.md), [ADR-0029](./0029-live-activity-and-foreground-service.md).
* Related code: `lib/views/concept_primer_screen.dart` (stage host), `lib/views/widgets/onboarding/` (stage widgets — to be created), `lib/services/notification_service.dart`, `lib/views/settings_page.dart`, `lib/main.dart`, `lib/utils/app_config.dart`.
* Deleted in the move: `lib/views/widgets/analytics_consent_dialog.dart`, `lib/views/widgets/notification_consent_dialog.dart`.
* External: [Apple HIG — Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications).
