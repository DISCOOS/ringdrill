#!/usr/bin/env bash
#
# Play Store screenshot helper for Android (Emulator).
#
# Captures native-resolution PNGs from a running emulator. Unlike Apple, Google
# Play has no fixed pixel sizes: phone and tablet screenshots may be 320..3840 px
# on each side with an aspect ratio no wider than 2:1. We capture at native
# resolution and only warn if a shot falls outside those bounds.
#
# Recommended emulators (mirror the iOS iPhone + iPad split):
#   Phone   e.g. "Pixel XL"     1440 x 2560 (16:9)   — within Play's 2:1 cap
#   Tablet  e.g. "Pixel Tablet" 1600 x 2560 (1.6:1)  — within Play's 2:1 cap
# Pixel XL is QHD and has no display cutout, so the status bar stays clean.
# Avoid tall 20:9 phones (e.g. Pixel 8 Pro, ~2.22:1): a full-bleed capture there
# exceeds Play's 2:1 limit and gets rejected. `shot` warns when that happens.
# Use AOSP system images (not "Google Play"), so `adb root` works and the
# locale/SystemUI-demo helpers below can do their job.
#
# Commands:
#   tools/screenshots.sh android devices            List running devices / AVDs.
#   tools/screenshots.sh android lang <nb|en>        Set the emulator's system
#                                                    locale and restart the
#                                                    framework (run before
#                                                    `flutter run`).
#   tools/screenshots.sh android prep               Clean status bar via SystemUI
#                                                    demo mode: 09:41, full
#                                                    battery, full wifi/signal,
#                                                    no notification icons.
#   tools/screenshots.sh android unprep             Exit SystemUI demo mode
#                                                    (restore the real status bar).
#   tools/screenshots.sh android shot <lang> <name> Capture the device to
#                                                    store/screenshots/android/<class>/<lang>/<name>.png
#                                                    (<class> = phone|tablet, auto-detected).
#   tools/screenshots.sh android appearance <light|dark>
#                                                    Switch the device between
#                                                    light and dark mode (e.g.
#                                                    dark for 03-live).
#
# Typical flow per device + language (see tools/screenshots/README.md):
#   emulator -avd Pixel_XL &              # boot a phone AVD
#   tools/screenshots.sh android lang en
#   flutter run                              # import demo-en.drill, navigate
#   tools/screenshots.sh android prep
#   tools/screenshots.sh android shot en 01-schedule
#   tools/screenshots.sh android shot en 02-map
#   tools/screenshots.sh android appearance dark    # 03-live looks best in dark
#   tools/screenshots.sh android shot en 03-live
#   tools/screenshots.sh android appearance light
#   tools/screenshots.sh android shot en 04-brief
#
set -euo pipefail

OUT_ROOT="${OUT_ROOT:-store/screenshots/android}"

# Remembers the language set by `lang` so `prep`/`appearance` can print
# precise "Next:" hints without being told the language again.
STATE_LANG="${TMPDIR:-/tmp}/ringdrill-screenshots-android.lang"

die() { echo "error: $*" >&2; exit 1; }

require_adb() { command -v adb >/dev/null || die "adb not found (install Android platform-tools and put adb on PATH)"; }

# Print the serial of the single running device. Honours $ANDROID_SERIAL if set;
# otherwise dies if zero or more than one device is connected, since `adb` would
# otherwise pick ambiguously and may capture the wrong screen.
device_one() {
  if [ -n "${ANDROID_SERIAL:-}" ]; then echo "$ANDROID_SERIAL"; return; fi
  local serials
  serials="$(adb devices | awk 'NR>1 && $2=="device"{print $1}')"
  local n; n="$(printf '%s\n' "$serials" | grep -c .)"
  if [ "$n" -eq 0 ]; then
    die "no running device (boot an emulator: emulator -avd <name>)"
  elif [ "$n" -gt 1 ]; then
    echo "multiple devices connected:" >&2
    printf '  %s\n' $serials >&2
    die "set ANDROID_SERIAL=<serial> to pick one"
  fi
  printf '%s\n' "$serials"
}

# adb against the chosen device.
adbx() { adb -s "$SERIAL" "$@"; }

# Smallest-width dp of the device, used to classify phone vs tablet (>=600 = tablet).
swdp() {
  local size dens w h px py
  size="$(adbx shell wm size | awk -F': ' '/Override|Physical/{print $2; exit}')"
  dens="$(adbx shell wm density | awk -F': ' '/Override|Physical/{print $2; exit}')"
  w="${size%%x*}"; h="${size##*x}"
  [ -n "$w" ] && [ -n "$h" ] && [ -n "$dens" ] || { echo 0; return; }
  px=$(( w < h ? w : h ))
  echo $(( px * 160 / dens ))
}

