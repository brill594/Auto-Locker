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

enum LocationAuthorizationState: String, Codable {
    case notDetermined
    case restricted
    case denied
    case authorizedWhenInUse
    case authorizedAlways

    var label: String {
        switch self {
        case .notDetermined: return "未请求"
        case .restricted: return "受限"
        case .denied: return "已拒绝"
        case .authorizedWhenInUse: return "使用时允许"
        case .authorizedAlways: return "始终允许"
        }
    }

    var allowsWiFiReading: Bool {
        switch self {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .notDetermined, .restricted, .denied:
            return false
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
        if let serviceUUIDVendorName {
            return "\(serviceUUIDVendorName) 广播"
        }
        return "未命名设备"
    }

    var manufacturerName: String? {
        if let manufacturerCompanyID {
            return ManufacturerDirectory.name(for: manufacturerCompanyID)
        }
        return serviceUUIDVendorName
    }

    var manufacturerDisplayName: String? {
        if let manufacturerCompanyID {
            return ManufacturerDirectory.displayName(for: manufacturerCompanyID)
        }
        if let serviceUUIDVendorMatch {
            return "\(serviceUUIDVendorMatch.name) (Service UUID \(serviceUUIDVendorMatch.displayUUID))"
        }
        return nil
    }

    var manufacturerIconSystemName: String? {
        ManufacturerDirectory.iconSystemName(for: manufacturerCompanyID)
            ?? BluetoothMemberUUIDDirectory.iconSystemName(for: serviceUUIDVendorName)
    }

    var serviceUUIDVendorName: String? {
        serviceUUIDVendorMatch?.name
    }

    var serviceUUIDVendorMatch: MemberUUIDVendorMatch? {
        BluetoothMemberUUIDDirectory.match(for: advertisedServiceUUIDs)
    }

    var advertisedServiceUUIDs: [String] {
        let values = serviceUUIDs + solicitedServiceUUIDs + overflowServiceUUIDs + serviceDataHex.keys.sorted()
        var seen = Set<String>()
        return values.filter { uuid in
            seen.insert(BluetoothMemberUUIDDirectory.normalizedUUID(uuid)).inserted
        }
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
        if !serviceDataHex.isEmpty {
            parts.append("Service Data \(serviceDataHex.keys.sorted().prefix(3).joined(separator: ", "))")
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
        if !solicitedServiceUUIDs.isEmpty {
            parts.append("Solicited UUIDs: \(solicitedServiceUUIDs.joined(separator: ", "))")
        }
        if !overflowServiceUUIDs.isEmpty {
            parts.append("Overflow UUIDs: \(overflowServiceUUIDs.joined(separator: ", "))")
        }
        if !serviceDataHex.isEmpty {
            let serviceData = serviceDataHex.keys.sorted().map { "\($0)=\(serviceDataHex[$0] ?? "")" }
            parts.append("Service Data: \(serviceData.joined(separator: ", "))")
        }
        if let txPowerLevel {
            parts.append("Tx Power: \(txPowerLevel)")
        }
        if let isConnectable {
            parts.append("Connectable: \(isConnectable ? "yes" : "no")")
        }
        if !advertisementKeys.isEmpty {
            parts.append("Keys: \(advertisementKeys.joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }

    func mergingAdvertisementUpdate(_ update: DiscoveredDevice) -> DiscoveredDevice {
        var merged = update
        merged.id = id
        merged.name = update.name.isEmpty ? name : update.name
        merged.localName = update.localName ?? localName
        merged.manufacturerDataHex = update.manufacturerDataHex ?? manufacturerDataHex
        merged.manufacturerCompanyID = update.manufacturerCompanyID ?? manufacturerCompanyID
        merged.serviceUUIDs = mergedUnique(existing: serviceUUIDs, latest: update.serviceUUIDs)
        merged.solicitedServiceUUIDs = mergedUnique(existing: solicitedServiceUUIDs, latest: update.solicitedServiceUUIDs)
        merged.overflowServiceUUIDs = mergedUnique(existing: overflowServiceUUIDs, latest: update.overflowServiceUUIDs)
        merged.serviceDataHex = serviceDataHex.merging(update.serviceDataHex) { _, latest in latest }
        merged.txPowerLevel = update.txPowerLevel ?? txPowerLevel
        merged.isConnectable = update.isConnectable ?? isConnectable
        merged.advertisementKeys = mergedUnique(existing: advertisementKeys, latest: update.advertisementKeys)
        return merged
    }

    func isLikelySameAdvertisement(as other: DiscoveredDevice) -> Bool {
        if id == other.id || identifier == other.identifier {
            return true
        }

        if let manufacturerDataHex,
           let otherManufacturerDataHex = other.manufacturerDataHex,
           !manufacturerDataHex.isEmpty,
           manufacturerDataHex == otherManufacturerDataHex {
            return true
        }

        if !serviceDataHex.isEmpty,
           serviceDataHex == other.serviceDataHex {
            return true
        }

        if rawNameForIdentity != nil,
           rawNameForIdentity == other.rawNameForIdentity,
           manufacturerCompanyID != nil,
           manufacturerCompanyID == other.manufacturerCompanyID {
            return true
        }

        guard abs(lastSeen.timeIntervalSince(other.lastSeen)) <= 10 * 60 else {
            return false
        }

        let serviceDataKeys = normalizedUUIDSet(serviceDataHex.keys)
        let otherServiceDataKeys = normalizedUUIDSet(other.serviceDataHex.keys)
        guard !serviceDataKeys.intersection(otherServiceDataKeys).isEmpty else {
            return false
        }

        let serviceUUIDSet = normalizedUUIDSet(advertisedServiceUUIDs)
        let otherServiceUUIDSet = normalizedUUIDSet(other.advertisedServiceUUIDs)
        guard serviceUUIDSet == otherServiceUUIDSet else {
            return false
        }

        if rawNameForIdentity != nil,
           rawNameForIdentity == other.rawNameForIdentity {
            return true
        }

        if serviceUUIDVendorName != nil,
           serviceUUIDVendorName == other.serviceUUIDVendorName,
           isConnectable == other.isConnectable,
           abs(rssi - other.rssi) <= 20 {
            return true
        }

        return false
    }

    private func mergedUnique(existing: [String], latest: [String]) -> [String] {
        var seen = Set<String>()
        return (existing + latest).filter { value in
            seen.insert(value).inserted
        }
    }

    private var rawNameForIdentity: String? {
        let value: String?
        if !name.isEmpty {
            value = name
        } else {
            value = localName
        }

        guard let value else {
            return nil
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? nil : normalized
    }

    private func normalizedUUIDSet<S: Sequence>(_ values: S) -> Set<String> where S.Element == String {
        Set(values.map { BluetoothMemberUUIDDirectory.normalizedUUID($0) })
    }
}

struct MemberUUIDVendorMatch: Hashable {
    var uuid: String
    var name: String

    var displayUUID: String {
        let normalized = BluetoothMemberUUIDDirectory.normalizedUUID(uuid)
        if normalized.count == 4 {
            return "0x\(normalized)"
        }
        return uuid
    }
}

// Member UUIDs are used by many non-connectable advertisements, including the Google 0xFEF3 packet shown by nRF Connect.
// Source: https://bitbucket.org/bluetooth-SIG/public/src/HEAD/assigned_numbers/uuids/member_uuids.yaml
enum BluetoothMemberUUIDDirectory {
    static let memberUUIDNames: [String: String] = [
        "FC3E": "Google LLC",
        "FC46": "Xiaomi",
        "FC56": "Google LLC",
        "FC66": "Xiaomi Inc.",
        "FC73": "Google LLC",
        "FC75": "Xiaomi Inc.",
        "FC8F": "Bose Corporation",
        "FC91": "Samsung Electronics Co., Ltd.",
        "FC94": "Apple Inc.",
        "FCA0": "Apple Inc.",
        "FCB1": "Google LLC",
        "FCB2": "Apple Inc.",
        "FCC0": "Xiaomi Inc.",
        "FCCF": "Google LLC",
        "FCDC": "Amazon.com Services, LLC",
        "FCE1": "Sony Group Corporation",
        "FCF1": "Google LLC",
        "FD1D": "Samsung Electronics Co., Ltd",
        "FD21": "Huawei Technologies Co., Ltd.",
        "FD22": "Huawei Technologies Co., Ltd.",
        "FD2A": "Sony Corporation",
        "FD2D": "Xiaomi Inc.",
        "FD36": "Google LLC",
        "FD41": "Amazon Lab126",
        "FD43": "Apple Inc.",
        "FD44": "Apple Inc.",
        "FD4B": "Samsung Electronics Co., Ltd.",
        "FD59": "Samsung Electronics Co., Ltd.",
        "FD5A": "Samsung Electronics Co., Ltd.",
        "FD5F": "Meta Platforms Technologies, LLC",
        "FD62": "Google LLC",
        "FD63": "Google LLC",
        "FD69": "Samsung Electronics Co., Ltd",
        "FD6C": "Samsung Electronics Co., Ltd.",
        "FD6F": "Apple, Inc.",
        "FD7E": "Samsung Electronics Co., Ltd.",
        "FD82": "Sony Corporation",
        "FD84": "Tile, Inc.",
        "FD87": "Google LLC",
        "FD8C": "Google LLC",
        "FD96": "Google LLC",
        "FD9A": "Huawei Technologies Co., Ltd.",
        "FD9B": "Huawei Technologies Co., Ltd.",
        "FD9C": "Huawei Technologies Co., Ltd.",
        "FDAA": "Xiaomi Inc.",
        "FDAB": "Xiaomi Inc.",
        "FDB0": "Oura Health Ltd",
        "FDB1": "Oura Health Ltd",
        "FDD0": "Huawei Technologies Co., Ltd",
        "FDD1": "Huawei Technologies Co., Ltd",
        "FDD2": "Bose Corporation",
        "FDDB": "Samsung Electronics Co., Ltd.",
        "FDE2": "Google LLC",
        "FDEE": "Huawei Technologies Co., Ltd.",
        "FDF0": "Google LLC",
        "FE00": "Amazon.com Services, Inc.",
        "FE03": "Amazon.com Services, Inc.",
        "FE08": "Microsoft",
        "FE13": "Apple Inc.",
        "FE15": "Amazon.com Services, Inc..",
        "FE19": "Google LLC",
        "FE21": "Bose Corporation",
        "FE25": "Apple, Inc.",
        "FE26": "Google LLC",
        "FE27": "Google LLC",
        "FE2C": "Google LLC",
        "FE35": "HUAWEI Technologies Co., Ltd",
        "FE36": "HUAWEI Technologies Co., Ltd",
        "FE50": "Google LLC",
        "FE55": "Google LLC",
        "FE56": "Google LLC",
        "FE58": "Nordic Semiconductor ASA",
        "FE59": "Nordic Semiconductor ASA",
        "FE86": "HUAWEI Technologies Co., Ltd",
        "FE8A": "Apple, Inc.",
        "FE8B": "Apple, Inc.",
        "FE95": "Xiaomi Inc.",
        "FE9F": "Google LLC",
        "FEA0": "Google LLC",
        "FEAA": "Google LLC",
        "FEB2": "Microsoft Corporation",
        "FEB7": "Meta Platforms, Inc.",
        "FEB8": "Meta Platforms, Inc.",
        "FEBE": "Bose Corporation",
        "FECE": "Apple, Inc.",
        "FECF": "Apple, Inc.",
        "FED0": "Apple, Inc.",
        "FED1": "Apple, Inc.",
        "FED2": "Apple, Inc.",
        "FED3": "Apple, Inc.",
        "FED4": "Apple, Inc.",
        "FED8": "Google LLC",
        "FEEC": "Tile, Inc.",
        "FEED": "Tile, Inc.",
        "FEF3": "Google LLC",
        "FEF4": "Google LLC"
    ]

    static func match(for uuids: [String]) -> MemberUUIDVendorMatch? {
        for uuid in uuids {
            let normalized = normalizedUUID(uuid)
            if let name = memberUUIDNames[normalized] {
                return MemberUUIDVendorMatch(uuid: normalized, name: name)
            }
        }
        return nil
    }

    static func normalizedUUID(_ uuid: String) -> String {
        let allowedHexCharacters = Set("0123456789ABCDEF")
        let compact = uuid.uppercased().filter { allowedHexCharacters.contains($0) }
        let bluetoothBaseUUIDSuffix = "00001000800000805F9B34FB"
        if compact.count == 32,
           compact.hasPrefix("0000"),
           compact.hasSuffix(bluetoothBaseUUIDSuffix) {
            let start = compact.index(compact.startIndex, offsetBy: 4)
            let end = compact.index(start, offsetBy: 4)
            return String(compact[start..<end])
        }
        return compact
    }

    static func iconSystemName(for name: String?) -> String? {
        guard let name else {
            return nil
        }
        let normalized = name.lowercased()
        if normalized.contains("google") {
            return "globe"
        }
        if normalized.contains("apple") {
            return "apple.logo"
        }
        if normalized.contains("bose") {
            return "headphones"
        }
        if normalized.contains("samsung") || normalized.contains("huawei") || normalized.contains("xiaomi") {
            return "iphone"
        }
        if normalized.contains("oura") {
            return "heart.circle"
        }
        if normalized.contains("tile") {
            return "location.circle"
        }
        if normalized.contains("nordic") {
            return "cpu"
        }
        if normalized.contains("amazon") || normalized.contains("microsoft") || normalized.contains("meta") {
            return "globe"
        }
        return nil
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
        selectedFields = Self.defaultSelectedFields(expectedName: device.displayName)
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

    static func defaultSelectedFields(expectedName: String?) -> [MatchField] {
        var fields: [MatchField] = [.identifier]
        let trimmedName = expectedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            fields.append(.name)
        }
        return fields
    }
}

enum BeaconRuntimeState: Equatable {
    case present
    case weakSignal
    case scanning
    case scanPaused
    case fieldMismatch
    case stale
    case notDetected
    case notConfigured
    case bluetoothUnavailable
}

struct BeaconRuntimeStatus: Equatable {
    var state: BeaconRuntimeState
    var ageSeconds: Int?
    var rssi: Int?
    var freshnessSeconds: Int
    var rssiThreshold: Int?
    var mismatchedFields: [String] = []

    var label: String {
        switch state {
        case .present: return "在线"
        case .weakSignal: return "信号过低"
        case .scanning: return "等待广播"
        case .scanPaused: return "扫描暂停"
        case .fieldMismatch: return "字段不匹配"
        case .stale: return "疑似离线"
        case .notDetected: return "未检测到"
        case .notConfigured: return "未配置"
        case .bluetoothUnavailable: return "蓝牙不可用"
        }
    }

    var detail: String {
        switch state {
        case .present:
            return [ageText, rssiText].compactMap { $0 }.joined(separator: "，")
        case .weakSignal:
            let threshold = rssiThreshold.map { "阈值 \($0) dBm" } ?? "低于阈值"
            return [ageText, rssiText, threshold].compactMap { $0 }.joined(separator: "，")
        case .scanning:
            return [ageText, rssiText, "等待下一次广播"].compactMap { $0 }.joined(separator: "，")
        case .scanPaused:
            let hint = ageSeconds == nil ? "点击扫描后刷新状态" : "点击扫描可继续刷新"
            return [ageText, rssiText, hint].compactMap { $0 }.joined(separator: "，")
        case .fieldMismatch:
            let detail = mismatchedFields.isEmpty ? "已发现设备，但勾选字段未全部匹配" : "不一致字段：\(mismatchedFields.joined(separator: "、"))"
            return [ageText, rssiText, detail].compactMap { $0 }.joined(separator: "，")
        case .stale:
            let window = "超过 \(freshnessSeconds) 秒有效窗口"
            return [ageText, window].compactMap { $0 }.joined(separator: "，")
        case .notDetected:
            return "扫描中暂未发现匹配设备"
        case .notConfigured:
            return "未选择识别字段，守护不会计入在场"
        case .bluetoothUnavailable:
            return [ageText, rssiText, "蓝牙未处于可用状态"].compactMap { $0 }.joined(separator: "，")
        }
    }

    var systemImage: String {
        switch state {
        case .present: return "checkmark.circle.fill"
        case .weakSignal: return "antenna.radiowaves.left.and.right.slash"
        case .scanning: return "dot.radiowaves.left.and.right"
        case .scanPaused: return "pause.circle"
        case .fieldMismatch: return "slider.horizontal.3"
        case .stale: return "clock.badge.exclamationmark"
        case .notDetected: return "questionmark.circle"
        case .notConfigured: return "exclamationmark.triangle"
        case .bluetoothUnavailable: return "bolt.horizontal.circle"
        }
    }

    private var ageText: String? {
        guard let ageSeconds else {
            return nil
        }
        if ageSeconds <= 0 {
            return "刚刚出现"
        }
        return "最后出现 \(ageSeconds) 秒前"
    }

    private var rssiText: String? {
        rssi.map { "RSSI \($0) dBm" }
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
    var timerLockEnd: Date?
    var timerLockDurationMinutes: Int

    init(
        guardEnabled: Bool,
        beacons: [Beacon],
        rules: GuardRules,
        networkRules: NetworkRules,
        advanced: AdvancedSettings,
        logs: [EventLog],
        activePause: ActivePause?,
        timerLockEnd: Date?,
        timerLockDurationMinutes: Int
    ) {
        self.guardEnabled = guardEnabled
        self.beacons = beacons
        self.rules = rules
        self.networkRules = networkRules
        self.advanced = advanced
        self.logs = logs
        self.activePause = activePause
        self.timerLockEnd = timerLockEnd
        self.timerLockDurationMinutes = timerLockDurationMinutes
    }

    private enum CodingKeys: String, CodingKey {
        case guardEnabled
        case beacons
        case rules
        case networkRules
        case advanced
        case logs
        case activePause
        case timerLockEnd
        case timerLockDurationMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guardEnabled = try container.decodeIfPresent(Bool.self, forKey: .guardEnabled) ?? false
        beacons = try container.decodeIfPresent([Beacon].self, forKey: .beacons) ?? []
        rules = try container.decodeIfPresent(GuardRules.self, forKey: .rules) ?? GuardRules()
        networkRules = try container.decodeIfPresent(NetworkRules.self, forKey: .networkRules) ?? NetworkRules()
        advanced = try container.decodeIfPresent(AdvancedSettings.self, forKey: .advanced) ?? AdvancedSettings()
        logs = try container.decodeIfPresent([EventLog].self, forKey: .logs) ?? []
        activePause = try container.decodeIfPresent(ActivePause.self, forKey: .activePause)
        timerLockEnd = try container.decodeIfPresent(Date.self, forKey: .timerLockEnd)
        timerLockDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .timerLockDurationMinutes) ?? 10
    }
}

struct BluetoothRuntimeSnapshot: Codable, Equatable {
    var powerState: BluetoothPowerState = .unknown
    var isScanning = false
    var scanStartedAt: Date?
    var scanEndsAt: Date?
    var scanRemainingSeconds = 0
    var lastError: String?
    var devices: [DiscoveredDevice] = []
}

struct NetworkRuntimeSnapshot: Codable, Equatable {
    var currentSSID: String?
    var currentBSSID: String?
    var locationAuthorizationState: LocationAuthorizationState = .notDetermined
}

struct SharedRuntimeState: Codable {
    var updatedAt: Date
    var guardEnabled: Bool
    var status: GuardRuntimeState
    var unavailableReason: String?
    var activePause: ActivePause?
    var logs: [EventLog]
    var promptReason: String
    var countdownRemaining: Int
    var timerLockEnd: Date?
    var timerLockDurationMinutes: Int
    var lastStabilityResult: StabilityTestResult?
    var bluetooth: BluetoothRuntimeSnapshot
    var network: NetworkRuntimeSnapshot

    init(
        updatedAt: Date,
        guardEnabled: Bool,
        status: GuardRuntimeState,
        unavailableReason: String?,
        activePause: ActivePause?,
        logs: [EventLog],
        promptReason: String,
        countdownRemaining: Int,
        timerLockEnd: Date?,
        timerLockDurationMinutes: Int,
        lastStabilityResult: StabilityTestResult?,
        bluetooth: BluetoothRuntimeSnapshot,
        network: NetworkRuntimeSnapshot = NetworkRuntimeSnapshot()
    ) {
        self.updatedAt = updatedAt
        self.guardEnabled = guardEnabled
        self.status = status
        self.unavailableReason = unavailableReason
        self.activePause = activePause
        self.logs = logs
        self.promptReason = promptReason
        self.countdownRemaining = countdownRemaining
        self.timerLockEnd = timerLockEnd
        self.timerLockDurationMinutes = timerLockDurationMinutes
        self.lastStabilityResult = lastStabilityResult
        self.bluetooth = bluetooth
        self.network = network
    }

    private enum CodingKeys: String, CodingKey {
        case updatedAt
        case guardEnabled
        case status
        case unavailableReason
        case activePause
        case logs
        case promptReason
        case countdownRemaining
        case timerLockEnd
        case timerLockDurationMinutes
        case lastStabilityResult
        case bluetooth
        case network
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        guardEnabled = try container.decode(Bool.self, forKey: .guardEnabled)
        status = try container.decode(GuardRuntimeState.self, forKey: .status)
        unavailableReason = try container.decodeIfPresent(String.self, forKey: .unavailableReason)
        activePause = try container.decodeIfPresent(ActivePause.self, forKey: .activePause)
        logs = try container.decode([EventLog].self, forKey: .logs)
        promptReason = try container.decode(String.self, forKey: .promptReason)
        countdownRemaining = try container.decode(Int.self, forKey: .countdownRemaining)
        timerLockEnd = try container.decodeIfPresent(Date.self, forKey: .timerLockEnd)
        timerLockDurationMinutes = try container.decode(Int.self, forKey: .timerLockDurationMinutes)
        lastStabilityResult = try container.decodeIfPresent(StabilityTestResult.self, forKey: .lastStabilityResult)
        bluetooth = try container.decode(BluetoothRuntimeSnapshot.self, forKey: .bluetooth)
        network = try container.decodeIfPresent(NetworkRuntimeSnapshot.self, forKey: .network) ?? NetworkRuntimeSnapshot()
    }
}

enum AgentCommandKind: String, Codable {
    case startManualScan
    case stopManualScan
    case clearDevices
    case startStabilityTest
    case stopStabilityTest
    case debugBluetoothAvailability
    case requestLocationPermission
}

struct AgentCommand: Codable {
    var id: UUID = UUID()
    var requestedAt: Date = Date()
    var kind: AgentCommandKind
    var scanDurationSeconds: Int?
    var beaconID: UUID?
}

struct ScanDiagnosticsExport: Codable {
    var exportedAt: Date
    var bluetoothState: BluetoothPowerState
    var isScanning: Bool
    var devices: [DiscoveredDevice]
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
