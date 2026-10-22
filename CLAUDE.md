@AGENTS.md

# Fork guidance — ab2005/ai-host (branded fork of block/buzz)

Upstream tracks `CLAUDE.md` as a symlink to `AGENTS.md`. In this fork it is a regular file that
imports `AGENTS.md` (above) and adds the rules below. Don't edit `AGENTS.md` for fork-specific
guidance; keep it identical to upstream so merges stay clean. If upstream changes `CLAUDE.md`
during a sync, keep the `@AGENTS.md` import and this section.

This fork builds our own branded **macOS** (Tauri desktop) and **iOS** (Flutter mobile) apps.
Android, Windows, Linux, and relay/Docker builds are out of scope for now.
Upstream contributor docs still apply to the code itself: see `AGENTS.md` and `CONTRIBUTING.md`.

## Goal

Our apps must stay **in sync with upstream releases**, with our own branding and a small set of
customizations:

- Upstream ships features A, B, C. We hide B. Upstream later adds D. Our next release must have A, C, D.
- So: **hide features, don't delete them**, and keep our diff small so upstream changes reapply cleanly.

## Remotes and branches

- `origin` = `ab2005/ai-host` (our fork). `upstream` = `block/buzz`. Never push to `upstream`.
- `main` in the fork is our customized line.
- Release lanes are independent upstream, with **different version numbers**:
  - Desktop: tags `desktop-vX.Y.Z` (currently 0.5.x); app version in `desktop/src-tauri/tauri.conf.json`.
  - Mobile: tags `mobile-vX.Y.Z-rc.N` (currently 0.25.x); immutable release candidates.
- Sync from upstream **tags**, not upstream `main`, so we only absorb released states.
- Use merges, not rebases or force-pushes, on shared branches.
- Our releases are tagged `<upstream version>-<brand>.N`, e.g. `desktop-v0.5.29-acme.1`.
  Our tag must never collide with an upstream tag name. Block does the same for its internal
  signed macOS and iOS builds (`squareup/buzz-releases`, desktop version suffix `-block`), so this
  scheme follows upstream's own convention.

## Rules for keeping the diff small (most important)

1. **Prefer additive changes.** Put our code in new files/modules (e.g. `desktop/src/<brand>/`,
   `mobile/lib/<brand>/`) and touch upstream files only at thin hook points.
2. **Hide, don't delete.** Disable a feature by removing its entry point (nav item, route, command) or
   via config/flags. Leave the implementation so upstream fixes still apply.
3. **Use upstream's feature mechanism first.** `preview-features.json` lists gated features
   (`workflows`, `projects`, `pulse`, `forum`, `agentManagedProfiles`), all `"platforms": ["desktop"]`.
   Check how the desktop reads it before inventing a new flag. Mobile has no equivalent registry;
   its build-time options are `--dart-define` values (see `mobile/README.md`).
4. **Don't reformat or reorganize upstream files.** No drive-by cleanups, renames, or formatter runs
   over files we don't otherwise change.
5. Record every customization in `FORK.md` (create it with the first one): what, why, which files,
   how to re-apply. It is the checklist for resolving sync conflicts.

## Branding checklist (change in as few places as possible)

Desktop (`desktop/src-tauri/`):
- `tauri.conf.json`: `productName` ("Buzz"), `identifier` (`xyz.block.buzz.app`), `version`, and
  `plugins.updater` (endpoints is empty upstream; our updater needs its own endpoint and signing pubkey).
- `icons/`, `Info.plist`, `Entitlements.plist`.

iOS (`mobile/ios/`):
- Bundle IDs derive from `$(BUNDLE_IDENTIFIER)` (extensions: `.NotificationService`, `.RunnerTests`).
  The signing team comes from `$(BUZZ_DEVELOPMENT_TEAM)`. Set these via xcconfig/env, not by editing the pbxproj.
- App name, icons, and the `NotificationService` extension. Push uses `BuzzPushKit` and a push gateway,
  so confirm which backend our build points at before shipping.

Never commit signing certificates, provisioning profiles, API keys, or the updater private key.

## Build and test

Toolchains are pinned with Hermit. From the repo root: `. ./bin/activate-hermit`, then use `just`.

- Desktop: `just desktop-install`, `desktop-dev`, `desktop-check`, `desktop-test`, `desktop-build`,
  `desktop-tauri-check`, `desktop-tauri-test`. Full gate: `just desktop-ci`.
  Packaged-app smoke test: `just desktop-release-smoke`.
- Mobile: `just mobile-install`, `mobile-check`, `mobile-test`, `mobile-dev`.
  There is no `mobile-build-ios` recipe (only `mobile-build-android`); iOS builds go through
  Xcode / `flutter build ios`. Use Xcode 27.0 on Apple silicon (macOS 26.6+), or Xcode 26 otherwise
  (see `mobile/README.md`).
- For iOS runtime validation use `just mobile-dev` (runs `flutter run` against a simulator).
- Before calling anything done: `just check` and the relevant `*-test` recipes pass.
- `just setup` / `just hooks` install lefthook pre-commit hooks that auto-format and re-stage files.
  Fork-only commits touching upstream files can pick up formatter changes, so check `git diff --staged`
  before committing. Upstream requires `git commit -s` (DCO); do the same here so commits stay
  compatible if we ever send a fix upstream.

## Syncing a new upstream release

1. `git fetch upstream --tags`; list new tags with `git tag -l 'desktop-v*' --sort=-v:refname | head`
   (and `mobile-v*`).
2. Read the upstream release notes for every release since our last sync (desktop: GitHub releases;
   mobile: `mobile/CHANGELOG.md`).
3. Branch `sync/desktop-vX.Y.Z` (or `sync/mobile-vX.Y.Z`) from `main` and `git merge <upstream tag>`.
4. Resolve conflicts guided by `FORK.md`. Re-apply our intent on top of upstream's new code; don't just
   pick a side. If upstream refactored the area, redo the customization against the new structure.
5. **New-feature report:** list upstream `feat:` commits since our last sync and say for each whether it
   is on in our build. New features default to on; ask before hiding one.
6. Run the build/test gates, then open a PR to `main`. Don't merge it yourself.
7. Version and tag per the scheme above. Never reuse or move an existing tag.

## Upstream release mechanics (don't copy blindly)

Upstream desktop releases run `just release-desktop <version>`, which opens an immutable candidate PR;
merging it triggers `auto-tag-on-release-pr-merge` and `release.yml`. Upstream mobile hands off to a
**private** `buzz-releases` pipeline we don't have. Their workflows depend on upstream-only secrets,
apps, and runners, so most of `.github/workflows/` won't work in our fork. Disable the ones we can't
run rather than letting them fail on every push, and write our own minimal macOS and iOS build
workflows as new files (don't edit upstream's in place, to keep merges clean).

## Open questions (answer, then delete from here)

- Brand name, bundle ID prefix, Apple developer team ID.
- Which features to hide in v1 (candidates: the ids in `preview-features.json`).
- Which relay our apps connect to (Block's hosted, or self-hosted).
- Distribution: direct download with our own updater, TestFlight, or App Store.
- Trademark: Apache-2.0 doesn't license Block's name or logos. Keep `LICENSE`/`NOTICE`; remove Block branding.

## Working rules for Claude in this repo

- Ask before pushing, tagging, creating releases, or touching signing/secrets. Never force-push.
- Say which upstream files a change touches and why it can't be additive.
- If a sync conflict isn't clearly resolvable from `FORK.md`, stop and ask.