cmd_devices() {
  echo "Connected devices:"
  adb devices -l
  if command -v emulator >/dev/null; then
    echo
    echo "Available AVDs:"
    emulator -list-avds
  fi
}

cmd_lang() {
  local lang="${1:-}"
  local locale
  case "$lang" in
    nb) locale="nb-NO" ;;
    en) locale="en-US" ;;
    *) die "usage: lang <nb|en>" ;;
  esac
  SERIAL="$(device_one)" || exit 1
  # Locale changes need a writable system + a framework restart, which means
  # adb root (AOSP images only). Google Play images refuse root.
  if ! adbx root >/dev/null 2>&1 || adbx root 2>&1 | grep -qi "cannot run as root"; then
    echo "warning: 'adb root' is not available on this image." >&2
    echo "         Use an AOSP system image, or change the language manually in" >&2
    echo "         Settings > System > Languages, then continue with 'prep'." >&2
  else
    adbx wait-for-device
    adbx shell "setprop persist.sys.locale $locale; setprop ctl.restart zygote"
    echo "set locale=$locale; restarting framework on $SERIAL ..."
    adbx wait-for-device
    # Wait for the framework to finish coming back up.
    local i
    for i in $(seq 1 60); do
      [ "$(adbx shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break
      sleep 1
    done
    adbx unroot >/dev/null 2>&1 || true
  fi
  echo "$lang" > "$STATE_LANG"
  local file; [ "$lang" = nb ] && file="no" || file="en"
  echo "done."
  echo "Next:  flutter run, import tools/screenshots/demo-$file.drill into the app, then:  tools/screenshots.sh android prep"
}

# Send one SystemUI demo-mode command.
demo() { adbx shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }

cmd_prep() {
  SERIAL="$(device_one)" || exit 1
  adbx shell settings put global sysui_demo_allowed 1 >/dev/null
  demo enter
  demo clock -e hhmm 0941
  demo battery -e level 100 -e plugged false
  demo network -e wifi show -e level 4
  demo network -e mobile show -e datatype none -e level 4
  demo notifications -e visible false
  echo "status bar set via SystemUI demo mode on $SERIAL"
  local lang; lang="$(cat "$STATE_LANG" 2>/dev/null || echo '<lang>')"
  echo "Next:  tools/screenshots.sh android shot $lang 01-schedule   (light mode)"
}

cmd_unprep() {
  SERIAL="$(device_one)" || exit 1
  demo exit
  echo "SystemUI demo mode exited on $SERIAL (real status bar restored)"
}

cmd_appearance() {
  local mode="${1:-}"
  local night
  case "$mode" in light) night="no" ;; dark) night="yes" ;; *) die "usage: appearance <light|dark>" ;; esac
  SERIAL="$(device_one)" || exit 1
  adbx shell cmd uimode night "$night" >/dev/null
  echo "appearance set to $mode on $SERIAL"
  local lang; lang="$(cat "$STATE_LANG" 2>/dev/null || echo '<lang>')"
  case "$mode" in
    dark)  echo "Next:  tools/screenshots.sh android shot $lang 03-live" ;;
    light) echo "Next:  tools/screenshots.sh android shot $lang 04-brief" ;;
  esac
}

