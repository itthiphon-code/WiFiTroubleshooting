#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
swift build -c release
BIN_DIR=$(swift build -c release --show-bin-path)
APP="$PWD/dist/Wi-Fi Troubleshooting.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/WiFiTroubleshooting" "$APP/Contents/MacOS/WiFiTroubleshooting.new"
mv -f "$APP/Contents/MacOS/WiFiTroubleshooting.new" "$APP/Contents/MacOS/WiFiTroubleshooting"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# Set SIGN_IDENTITY to an installed Apple signing identity for stable distribution.
codesign --force --sign "${SIGN_IDENTITY:--}" --options runtime "$APP"
codesign --verify --strict "$APP"
printf '%s\n' "$APP"
