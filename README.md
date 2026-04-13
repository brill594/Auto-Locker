# Auto Locker

Auto Locker 是一个 macOS 原生 Swift 应用，根据 `auto_locker_prd_v_1.md` 实现蓝牙信标守护、网络规则、定时锁屏、暂停机制和结构化日志。

## 打开与构建

```sh
open AutoLocker.xcodeproj
```

或使用命令行构建：

```sh
xcodebuild -project AutoLocker.xcodeproj -scheme AutoLocker -configuration Debug -derivedDataPath /tmp/AutoLockerDerivedData CODE_SIGNING_ALLOWED=NO build
```

构建产物位于：

```text
/tmp/AutoLockerDerivedData/Build/Products/Debug/AutoLocker.app
```

## 已实现范围

- macOS 主窗口应用，使用 SwiftUI 分栏：总览、信标、规则、网络规则、日志、高级。
- 菜单栏常驻入口：开启/关闭守护、暂停、恢复、查看信标状态、打开主窗口、打开日志。
- CoreBluetooth 定时扫描、发现设备、绑定/移除信标、配置识别字段和缺失容忍。
- 解析 Manufacturer Data 中的厂商 ID，通过 Bluetooth SIG Company Identifiers 内置表显示厂商名。
- 为常见厂商显示对应图标，未命中图标映射时沿用默认蓝牙天线图标。
- 信标页支持按设备名、厂商、厂商数据、系统标识符搜索，并可按发现顺序、厂商名、信号强度、设备名、最后出现时间排序。
- 信标页提供 30 秒长扫描和清空扫描结果，便于排查低频广播设备。
- 多信标规则：任一、全部、至少 N 个。
- 离开判定：检测不到设备、RSSI 阈值。
- 抗抖：延迟吸收、连续丢失判定。
- 锁屏前提示：浮层倒计时、取消、暂停 15 分钟、立即锁屏。
- 暂停机制：15 分钟、30 分钟、1 小时、手动恢复、下次解锁后恢复、离开当前 Wi-Fi 后恢复、今天结束前、自定义时间点。
- CoreWLAN 读取当前 Wi-Fi，支持白名单/黑名单规则。
- 独立定时锁屏。
- 稳定性测试：默认 120 秒采样，输出连续性、RSSI 波动和建议评分。
- 结构化事件日志：本地无限保存、单条删除、清空、JSON 导出。
- 应用启动后按上次守护状态自动恢复。

## 系统说明

首次运行时 macOS 会请求蓝牙权限。锁屏动作使用系统提供的 `CGSession -suspend`，如果该工具不可用则回退到打开系统屏幕保护程序。
