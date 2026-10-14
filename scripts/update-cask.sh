#!/usr/bin/env bash
set -euo pipefail

# Points the Homebrew cask (tuhage/homebrew-cellar) at a published release.
# Run it after `gh release create`, once the DMG is on GitHub.
#
# Usage:
#   ./scripts/update-cask.sh 1.7.3

VERSION="${1:?Usage: $0 <version>}"
APP_REPO="tuhage/Cellar"
TAP_REPO="tuhage/homebrew-cellar"
CASK_PATH="Casks/cellar.rb"
DMG_NAME="Cellar-$VERSION.dmg"

# GitHub computes each asset's digest on upload, so the cask always matches
# the file users download.
SHA256=$(gh release view "v$VERSION" --repo "$APP_REPO" --json assets \
  --jq ".assets[] | select(.name == \"$DMG_NAME\") | .digest | ltrimstr(\"sha256:\")")
if [[ -z "$SHA256" ]]; then
  echo "$DMG_NAME isn't on the v$VERSION release yet" >&2
  exit 1
fi

CASK=$(gh api "repos/$TAP_REPO/contents/$CASK_PATH" -H "Accept: application/vnd.github.raw")
UPDATED=$(sed -E \
  -e "s/^  version \".*\"$/  version \"$VERSION\"/" \
  -e "s/^  sha256 \".*\"$/  sha256 \"$SHA256\"/" <<<"$CASK")

if [[ "$UPDATED" == "$CASK" ]]; then
  echo "The cask is already at $VERSION"
  exit 0
fi

gh api -X PUT "repos/$TAP_REPO/contents/$CASK_PATH" \
  -f message="cellar $VERSION" \
  -f content="$(base64 <<<"$UPDATED")" \
  -f sha="$(gh api "repos/$TAP_REPO/contents/$CASK_PATH" --jq .sha)" >/dev/null

echo "Updated $TAP_REPO to $VERSION ($SHA256)"
