#!/bin/bash
# Draws the app icon (scripts/make-icon.swift) and writes every size into App/Assets.xcassets/AppIcon.appiconset.
# Usage: scripts/make-app-icon.sh
set -euo pipefail
cd "$(dirname "$0")/.."
SET=App/Assets.xcassets/AppIcon.appiconset
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
swiftc -O scripts/make-icon.swift -o "$TMP/make-icon"
"$TMP/make-icon" "$TMP/icon-1024.png"
mkdir -p "$SET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$TMP/icon-1024.png" --out "$SET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2)); sips -z $d $d "$TMP/icon-1024.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
echo "$SET"
