#!/usr/bin/env bash
# Prints the next release candidate version, e.g. 6.1.0-rc.2.
#
# The base is the latest stable tag (X.Y.Z) of the original repository. The
# bump is taken from the conventional commits between that tag and HEAD:
#   type!: ... or BREAKING CHANGE:  -> major
#   feat: ...                       -> minor
#   anything else                   -> patch
# The rc number is one more than the highest existing rc tag of that version.
set -euo pipefail

UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/fvtt-fria-ligan/morkborg-foundry-vtt.git}"

# bring in the original repository's tags (stable tags are the base)
git fetch --quiet --no-tags "$UPSTREAM_URL" '+refs/tags/*:refs/tags/*'

# re-running on a commit that already has a release candidate reuses its version
existing=$(git tag --points-at HEAD --list '*-rc.*' | sort -V | tail -n 1)
if [ -n "$existing" ]; then
  echo "$existing"
  exit 0
fi

stable=$(git tag --list | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1)
if [ -z "$stable" ]; then
  echo "No stable X.Y.Z tag found" >&2
  exit 1
fi

level=patch
if git log --format=%s "$stable..HEAD" | grep -qE '^feat(\([^)]+\))?!?:'; then
  level=minor
fi
if git log --format=%s "$stable..HEAD" | grep -qE '^[a-z]+(\([^)]+\))?!:' ||
  git log --format=%b "$stable..HEAD" | grep -qE '^BREAKING[ -]CHANGE:'; then
  level=major
fi

IFS=. read -r major minor patch <<<"$stable"
case "$level" in
  major) target="$((major + 1)).0.0" ;;
  minor) target="$major.$((minor + 1)).0" ;;
  patch) target="$major.$minor.$((patch + 1))" ;;
esac

last_rc=$(git tag --list "$target-rc.*" | sed 's/.*-rc\.//' | sort -n | tail -n 1)
echo "$target-rc.$((${last_rc:-0} + 1))"
