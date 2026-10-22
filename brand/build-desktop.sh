#!/usr/bin/env bash
# Build the branded AI-HOST macOS app (unsigned .app) from the repo root:
#   . ./bin/activate-hermit && brand/build-desktop.sh [target-triple]
# Applies the overlay in brand/desktop/ and the build-time identity values below.
# Mirrors upstream's `just desktop-demo-build`; keep in step with it on sync (FORK.md).
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
TARGET="${1:-aarch64-apple-darwin}"
[[ "$(uname -s)" == "Darwin" && "$TARGET" == *-apple-darwin ]] || { echo "macOS Apple target required" >&2; exit 2; }

# Runtime identity baked into the binary. The keychain service is permanent once
# users store secrets under it: do not change it after the first release.
export BUZZ_BUILD_KEYRING_SERVICE="ai-host-desktop"
export BUZZ_BUILD_APP_IDENTIFIER="ai.new-i.aihost.mac"

cargo build --release --target "$TARGET" \
  -p buzz-acp -p buzz-agent -p buzz-backend-kubernetes -p buzz-dev-mcp \
  -p git-credential-nostr -p buzz-cli
./scripts/bundle-sidecars.sh "$TARGET"
pnpm install
cd desktop
pnpm tauri build --features mesh-llm --target "$TARGET" --bundles app \
  --config "$ROOT/brand/desktop/tauri.conf.json"

APP="$ROOT/desktop/src-tauri/target/$TARGET/release/bundle/macos/AI-HOST.app"
echo "Built: $APP"
