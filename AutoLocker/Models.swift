import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case overview
    case beacons
    case rules
    case network
    case logs
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "总览"
        case .beacons: return "信标"
        case .rules: return "规则"
        case .network: return "网络规则"
        case .logs: return "日志"
        case .advanced: return "高级"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.67percent"
        case .beacons: return "dot.radiowaves.left.and.right"
        case .rules: return "slider.horizontal.3"
        case .network: return "wifi"
        case .logs: return "list.bullet.rectangle"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
}

enum GuardRuntimeState: String, Codable {
    case disabled
    case guarding
    case paused
    case unavailable
    case prompting

    var label: String {
        switch self {
        case .disabled: return "未启用"
        case .guarding: return "守护中"
        case .paused: return "已暂停"
        case .unavailable: return "不可用"
        case .prompting: return "提示中"
        }
    }

    var systemImage: String {
        switch self {
        case .disabled: return "pause.circle"
        case .guarding: return "lock.shield"
        case .paused: return "clock.badge.pause"
        case .unavailable: return "exclamationmark.triangle"
        case .prompting: return "bell.badge"
        }
    }
}

enum BluetoothPowerState: String, Codable {
    case unknown
    case resetting
    case unsupported
    case unauthorized
    case poweredOff
    case poweredOn

    var label: String {
        switch self {
        case .unknown: return "初始化中"
        case .resetting: return "重置中"
        case .unsupported: return "不支持"
        case .unauthorized: return "未授权"
        case .poweredOff: return "已关闭"
        case .poweredOn: return "可用"
        }
    }
}

enum DetectionMode: String, Codable, CaseIterable, Identifiable {
    case missing
    case rssiThreshold

    var id: String { rawValue }

    var label: String {
        switch self {
        case .missing: return "检测不到设备"
        case .rssiThreshold: return "信号强度低于阈值"
        }
    }
}

enum DebounceStrategy: String, Codable, CaseIterable, Identifiable {
    case delayOnly
    case consecutiveMisses

    var id: String { rawValue }

    var label: String {
        switch self {
        case .delayOnly: return "仅依赖延迟"
        case .consecutiveMisses: return "连续丢失判定"
        }
    }
}

enum MultiBeaconLogic: String, Codable, CaseIterable, Identifiable {
    case any
    case all
    case atLeast

    var id: String { rawValue }

    var label: String {
        switch self {
        case .any: return "任一存在即可"
        case .all: return "必须全部存在"
        case .atLeast: return "至少 N 个在场"
        }
    }
}

enum MatchField: String, Codable, CaseIterable, Identifiable, Hashable {
    case name
    case identifier
    case manufacturerData

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: return "设备名"
        case .identifier: return "系统设备标识符"
        case .manufacturerData: return "Manufacturer Data"
        }
    }
}

enum LogEventType: String, Codable, CaseIterable, Identifiable {
    case scan
    case settings
    case prompt
    case cancel
    case pause
    case resume
    case lock
    case timer
    case unavailable
    case network
    case stability

    var id: String { rawValue }

    var label: String {
        switch self {
        case .scan: return "扫描"
        case .settings: return "设置"
        case .prompt: return "提示"
        case .cancel: return "取消"
        case .pause: return "暂停"
        case .resume: return "恢复"
        case .lock: return "锁屏"
        case .timer: return "定时"
        case .unavailable: return "不可用"
        case .network: return "网络"
        case .stability: return "稳定性测试"
        }
    }
}

enum PauseMode: String, Codable, CaseIterable, Identifiable {
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case manual
    case nextUnlock
    case wifiLeaves
    case endOfDay
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fifteenMinutes: return "暂停 15 分钟"
        case .thirtyMinutes: return "暂停 30 分钟"
        case .oneHour: return "暂停 1 小时"
        case .manual: return "直到手动恢复"
        case .nextUnlock: return "直到下次解锁后恢复"
        case .wifiLeaves: return "离开当前 Wi-Fi 后恢复"
        case .endOfDay: return "今天结束前"
        case .custom: return "指定时间点"
        }
    }
}

enum NetworkRuleBehavior: String, Codable, CaseIterable, Identifiable {
    case suppressLock
    case pauseGuard
    case enableGuard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .suppressLock: return "命中时不触发锁屏"
        case .pauseGuard: return "命中时暂停守护"
        case .enableGuard: return "命中时自动启用守护"
        }
    }
}

struct DiscoveredDevice: Identifiable, Codable, Hashable {
    var id: UUID
    var identifier: String
    var name: String
    var localName: String?
    var manufacturerDataHex: String?
    var manufacturerCompanyID: UInt16?
    var serviceUUIDs: [String]
    var solicitedServiceUUIDs: [String]
    var overflowServiceUUIDs: [String]
    var serviceDataHex: [String: String]
    var txPowerLevel: Int?
    var isConnectable: Bool?
    var advertisementKeys: [String]
    var rssi: Int
    var lastSeen: Date

