#!/usr/bin/env bash
# Live network-quiet check for the white-label build (Stage 4 step 37).
#
# Captures DNS queries on the active interface while the freshly-built
# white-label app launches and sits idle, then greps for any lookups to
# Pocket Casts / Automattic hosts. The iOS simulator shares the host
# network stack, so its DNS appears on the host interface.
#
# Requires sudo (tcpdump). Run on an otherwise-quiet machine — the filter
# matches any process resolving these domains, not just the simulator.
set -euo pipefail

DEV="${1:-F0EEE50D-0EE6-4E1A-9BBC-A05A8F7E6D5C}"
BUNDLE="com.example.whitelabel"
APP="$HOME/Library/Developer/Xcode/DerivedData/podcasts-fzfvphhenmysjeceqjyjwzxmgwyr/Build/Products/WhitelabelDebug-iphonesimulator/podcasts.app"
PCAP="${TMPDIR:-/tmp}/wl-netcheck.pcap"
LEAKS='pocketcasts|automattic|wordpress|wp\.com|tracks|pca\.st|a8c|sentry|shiftyjelly'

IFACE="$(route get default 2>/dev/null | awk '/interface:/{print $2}')"
echo "Capturing DNS on ${IFACE} for ${BUNDLE} ..."

# shellcheck disable=SC2024  # $TMPDIR is user-writable; redirect-as-user is intended, and we need tcpdump's own PID to stop the capture
sudo tcpdump -i "$IFACE" -n -l -s 0 'udp port 53' >"$PCAP" 2>/dev/null &
TPID=$!
sleep 2

xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$DEV" "$APP"
xcrun simctl launch "$DEV" "$BUNDLE" >/dev/null
echo "Launched; observing idle for 45s ..."
sleep 45
xcrun simctl terminate "$DEV" "$BUNDLE" 2>/dev/null || true

sudo kill "$TPID" 2>/dev/null || true
sleep 1

echo "=== DNS lookups to Pocket Casts / Automattic hosts (want NONE) ==="
if grep -iE "$LEAKS" "$PCAP"; then
  echo "LEAK: app resolved an upstream host — investigate above."
  exit 1
fi
echo "NONE — white-label build is network-quiet at launch/idle ✓"
