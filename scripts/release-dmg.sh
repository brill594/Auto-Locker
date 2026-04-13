#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/AutoLocker.xcodeproj}"
SCHEME="${SCHEME:-AutoLocker}"
APP_NAME="${APP_NAME:-AutoLocker}"
TEAM_ID="${TEAM_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-0}"
SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"

DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
WORK_DIR="${WORK_DIR:-$(mktemp -d "/tmp/${APP_NAME}-dist.XXXXXX")}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$WORK_DIR/DerivedData}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$WORK_DIR/${APP_NAME}.xcarchive}"
EXPORT_DIR="${EXPORT_DIR:-$WORK_DIR/export}"
DMG_STAGING_DIR="${DMG_STAGING_DIR:-$WORK_DIR/dmg-root}"
DMG_PATH="${DMG_PATH:-$DIST_DIR/${APP_NAME}.dmg}"
VOL_NAME="${VOL_NAME:-$APP_NAME}"
EXPORT_OPTIONS_PLIST="$WORK_DIR/ExportOptions.plist"

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

find_exported_app() {
    local candidate

    candidate="$EXPORT_DIR/$APP_NAME.app"
    if [[ -d "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    candidate="$(find "$EXPORT_DIR" -maxdepth 1 -name "*.app" -print -quit)"
    if [[ -n "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    return 1
}

require_tool xcodebuild
require_tool hdiutil
require_tool xcrun
require_tool codesign
require_tool security

if [[ -z "$TEAM_ID" ]]; then
    echo "Set TEAM_ID to your Apple Developer Team ID." >&2
    echo "Example: TEAM_ID=ABCDE12345 scripts/release-dmg.sh" >&2
    exit 1
fi

if [[ "$SKIP_NOTARIZATION" != "1" && -z "$NOTARY_PROFILE" ]]; then
    echo "Set NOTARY_PROFILE to a notarytool keychain profile, or set SKIP_NOTARIZATION=1." >&2
    echo "Example: NOTARY_PROFILE=AutoLockerNotary TEAM_ID=$TEAM_ID scripts/release-dmg.sh" >&2
    exit 1
fi

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo "No 'Developer ID Application' certificate found in the keychain." >&2
    exit 1
fi

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR" "$DMG_STAGING_DIR" "$DERIVED_DATA_PATH"

cat >"$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
</dict>
</plist>
EOF

archive_cmd=(
    xcodebuild
    -project "$PROJECT_PATH"
    -scheme "$SCHEME"
    -configuration Release
    -destination "generic/platform=macOS"
    -derivedDataPath "$DERIVED_DATA_PATH"
    -archivePath "$ARCHIVE_PATH"
    archive
    DEVELOPMENT_TEAM="$TEAM_ID"
)

export_cmd=(
    xcodebuild
    -exportArchive
    -archivePath "$ARCHIVE_PATH"
    -exportPath "$EXPORT_DIR"
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"
)

if [[ "$ALLOW_PROVISIONING_UPDATES" == "1" ]]; then
    archive_cmd+=(-allowProvisioningUpdates)
    export_cmd+=(-allowProvisioningUpdates)
fi

"${archive_cmd[@]}"
"${export_cmd[@]}"

APP_PATH="$(find_exported_app)"

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
    echo "Failed to locate exported app in $EXPORT_DIR" >&2
    exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_PATH" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

if [[ "$SKIP_NOTARIZATION" != "1" ]]; then
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
fi

echo "App export: $APP_PATH"
echo "DMG: $DMG_PATH"