    var displayName: String {
        if !name.isEmpty {
            return name
        }
        if let localName, !localName.isEmpty {
            return localName
        }
        return "未命名设备"
    }

    var manufacturerName: String? {
        manufacturerCompanyID.flatMap { ManufacturerDirectory.name(for: $0) }
    }

    var manufacturerDisplayName: String? {
        manufacturerCompanyID.map { ManufacturerDirectory.displayName(for: $0) }
    }

    var manufacturerIconSystemName: String? {
        ManufacturerDirectory.iconSystemName(for: manufacturerCompanyID)
    }

    var summary: String {
        var parts = ["RSSI \(rssi) dBm"]
        if let manufacturerDisplayName {
            parts.append("厂商 \(manufacturerDisplayName)")
        }
        if let manufacturerDataHex, !manufacturerDataHex.isEmpty {
            parts.append("厂商数据 \(manufacturerDataHex.prefix(16))")
        }
        if !serviceUUIDs.isEmpty {
            parts.append("服务 \(serviceUUIDs.prefix(3).joined(separator: ", "))")
        }
        if let isConnectable {
            parts.append(isConnectable ? "可连接" : "不可连接")
        }
        return parts.joined(separator: " · ")
    }

    var rawFieldSummary: String {
        var parts: [String] = []
        if !serviceUUIDs.isEmpty {
            parts.append("Service UUIDs: \(serviceUUIDs.joined(separator: ", "))")
        }
        if !serviceDataHex.isEmpty {
            let serviceData = serviceDataHex.keys.sorted().map { "\($0)=\(serviceDataHex[$0] ?? "")" }
            parts.append("Service Data: \(serviceData.joined(separator: ", "))")
        }
        if !advertisementKeys.isEmpty {
            parts.append("Keys: \(advertisementKeys.joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }
}

struct Beacon: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var displayName: String
    var manufacturerInfo: String?
    var manufacturerCompanyID: UInt16?
    var manufacturerName: String?
    var expectedIdentifier: String?
    var expectedName: String?
    var expectedManufacturerDataHex: String?
    var selectedFields: [MatchField] = [.identifier, .name]
    var missingTolerance: Int = 0
    var isPrimary: Bool = false
    var createdAt: Date = Date()
    var lastSeen: Date?
    var lastRSSI: Int?

    init(from device: DiscoveredDevice) {
        displayName = device.displayName
        manufacturerInfo = device.manufacturerDisplayName ?? device.manufacturerDataHex
        manufacturerCompanyID = device.manufacturerCompanyID
        manufacturerName = device.manufacturerName
        expectedIdentifier = device.identifier
        expectedName = device.displayName
        expectedManufacturerDataHex = device.manufacturerDataHex
        lastSeen = device.lastSeen
        lastRSSI = device.rssi
        if device.manufacturerDataHex != nil {
            selectedFields = [.identifier, .name, .manufacturerData]
        }
    }

    var manufacturerDisplayName: String? {
        if let manufacturerCompanyID {
            return ManufacturerDirectory.displayName(for: manufacturerCompanyID)
        }
        if let manufacturerName, !manufacturerName.isEmpty {
            return manufacturerName
        }
        return manufacturerInfo
    }

    var manufacturerIconSystemName: String? {
        ManufacturerDirectory.iconSystemName(for: manufacturerCompanyID)
    }

    var selectedFieldSummary: String {
        if selectedFields.isEmpty {
            return "未选择识别字段"
        }
        return selectedFields.map(\.label).joined(separator: "、")
    }
}

extension ManufacturerDirectory {
    static func iconSystemName(for companyID: UInt16?) -> String? {
        guard let companyID else {
            return nil
        }

        switch companyID {
        case 0x004C:
            return "apple.logo"
        case 0x0002, 0x000A, 0x001D, 0x00B8, 0x00D7, 0x00D8, 0x011A:
            return "cpu"
        case 0x0006:
            return "square.grid.2x2"
        case 0x00E0, 0x018E:
            return "globe"
        case 0x0056, 0x0057, 0x009E, 0x00CC, 0x012D, 0x0EDE:
            return "headphones"
        case 0x0059:
            return "dot.radiowaves.left.and.right"
        case 0x006B, 0x009F, 0x00D1, 0x0157:
            return "heart.circle"
        case 0x0075, 0x027D, 0x038F, 0x072F, 0x079A, 0x0837, 0x08A4:
            return "iphone"
        case 0x0087, 0x067C:
            return "location.circle"
        case 0x0171:
            return "shippingbox"
        case 0x01AB, 0x058E:
            return "person.2.circle"
        case 0x01DA:
            return "keyboard"
        case 0x0CC2:
            return "bolt.circle"
        default:
            return nil
        }
    }
}

struct GuardRules: Codable, Equatable {
    var detectionMode: DetectionMode = .missing
    var delaySeconds: Int = 15
    var rssiThreshold: Int = -82
    var debounceStrategy: DebounceStrategy = .delayOnly
    var requiredConsecutiveMisses: Int = 3
    var multiBeaconLogic: MultiBeaconLogic = .any
    var requiredBeaconCount: Int = 1
    var preLockCountdownSeconds: Int = 10
    var cancelThreshold: Int = 3
    var cancelWindowMinutes: Int = 15

    var summary: String {
        let detection = detectionMode == .missing ? "检测不到持续 \(delaySeconds) 秒" : "RSSI < \(rssiThreshold) dBm 持续 \(delaySeconds) 秒"
        let multi = multiBeaconLogic == .atLeast ? "至少 \(requiredBeaconCount) 个信标" : multiBeaconLogic.label
        return "\(detection)，\(multi)，提示 \(preLockCountdownSeconds) 秒"
    }
}

struct NetworkRules: Codable, Equatable {
    var whitelistSSIDs: [String] = []
    var blacklistSSIDs: [String] = []
    var whitelistBehavior: NetworkRuleBehavior = .suppressLock
    var blacklistBehavior: NetworkRuleBehavior = .enableGuard
}

struct AdvancedSettings: Codable, Equatable {
    var foregroundScanIntervalSeconds: Int = 8
    var discoveryScanDurationSeconds: Int = 5
    var backgroundScanIntervalSeconds: Int = 30
    var lowFrequencyScanIntervalSeconds: Int = 60
    var autoRestoreGuard: Bool = true
    var fieldPriority: [MatchField] = [.identifier, .manufacturerData, .name]

    init() {}

    private enum CodingKeys: String, CodingKey {
        case foregroundScanIntervalSeconds
        case discoveryScanDurationSeconds
        case backgroundScanIntervalSeconds
        case lowFrequencyScanIntervalSeconds
        case autoRestoreGuard
        case fieldPriority
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        foregroundScanIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .foregroundScanIntervalSeconds) ?? 8
        discoveryScanDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .discoveryScanDurationSeconds) ?? 5
        backgroundScanIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .backgroundScanIntervalSeconds) ?? 30
        lowFrequencyScanIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .lowFrequencyScanIntervalSeconds) ?? 60
        autoRestoreGuard = try container.decodeIfPresent(Bool.self, forKey: .autoRestoreGuard) ?? true
        fieldPriority = try container.decodeIfPresent([MatchField].self, forKey: .fieldPriority) ?? [.identifier, .manufacturerData, .name]
    }
}

