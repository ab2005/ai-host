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

Not yet changed (do these deliberately, each needs testing):
- Icons (`desktop/src-tauri/icons/`, `mobile/ios/Runner/Assets.xcassets`): need AI-HOST artwork.
- Apple Developer team ID (`BUZZ_DEVELOPMENT_TEAM` in `AppOverrides.xcconfig`).
- Deep-link scheme `buzz://` (desktop `plugins.deep-link`, iOS `CFBundleURLSchemes`): shared protocol
  with relay-generated links. Change only together with the relay.
- User-visible "Buzz" strings in `desktop/src` (~260 files) and `mobile/lib` (~190 files).
- Updater endpoint and signing key (`plugins.updater` is empty upstream).
- The iOS hosted-login callback scheme `xyz.block.buzz.mobile` (`AppDelegate.swift`,
  `mobile/lib/shared/hosted/browser_auth.dart`). Inactive unless `BUZZ_AUTH_DOMAINS` is set.

## Known risk: macOS bundle ID is hardcoded in desktop code

Upstream hardcodes `xyz.block.buzz.app` (and `.dev`) in Rust and scripts: `desktop/src-tauri/src/`
`reset.rs`, `migration.rs`, `commands/legacy_storage.rs`, `managed_agents/{nest.rs,runtime/*}`,
`crates/buzz-cli/src/commands/channel_templates.rs`, `desktop/scripts/demo-build-config.mjs`.
With `ai.new-i.aihost.mac` the app runs from a different data directory, so "reset app data" and the
CLI's channel-templates path may target the wrong directory. This has NOT been built or tested yet;
verify before the first release (`just desktop-tauri-test`, then a packaged-app smoke test).
Fix by changing those constants, then record them in this file.
