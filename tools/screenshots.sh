#!/usr/bin/env bash
#
# App Store screenshot helper for iOS (Simulator).
#
# Captures native-resolution PNGs that already match Apple's required sizes,
# so nothing needs resizing:
#   iPhone 6.9" (e.g. iPhone 16 Pro Max): 1320 x 2868
#   iPad 13"    (iPad Pro 13-inch, M4):   2064 x 2752
# Apple scales these down for smaller devices, so the two largest sets suffice.
#
# Commands:
#   tools/screenshots.sh devices            List available simulators.
#   tools/screenshots.sh lang <nb|en>       Set the booted sim's language and
#                                           reboot it (run before `flutter run`).
#   tools/screenshots.sh prep               Clean status bar: 09:41, full battery,
#                                           full signal, no carrier name.
#   tools/screenshots.sh shot <lang> <name> Capture the booted sim to
#                                           store/screenshots/ios/<class>/<lang>/<name>.png
#                                           (<class> = iphone|ipad, auto-detected).
#   tools/screenshots.sh appearance <light|dark>
#                                           Switch the booted sim between light
#                                           and dark mode (e.g. dark for 03-live).
#
# Typical flow per device + language (see tools/screenshots/README.md):
#   open -a Simulator                       # pick "iPhone 16 Pro Max"
#   tools/screenshots.sh lang en
#   flutter run                             # import demo-en.drill, navigate
#   tools/screenshots.sh prep
#   tools/screenshots.sh shot en 01-schedule
#   tools/screenshots.sh shot en 02-map
#   tools/screenshots.sh appearance dark        # 03-live looks best in dark
#   tools/screenshots.sh shot en 03-live
#   tools/screenshots.sh appearance light
#   tools/screenshots.sh shot en 04-brief
#
set -euo pipefail

OUT_ROOT="${OUT_ROOT:-store/screenshots/ios}"

# Remembers the language set by `lang` so `prep`/`appearance` can print
# precise "Next:" hints without being told the language again.
STATE_LANG="${TMPDIR:-/tmp}/ringdrill-screenshots.lang"

die() { echo "error: $*" >&2; exit 1; }

require_xcrun() { command -v xcrun >/dev/null || die "xcrun not found (install Xcode command line tools)"; }

# UDID of the (first) booted simulator, or empty.
booted_udid() {
  xcrun simctl list devices booted -j | python3 -c '
import sys, json
d = json.load(sys.stdin)
for runtime in d["devices"].values():
    for dev in runtime:
        if dev.get("state") == "Booted":
            print(dev["udid"]); sys.exit(0)
'
}

# Name of the (first) booted simulator, or empty.
booted_name() {
  xcrun simctl list devices booted -j | python3 -c '
import sys, json
d = json.load(sys.stdin)
for runtime in d["devices"].values():
    for dev in runtime:
        if dev.get("state") == "Booted":
            print(dev["name"]); sys.exit(0)
'
}

cmd_devices() {
  xcrun simctl list devices available
}

cmd_lang() {
  local lang="${1:-}"
  local locale
  case "$lang" in
    nb) locale="nb_NO" ;;
    en) locale="en_US" ;;
    *) die "usage: lang <nb|en>" ;;
  esac
  local udid; udid="$(booted_udid)"
  [ -n "$udid" ] || die "no booted simulator (open -a Simulator and pick a device first)"
  xcrun simctl spawn "$udid" defaults write -g AppleLanguages -array "$lang"
  xcrun simctl spawn "$udid" defaults write -g AppleLocale -string "$locale"
  echo "set language=$lang locale=$locale; rebooting simulator $udid ..."
  xcrun simctl shutdown "$udid"
  xcrun simctl boot "$udid"
  echo "$lang" > "$STATE_LANG"
  local file; [ "$lang" = nb ] && file="no" || file="en"
  echo "done."
  echo "Next:  flutter run, import tools/screenshots/demo-$file.drill into the app, then:  tools/screenshots.sh prep"
}

cmd_prep() {
  local udid; udid="$(booted_udid)"
  [ -n "$udid" ] || die "no booted simulator"
  xcrun simctl status_bar "$udid" override \
    --time "09:41" \
    --batteryState charged --batteryLevel 100 \
    --wifiBars 3 --cellularBars 4 \
    --operatorName ""
  echo "status bar set on $udid"
  local lang; lang="$(cat "$STATE_LANG" 2>/dev/null || echo '<lang>')"
  echo "Next:  tools/screenshots.sh shot $lang 01-schedule   (light mode)"
}

cmd_appearance() {
  local mode="${1:-}"
  case "$mode" in light|dark) ;; *) die "usage: appearance <light|dark>" ;; esac
  local udid; udid="$(booted_udid)"
  [ -n "$udid" ] || die "no booted simulator"
  xcrun simctl ui "$udid" appearance "$mode"
  echo "appearance set to $mode on $udid"
  local lang; lang="$(cat "$STATE_LANG" 2>/dev/null || echo '<lang>')"
  case "$mode" in
    dark)  echo "Next:  tools/screenshots.sh shot $lang 03-live" ;;
    light) echo "Next:  tools/screenshots.sh shot $lang 04-brief" ;;
  esac
}

