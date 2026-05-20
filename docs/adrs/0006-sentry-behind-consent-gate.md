---
status: accepted
date: 2026-05-20
deciders: ["@kengu"]
consulted: []
informed: []
---

# 0006. Sentry telemetry is gated behind opt-in analytics consent

## Context and problem statement

RingDrill uses [Sentry](https://sentry.io) for crash and error reporting. Sentry collects stack traces, breadcrumbs and device metadata, which is personal data under GDPR. Many of our users are operational and emergency-services personnel, and DISCOOS values privacy by default.

We need a clear, single rule for when telemetry is allowed to leave the device, and a single place in the code where that rule is enforced.

## Decision drivers

* Privacy by default. No telemetry without informed user consent.
* GDPR alignment, particularly for EU users.
* One enforcement point, not telemetry sprinkled across the code base behind ad-hoc flags.
* Cheap to opt in for users who want to help.

## Considered options

* Opt-in (default off, user enables in settings).
* Opt-out (default on, user disables in settings).
* No telemetry at all.

## Decision outcome

Chosen option: **opt-in, gated by a single consent flag**.

Concretely:

* The flag is `AppConfig.keyAnalyticsConsent` in `shared_preferences`. Default value on first launch is `false`.
* `SentryFlutter.init` is called only when the flag is `true`. The decision is made in `lib/main.dart` before `runApp`, see the `if (analyticsConsent)` branch.
* Anywhere else in the code, Sentry calls must be guarded by `if (Sentry.isEnabled)` to avoid initializing Sentry implicitly or sending events when the user opted out.
* Drill content and PII must never be sent to Sentry. Errors and stack traces only.

### Consequences

* Good: Privacy-preserving default. Users who do nothing send nothing.
* Good: One choke point (`lib/main.dart`) makes the rule auditable.
* Good: Easy to extend to other telemetry (analytics, performance) by gating on the same flag.
* Bad: Lower telemetry volume than an opt-out default. Acceptable trade-off.
* Bad: Easy to violate by accident. The rule is repeated in [`AGENTS.md`](../../AGENTS.md) and in this ADR to maximize discoverability.

## Pros and cons of the options

### Opt-in (chosen)
* Good: Privacy by default, GDPR-friendly.
* Good: Builds user trust in an operational-use context.
* Bad: Lower telemetry signal for crash diagnostics.

### Opt-out
* Good: Higher telemetry signal.
* Bad: Sends personal data without prior consent. Difficult to justify under GDPR without a strong legal basis we do not have.

### No telemetry
* Good: Strongest privacy posture.
* Bad: Losing crash reporting is unacceptable for a field-deployed app where users will not file structured bug reports.

## Links

* Related code: `lib/main.dart` (consent gate), `lib/utils/app_config.dart` (`keyAnalyticsConsent`), `lib/utils/sentry_config.dart`, `lib/views/settings_page.dart` (user toggle).
* Operating rule (in [`AGENTS.md`](../../AGENTS.md)): "Respect the analytics consent gate."
