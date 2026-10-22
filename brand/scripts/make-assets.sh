#!/usr/bin/env bash
# Regenerate AI-HOST raster assets from the SVG sources. macOS only (headless
# Chrome, sips, iconutil). Run from anywhere:  brand/scripts/make-assets.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUT="$ROOT/brand/desktop/icons"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT" "$ROOT/brand/assets/ios"

ARCH='<path d="M312 724V512a200 200 0 0 1 400 0v212" fill="none" stroke="#f4f2eb" stroke-width="56" stroke-linecap="round"/><circle cx="512" cy="606" r="58" fill="#b54d32"/>'

render() { # <html-file> <out-png> <w> <h> [transparent]
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    ${5:+--default-background-color=00000000} \
    --window-size="$3,$4" --screenshot="$2" "file://$1" >/dev/null 2>&1
}
page() { # <w> <h> <body>
  printf '<!doctype html><meta charset=utf-8><style>html,body{margin:0;background:transparent}svg{display:block}</style>%s' "$3"
}

# macOS: rounded square inset on a transparent 1024 canvas (Big Sur style).
page 1024 1024 "<svg width=1024 height=1024 viewBox='0 0 1024 1024'><rect x=100 y=100 width=824 height=824 rx=185 fill='#303d34'/><g transform='translate(512 512) scale(.805) translate(-512 -512)'>$ARCH</g></svg>" >"$TMP/mac.html"
render "$TMP/mac.html" "$TMP/mac-1024.png" 1024 1024 transparent

# iOS: full-bleed opaque square; iOS applies its own corner mask.
page 1024 1024 "<svg width=1024 height=1024 viewBox='0 0 1024 1024'><rect width=1024 height=1024 fill='#303d34'/>$ARCH</svg>" >"$TMP/ios.html"
render "$TMP/ios.html" "$ROOT/brand/assets/ios/AppIcon-1024.png" 1024 1024

# Start-page wordmark (replaces desktop/public/landing/buzz-wordmark.png).
page 1200 300 "<div style=\"font:400 230px/300px Arial,Helvetica,sans-serif;letter-spacing:-.015em;color:#242722;text-align:center\">AI-HOST</div>" >"$TMP/word.html"
render "$TMP/word.html" "$ROOT/desktop/public/landing/buzz-wordmark.png" 1200 300 transparent

# iOS app icon: every size listed in the existing AppIcon.appiconset, in place.
IOS_SET="$ROOT/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset"
python3 -I - "$IOS_SET" "$ROOT/brand/assets/ios/AppIcon-1024.png" <<'PY'
import json, subprocess, sys, os
d, src = sys.argv[1], sys.argv[2]
for im in json.load(open(os.path.join(d, "Contents.json")))["images"]:
    px = round(float(im["size"].split("x")[0]) * int(im["scale"][0]))
    subprocess.run(["sips", "-z", str(px), str(px), src, "--out", os.path.join(d, im["filename"])],
                   check=True, stdout=subprocess.DEVNULL)
PY

# iOS launch image: mark on transparent, shown over the storyboard's forest background.
LAUNCH="$ROOT/mobile/ios/Runner/Assets.xcassets/LaunchImage.imageset"
page 504 504 "<svg width=504 height=504 viewBox='0 0 1024 1024'><g transform='translate(512 512) scale(.8) translate(-512 -512)'>$ARCH</g></svg>" >"$TMP/launch.html"
render "$TMP/launch.html" "$LAUNCH/LaunchImage@3x.png" 504 504 transparent
sips -z 336 336 "$LAUNCH/LaunchImage@3x.png" --out "$LAUNCH/LaunchImage@2x.png" >/dev/null
sips -z 168 168 "$LAUNCH/LaunchImage@3x.png" --out "$LAUNCH/LaunchImage.png" >/dev/null

# Tauri icon set.
rs() { sips -z "$1" "$1" "$TMP/mac-1024.png" --out "$2" >/dev/null; }
rs 32 "$OUT/32x32.png"; rs 128 "$OUT/128x128.png"; rs 256 "$OUT/128x128@2x.png"
rs 512 "$OUT/icon.png"; rs 64 "$OUT/64x64.png"

SET="$TMP/icon.iconset"; mkdir -p "$SET"
for s in 16 32 128 256 512; do rs "$s" "$SET/icon_${s}x${s}.png"; rs "$((s*2))" "$SET/icon_${s}x${s}@2x.png"; done
iconutil -c icns "$SET" -o "$OUT/icon.icns"

# Windows .ico (PNG-compressed entries) so the Tauri icon list stays complete.
for s in 16 32 48 64 128 256; do rs "$s" "$TMP/ico-$s.png"; done
python3 -I - "$TMP" "$OUT/icon.ico" <<'PY'
import struct, sys
tmp, out = sys.argv[1], sys.argv[2]
sizes = [16, 32, 48, 64, 128, 256]
imgs = [open(f"{tmp}/ico-{s}.png", "rb").read() for s in sizes]
head = struct.pack("<HHH", 0, 1, len(sizes))
offset = 6 + 16 * len(sizes)
entries = b""
for s, d in zip(sizes, imgs):
    entries += struct.pack("<BBBBHHII", s % 256, s % 256, 0, 0, 1, 32, len(d), offset)
    offset += len(d)
open(out, "wb").write(head + entries + b"".join(imgs))
PY
echo "Wrote: $OUT, iOS AppIcon + LaunchImage sets, desktop/public/landing/buzz-wordmark.png"
