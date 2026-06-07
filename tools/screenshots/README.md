# Store screenshots

Repeatable workflow for capturing App Store and Play Store screenshots from the
simulator/emulator. Captures are native resolution, so they already match (iOS)
or fall within (Android) the required store sizes and need no resizing. The iOS
flow uses `tools/screenshots-ios.sh`; the Android flow uses
`tools/screenshots-android.sh` (see the [Android](#android) section).

## Matrix

Four screenshots, two form factors, two languages = 16 captures.

| Form factor | Device (iOS)            | Required size  |
|-------------|-------------------------|----------------|
| iPhone 6.9" | iPhone 17 Pro Max       | 1320 x 2868    |
| iPad 13"    | iPad Pro 13-inch (M4)   | 2064 x 2752    |

Apple scales these down for smaller devices, so the two largest sets suffice.
The app targets iPhone + iPad (`TARGETED_DEVICE_FAMILY = "1,2"`), so the iPad
set is mandatory, not optional.

The four screenshots (plan -> place -> run -> brief):

1. `01-schedule` — the rotation schedule of the ring exercise
2. `02-map` — the map with stations placed
3. `03-live` — the live coordinator with the countdown running
4. `04-brief` — a generated briefing

## Demo plans

Content language lives in the plan; the app UI follows the device locale. So
each language uses its own plan on a device set to that locale:

- `demo-no.drill` — Norwegian content, capture on a device set to `nb`
- `demo-en.drill` — English content, capture on a device set to `en`

Regenerate them with:

```bash
python3 tools/screenshots/make_demo_drills.py
```

Load a plan into a running app by sharing the `.drill` into the simulator
(drag the file onto the Simulator window, then Files -> Share -> RingDrill),
or import it however you normally open a drill file.

## Capture flow (per form factor x language)

First set the Simulator to **Window > Pixel Accurate** so it renders at native
resolution. Otherwise `simctl` saves a downscaled image (e.g. 1488x2266) that
App Store rejects; `shot` warns when the size is wrong.

Example for iPhone in English:

```bash
open -a Simulator                      # pick "iPhone 17 Pro Max"
tools/screenshots.sh ios lang en           # sets locale + reboots the sim
flutter run                            # then import demo-en.drill, navigate
tools/screenshots.sh ios prep              # clean status bar (09:41, full battery/signal)
tools/screenshots.sh ios shot en 01-schedule
tools/screenshots.sh ios shot en 02-map
tools/screenshots.sh ios appearance dark   # 03-live is captured in dark mode
tools/screenshots.sh ios shot en 03-live
tools/screenshots.sh ios appearance light
tools/screenshots.sh ios shot en 04-brief
```

`03-live` (the live coordinator) is captured in **dark mode** across all
passes; the other three stay in light mode. This signals dark-mode support
and gives the set some variety without making it look inconsistent.

Then repeat with `lang nb` + `demo-no.drill`, and again on the iPad Pro 13-inch
simulator for both languages. Files land under `store/screenshots/ios/`
(alongside the existing `store/screenshots/android/`), and are committed:

```
store/screenshots/ios/iphone/en/01-schedule.png
store/screenshots/ios/iphone/nb/...
store/screenshots/ios/ipad/en/...
store/screenshots/ios/ipad/nb/...
```

`shot` auto-detects iphone vs ipad from the booted device name. The `store/`
tree holds store-listing artifacts (screenshots, Play promo graphics) and lives
outside `assets/` on purpose, so it can never be bundled into the app build.

## Uploading

App Store screenshots are per store localization, not per form factor. To show
Norwegian screenshots to Norwegian users, add a **Norwegian (Bokmål)**
localization in App Store Connect and upload the `nb` set there; upload the `en`
set under **English (U.S.)**. A localization with no screenshots falls back to
the primary localization, so if you skip Norwegian the English set is used
everywhere.

Format rules Apple enforces: PNG or JPEG, RGB, **no alpha channel**, exact pixel
dimensions, 1–10 per device class. `shot` flattens an alpha channel
automatically if ImageMagick is installed and warns otherwise.

## Android

`tools/screenshots-android.sh` mirrors the iOS script for the emulator, using
`adb` instead of `xcrun simctl`. It reuses the same two demo plans and the same
four shots, and writes to `store/screenshots/android/<class>/<lang>/` (where
`<class>` is `phone` or `tablet`, auto-detected from the device's smallest-width
dp).

Google Play has no fixed pixel sizes, but each side must be 320–3840 px and the
longer side may be no more than twice the shorter (a 2:1 cap; 16:9 / 9:16 is the
recommendation). The script captures native resolution and warns only if a shot
falls outside those bounds, so there is nothing to resize.

| Form factor | Device (Android)      | Capture       | Ratio  |
|-------------|-----------------------|---------------|--------|
| Phone       | Pixel XL              | 1440 x 2560   | 16:9   |
| Tablet      | Pixel Tablet          | 1600 x 2560   | 1.6:1  |

Pick a 16:9 phone AVD (e.g. Pixel XL — QHD, no display cutout). Tall 20:9 phones such as the Pixel 8 Pro
render ~2.22:1, which exceeds Play's 2:1 cap and gets rejected; `shot` warns when
that happens.

Use **AOSP** system images (not "Google Play"), so `adb root` works — the `lang`
command sets `persist.sys.locale` and restarts the framework, which root allows.
On a Google Play image, set the language manually in Settings > System >
Languages and skip straight to `prep`.

Example for a phone in English:

```bash
emulator -avd Pixel_XL &                 # boot a 16:9 phone AVD
tools/screenshots.sh android lang en     # sets locale + restarts framework
flutter run                              # then import demo-en.drill, navigate
tools/screenshots.sh android prep        # clean status bar (09:41, full battery/signal)
tools/screenshots.sh android shot en 01-schedule
tools/screenshots.sh android shot en 02-map
tools/screenshots.sh android appearance dark   # 03-live is captured in dark mode
tools/screenshots.sh android shot en 03-live
tools/screenshots.sh android appearance light
tools/screenshots.sh android shot en 04-brief
tools/screenshots.sh android unprep      # restore the real status bar when done
```

Then repeat with `lang nb` + `demo-no.drill`, and again on a tablet AVD for both
languages. Files land under `store/screenshots/android/`:

```
store/screenshots/android/phone/en/01-schedule.png
store/screenshots/android/phone/nb/...
store/screenshots/android/tablet/en/...
store/screenshots/android/tablet/nb/...
```

The flat-named PNGs already in `store/screenshots/android/` are the older manual
captures; the script writes into the structured `phone/` and `tablet/` subtrees
and leaves the old files alone.

`prep` uses SystemUI demo mode for a clean status bar, so run `unprep` when you
are done to restore the real one.
