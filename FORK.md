# FORK.md — customizations on top of block/buzz

Checklist for resolving upstream sync conflicts. Every change we make to upstream-owned files is
listed here with its intent, so it can be re-applied if upstream moves. Purely additive files
(`brand/`, `FORK.md`) never conflict.

Company: New-I (new-i.ai). Product: AI-HOST (ai-host.ai). Audience of these apps: property hosts
and their team of AI agents. (Guests use a separate app in another repo.)

## Branding (macOS + iOS)

| What | Where | Upstream files touched |
|------|-------|------------------------|
| macOS product name, bundle ID `ai.new-i.aihost.mac`, Info.plist strings | `brand/desktop/tauri.conf.json`, `brand/desktop/Info.plist`, merged at build time with `tauri build --config brand/desktop/tauri.conf.json` | none |
| iOS display name, bundle IDs (`ai.new-i.aihost.mobile`, dev: `ai.new-i.aihost.dev.mobile`), team ID | `mobile/ios/Flutter/AppOverrides.xcconfig` (gitignored upstream, force-added here) | none |
| iOS user-facing strings (`CFBundleName`, camera/mic/photo/Face ID usage text) | `mobile/ios/Runner/Info.plist` | yes: 6 string values. Re-apply "Buzz" -> "AI-HOST" |
| macOS keychain service. Release builds read `BUZZ_BUILD_KEYRING_SERVICE` (default `buzz-desktop`); we set `ai-host-desktop` | `brand/build-desktop.sh` sets it | yes: `desktop/src-tauri/src/app_state_keyring.rs`, release branch of `keyring_service()` |
| App ID the `buzz` CLI uses to find the desktop app's data dir. Reads `BUZZ_BUILD_APP_IDENTIFIER` (default `xyz.block.buzz.app`); we set `ai.new-i.aihost.mac` | `brand/build-desktop.sh` sets it | yes: `crates/buzz-cli/src/commands/channel_templates.rs`, `PROD_BUNDLE_IDENTIFIER` |
| Branded macOS build (sidecars + `tauri build --config`); mirrors upstream's `just desktop-demo-build` | `brand/build-desktop.sh` | none |

The two edited Rust spots are build-time switches that default to upstream's values, so upstream's
tests are unaffected. If upstream changes either function, re-apply the `option_env!` read.
The keychain service name is permanent once users store secrets under it: never change it after
the first release without a migration.

## Visual identity (macOS + iOS)

