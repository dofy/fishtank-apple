#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/validation
xcodegen generate > build/validation/project.log
swift test > build/validation/core-tests.log 2>&1
xcodebuild -project FishtankApple.xcodeproj -scheme FishtankMac -configuration Release \
  -derivedDataPath build/release-mac ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO build > build/validation/mac-release.log 2>&1
xcodebuild -project FishtankApple.xcodeproj -scheme FishtankPad -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build/release-pad \
  -archivePath build/FishtankPad.xcarchive CODE_SIGNING_ALLOWED=NO archive > build/validation/pad-archive.log 2>&1
python3 tools/check-release-bundle.py build/release-mac/Build/Products/Release/FishtankMac.app \
  build/FishtankPad.xcarchive/Products/Applications/FishtankPad.app
# Optional existing simulator UUID; no runtimes or dependencies are installed.
if [[ -n "${FISHTANK_SIMULATOR_ID:-}" ]]; then
  result="build/validation/UI-$(date +%Y%m%d-%H%M%S).xcresult"
  xcodebuild -project FishtankApple.xcodeproj -scheme FishtankPad -configuration Debug \
    -destination "platform=iOS Simulator,id=$FISHTANK_SIMULATOR_ID" -derivedDataPath build/simulator \
    -resultBundlePath "$result" CODE_SIGNING_ALLOWED=NO test > build/validation/ui-tests.log 2>&1
fi
printf 'Local release checks passed. Public signing, notarization and device acceptance are separate gates.\n'
