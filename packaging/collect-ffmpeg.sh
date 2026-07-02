#!/bin/bash
# Copy ffmpeg/ffprobe binaries and their full transitive Homebrew dylib closure
# into build/{bin,lib}. Files land under their load-command leaf names so
# DYLD_FALLBACK_LIBRARY_PATH resolves them on a machine without Homebrew.
set -euo pipefail

B="$(cd "$(dirname "$0")" && pwd)/build"
mkdir -p "$B/lib" "$B/bin"

seed=$(ls /opt/homebrew/opt/ffmpeg/lib/libav*.*.dylib /opt/homebrew/opt/ffmpeg/lib/libsw*.*.dylib 2>/dev/null | grep -E '\.[0-9]+\.dylib$')
queue="/opt/homebrew/bin/ffmpeg /opt/homebrew/bin/ffprobe $seed"
seen=" "

while [ -n "${queue// /}" ]; do
  next=""
  for f in $queue; do
    real=$(readlink -f "$f" 2>/dev/null) || continue
    case "$seen" in *" $real "*) continue ;; esac
    seen="$seen$real "
    leaf=$(basename "$f")
    case "$f" in
      /opt/homebrew/bin/*) cp -f "$real" "$B/bin/$leaf" ;;
      *)                   cp -f "$real" "$B/lib/$leaf" ;;
    esac
    deps=$(otool -L "$real" | tail -n +2 | awk '{print $1}' | grep -E '^/(opt/homebrew|usr/local)' || true)
    for d in $deps; do
      dr=$(readlink -f "$d" 2>/dev/null) || continue
      case "$seen" in *" $dr "*) ;; *) next="$next $d" ;; esac
    done
  done
  queue="$next"
done

# normalize each dylib's filename to its install-name leaf (what dyld searches for)
for f in "$B"/lib/*.dylib; do
  inst_leaf=$(basename "$(otool -D "$f" | tail -1)")
  [ "$(basename "$f")" != "$inst_leaf" ] && mv "$f" "$B/lib/$inst_leaf"
done

echo "libs: $(ls "$B/lib" | wc -l | tr -d ' ')  bins: $(ls "$B/bin" | wc -l | tr -d ' ')"
du -sh "$B/lib" "$B/bin"
