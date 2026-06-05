---
status: accepted            # proposed | accepted | deprecated | superseded by ADR-NNNN
date: 2026-06-04            # date of the decision
deciders: ["kengu"]        # who signed off
consulted: []               # who was asked for input
informed: []                # who was kept in the loop
---

# ADR-0033: Adopt a selective platform-adaptive UI layer on iOS, keeping Material as the base

## Context and problem statement

RingDrill is built Material-first: `lib/main.dart` mounts a `MaterialApp.router`, every screen is composed from Material widgets, and `lib/theme.dart` enforces Material conventions across platforms on purpose (for example `centerTitle: false`). iOS is a first-class target (ADR-0021, ADR-0029), so a meaningful share of users run the app on iPhone and iPad.

A review against the iOS Human Interface Guidelines found four places where the Material-first choice stops being cosmetic and costs iOS users real friction or breaks an ingrained gesture:

* Start time is set with `showTimePicker` (the Material clock dial) in `exercise_form_screen.dart`. Setting times is the core interaction, and iOS users expect the wheel picker.
* `drawerEnableOpenDragGesture: true` in `main_screen.dart` binds a left-edge swipe to the drawer, colliding with the iOS back gesture.
* Toggles (`SwitchListTile` in `settings_page.dart`) and alerts (`AlertDialog` / `showDialog`) render in pure Material.
* Haptic feedback exists in only one place (`coordinator_screen.dart`), where iOS users expect it on toggles and on starting or stopping a drill.

The question this ADR settles is how far to go: leave it fully Material, fork a Cupertino UI on iOS, or adapt only the points that cause friction.

## Decision drivers

* iOS is a first-class target and should not feel foreign.
* The documented preference for cross-platform Material consistency should not be discarded wholesale.
* The app targets six platforms, so per-platform branching multiplies what must be built and tested.
* Changes must be low-risk for Android, the primary distribution channel.
* Effort should go where user impact is highest, not toward cosmetic parity.

## Considered options

* **Option A — Stay fully Material.** Change nothing.
* **Option B — Fork a Cupertino UI on iOS.** Branch navigation, scaffolding and components per platform.
* **Option C — Selective platform-adaptive layer.** Keep the Material structure and theme, adapt only the four friction points above.

## Decision outcome

Chosen option: **Option C**, because it removes the concrete iOS friction while preserving the Material-consistency philosophy and adding almost no Android risk.

In force when accepted:

1. **Adaptive primitives.** `Switch` / `SwitchListTile` become their `.adaptive` forms, and `AlertDialog` / `showDialog` become `AlertDialog.adaptive` / `showAdaptiveDialog`. These render Cupertino on iOS and Material elsewhere with no branching at the call site.
2. **Time picker.** A helper presents a `CupertinoDatePicker` (time mode) in the standard sheet chrome on iOS and keeps `showTimePicker` elsewhere. This is the one bespoke adaptive surface.
3. **Drawer gesture.** `drawerEnableOpenDragGesture` is `false` on iOS so the left-edge swipe stays free for the back gesture. The hamburger button still opens the drawer.
4. **Haptics.** `HapticFeedback` on toggle and on drill start/stop, a no-op where the platform has none.

Navigation (bottom `NavigationBar`, `NavigationRail`, drawer, master/detail from ADR-0030), sheet-based context navigation (ADR-0026/0027), `centerTitle: false`, Material icons and the `RefreshIndicator` stay as they are. Platform detection uses `Theme.of(context).platform == TargetPlatform.iOS` so it stays test-overridable and web-safe.

### Consequences

* Good: iOS users get native time entry, toggles, alerts, the expected back-swipe and tactile feedback.
* Good: Android, desktop and web are untouched. `.adaptive` is a no-op there and the time-picker helper falls through to `showTimePicker`.
* Good: The adaptive surface is small and centralised, so it is easy to test.
* Bad: This is the first deliberate per-platform UI branching. It is the sanctioned exception, not an open door.
* Bad: Adapted controls now have two visual treatments, so visual tests must cover both platforms.
* Bad: `centerTitle: false`, Material icons and the Material refresh control stay non-native on iOS. Accepted as cosmetic and out of scope.

## Pros and cons of the options

### Option A — Stay fully Material
* Good: Zero work, one code path.
* Bad: Leaves the friction this review set out to fix.

### Option B — Fork a Cupertino UI on iOS
* Good: Most native result on iOS.
* Bad: Roughly doubles the UI surface across six targets and conflicts with the single-shell architecture (ADR-0030, ADR-0026/0027). Far more risk than the benefit justifies.

### Option C — Selective platform-adaptive layer
* Good: Fixes the high-impact friction with low effort and near-zero Android risk, keeping one layout architecture.
* Bad: Establishes a branching precedent that must be kept narrow.

## Links

* Related ADRs: [ADR-0021](./0021-ios-bundle-identifier-app-ringdrill.md), [ADR-0029](./0029-live-activity-and-foreground-service.md), [ADR-0023](./0023-brief-theme-tokens.md), [ADR-0030](./0030-wide-screen-master-detail-layout.md), [ADR-0026](./0026-sheet-based-context-navigation.md), [ADR-0027](./0027-unified-bottom-sheet-chrome.md)
* Related code: `lib/theme.dart`, `lib/views/main_screen.dart`, `lib/views/exercise_form_screen.dart`, `lib/views/settings_page.dart`, `lib/views/coordinator_screen.dart`
* External references: [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines), Flutter `*.adaptive` constructors and `CupertinoDatePicker`
