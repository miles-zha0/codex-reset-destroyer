#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app='dist/Codex Reset Destroyer.app'
mkdir -p "$app/Contents/MacOS"
swiftc -O -target arm64-apple-macos13.0 Engine.swift main.swift -o "$app/Contents/MacOS/QuotaClock"
test "$(lipo -archs "$app/Contents/MacOS/QuotaClock")" = arm64
cp Info.plist "$app/Contents/Info.plist"
codesign --force --options runtime --sign "${SIGN_IDENTITY:--}" "$app"
codesign --verify --strict "$app"
stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Codex Reset Destroyer.app"; ln -s /Applications "$stage/Applications"
hdiutil create -quiet -ov -format UDZO -volname 'Codex Reset Destroyer' -srcfolder "$stage" dist/Codex-Reset-Destroyer.dmg
(cd dist && shasum -a 256 Codex-Reset-Destroyer.dmg > SHA256SUMS)
