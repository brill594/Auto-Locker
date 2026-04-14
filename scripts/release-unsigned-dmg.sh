#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/AutoLocker.xcodeproj}"
SCHEME="${SCHEME:-AutoLocker}"
APP_NAME="${APP_NAME:-AutoLocker}"

DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
WORK_DIR="${WORK_DIR:-$(mktemp -d "/tmp/${APP_NAME}-unsigned.XXXXXX")}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$WORK_DIR/DerivedData}"
DMG_STAGING_DIR="${DMG_STAGING_DIR:-$WORK_DIR/dmg-root}"
APP_PATH="${APP_PATH:-$DERIVED_DATA_PATH/Build/Products/Release/${APP_NAME}.app}"
DMG_PATH="${DMG_PATH:-$DIST_DIR/${APP_NAME}-unsigned.dmg}"
VOL_NAME="${VOL_NAME:-$APP_NAME}"

cleanup() {
    if [[ "${KEEP_WORK_DIR:-0}" != "1" && -d "$WORK_DIR" ]]; then
        rm -rf "$WORK_DIR"
    fi
}

trap cleanup EXIT

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required tool: $1" >&2
        exit 1
    fi
}

require_tool xcodebuild
require_tool hdiutil

cat >&2 <<'EOF'
WARNING: this script creates an unsigned build for quick UI checks only.
TCC permissions such as Bluetooth/Input Monitoring are tied to code-signing identity;
use scripts/release-dmg.sh with a Developer ID Team ID for permission debugging.
EOF

mkdir -p "$DIST_DIR"
rm -rf "$DERIVED_DATA_PATH" "$DMG_STAGING_DIR"
rm -f "$DMG_PATH"

xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    build

if [[ ! -d "$APP_PATH" ]]; then
    echo "Failed to locate built app: $APP_PATH" >&2
    exit 1
fi

mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_PATH" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo "Unsigned app: $APP_PATH"
echo "Unsigned DMG: $DMG_PATH"
echo "Do not use this unsigned DMG to validate TCC/Bluetooth permissions."
