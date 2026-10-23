#!/usr/bin/env bash
# Verify the AI-HOST customization layer is intact. Run on every release
# candidate: a clean merge can still silently lose a customization (an upstream
# refactor can make a replayed hunk apply to the wrong place), and Block's
# identifiers must never leak into our overlay. Anchors mirror FORK.md.
set -uo pipefail
cd "$(dirname "$0")/../.."

fail=0
check() { # <description> <command...>
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "ok    $d"; else echo "FAIL  $d"; fail=1; fi
}
has()  { grep -qF -- "$1" "$2"; }
lacks() { ! grep -qF -- "$1" "$2"; }

# Identity overlay.
check "macOS overlay identifier" has '"identifier": "ai.new-i.aihost.mac"' brand/desktop/tauri.conf.json
check "macOS overlay product name" has '"productName": "AI-HOST"' brand/desktop/tauri.conf.json
check "macOS overlay icons" has 'brand/desktop/icons/icon.icns' brand/desktop/tauri.conf.json
check "iOS release bundle id" has 'BUNDLE_IDENTIFIER[config=Release] = ai.new-i.aihost.mobile' mobile/ios/Flutter/AppOverrides.xcconfig
check "iOS team id" has 'BUZZ_DEVELOPMENT_TEAM = 3XBDMLQ9NV' mobile/ios/Flutter/AppOverrides.xcconfig
check "iOS display name" has 'APP_DISPLAY_NAME = AI-HOST' mobile/ios/Flutter/AppOverrides.xcconfig
check "iOS Info.plist name" has '<string>AI-HOST</string>' mobile/ios/Runner/Info.plist
check "AppOverrides.xcconfig is tracked" git ls-files --error-unmatch mobile/ios/Flutter/AppOverrides.xcconfig

# Block identifiers must not appear in our overlay files.
for f in brand/desktop/tauri.conf.json brand/desktop/Info.plist mobile/ios/Flutter/AppOverrides.xcconfig brand/build-desktop.sh; do
  check "no Block identifiers in $f" lacks 'xyz.block' "$f"
done

# Upstream-file edits (FORK.md "Visual identity" and runtime identity tables).
check "keychain service switch" has 'BUZZ_BUILD_KEYRING_SERVICE' desktop/src-tauri/src/app_state_keyring.rs
check "CLI app id switch" has 'BUZZ_BUILD_APP_IDENTIFIER' crates/buzz-cli/src/commands/channel_templates.rs
check "brand.css imported" has 'brand/desktop/brand.css' desktop/src/main.tsx
check "arch mark (BuzzMark)" has 'M24 76V46a24 24 0 0 1 48 0v30' desktop/src/shared/ui/buzz-logo/BuzzMark.tsx
check "arch mark (FlappingBee)" has 'aihost-mark-dot' desktop/src/shared/ui/buzz-logo/FlappingBee.tsx
check "arch mark (BuzzLogoAnimation)" has 'aihost-mark-dot' desktop/src/shared/ui/buzz-logo/BuzzLogoAnimation.tsx
check "start page tagline" has 'in one place.' desktop/src/features/onboarding/ui/MachineOnboardingFlow.tsx
check "start page alt text" has 'alt="AI-HOST"' desktop/src/features/onboarding/ui/MachineOnboardingFlow.tsx
check "identity key help copy" has 'how AI-HOST knows' desktop/src/features/onboarding/ui/IdentityKeyHelpDialog.tsx
check "iOS theme palette" has 'Color(0xFFF4F2EB)' mobile/lib/shared/theme/buzz_theme.dart
check "iOS launch background" has 'red="0.188" green="0.239" blue="0.204"' mobile/ios/Runner/Base.lproj/LaunchScreen.storyboard

# Generated assets exist.
for f in brand/desktop/icons/icon.icns brand/desktop/icons/icon.ico brand/desktop/icons/icon.png desktop/public/landing/buzz-wordmark.png; do
  check "asset $f" test -s "$f"
done

[[ $fail -eq 0 ]] && echo "brand check: all good" || { echo "brand check: FAILED (see above and FORK.md)"; exit 1; }