struct ActivePause: Codable, Equatable {
    var mode: PauseMode
    var startedAt: Date
    var until: Date?
    var wifiSSID: String?

    var label: String {
        switch mode {
        case .manual:
            return "已暂停，等待手动恢复"
        case .nextUnlock:
            return "已暂停，下次解锁后恢复"
        case .wifiLeaves:
            return "已暂停，离开 \(wifiSSID ?? "当前 Wi-Fi") 后恢复"
        case .endOfDay, .custom, .fifteenMinutes, .thirtyMinutes, .oneHour:
            if let until {
                return "已暂停至 \(until.formatted(date: .omitted, time: .shortened))"
            }
            return mode.label
        }
    }
}

struct BeaconSnapshot: Codable, Hashable {
    var id: UUID
    var displayName: String
    var manufacturerName: String?
    var selectedFields: [MatchField]
    var lastRSSI: Int?
    var lastSeen: Date?
}

struct GuardRuleSnapshot: Codable, Hashable {
    var detectionMode: DetectionMode
    var delaySeconds: Int
    var rssiThreshold: Int
    var debounceStrategy: DebounceStrategy
    var multiBeaconLogic: MultiBeaconLogic
    var requiredBeaconCount: Int
    var preLockCountdownSeconds: Int
}

struct NetworkSnapshot: Codable, Hashable {
    var ssid: String?
    var whitelistHit: Bool
    var blacklistHit: Bool
}

struct EventLog: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var type: LogEventType
    var reason: String
    var beaconSnapshots: [BeaconSnapshot]
    var networkSnapshot: NetworkSnapshot
    var ruleSnapshot: GuardRuleSnapshot
    var debug: [String: String]

    var displayReason: String {
        reason.isEmpty ? type.label : reason
    }
}

struct PersistedState: Codable {
    var guardEnabled: Bool
    var beacons: [Beacon]
    var rules: GuardRules
    var networkRules: NetworkRules
    var advanced: AdvancedSettings
    var logs: [EventLog]
    var activePause: ActivePause?
}

struct StabilityTestResult: Codable, Equatable {
    var beaconID: UUID
    var startedAt: Date
    var endedAt: Date
    var sampleCount: Int
    var seenSamples: Int
    var averageRSSI: Double?
    var rssiSpread: Int?
    var score: Int
    var recommendation: String
}

struct StabilityTestSession {
    var beaconID: UUID
    var startedAt: Date = Date()
    var duration: TimeInterval = 120
    var samples: [(date: Date, rssi: Int?)] = []

    var remainingSeconds: Int {
        max(0, Int(duration - Date().timeIntervalSince(startedAt)))
    }
}
