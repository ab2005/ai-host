#!/usr/bin/env bash
# Package AI-HOST.app into release assets: a .zip, a plain drag-to-Applications
# .dmg (no upstream background art, which is Buzz-branded), and SHA-256 sums.
#   package-macos.sh <AI-HOST.app> <out-dir> <label>      e.g. label 0.5.28-aihost.1
# Also stamps CFBundleVersion with BUILD_NUMBER when set (the sub-version), then
# signs: with CODESIGN_IDENTITY (Developer ID, hardened runtime) or ad-hoc without it.
# With NOTARY_KEY_PATH/NOTARY_KEY_ID/NOTARY_ISSUER_ID set (and a Developer ID identity), it also
# notarizes and staples the app and the .dmg, so they open without a Gatekeeper warning.
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

# Submit a file to Apple's notary service and fail unless it is Accepted.
notarize() {
  local file="$1" out status
  out="$(xcrun notarytool submit "$file" --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" \
    --issuer "$NOTARY_ISSUER_ID" --wait --output-format json)"
  echo "$out"
  status="$(echo "$out" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))')"
  if [[ "$status" != "Accepted" ]]; then
    echo "::error::Notarization of $(basename "$file") ended with status '$status'" >&2
    local id; id="$(echo "$out" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("id",""))')"
    [[ -n "$id" ]] && xcrun notarytool log "$id" --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" >&2 || true
    exit 1
  fi
}
notarizing=false
[[ -n "${CODESIGN_IDENTITY:-}" && -n "${NOTARY_KEY_PATH:-}" ]] && notarizing=true

if $notarizing; then
  tmpzip="$(mktemp -d "${TMPDIR:-/tmp}/aihost-notary.XXXXXX")/AI-HOST.zip"
  ditto -c -k --keepParent "$app" "$tmpzip"
  notarize "$tmpzip"
  xcrun stapler staple "$app"
fi

base="AI-HOST_${label}_${arch}"
ditto -c -k --sequesterRsrc --keepParent "$app" "$out/$base.zip"

stage="$(mktemp -d "${TMPDIR:-/tmp}/aihost-dmg.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"
hdiutil create -quiet -volname "AI-HOST ${label}" -srcfolder "$stage" -ov -format UDZO "$out/$base.dmg"
if $notarizing; then
  codesign --force --sign "$CODESIGN_IDENTITY" "$out/$base.dmg"
  notarize "$out/$base.dmg"
  xcrun stapler staple "$out/$base.dmg"
fi

( cd "$out" && shasum -a 256 "$base.zip" "$base.dmg" > "$base.sha256" )
echo "Packaged:"; ls -la "$out"
