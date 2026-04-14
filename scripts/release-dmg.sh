#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/AutoLocker.xcodeproj}"
SCHEME="${SCHEME:-AutoLocker}"
APP_NAME="${APP_NAME:-AutoLocker}"
TEAM_ID="${TEAM_ID:-}"
SIGNING_MODE="${SIGNING_MODE:-developer-id}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-0}"
SKIP_NOTARIZATION="${SKIP_NOTARIZATION:-0}"

DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
WORK_DIR="${WORK_DIR:-$(mktemp -d "/tmp/${APP_NAME}-dist.XXXXXX")}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$WORK_DIR/DerivedData}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$WORK_DIR/${APP_NAME}.xcarchive}"
EXPORT_DIR="${EXPORT_DIR:-$WORK_DIR/export}"
DMG_STAGING_DIR="${DMG_STAGING_DIR:-$WORK_DIR/dmg-root}"
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

find_built_app() {
    local candidate

    candidate="$DERIVED_DATA_PATH/Build/Products/Release/$APP_NAME.app"
    if [[ -d "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    candidate="$(find "$DERIVED_DATA_PATH/Build/Products/Release" -maxdepth 1 -name "*.app" -print -quit 2>/dev/null || true)"
    if [[ -n "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    return 1
}

has_codesigning_identity() {
    security find-identity -v -p codesigning | grep -F "$1" >/dev/null
}

detect_team_id_from_identity() {
    security find-identity -v -p codesigning \
        | sed -nE "/$1: / { s/.*\\(([A-Z0-9]{10})\\).*/\\1/; p; q; }"
}

require_tool xcodebuild
require_tool hdiutil
require_tool codesign
require_tool security

case "$SIGNING_MODE" in
    developer-id | developer_id | release)
        SIGNING_MODE="developer-id"
        EXPORT_METHOD="developer-id"
        CERTIFICATE_PATTERN="Developer ID Application"
        DEFAULT_DMG_PATH="$DIST_DIR/${APP_NAME}.dmg"
        ;;
    development | personal | debugging)
        SIGNING_MODE="development"
        EXPORT_METHOD="debugging"
        CERTIFICATE_PATTERN="Apple Development"
        DEFAULT_DMG_PATH="$DIST_DIR/${APP_NAME}-development.dmg"
        if [[ "$SKIP_NOTARIZATION" != "1" ]]; then
            echo "Development signing cannot be notarized; forcing SKIP_NOTARIZATION=1." >&2
            SKIP_NOTARIZATION=1
        fi
        if [[ -z "$TEAM_ID" ]]; then
            TEAM_ID="$(detect_team_id_from_identity "$CERTIFICATE_PATTERN")"
            if [[ -n "$TEAM_ID" ]]; then
                echo "Using TEAM_ID=$TEAM_ID from the first '$CERTIFICATE_PATTERN' identity." >&2
            fi
        fi
        ;;
    *)
        echo "Unsupported SIGNING_MODE: $SIGNING_MODE" >&2
        echo "Use SIGNING_MODE=developer-id or SIGNING_MODE=development." >&2
        exit 1
        ;;
esac

DMG_PATH="${DMG_PATH:-$DEFAULT_DMG_PATH}"

if [[ -z "$TEAM_ID" ]]; then
    if [[ "$SIGNING_MODE" == "development" ]]; then
        echo "Set TEAM_ID to the Personal Team ID shown in Xcode." >&2
        echo "Example: SIGNING_MODE=development TEAM_ID=ABCDE12345 SKIP_NOTARIZATION=1 ALLOW_PROVISIONING_UPDATES=1 scripts/release-dmg.sh" >&2
    else
        echo "Set TEAM_ID to your Apple Developer Team ID." >&2
        echo "Example: TEAM_ID=ABCDE12345 scripts/release-dmg.sh" >&2
    fi
    exit 1
fi

if [[ "$SKIP_NOTARIZATION" != "1" && -z "$NOTARY_PROFILE" ]]; then
    echo "Set NOTARY_PROFILE to a notarytool keychain profile, or set SKIP_NOTARIZATION=1." >&2
    echo "Example: NOTARY_PROFILE=AutoLockerNotary TEAM_ID=$TEAM_ID scripts/release-dmg.sh" >&2
    exit 1
fi

if [[ "$SKIP_NOTARIZATION" != "1" ]]; then
    require_tool xcrun
fi

if [[ "$ALLOW_PROVISIONING_UPDATES" != "1" ]] && ! has_codesigning_identity "$CERTIFICATE_PATTERN"; then
    echo "No '$CERTIFICATE_PATTERN' certificate found in the keychain." >&2
    if [[ "$SIGNING_MODE" == "development" ]]; then
        echo "Create one in Xcode, or rerun with ALLOW_PROVISIONING_UPDATES=1 so Xcode can manage signing assets." >&2
    fi
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
    <string>${EXPORT_METHOD}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
</dict>
</plist>
EOF

if [[ "$SIGNING_MODE" == "developer-id" ]]; then
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
else
    build_cmd=(
        xcodebuild
        -project "$PROJECT_PATH"
        -scheme "$SCHEME"
        -configuration Release
        -destination "generic/platform=macOS"
        -derivedDataPath "$DERIVED_DATA_PATH"
        build
        CODE_SIGN_STYLE=Automatic
        CODE_SIGN_IDENTITY="$CERTIFICATE_PATTERN"
        DEVELOPMENT_TEAM="$TEAM_ID"
    )

    if [[ "$ALLOW_PROVISIONING_UPDATES" == "1" ]]; then
        build_cmd+=(-allowProvisioningUpdates)
    fi

    "${build_cmd[@]}"

    APP_PATH="$(find_built_app)"
fi

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
    echo "Failed to locate built app." >&2
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

echo "Signing mode: $SIGNING_MODE"
echo "App: $APP_PATH"
echo "DMG: $DMG_PATH"