cmd_shot() {
  local lang="${1:-}" name="${2:-}"
  [ -n "$lang" ] && [ -n "$name" ] || die "usage: shot <lang> <name>"
  SERIAL="$(device_one)" || exit 1
  local class="phone"
  [ "$(swdp)" -ge 600 ] && class="tablet"
  local dir="$OUT_ROOT/$class/$lang"
  mkdir -p "$dir"
  local out="$dir/$name.png"
  # exec-out streams raw bytes (no shell CRLF translation that corrupts PNGs).
  adbx exec-out screencap -p > "$out"

  # Play Store accepts PNG/JPEG; flatten any alpha channel to be safe, mirroring
  # the iOS flow. screencap is usually opaque already.
  if command -v sips >/dev/null; then
    local has_alpha
    has_alpha="$(sips -g hasAlpha "$out" 2>/dev/null | awk '/hasAlpha/{print $2}')"
    if [ "$has_alpha" = "yes" ]; then
      if command -v magick >/dev/null; then
        magick "$out" -alpha remove -alpha off "$out"; echo "flattened alpha: $out"
      elif command -v convert >/dev/null; then
        convert "$out" -alpha remove -alpha off "$out"; echo "flattened alpha: $out"
      else
        echo "warning: $out has an alpha channel; flatten it before upload." >&2
        echo "         install imagemagick (brew install imagemagick) to auto-flatten." >&2
      fi
    fi
    local w h
    w="$(sips -g pixelWidth "$out" 2>/dev/null | awk '/pixelWidth/{print $2}')"
    h="$(sips -g pixelHeight "$out" 2>/dev/null | awk '/pixelHeight/{print $2}')"
    echo "saved $out  ($class, ${w}x${h})"
    # Google Play: each side 320..3840, aspect ratio no wider than 2:1.
    if [ -n "$w" ] && [ -n "$h" ]; then
      local lo hi long short
      lo=$(( w < h ? w : h )); hi=$(( w > h ? w : h ))
      long="$hi"; short="$lo"
      if [ "$lo" -lt 320 ] || [ "$hi" -gt 3840 ]; then
        echo "WARNING: ${w}x${h} is outside Play's 320..3840 px per side." >&2
      elif [ $(( long * 10 )) -gt $(( short * 20 )) ]; then
        echo "WARNING: ${w}x${h} aspect ratio is wider than 2:1; Play will reject it." >&2
      fi
    fi
  else
    echo "saved $out  ($class)"
  fi

  echo "$lang" > "$STATE_LANG"
  local other; [ "$lang" = nb ] && other="en" || other="nb"
  case "$name" in
    01-schedule) echo "Next:  tools/screenshots.sh android shot $lang 02-map" ;;
    02-map)      echo "Next:  tools/screenshots.sh android appearance dark   (then: shot $lang 03-live)" ;;
    03-live)     echo "Next:  tools/screenshots.sh android appearance light  (then: shot $lang 04-brief)" ;;
    04-brief)    echo "Pass complete ($class/$lang). Next pass: 'tools/screenshots.sh android lang $other' for the other language, or boot the tablet AVD for the tablet set, then start again from 'lang'." ;;
    *)           echo "Next:  continue with the remaining shots, or 'tools/screenshots.sh android lang <nb|en>' for the next pass." ;;
  esac
}

usage() {
  cat <<'EOF'
tools/screenshots.sh android — capture Play Store screenshots from the Android emulator.

Google Play has no fixed pixel sizes: phone and tablet screenshots may be
320..3840 px per side with an aspect ratio no wider than 2:1. We capture at
native resolution and warn only if a shot falls outside those bounds.

COMMANDS
  devices                 List connected devices and available AVDs.
  lang <nb|en>            Set the system locale and restart the framework
                          (run before `flutter run`). Needs an AOSP image so
                          `adb root` works. The choice is remembered so later
                          steps suggest the right next command.
  prep                    Clean status bar via SystemUI demo mode: 09:41, full
                          battery, full wifi/signal, no notification icons.
  unprep                  Exit demo mode (restore the real status bar).
  appearance <light|dark> Switch the device between light and dark mode
                          (03-live is captured in dark).
  shot <lang> <name>      Capture the device to
                          store/screenshots/android/<class>/<lang>/<name>.png
                          (<class> = phone|tablet, auto-detected). Prints the
                          pixel size, flattens any alpha channel, and warns if
                          the size is outside Play's bounds.
  help, -h, --help        Show this help.

THE FOUR SHOTS (plan -> place -> run -> brief)
  01-schedule   rotation schedule of a ring exercise   (light)
  02-map        map with stations placed               (light)
  03-live       live coordinator, countdown running    (dark)
  04-brief      a generated briefing                   (light)

DEMO PLANS (content language; the UI follows the device locale)
  tools/screenshots/demo-en.drill   capture on a device set to `en`
  tools/screenshots/demo-no.drill   capture on a device set to `nb`
  Regenerate with: python3 tools/screenshots/make_demo_drills.py

TYPICAL PASS (phone, English; repeat for nb and for the tablet AVD)
  emulator -avd Pixel_XL &
  tools/screenshots.sh android lang en
  flutter run                           # import demo-en.drill, navigate
  tools/screenshots.sh android prep
  tools/screenshots.sh android shot en 01-schedule
  tools/screenshots.sh android shot en 02-map
  tools/screenshots.sh android appearance dark
  tools/screenshots.sh android shot en 03-live
  tools/screenshots.sh android appearance light
  tools/screenshots.sh android shot en 04-brief

Each command prints the next one to run. The full matrix is
phone + tablet x en + nb x the four shots = 16 captures.
EOF
}

sub="${1:-}"; shift || true
case "$sub" in
  ""|help|-h|--help) usage; exit 0 ;;
esac

require_adb
case "$sub" in
  devices)    cmd_devices "$@" ;;
  lang)       cmd_lang "$@" ;;
  prep)       cmd_prep "$@" ;;
  unprep)     cmd_unprep "$@" ;;
  appearance) cmd_appearance "$@" ;;
  shot)       cmd_shot "$@" ;;
  *) echo "error: unknown command '$sub'" >&2; echo >&2; usage >&2; exit 1 ;;
esac
