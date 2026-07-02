#!/bin/bash
# Build Stem Lab.app (native SwiftUI) + DMG from the staged payload tree.
# Prereqs (staged by collect-ffmpeg.sh + manual steps, see README):
#   build/python   - standalone CPython with site-packages symlinked to ../.venv
#   build/lib      - ffmpeg dylib closure
#   build/bin      - ffmpeg + ffprobe
#   build/payload  - symlink tree (python, lib, bin, models/*)
# If build/payload.tar.gz already exists it is reused instead of re-tarred.
set -euo pipefail

VERSION="1.3.0"
ENGINE_VERSION="1.3.0"   # bump only when the payload contents change
PKG="$(cd "$(dirname "$0")" && pwd)"
B="$PKG/build"
APP="$B/Stem Lab.app"

step() { printf '\n== %s ==\n' "$1"; }

if [ ! -f "$B/payload.tar.gz" ]; then
  step "payload.tar.gz (dereferencing symlinks; this takes a few minutes)"
  chmod +x "$PKG/payload/stemlab.sh"
  ln -sf "$PKG/payload/stemlab.sh" "$B/payload/stemlab.sh"
  printf '%s\n' "$ENGINE_VERSION" > "$B/payload/VERSION"
  tar -czLf "$B/payload.tar.gz" \
    --exclude 'site-packages.pbs-orig' \
    --exclude '.DS_Store' \
    --exclude 'diffq' \
    --exclude 'diffq-*' \
    -C "$B/payload" .
  du -sh "$B/payload.tar.gz"
else
  step "payload.tar.gz exists — reusing"
fi

step "swift app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun -sdk macosx swiftc -O -swift-version 5 -parse-as-library -target arm64-apple-macos13.0 \
  -o "$APP/Contents/MacOS/StemLab" "$PKG/app/StemLabApp.swift"
printf 'APPL????' > "$APP/Contents/PkgInfo"
printf '%s\n' "$ENGINE_VERSION" > "$APP/Contents/Resources/VERSION"
cp "$PKG/app/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$B/payload.tar.gz" "$APP/Contents/Resources/payload.tar.gz"
cp "$PKG/../LICENSE" "$PKG/../THIRD_PARTY.md" "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>          <string>StemLab</string>
	<key>CFBundleIdentifier</key>          <string>com.stemlab.app</string>
	<key>CFBundleName</key>                <string>Stem Lab</string>
	<key>CFBundleDisplayName</key>         <string>Stem Lab</string>
	<key>CFBundlePackageType</key>         <string>APPL</string>
	<key>CFBundleShortVersionString</key>  <string>$VERSION</string>
	<key>CFBundleVersion</key>             <string>$VERSION</string>
	<key>LSMinimumSystemVersion</key>      <string>13.0</string>
	<key>LSApplicationCategoryType</key>   <string>public.app-category.music</string>
	<key>NSHighResolutionCapable</key>     <true/>
	<key>CFBundleIconFile</key>            <string>AppIcon</string>
	<key>CFBundleDocumentTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>      <string>Viewer</string>
			<key>LSHandlerRank</key>         <string>Alternate</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>public.audio</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
EOF

step "codesign (ad-hoc)"
codesign -s - --force --deep "$APP"

step "dmg"
rm -rf "$B/dmg"
mkdir -p "$B/dmg"
mv "$APP" "$B/dmg/"
ln -s /Applications "$B/dmg/Applications"
cp "$PKG/app/AppIcon.icns" "$B/dmg/.VolumeIcon.icns"
cp "$PKG/../LICENSE" "$PKG/../THIRD_PARTY.md" "$B/dmg/"
cat > "$B/dmg/READ ME FIRST.txt" <<'EOF'
Stem Lab — install
==================
1. Drag "Stem Lab" onto the "Applications" folder icon.
2. Open Applications, double-click Stem Lab once.
   macOS will block it ("Apple could not verify..."). That's expected:
   go to  System Settings > Privacy & Security,  scroll down, and click
   "Open Anyway" next to Stem Lab. You only do this once.
3. First use installs the audio engine (takes a minute or two).
4. Drop any song file (wav / mp3 / flac / m4a) onto the window or the
   app icon. Progress bars show both models working (~5 min for a
   4-min song); hit Stop to cancel. When it finishes, "Open Stems
   Folder" shows vocals.wav, drums.wav, bass.wav, other.wav sitting
   in a "stems" folder next to your song.

Requires an Apple Silicon Mac (M1 or newer). Runs fully offline —
your music never leaves your computer.
EOF
# build RW first so the volume root can take the custom-icon Finder flag, then compress
rm -f "$B/rw-tmp.dmg"
hdiutil create -volname "Stem Lab" -srcfolder "$B/dmg" -ov -format UDRW "$B/rw-tmp.dmg"
hdiutil attach "$B/rw-tmp.dmg" -nobrowse -quiet -mountpoint "$B/rw-mnt"
xattr -wx com.apple.FinderInfo 0000000000000000040000000000000000000000000000000000000000000000 "$B/rw-mnt"
hdiutil detach "$B/rw-mnt" -quiet
hdiutil convert "$B/rw-tmp.dmg" -format UDZO -ov -o "$B/StemLab-$VERSION.dmg"
rm -f "$B/rw-tmp.dmg"
du -sh "$B/StemLab-$VERSION.dmg"
printf '\n✓ built %s\n' "$B/StemLab-$VERSION.dmg"
