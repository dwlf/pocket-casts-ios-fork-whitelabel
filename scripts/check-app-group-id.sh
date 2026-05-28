#!/usr/bin/env bash
# Fault-tolerance guard for the parameterised app-group container.
#
# Every .entitlements file and the Swift source must reference the app-group
# container via $(APP_GROUP_ID) / Info.plist, never the hardcoded literal.
# A stray literal means a target would silently fall back to the upstream
# container under a white-label build, breaking shared state (widgets, Share
# Extension, Siri intents) with no compile-time or runtime error.
#
# This script fails the build if the literal reappears.
set -euo pipefail

cd "$(dirname "$0")/.."

readonly LITERAL='group\.au\.com\.shiftyjelly\.pocketcasts'

# Search entitlements and the Swift sources that resolve the container id.
# rg exits 0 when matches are found, 1 when none.
if matches=$(rg -n "$LITERAL" --glob '*.entitlements' --glob '*.swift'); then
  echo "ERROR: hardcoded app-group literal found — use \$(APP_GROUP_ID) instead:" >&2
  echo "$matches" >&2
  exit 1
fi

echo "app-group guard: no hardcoded literals ✓"
