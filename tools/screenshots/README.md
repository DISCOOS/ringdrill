# Store screenshots

Repeatable workflow for capturing App Store (and later Play Store)
screenshots from the simulator/emulator. Captures are native resolution, so
they already match the required store sizes and need no resizing.

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
tools/screenshots.sh lang en           # sets locale + reboots the sim
flutter run                            # then import demo-en.drill, navigate
tools/screenshots.sh prep              # clean status bar (09:41, full battery/signal)
tools/screenshots.sh shot en 01-schedule
tools/screenshots.sh shot en 02-map
tools/screenshots.sh appearance dark   # 03-live is captured in dark mode
tools/screenshots.sh shot en 03-live
tools/screenshots.sh appearance light
tools/screenshots.sh shot en 04-brief
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

The emulator-based Android flow will write to `store/screenshots/android/`
(where the existing Android screenshots already live) and reuse the same two
demo plans.
