# Auto Locker

Auto Locker 是一个 macOS 原生 Swift 应用，用蓝牙设备存在状态、Wi‑Fi 规则和定时策略来自动锁屏。项目使用 SwiftUI 构建，包含主应用和登录项代理进程。

## 功能特性

- 蓝牙设备扫描、绑定和守护。
- 多设备规则：任一命中、全部命中、至少 N 个命中。
- 离开判定支持设备丢失和 RSSI 阈值。
- Wi‑Fi 白名单 / 黑名单联动规则。
- 锁屏前倒计时提示、取消和临时暂停。
- 菜单栏常驻控制和日志查看。
- 本地结构化日志导出。

## 环境要求

- macOS
- Xcode 15 或更高版本
- Command Line Tools for Xcode

## 本地构建

### 在 Xcode 中打开

```sh
open AutoLocker.xcodeproj
```

选择 `AutoLocker` Scheme，直接运行或 Archive 即可。

### 命令行构建 Debug 版本

```sh
xcodebuild \
  -project AutoLocker.xcodeproj \
  -scheme AutoLocker \
  -configuration Debug \
  -derivedDataPath /tmp/AutoLockerDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

构建产物默认位于：

```text
/tmp/AutoLockerDerivedData/Build/Products/Debug/AutoLocker.app
```

### 命令行构建 Release 版本

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

Release 构建产物默认位于：

```text
/tmp/AutoLockerReleaseDerivedData/Build/Products/Release/AutoLocker.app
```

## 打包指南

仓库内提供了两个打包脚本，方便别人自行构建发布包。

### 1. 构建未签名 DMG

适合本地测试或内部分发：

```sh
scripts/release-unsigned-dmg.sh
```

输出文件默认位于：

```text
dist/AutoLocker-unsigned.dmg
```

### 2. 构建签名并可选公证的 DMG

用于正式发布：

```sh
TEAM_ID=YOUR_TEAM_ID \
NOTARY_PROFILE=YOUR_NOTARY_PROFILE \
scripts/release-dmg.sh
```

如果只想签名打包、跳过公证：

```sh
TEAM_ID=YOUR_TEAM_ID \
SKIP_NOTARIZATION=1 \
scripts/release-dmg.sh
```

输出文件默认位于：

```text
dist/AutoLocker.dmg
```

如果只有 Xcode Personal Team，不能进行 Developer ID 公证发布，但可以构建一个本机开发签名 DMG，用于权限/TCC 调试：

```sh
SIGNING_MODE=development \
TEAM_ID=YOUR_PERSONAL_TEAM_ID \
SKIP_NOTARIZATION=1 \
ALLOW_PROVISIONING_UPDATES=1 \
scripts/release-dmg.sh
```

输出文件默认位于：

```text
dist/AutoLocker-development.dmg
```

## 运行说明

- 首次运行时，macOS 会请求蓝牙权限。
- 锁屏优先使用 `CGSession -suspend`，不可用时回退到启动系统屏保。
- 如果要分发给其他用户，建议使用签名并完成 notarization 的 DMG。
