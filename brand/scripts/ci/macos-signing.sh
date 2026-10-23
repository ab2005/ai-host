#!/usr/bin/env bash
# CI only: imports the Developer ID Application certificate into a temporary
# keychain and writes the App Store Connect API key for notarytool.
# Does nothing (and the build stays ad-hoc signed) when the certificate secret is empty.
# Reads: MACOS_DEVID_CERT_P12_BASE64, MACOS_DEVID_CERT_PASSWORD,
#        ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8_BASE64
# Exports via GITHUB_ENV: CODESIGN_IDENTITY, MACOS_KEYCHAIN_PATH, NOTARY_KEY_PATH,
#        NOTARY_KEY_ID, NOTARY_ISSUER_ID
set -euo pipefail

if [[ -z "${MACOS_DEVID_CERT_P12_BASE64:-}" ]]; then
  echo "No Developer ID certificate secret: the build stays ad-hoc signed."
  exit 0
fi
: "${RUNNER_TEMP:?}" "${MACOS_DEVID_CERT_PASSWORD:?}" "${ASC_KEY_ID:?}" "${ASC_ISSUER_ID:?}" "${ASC_KEY_P8_BASE64:?}"

keychain="$RUNNER_TEMP/aihost-devid.keychain-db"
kpass="$(uuidgen)"
security create-keychain -p "$kpass" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$kpass" "$keychain"
echo "$MACOS_DEVID_CERT_P12_BASE64" | base64 --decode > "$RUNNER_TEMP/devid.p12"
security import "$RUNNER_TEMP/devid.p12" -P "$MACOS_DEVID_CERT_PASSWORD" -A -t cert -f pkcs12 -k "$keychain"
security set-key-partition-list -S apple-tool:,apple: -k "$kpass" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" $(security list-keychains -d user | tr -d '"')
rm -f "$RUNNER_TEMP/devid.p12"

identity=$(security find-identity -v -p codesigning "$keychain" | sed -n 's/.*"\(Developer ID Application:.*\)".*/\1/p' | head -1)
[[ -n "$identity" ]] || { echo "::error::No Developer ID Application identity found after import"; exit 1; }
echo "Signing identity: $identity"

keyfile="$RUNNER_TEMP/AuthKey_${ASC_KEY_ID}.p8"
echo "$ASC_KEY_P8_BASE64" | base64 --decode > "$keyfile"
chmod 600 "$keyfile"

{
  echo "CODESIGN_IDENTITY=$identity"
  echo "MACOS_KEYCHAIN_PATH=$keychain"
  echo "NOTARY_KEY_PATH=$keyfile"
  echo "NOTARY_KEY_ID=$ASC_KEY_ID"
  echo "NOTARY_ISSUER_ID=$ASC_ISSUER_ID"
} >> "$GITHUB_ENV"
