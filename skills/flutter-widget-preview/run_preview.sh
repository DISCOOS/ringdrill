#!/usr/bin/env bash
# Headless widget preview runner. See skills/flutter-widget-preview/SKILL.md.
#
# Renders the preview test at test/preview/_preview.dart to PNGs under
# test/preview/output/ — no browser, no device — then lists them.
#
# Usage:
#   skills/flutter-widget-preview/run_preview.sh
#   skills/flutter-widget-preview/run_preview.sh path/to/other_preview.dart
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

TEST_FILE="${1:-test/preview/_preview.dart}"

if [[ ! -f "$TEST_FILE" ]]; then
  echo "No preview test at '$TEST_FILE'." >&2
  echo "Copy the template first:" >&2
  echo "  mkdir -p test/preview && cp skills/flutter-widget-preview/preview.template.dart test/preview/_preview.dart" >&2
  exit 1
fi

echo "Rendering $TEST_FILE ..."
flutter test "$TEST_FILE" --update-goldens

echo
echo "PNGs written to test/preview/output/:"
ls -1 test/preview/output/*.png 2>/dev/null || echo "  (none — check the test defined a renderPreview call)"
