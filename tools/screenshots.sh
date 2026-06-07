#!/usr/bin/env bash
#
# Store screenshot helper — platform dispatcher.
#
# Thin wrapper that forwards to the platform-specific script:
#   tools/screenshots-ios.sh      (iOS Simulator, via xcrun simctl)
#   tools/screenshots-android.sh  (Android Emulator, via adb)
#
# Usage:
#   tools/screenshots.sh <ios|android> <command> [args...]
#
# Examples:
#   tools/screenshots.sh ios lang en
#   tools/screenshots.sh ios shot en 01-schedule
#   tools/screenshots.sh android prep
#   tools/screenshots.sh android shot nb 03-live
#
# Each platform script can still be run directly; this wrapper just picks one
# by its first argument. Run `tools/screenshots.sh <ios|android> help` for the
# platform-specific commands.
#
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
tools/screenshots.sh — capture store screenshots (iOS + Android dispatcher).

USAGE
  tools/screenshots.sh <ios|android> <command> [args...]

PLATFORMS
  ios       Forwards to tools/screenshots-ios.sh      (iOS Simulator, xcrun simctl).
  android   Forwards to tools/screenshots-android.sh  (Android Emulator, adb).

Both platforms share the same commands and the same four shots:
  devices | lang <nb|en> | prep | appearance <light|dark> | shot <lang> <name>
(Android adds `unprep` to leave SystemUI demo mode.)

EXAMPLES
  tools/screenshots.sh ios lang en
  tools/screenshots.sh ios shot en 01-schedule
  tools/screenshots.sh android prep
  tools/screenshots.sh android shot nb 03-live

Run `tools/screenshots.sh <ios|android> help` for the full per-platform help,
or invoke the platform script directly (tools/screenshots-ios.sh,
tools/screenshots-android.sh). See tools/screenshots/README.md for the workflow.
EOF
}

platform="${1:-}"; shift || true
case "$platform" in
  ios)     exec "$here/screenshots-ios.sh" "$@" ;;
  android) exec "$here/screenshots-android.sh" "$@" ;;
  ""|help|-h|--help) usage; exit 0 ;;
  *) echo "error: unknown platform '$platform' (expected ios or android)" >&2; echo >&2; usage >&2; exit 1 ;;
esac
