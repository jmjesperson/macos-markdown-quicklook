#!/bin/bash
# Builds an unsigned (ad-hoc signed) release zip of MarkdownQuicklook.app for GitHub Releases.
# Usage: scripts/build-release.sh            -> build/release/MarkdownQuicklook-<version>.zip
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=build/release
ARCHIVE=$OUT/MarkdownQuicklook.xcarchive
rm -rf "$OUT"
mkdir -p "$OUT"

# Ad-hoc signing ("-"), without the debugger entitlement Xcode adds by default.
xcodebuild archive \
  -project MarkdownQuicklook.xcodeproj -scheme MarkdownQuicklook -configuration Release \
  -archivePath "$ARCHIVE" -derivedDataPath build/DerivedData-release \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  -quiet

# Archiving leaves a copy of the app in the build folder, and macOS registers its extension, which can
# then take over Quick Look from the installed copy. Unregister it and remove the build folder.
INTERMEDIATE=build/DerivedData-release/Build/Intermediates.noindex/ArchiveIntermediates/MarkdownQuicklook/InstallationBuildProductsLocation/Applications/MarkdownQuicklook.app
pluginkit -r "$INTERMEDIATE/Contents/PlugIns/PreviewExtension.appex" 2>/dev/null || true
rm -rf build/DerivedData-release

APP="$ARCHIVE/Products/Applications/MarkdownQuicklook.app"
codesign --verify --deep --strict "$APP"

EXT="$APP/Contents/PlugIns/PreviewExtension.appex"
# Capture the entitlements first: piping codesign into `grep -q` under pipefail can fail with SIGPIPE.
EXT_ENTITLEMENTS=$(codesign -d --entitlements - "$EXT" 2>/dev/null)
APP_ENTITLEMENTS=$(codesign -d --entitlements - "$APP" 2>/dev/null)
grep -q com.apple.security.app-sandbox <<<"$EXT_ENTITLEMENTS" \
  || { echo "error: the preview extension is not sandboxed" >&2; exit 1; }
if grep -q get-task-allow <<<"$APP_ENTITLEMENTS$EXT_ENTITLEMENTS"; then
  echo "error: release build carries get-task-allow" >&2; exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
ZIP="$OUT/MarkdownQuicklook-$VERSION.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
# The archived app's own extension may also have been registered; the zip is the artifact.
pluginkit -r "$APP/Contents/PlugIns/PreviewExtension.appex" 2>/dev/null || true
echo "$ZIP"
