#!/bin/bash
#
# generate_whitelabel_config.sh
#
# Generates podcasts/Whitelabel/WhitelabelConfig.swift from
# WhitelabelConfig.tpl and a flat key/value JSON file. Mirrors the
# existing ApiCredentials.tpl -> LocalApiCredentials.swift pipeline.
#
# Invoked as an Xcode build phase script before "Compile Sources" on
# every target that imports WhitelabelConfig. Environment expected:
#
#   SRCROOT                  - Xcode project root (set by xcodebuild)
#   WHITELABEL_CONFIG_JSON   - path to whitelabel JSON file (from active
#                              xcconfig). Falls back to the default
#                              empty-values JSON if unset.
#
# Exits non-zero on any failure to fail the build fast.

set -euo pipefail

if [[ -z "${SRCROOT:-}" ]]; then
    # Allow running standalone from repo root for testing.
    SRCROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi

# WhitelabelConfig lives in the PocketCastsUtils Swift Package so every
# target that imports PocketCastsUtils (main app + 4 extensions + TV app +
# PocketCastsServer module) gets access. The .tpl is committed source of
# truth; the generated .swift is gitignored and recreated per build.
TEMPLATE="$SRCROOT/Modules/Sources/PocketCastsUtils/General/WhitelabelConfig.tpl"
OUTPUT="$SRCROOT/Modules/Sources/PocketCastsUtils/General/WhitelabelConfig.swift"
DEFAULT_JSON="$SRCROOT/config/whitelabel/whitelabel.json"

JSON_PATH="${WHITELABEL_CONFIG_JSON:-$DEFAULT_JSON}"

if [[ ! -f "$TEMPLATE" ]]; then
    echo "error: WhitelabelConfig template not found at $TEMPLATE" >&2
    exit 1
fi

if [[ ! -f "$JSON_PATH" ]]; then
    echo "error: WhitelabelConfig JSON not found at $JSON_PATH" >&2
    echo "  (WHITELABEL_CONFIG_JSON='${WHITELABEL_CONFIG_JSON:-<unset>}')" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"

ruby "$SRCROOT/podcasts/Credentials/replace_secrets.rb" \
    -i "$TEMPLATE" \
    -s "$JSON_PATH" \
    > "$OUTPUT"

echo "Generated $OUTPUT from $JSON_PATH"
