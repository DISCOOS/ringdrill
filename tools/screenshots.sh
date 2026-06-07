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
#
# Typical flow per device + language (see tools/screenshots/README.md):
#   open -a Simulator                       # pick "iPhone 16 Pro Max"
#   tools/screenshots.sh lang en
#   flutter run                             # import demo-en.drill, navigate
#   tools/screenshots.sh prep
#   tools/screenshots.sh shot en 01-schedule
#   tools/screenshots.sh shot en 02-map
#   tools/screenshots.sh shot en 03-live
#   tools/screenshots.sh shot en 04-brief
#
set -euo pipefail

OUT_ROOT="${OUT_ROOT:-store/screenshots/ios}"

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
  echo "done. Now run 'flutter run' and import the matching demo plan."
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
  echo "saved $out  ($nm, $(sips -g pixelWidth -g pixelHeight "$out" 2>/dev/null | awk '/pixel/{printf "%s ", $2}'))"
}

require_xcrun
sub="${1:-}"; shift || true
case "$sub" in
  devices) cmd_devices "$@" ;;
  lang)    cmd_lang "$@" ;;
  prep)    cmd_prep "$@" ;;
  shot)    cmd_shot "$@" ;;
  *) die "usage: $0 {devices|lang <nb|en>|prep|shot <lang> <name>}" ;;
esac
