#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app='dist/Codex Reset Destroyer.app'
mkdir -p "$app/Contents/MacOS" build
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos13.0" Engine.swift main.swift -o "build/$arch"
done
lipo -create build/arm64 build/x86_64 -output "$app/Contents/MacOS/QuotaClock"
cp Info.plist "$app/Contents/Info.plist"
codesign --force --options runtime --sign "${SIGN_IDENTITY:--}" "$app"
codesign --verify --strict "$app"
stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Codex Reset Destroyer.app"; ln -s /Applications "$stage/Applications"
hdiutil create -quiet -ov -format UDZO -volname 'Codex Reset Destroyer' -srcfolder "$stage" dist/Codex-Reset-Destroyer.dmg
(cd dist && shasum -a 256 Codex-Reset-Destroyer.dmg > SHA256SUMS)
