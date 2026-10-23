#!/usr/bin/env bash
# Decide whether there is an upstream release to build. Prints key=value lines
# (also appended to $GITHUB_OUTPUT when set):
#   needed, upstream_tag, version, subversion, release_tag
#
# Scheduled mode (no UPSTREAM_TAG): the newest stable block/buzz `desktop-vX.Y.Z`
# release; needed=true only if we have no release or draft for that base yet.
# Manual mode (UPSTREAM_TAG set): always needed; subversion = highest existing + 1,
# which is how a fix to our own layer on the same upstream base gets released.
#
# Needs: gh (GH_TOKEN), git. Run from a checkout of the fork.
set -euo pipefail

UP="${UPSTREAM_REPO:-block/buzz}"
MINE="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
tag="${UPSTREAM_TAG:-}"

if [[ -z "$tag" ]]; then
  tag="$(gh api "repos/$UP/releases?per_page=100" \
    --jq '.[] | select(.draft == false and .prerelease == false) | .tag_name' \
    | grep -E '^desktop-v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1 || true)"
fi
[[ -n "$tag" ]] || { echo "no official desktop release found in $UP" >&2; exit 1; }
[[ "$tag" =~ ^desktop-v([0-9]+\.[0-9]+\.[0-9]+)$ ]] || { echo "unexpected tag: $tag" >&2; exit 1; }
version="${BASH_REMATCH[1]}"

# Sub-versions already used for this base: published tags, plus draft releases
# (a draft has a tag name but no git tag yet).
existing="$( { git ls-remote --tags origin "refs/tags/desktop-v${version}-aihost.*" | sed 's#.*refs/tags/##'
               gh release list --repo "$MINE" --limit 200 --json tagName --jq '.[].tagName'; } \
             | grep -E "^desktop-v${version//./\\.}-aihost\.[0-9]+$" | sort -u || true)"
last="$(printf '%s\n' "$existing" | sed -nE 's/.*-aihost\.([0-9]+)$/\1/p' | sort -n | tail -1)"

if [[ -z "${UPSTREAM_TAG:-}" ]]; then
  if [[ -n "$last" ]]; then needed=false; sub="$last"; else needed=true; sub=1; fi
else
  needed=true; sub=$(( ${last:-0} + 1 ))
fi

out="needed=$needed
upstream_tag=$tag
version=$version
subversion=$sub
release_tag=desktop-v${version}-aihost.${sub}"
echo "$out"
[[ -z "${GITHUB_OUTPUT:-}" ]] || echo "$out" >> "$GITHUB_OUTPUT"
