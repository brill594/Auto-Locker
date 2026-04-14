# Auto Locker

[中文说明](README.md)

Auto Locker is a native macOS app that locks your Mac automatically based on Bluetooth beacon presence, Wi-Fi rules, and timer-based policies. The project is built with SwiftUI and includes both the main app and a login-item background agent.

## Features

- Scan, bind, and monitor Bluetooth devices.
- Multi-device rules: any match, all match, or at least N matches.
- Away detection based on missing devices or RSSI thresholds.
- Wi-Fi whitelist / blacklist automation.
- Countdown prompt before locking, cancellation, and temporary pause modes.
- Menu bar controls and log inspection.
- Local structured log export.

## Requirements

- macOS
- Xcode 15 or later
- Command Line Tools for Xcode

## Local Build

### Open in Xcode

```sh
open AutoLocker.xcodeproj
```

Select the `AutoLocker` scheme and run or archive it directly.

### Build a Debug version from the command line

```sh
xcodebuild \
  -project AutoLocker.xcodeproj \
  -scheme AutoLocker \
  -configuration Debug \
  -derivedDataPath /tmp/AutoLockerDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The build artifact is generated at:

```text
/tmp/AutoLockerDerivedData/Build/Products/Debug/AutoLocker.app
```

### Build a Release version from the command line

```sh
xcodebuild \
  -project AutoLocker.xcodeproj \
  -scheme AutoLocker \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath /tmp/AutoLockerReleaseDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build
```

The Release artifact is generated at:

```text
/tmp/AutoLockerReleaseDerivedData/Build/Products/Release/AutoLocker.app
```

## Packaging

The repository includes two scripts for building release packages.

### 1. Build an unsigned DMG

Useful for local testing or internal distribution:

```sh
scripts/release-unsigned-dmg.sh
```

The output file is:

```text
dist/AutoLocker-unsigned.dmg
```

### 2. Build a signed DMG with optional notarization

For production release:

```sh
TEAM_ID=YOUR_TEAM_ID \
NOTARY_PROFILE=YOUR_NOTARY_PROFILE \
scripts/release-dmg.sh
```

If you want to sign the DMG but skip notarization:

```sh
TEAM_ID=YOUR_TEAM_ID \
SKIP_NOTARIZATION=1 \
scripts/release-dmg.sh
```

The output file is:

```text
dist/AutoLocker.dmg
```

If you only have an Xcode Personal Team, you cannot create a notarized Developer ID release, but you can build a locally development-signed DMG for permissions/TCC debugging:

```sh
SIGNING_MODE=development \
TEAM_ID=YOUR_PERSONAL_TEAM_ID \
SKIP_NOTARIZATION=1 \
ALLOW_PROVISIONING_UPDATES=1 \
scripts/release-dmg.sh
```

The output file is:

```text
dist/AutoLocker-development.dmg
```

## Runtime Notes

- On first launch, macOS asks for Bluetooth permission.
- Locking prefers `CGSession -suspend`, and falls back to launching the system screen saver if needed.
- For distribution to other users, a signed and notarized DMG is recommended.
