#!/usr/bin/env bash
# Build the release source for one upstream release: the official upstream tag
# plus our customization layer replayed on top of it.
#
# Our layer is every non-merge commit on origin/main that is not in upstream's
# history (`upstream/main..origin/main`). Upstream release tags sit on side
# branches and main may hold unreleased upstream work, so we never merge a tag
# into main; we replay our commits onto the tag instead (see FORK.md).
#
# Env: UPSTREAM_TAG, VERSION, SUBVERSION. Optional: UPSTREAM_URL, LAYER_REF.
# Exit 3 on a cherry-pick conflict, with details in $CONFLICT_FILE.
# Prints: branch=..., sha=... (also to $GITHUB_OUTPUT).
set -euo pipefail

: "${UPSTREAM_TAG:?}" "${VERSION:?}" "${SUBVERSION:?}"
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/block/buzz.git}"
LAYER_REF="${LAYER_REF:-origin/main}"
CONFLICT_FILE="${CONFLICT_FILE:-${RUNNER_TEMP:-/tmp}/aihost-conflicts.md}"
BRANCH="release/desktop-v${VERSION}-aihost.${SUBVERSION}"

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$UPSTREAM_URL"
git fetch --quiet upstream main "refs/tags/${UPSTREAM_TAG}:refs/tags/${UPSTREAM_TAG}"
git rev-parse --verify --quiet "refs/tags/${UPSTREAM_TAG}^{commit}" >/dev/null

layer="$(git rev-list --reverse --no-merges "upstream/main..${LAYER_REF}")"
git checkout --quiet -B "$BRANCH" "refs/tags/${UPSTREAM_TAG}"

for c in $layer; do
  if ! git cherry-pick -x "$c" >/dev/null 2>&1; then
    {
      echo "Cherry-pick of our commit onto \`${UPSTREAM_TAG}\` conflicted."
      echo
      echo "- commit: $(git log -1 --format='%h %s' "$c")"
      echo "- conflicting files:"
      git diff --name-only --diff-filter=U | sed 's/^/  - `/; s/$/`/'
      echo
      echo "Resolve by hand: replay our layer onto the tag locally, fix FORK.md's"
      echo "listed customizations, then land the fix on main so the next run is clean."
    } > "$CONFLICT_FILE"
    git cherry-pick --abort >/dev/null 2>&1 || true
    echo "conflict: see $CONFLICT_FILE" >&2
    exit 3
  fi
done

# The release tree must carry our workflows, not upstream's (upstream's are
# guarded to block/buzz and change often).
git rm -rq --ignore-unmatch .github/workflows
git checkout "$LAYER_REF" -- .github/workflows
if ! git diff --cached --quiet; then
  git commit -q -m "Use fork workflows in release source"
fi

sha="$(git rev-parse HEAD)"
out="branch=$BRANCH
sha=$sha"
echo "$out"
[[ -z "${GITHUB_OUTPUT:-}" ]] || echo "$out" >> "$GITHUB_OUTPUT"
