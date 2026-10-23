#!/usr/bin/env bash
# Package AI-HOST.app into release assets: a .zip, a plain drag-to-Applications
# .dmg (no upstream background art, which is Buzz-branded), and SHA-256 sums.
#   package-macos.sh <AI-HOST.app> <out-dir> <label>      e.g. label 0.5.28-aihost.1
# Also stamps CFBundleVersion with BUILD_NUMBER when set (the sub-version), then
# ad-hoc signs: the app is unsigned for distribution until a Developer ID exists.
set -euo pipefail

app="${1:?app path}"; out="${2:?out dir}"; label="${3:?label}"
arch="${ARCH_LABEL:-aarch64}"
mkdir -p "$out"

if [[ -n "${BUILD_NUMBER:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$app/Contents/Info.plist"
fi
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --sign "$CODESIGN_IDENTITY" "$app"
else
  codesign --force --deep --sign - "$app"
fi

base="AI-HOST_${label}_${arch}"
ditto -c -k --sequesterRsrc --keepParent "$app" "$out/$base.zip"

stage="$(mktemp -d "${TMPDIR:-/tmp}/aihost-dmg.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"
hdiutil create -quiet -volname "AI-HOST ${label}" -srcfolder "$stage" -ov -format UDZO "$out/$base.dmg"

( cd "$out" && shasum -a 256 "$base.zip" "$base.dmg" > "$base.sha256" )
echo "Packaged:"; ls -la "$out"
