#!/usr/bin/env bash
# The release gate: everything must pass before an AI-HOST build is published.
# Run from the repo root with Hermit active (. ./bin/activate-hermit).
set -euo pipefail
cd "$(dirname "$0")/../.."

echo "::group::brand check"; brand/scripts/check-brand.sh; echo "::endgroup::"
echo "::group::desktop"; just desktop-install-ci desktop-check desktop-test; echo "::endgroup::"
echo "::group::desktop rust"; just desktop-tauri-check desktop-tauri-test; echo "::endgroup::"
echo "::group::mobile"; just mobile-install mobile-check mobile-test; echo "::endgroup::"
if [[ -x brand/scripts/e2e-gate.sh ]]; then
  echo "::group::browser e2e"; brand/scripts/e2e-gate.sh; echo "::endgroup::"
fi
echo "gate: all checks passed"
