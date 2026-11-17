#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -m)" == arm64 ]] || { echo 'Apple Silicon Mac required' >&2; exit 1; }
output="$(pwd)/dist/Fishtank-1.6.1-macos-arm64.dmg"
[[ ! -e "$output" ]] || { echo "Refusing to overwrite $output" >&2; exit 1; }
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
xcodegen generate
xcodebuild -project FishtankApple.xcodeproj -scheme FishtankMac -configuration Release \
  -derivedDataPath "$tmp/DerivedData" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
mkdir -p "$tmp/stage" dist
ditto "$tmp/DerivedData/Build/Products/Release/FishtankMac.app" "$tmp/stage/Fishtank.app"
codesign --force --sign - --entitlements Configuration/FishtankMac.entitlements --timestamp=none "$tmp/stage/Fishtank.app"
codesign --verify --deep --strict "$tmp/stage/Fishtank.app"
[[ "$(lipo -archs "$tmp/stage/Fishtank.app/Contents/MacOS/FishtankMac")" == arm64 ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$tmp/stage/Fishtank.app/Contents/Info.plist")" == xyz.phpz.app.fishtank ]]
ln -s /Applications "$tmp/stage/Applications"
cat > "$tmp/stage/Read Me.txt" <<'NOTE'
Fishtank for macOS — Apple Silicon preview
Drag Fishtank to Applications. This app is not notarized by Apple. After trying
 to open it, go to System Settings > Privacy & Security > Open Anyway.
If upgrading from an earlier Fishtank, read the migration instructions at:
https://github.com/dofy/fishtank-apple#upgrading-from-the-previous-mac-preview
Migrate before opening the new version, and keep your old app and data until
 you have verified the transfer.
NOTE
hdiutil create -volname 'Fishtank 1.6.1 Preview' -srcfolder "$tmp/stage" -fs HFS+ -format UDZO "$output" >/dev/null
hdiutil verify "$output" >/dev/null
printf 'Created %s\n' "$output"