cmd_shot() {
  local lang="${1:-}" name="${2:-}"
  [ -n "$lang" ] && [ -n "$name" ] || die "usage: shot <lang> <name>"
  local nm; nm="$(booted_name)"
  [ -n "$nm" ] || die "no booted simulator"
  local class="iphone"
  case "$nm" in *iPad*) class="ipad" ;; esac
  local dir="$OUT_ROOT/$class/$lang"
  mkdir -p "$dir"
  local out="$dir/$name.png"
  xcrun simctl io booted screenshot "$out"

  # App Store rejects screenshots with an alpha channel. simctl rarely adds
  # one, but flatten it if present (ImageMagick) or warn loudly.
  if command -v sips >/dev/null; then
    local has_alpha
    has_alpha="$(sips -g hasAlpha "$out" 2>/dev/null | awk '/hasAlpha/{print $2}')"
    if [ "$has_alpha" = "yes" ]; then
      if command -v magick >/dev/null; then
        magick "$out" -alpha remove -alpha off "$out"; echo "flattened alpha: $out"
      elif command -v convert >/dev/null; then
        convert "$out" -alpha remove -alpha off "$out"; echo "flattened alpha: $out"
      else
        echo "warning: $out has an alpha channel; App Store will reject it." >&2
        echo "         install imagemagick (brew install imagemagick) to auto-flatten." >&2
      fi
    fi
  fi
  local w h expected
  w="$(sips -g pixelWidth "$out" 2>/dev/null | awk '/pixelWidth/{print $2}')"
  h="$(sips -g pixelHeight "$out" 2>/dev/null | awk '/pixelHeight/{print $2}')"
  case "$class" in
    iphone) expected="1320x2868" ;;
    ipad)   expected="2064x2752" ;;
    *)      expected="" ;;
  esac
  echo "saved $out  ($nm, ${w}x${h})"
  if [ -n "$expected" ] && [ "${w}x${h}" != "$expected" ]; then
    echo "WARNING: ${w}x${h} does not match the required $expected for $class." >&2
    echo "         App Store will reject this size. In the Simulator, turn OFF" >&2
    echo "         Debug > 'Optimize Rendering for Window Scale' (or set the window" >&2
    echo "         to 100% scale), then re-run this shot." >&2
  fi

  echo "$lang" > "$STATE_LANG"
  local other; [ "$lang" = nb ] && other="en" || other="nb"
  case "$name" in
    01-schedule) echo "Next:  tools/screenshots.sh shot $lang 02-map" ;;
    02-map)      echo "Next:  tools/screenshots.sh appearance dark   (then: shot $lang 03-live)" ;;
    03-live)     echo "Next:  tools/screenshots.sh appearance light  (then: shot $lang 04-brief)" ;;
    04-brief)    echo "Pass complete ($class/$lang). Next pass: 'tools/screenshots.sh lang $other' for the other language, or boot the iPad Pro 13-inch simulator for the iPad set, then start again from 'lang'." ;;
    *)           echo "Next:  continue with the remaining shots, or 'tools/screenshots.sh lang <nb|en>' for the next pass." ;;
  esac
}

usage() {
  cat <<'EOF'
tools/screenshots.sh — capture App Store screenshots from the iOS Simulator.

Captures native-resolution PNGs that already match Apple's required sizes:
  iPhone 6.9" (iPhone 17 Pro Max): 1320 x 2868
  iPad 13"    (iPad Pro 13-inch):  2064 x 2752
Apple scales these down for smaller devices, so the two largest sets suffice.

COMMANDS
  devices                 List available simulators.
  lang <nb|en>            Set the booted sim's language and reboot it
                          (run before `flutter run`). The choice is remembered
                          so later steps suggest the right next command.
  prep                    Clean status bar: 09:41, full battery, full signal,
                          no carrier name.
  appearance <light|dark> Switch the booted sim between light and dark mode
                          (03-live is captured in dark).
  shot <lang> <name>      Capture the booted sim to
                          store/screenshots/ios/<class>/<lang>/<name>.png
                          (<class> = iphone|ipad, auto-detected). Prints the
                          pixel size and flattens any alpha channel.
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

TYPICAL PASS (iPhone, English; repeat for nb and for the iPad)
  open -a Simulator                     # pick "iPhone 17 Pro Max"
  tools/screenshots.sh lang en
  flutter run                           # import demo-en.drill, navigate
  tools/screenshots.sh prep
  tools/screenshots.sh shot en 01-schedule
  tools/screenshots.sh shot en 02-map
  tools/screenshots.sh appearance dark
  tools/screenshots.sh shot en 03-live
  tools/screenshots.sh appearance light
  tools/screenshots.sh shot en 04-brief

Each command prints the next one to run. The full matrix is
iPhone + iPad x en + nb x the four shots = 16 captures.
EOF
}

sub="${1:-}"; shift || true
case "$sub" in
  ""|help|-h|--help) usage; exit 0 ;;
esac

require_xcrun
case "$sub" in
  devices)    cmd_devices "$@" ;;
  lang)       cmd_lang "$@" ;;
  prep)       cmd_prep "$@" ;;
  appearance) cmd_appearance "$@" ;;
  shot)       cmd_shot "$@" ;;
  *) echo "error: unknown command '$sub'" >&2; echo >&2; usage >&2; exit 1 ;;
esac
