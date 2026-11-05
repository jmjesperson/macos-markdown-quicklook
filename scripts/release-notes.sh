#!/bin/bash
# Prints the GitHub release notes for a version: its CHANGELOG.md section, the install steps, and the
# zip's SHA-256. Usage: scripts/release-notes.sh <version> <zip>
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$1 ZIP=$2
SECTION=$(awk -v v="$VERSION" '
  index($0, "## [" v "]") == 1 { on = 1; next }
  on && /^## \[/ { exit }
  on && /^\[[^]]+\]: / { exit }
  on { print }' CHANGELOG.md | sed -e '/./,$!d')
[ -n "$SECTION" ] || { echo "error: CHANGELOG.md has no section for [$VERSION]" >&2; exit 1; }
printf '%s\n\n' "$SECTION"
sed "s/<version>/$VERSION/g" .github/release-install.md
printf '\nSHA-256 of `%s`: `%s`\n' "$(basename "$ZIP")" "$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
