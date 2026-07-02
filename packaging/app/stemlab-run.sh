#!/bin/bash
# Stem Lab launcher — runs inside the Terminal window the droplet opens.
# First run (or after an app update) unpacks the bundled runtime into
# ~/Library/Application Support/StemLab, then hands off to stemlab.sh.

RES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/Library/Application Support/StemLab"
PAYLOAD="$RES/payload.tar.gz"

BOLD=$'\033[1m'; DIM=$'\033[2m'; GREEN=$'\033[32m'; RED=$'\033[31m'; RST=$'\033[0m'

fail() { printf '%s✗ %s%s\n\n(you can close this window)\n' "$RED" "$1" "$RST" >&2; exit 1; }

[ "$(uname -m)" = "arm64" ] || fail "Stem Lab requires an Apple Silicon Mac (M1 or newer)."

BUNDLED_VERSION="$(cat "$RES/VERSION" 2>/dev/null)"
INSTALLED_VERSION="$(cat "$DEST/VERSION" 2>/dev/null)"

if [ ! -x "$DEST/stemlab.sh" ] || [ "$BUNDLED_VERSION" != "$INSTALLED_VERSION" ]; then
  [ -f "$PAYLOAD" ] || fail "payload.tar.gz missing from the app bundle"
  printf '%sStem Lab — first-run setup%s\n' "$BOLD" "$RST"
  printf '  installing runtime (~2.3 GB) to:\n  %s%s%s\n  takes a minute or two, one time only...\n\n' "$DIM" "$DEST" "$RST"
  if [ -n "$DEST" ] && [ -d "$DEST" ]; then rm -rf "$DEST"; fi
  mkdir -p "$DEST" || fail "could not create $DEST"
  tar -xzf "$PAYLOAD" -C "$DEST" || fail "runtime unpack failed"
  printf '%s✓ runtime installed%s\n\n' "$GREEN" "$RST"
fi

if [ -z "$1" ]; then
  printf 'usage: drop an audio file onto the Stem Lab app icon\n'
else
  "$DEST/stemlab.sh" "$1"
fi

STATUS=$?
echo
printf '%s(you can close this window)%s\n' "$DIM" "$RST"
exit $STATUS
