# Follow-up prompt — iOS adaptation round 2 (keyboard dismissal + status bar)

Continues the work under [ADR-0033](../adrs/0033-platform-adaptive-ui-on-ios.md).
No new ADR is required: both steps execute the adaptive principle ADR-0033
already accepted and add no third-party dependency. If you find you need a
package for either step, stop and flag it instead of adding it, since that
would need its own ADR per AGENTS.md rule 11.

Use `Theme.of(context).platform == TargetPlatform.iOS` for any branching, never
`dart:io` `Platform`. Each step is one commit. Before every commit run
`flutter analyze` and `flutter test`, then confirm `git status` is clean before
moving on. No new user-visible strings are expected. If you add one, localize
it in both `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`.

## Step 1 — Dismiss the keyboard on forms

iOS numeric and phone keyboards have no return key, so users cannot dismiss
them. Add a tap-outside-to-dismiss wrapper. This pattern is safe on all
platforms (taps on fields and buttons are still consumed by those widgets, only
taps on empty space unfocus), so apply it everywhere rather than branching.

1. Add a small reusable widget `DismissKeyboard` in
   `lib/views/widgets/dismiss_keyboard.dart`: a `GestureDetector` with
   `behavior: HitTestBehavior.opaque` and `onTap: () =>
   FocusScope.of(context).unfocus()` wrapping its `child`.
2. Wrap the body of each form that has text input with `DismissKeyboard`:
   - `lib/views/exercise_form_screen.dart` (six numeric fields)
   - `lib/views/team_form_screen.dart`
   - `lib/views/roleplay_form_screen.dart`
   - `lib/views/actor_form_screen.dart` (phone)
   - `lib/views/station_form_screen.dart`
   - `lib/views/program_form_screen.dart`

Add a widget test in `test/views/widgets/dismiss_keyboard_test.dart`: focus a
field, tap empty space, assert the field loses focus.

Files: the new widget, the new test, the six form screens.
Commit: `feat(ios-adaptive): dismiss keyboard on tap outside on forms`

## Step 2 — Status bar contrast on chrome-free surfaces

Surfaces without an `AppBar` do not set a status bar style, so on iOS the
status bar icons can be invisible against the content. Screens that have an
`AppBar` already get their style from it, so leave those alone.

Wrap the chrome-free surfaces in
`AnnotatedRegion<SystemUiOverlayStyle>` with a style derived from the active
theme brightness: `SystemUiOverlayStyle.light` (light icons) over the dark
brand surfaces, `SystemUiOverlayStyle.dark` over light surfaces. Pick the
brightness from `Theme.of(context).brightness`.

Apply to:
- The Map tab body in `lib/views/main_screen.dart` (the `isMapTab` branch that
  renders without an AppBar)
- The brief surface in `lib/views/brief_screen.dart` if it presents without a
  standard AppBar

Files: `lib/views/main_screen.dart`, `lib/views/brief_screen.dart`.
Commit: `fix(ios-adaptive): set status bar style on chrome-free surfaces`

## Out of scope

Dynamic Type / fixed-height audit, the Material `RefreshIndicator`, Material
icons, `centerTitle: false`, and all native iOS config (`Info.plist`,
`LaunchScreen`, app icon, splash). Those are separate tracks.

## Final verification

Run `flutter analyze` and `flutter test` on the final state. Confirm
`git status` is clean and that each step is its own commit.
