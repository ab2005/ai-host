#!/usr/bin/env bash
# CI only: installs the Apple Distribution certificate and the two App Store
# provisioning profiles on a macOS runner, switches the Runner and
# NotificationService targets to manual signing in the checked-out project
# (the change is never committed), and writes ExportOptions.plist.
#
# Reads (all from repository secrets, passed as env by the workflow):
#   IOS_DIST_CERT_P12_BASE64, IOS_DIST_CERT_PASSWORD,
#   IOS_PROFILE_APP_BASE64, IOS_PROFILE_NSE_BASE64
# Writes: $RUNNER_TEMP/ExportOptions.plist, and exports KEYCHAIN_PATH via GITHUB_ENV.
set -euo pipefail

: "${RUNNER_TEMP:?}" "${IOS_DIST_CERT_P12_BASE64:?}" "${IOS_DIST_CERT_PASSWORD:?}"
: "${IOS_PROFILE_APP_BASE64:?}" "${IOS_PROFILE_NSE_BASE64:?}"

TEAM=3XBDMLQ9NV
APP_ID=ai.new-i.aihost.mobile
NSE_ID=ai.new-i.aihost.mobile.NotificationService
PBXPROJ=mobile/ios/Runner.xcodeproj/project.pbxproj

keychain="$RUNNER_TEMP/aihost-signing.keychain-db"
kpass="$(uuidgen)"
security create-keychain -p "$kpass" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$kpass" "$keychain"
echo "$IOS_DIST_CERT_P12_BASE64" | base64 --decode > "$RUNNER_TEMP/dist.p12"
security import "$RUNNER_TEMP/dist.p12" -P "$IOS_DIST_CERT_PASSWORD" -A -t cert -f pkcs12 -k "$keychain"
security set-key-partition-list -S apple-tool:,apple: -k "$kpass" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" $(security list-keychains -d user | tr -d '"')
rm -f "$RUNNER_TEMP/dist.p12"
echo "KEYCHAIN_PATH=$keychain" >> "$GITHUB_ENV"

# Install a profile under its UUID and print its name.
install_profile() {
  local b64="$1" f="$RUNNER_TEMP/profile.mobileprovision" plist
  echo "$b64" | base64 --decode > "$f"
  plist="$RUNNER_TEMP/profile.plist"
  security cms -D -i "$f" > "$plist"
  local uuid name
  uuid=$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$plist")
  name=$(/usr/libexec/PlistBuddy -c 'Print :Name' "$plist")
  mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
  cp "$f" "$HOME/Library/MobileDevice/Provisioning Profiles/$uuid.mobileprovision"
  rm -f "$f" "$plist"
  echo "$name"
}
APP_PROFILE=$(install_profile "$IOS_PROFILE_APP_BASE64")
NSE_PROFILE=$(install_profile "$IOS_PROFILE_NSE_BASE64")
echo "Installed profiles: '$APP_PROFILE' and '$NSE_PROFILE'"

# Manual signing for the two shipped targets. Matches by bundle id line, so it
# survives upstream reshuffling the project, and fails loudly if it stops matching.
python3 - "$PBXPROJ" "$TEAM" "$APP_PROFILE" "$NSE_PROFILE" <<'PY'
import re, sys
path, team, app_profile, nse_profile = sys.argv[1:5]
src = open(path).read()
pat = re.compile(r'(\t\t\tbuildSettings = \{\n)(.*?)(\n\t\t\t\};)', re.S)
hits = {"app": 0, "nse": 0}

def patch(m):
    body = m.group(2)
    if 'PRODUCT_BUNDLE_IDENTIFIER = "$(BUNDLE_IDENTIFIER).NotificationService";' in body:
        kind, profile = "nse", nse_profile
    elif 'PRODUCT_BUNDLE_IDENTIFIER = "$(BUNDLE_IDENTIFIER)";' in body:
        kind, profile = "app", app_profile
    else:
        return m.group(0)
    body = re.sub(r'\t*CODE_SIGN_STYLE = [^;]+;\n?', '', body)
    body = re.sub(r'\t*"?CODE_SIGN_IDENTITY(\[sdk=iphoneos\*\])?"? = [^;]+;\n?', '', body)
    body = re.sub(r'\t*PROVISIONING_PROFILE_SPECIFIER = [^;]+;\n?', '', body)
    body = re.sub(r'\t*DEVELOPMENT_TEAM = [^;]+;\n?', '', body)
    add = (f'\t\t\t\tCODE_SIGN_STYLE = Manual;\n'
           f'\t\t\t\t"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";\n'
           f'\t\t\t\tDEVELOPMENT_TEAM = {team};\n'
           f'\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "{profile}";\n')
    hits[kind] += 1
    return m.group(1) + add + body.rstrip("\n") + m.group(3)

out = pat.sub(patch, src)
if hits["app"] == 0 or hits["nse"] == 0:
    sys.exit(f"signing patch did not match the project (app={hits['app']}, nse={hits['nse']})")
open(path, "w").write(out)
print(f"patched build configurations: app={hits['app']}, notification service={hits['nse']}")
PY

cat > "$RUNNER_TEMP/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Apple Distribution</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>$APP_ID</key><string>$APP_PROFILE</string>
    <key>$NSE_ID</key><string>$NSE_PROFILE</string>
  </dict>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
PLIST
