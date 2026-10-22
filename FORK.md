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

Not yet changed (do these deliberately, each needs testing):
- Icons (`desktop/src-tauri/icons/`, `mobile/ios/Runner/Assets.xcassets`): need AI-HOST artwork.
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
