#!/bin/bash
# Notarize + staple the Stem Lab DMG. One-time setup (Marcello runs this
# himself, the password never touches chat):
#   xcrun notarytool store-credentials notarytool
#     (Apple ID + app-specific password from appleid.apple.com)
# Then: packaging/notarize.sh
set -euo pipefail
DMG="$(cd "$(dirname "$0")" && pwd)/build/StemLab-1.3.1.dmg"
[ -f "$DMG" ] || { echo "no dmg: $DMG (run packaging/build-app.sh first)"; exit 1; }
xcrun notarytool submit "$DMG" --keychain-profile notarytool --wait
xcrun stapler staple "$DMG"
spctl -a -t open -vv "$DMG" || true
echo "✓ notarized: $DMG"