Theme from new-i.ai: paper `#f4f2eb`, ink `#242722`, terracotta accent `#b54d32`, forest `#303d34`,
sage `#dfe4d9`; Arial headings with Georgia italic emphasis. Mark: an arch (the "∩" in "where new ∩
now") as a doorway, with a terracotta dot. Preview: `brand/assets/preview.html`.

Additive files (never conflict): `brand/desktop/brand.css` (theme overrides, unlayered so they win
over upstream's layered rules), `brand/desktop/icons/` (macOS icon set, referenced by
`brand/desktop/tauri.conf.json`), `brand/assets/` (SVG sources, iOS 1024 icon, preview),
`brand/scripts/make-assets.sh` (regenerates every raster asset below from the SVGs; macOS only).

Upstream files we changed (re-apply after a sync conflict):

| File | Change |
|------|--------|
| `desktop/src/main.tsx` | one line: `import "../../brand/desktop/brand.css";` after `globals.css` |
| `desktop/src/shared/ui/buzz-logo/BuzzMark.tsx`, `FlappingBee.tsx`, `BuzzLogoAnimation.tsx` | bodies replaced with the arch mark; exports and prop types unchanged so ~18 call sites stay as upstream |
| `desktop/src/features/onboarding/ui/LandingBees.tsx` | replaced: mark top-left plus line artwork instead of the animated bee field |
| `desktop/src/features/onboarding/ui/MachineOnboardingFlow.tsx` | start page: `alt="AI-HOST"`, wordmark max width, tagline "Your property team, *in one place.*" (about 8 lines) |
| `desktop/src/features/onboarding/ui/IdentityKeyHelpDialog.tsx` | `IdentityKeyHelpBody()` copy rewritten in plain language for property managers (office key and name badge, no "Nostr"); the iOS app has no equivalent text yet |
| `desktop/public/landing/buzz-wordmark.png` | binary replaced by `make-assets.sh` |
| `mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png` (16), `LaunchImage.imageset/*.png` (3) | binaries replaced by `make-assets.sh`; `Contents.json` untouched. The icon name is fixed in the Xcode project, so it cannot be overridden from `AppOverrides.xcconfig` |
| `mobile/ios/Runner/Base.lproj/LaunchScreen.storyboard` | one line: launch background color black to forest (`0.188 0.239 0.204`) |
| `mobile/lib/shared/theme/theme_catalog.dart` | the `buzz` and `buzz-dark` entries use the AI-HOST palette instead of GitHub's (bg, fg, comment, added) |
| `mobile/lib/shared/theme/buzz_theme.dart` | the four gradient stop constants (paper to sage; dark `#232b26` to `#141a16`) |
| `mobile/test/shared/theme/buzz_theme_test.dart` | the test "borrow the GitHub palettes" became "use the AI-HOST palette" and asserts the new values |

Dark mode palette (`#1b211d` background) is our proposal, not taken from new-i.ai. Role colors for
agents (pine `#2f6b2f` concierge, lake `#1d5a73` chief of staff) come from the AI-HOST product page
and are not used in the app yet.

Not yet changed (do these deliberately, each needs testing):
- iOS pairing-screen artwork: `mobile/assets/images/{buzz-wordmark,buzz-icon,shell-gradient}.png`. The
  wordmark is animated by a custom shader (`shaders/onboarding_wordmark.frag`) tuned to the bee, so
  swapping the image needs a simulator or device to judge. Needs Xcode.
- iOS default chat accent "Chartreuse" (`chat_colors.dart`, `accent_colors.dart`): the accent table is
  shared with desktop through `test-fixtures/community-theme-accents.json`, so change both sides together.
- iOS visuals have not been seen on a device or simulator yet (no Xcode); only the Dart tests ran.
- Remaining "Buzz" text, for example the key-entry page says "sign in to Buzz".
- Web favicon `desktop/public/buzz.svg` and `desktop/public/app-icon@*.png` (not used by the packaged app).
- Deep-link scheme `buzz://` (desktop `plugins.deep-link`, iOS `CFBundleURLSchemes`): shared protocol
  with relay-generated links. Change only together with the relay.
- User-visible "Buzz" strings in `desktop/src` (~260 files) and `mobile/lib` (~190 files).
- Updater endpoint and signing key (`plugins.updater` is empty upstream).
- The iOS hosted-login callback scheme `xyz.block.buzz.mobile` (`AppDelegate.swift`,
  `mobile/lib/shared/hosted/browser_auth.dart`). Inactive unless `BUZZ_AUTH_DOMAINS` is set.

## Known limitation: AI-HOST and Block's Buzz share some names (decided: accept and document)

Upstream hardcodes the bundle ID `xyz.block.buzz.app` in several Rust files. After reading them, the
only functional problem was the CLI's channel-templates path (fixed above). The rest is test code,
dev-build detection, or a legacy-data import that does nothing for a new app.

The desktop runtime identity is fixed to upstream's names and is NOT changed by this fork:
the `~/.buzz` folder, the `buzz` CLI name, and the `buzz://` deep-link scheme
(`desktop/src-tauri/src/build_identity.rs`). If a host has Block's Buzz installed next to AI-HOST,
both apps share `~/.buzz` and compete for `buzz://` links. We chose to accept this and tell users
(installer notes and docs, still to write) rather than patch more upstream files. The keychain
service IS renamed, because both apps would otherwise share one secrets blob in the keychain.
Revisit if Buzz users become a real audience; changing the folder or scheme needs a migration and,
for the scheme, a matching relay change.

Verify before the first release: run `brand/build-desktop.sh`, launch the app, and confirm in
Keychain Access that secrets are stored under `ai-host-desktop`, not `buzz-desktop`.

## Release pipeline

`.github/workflows/aihost-release.yml` builds AI-HOST from the newest official Buzz Desktop release
and publishes it to this repository's Releases. It runs every 6 hours and on demand.

**Versioning.** Tag and release name: `desktop-vX.Y.Z-aihost.N`. X.Y.Z is Block's version and N is
our sub-version (1 for the first build of a base, then 2, 3, ... for fixes to our layer on the same
base). The app's internal version stays X.Y.Z; N is stamped as the build number (`CFBundleVersion`).
A SemVer suffix would sort *below* X.Y.Z and break updaters, and Apple allows only three numbers.

**Source model.** Upstream tags sit on side branches and `main` holds unreleased upstream work, so we
never merge a tag into `main`. Our layer is `git rev-list --no-merges upstream/main..main`; the
pipeline checks out the official tag and cherry-picks that layer onto it
(`brand/scripts/ci/build-release-branch.sh`), then restores our `.github/workflows`. The result is
pushed as `release/desktop-vX.Y.Z-aihost.N`. Tested: all 7 of our commits replay cleanly onto
`desktop-v0.5.28`.

**Steps.** detect (`detect-upstream.sh`) -> release source -> gate (`brand/scripts/gate.sh`: brand
check, desktop lint/types/tests, Rust tests, mobile analysis/tests) -> build
(`brand/build-desktop.sh`) -> package (`package-macos.sh`: zip, dmg, SHA-256) -> release.
Nothing is published if any step fails; the pipeline opens an issue instead. A cherry-pick conflict
also opens an issue naming the files.

**Debug runs.** Set `skip_gate` when running manually to skip the 35-minute test gate while fixing build or packaging steps. Such a release is always a draft, labeled as ungated.

**Releasing a fix to our own layer.** Land it on `main`, then run the workflow manually with
`upstream_tag` set (e.g. `desktop-v0.5.28`); it builds the next sub-version.

**Draft or live.** Releases are created as drafts: review, then click Publish. Set the repository
variable `AIHOST_AUTO_PUBLISH` to `true` to publish automatically.

**One-time setup (needs you).**
1. Create a fine-grained personal access token on `ab2005/ai-host` with Contents, Workflows, Issues
   and Actions: read and write. Store it as the repository secret `AIHOST_BOT_TOKEN`. (The default
   token cannot push commits that touch `.github/workflows`, and its pushes do not start workflows.)
2. Optional: Developer ID signing (set `CODESIGN_IDENTITY` and import the certificate) so users need
   not use "Open Anyway". Until then builds are ad-hoc signed.

**Upstream workflows are disabled** in the fork (all 27 `disabled_manually`; GitHub tracks this per
file path, so it survives syncs). Do not re-enable them: they need Block's secrets and runners.

**Not built yet:** the browser-test gate (`brand/scripts/e2e-gate.sh` runs automatically when it
exists), signing and notarization, iOS to TestFlight, Intel Macs, and an agent to resolve conflicts.

## iOS build and signing (CI)

`.github/workflows/aihost-ios.yml`, manual runs. Default: unsigned build plus a check that the display
name is AI-HOST and the bundle id is `ai.new-i.aihost.mobile`. `sign=true` adds a signed App Store `.ipa`
(`brand/scripts/ci/ios-signing.sh` installs the certificate and profiles, switches the Runner and
NotificationService targets to manual signing in the runner's checkout only, and writes
`ExportOptions.plist`). `upload=true` sends it to TestFlight with `altool`.

Repository secrets: `IOS_DIST_CERT_P12_BASE64`, `IOS_DIST_CERT_PASSWORD`, `IOS_PROFILE_APP_BASE64`,
`IOS_PROFILE_NSE_BASE64`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`. They come from the
Apple Distribution certificate, the two App Store provisioning profiles and the team API key
"ai-host CI" (App Manager). The certificate and profiles expire 2027-10-23: reissue them then.
Originals and the private key are kept off-repo in `~/aihost-signing/` (backed up in iCloud Drive).

## macOS signing and notarization (CI)

`brand/scripts/ci/macos-signing.sh` imports the Developer ID Application certificate into a temporary
keychain and writes the App Store Connect API key for `notarytool`; `brand/scripts/package-macos.sh`
then signs with the hardened runtime, notarizes and staples the app and the `.dmg`, and fails unless
Apple answers "Accepted". Without the certificate secret the build stays ad-hoc signed (as before).
Secrets: `MACOS_DEVID_CERT_P12_BASE64`, `MACOS_DEVID_CERT_PASSWORD` plus the `ASC_*` key secrets above.
The certificate expires 2027-11-22: reissue it then. Files are in `~/aihost-signing/` (`devid.*`).
