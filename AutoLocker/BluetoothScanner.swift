import AppKit
import Combine
import CoreBluetooth
import Foundation

final class BluetoothScanner: NSObject, ObservableObject {
    @Published private(set) var devices: [DiscoveredDevice] = []
    @Published private(set) var powerState: BluetoothPowerState = .unknown
    @Published private(set) var isScanning = false
    @Published private(set) var scanStartedAt: Date?
    @Published private(set) var scanEndsAt: Date?
    @Published private(set) var scanRemainingSeconds = 0
    @Published private(set) var lastError: String?

    var onDevicesChanged: (() -> Void)?
    var onStateChanged: (() -> Void)?

    private var central: CBCentralManager?
    private var shouldScanWhenReady = false
    private var pendingScanDuration: TimeInterval?
    private var scanTimer: Timer?
    private var devicesChangeNotifyTimer: Timer?
    private var pendingDevicesChangeNotify = false
    private var lastDevicesChangeNotifyAt = Date.distantPast
    private let devicesChangeNotifyInterval: TimeInterval = 0.25
    private var centralCreationScheduled = false
    private var shouldRetryAuthorizationAfterActivation = false
    private var diagnosticsTimer: Timer?
    private var diagnosticsEndsAt: Date?
    private var diagnosticsStartedTemporaryScan = false
    private var diagnosticsDiscoveryCount = 0

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        scanTimer?.invalidate()
        devicesChangeNotifyTimer?.invalidate()
        diagnosticsTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    var scanStatusText: String {
        if isScanning, scanRemainingSeconds > 0 {
            return "正在扫描，\(scanRemainingSeconds) 秒后暂停"
        }
        if isScanning {
            return "正在持续扫描"
        }
        return "扫描已暂停"
    }

    var runtimeSnapshot: BluetoothRuntimeSnapshot {
        BluetoothRuntimeSnapshot(
            powerState: powerState,
            isScanning: isScanning,
            scanStartedAt: scanStartedAt,
            scanEndsAt: scanEndsAt,
            scanRemainingSeconds: scanRemainingSeconds,
            lastError: lastError,
            devices: devices
        )
    }

    func applyRuntimeSnapshot(_ snapshot: BluetoothRuntimeSnapshot) {
        shouldScanWhenReady = false
        pendingScanDuration = nil
        scanTimer?.invalidate()
        scanTimer = nil
        devicesChangeNotifyTimer?.invalidate()
        devicesChangeNotifyTimer = nil
        pendingDevicesChangeNotify = false

        devices = snapshot.devices
        powerState = snapshot.powerState
        isScanning = snapshot.isScanning
        scanStartedAt = snapshot.scanStartedAt
        scanEndsAt = snapshot.scanEndsAt
        scanRemainingSeconds = snapshot.scanRemainingSeconds
        lastError = snapshot.lastError
    }

    func startScanning(duration: TimeInterval? = nil) {
        shouldScanWhenReady = true
        pendingScanDuration = duration
        ensureCentralManagerReady()
        guard powerState == .poweredOn else {
            return
        }
        if !isScanning {
            compactLikelyDuplicateDevices()
            central?.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
            isScanning = true
            scanStartedAt = Date()
            SharedDebugTrace.log("蓝牙扫描启动：duration=\(duration.map { String(format: "%.1f", $0) } ?? "continuous") devices=\(devices.count)")
        }
        configureScanTimer(duration: duration)
        lastError = nil
    }

    func restartScanning(duration: TimeInterval? = nil) {
        shouldScanWhenReady = true
        pendingScanDuration = duration
        ensureCentralManagerReady()
        guard powerState == .poweredOn else {
            return
        }

        if isScanning {
            central?.stopScan()
            isScanning = false
        }
        compactLikelyDuplicateDevices()
        central?.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        isScanning = true
        scanStartedAt = Date()
        configureScanTimer(duration: duration)
        lastError = nil
        SharedDebugTrace.log("蓝牙扫描重启：duration=\(duration.map { String(format: "%.1f", $0) } ?? "continuous") devices=\(devices.count)")
    }

    func stopScanning() {
        shouldScanWhenReady = false
        pendingScanDuration = nil
        scanTimer?.invalidate()
        scanTimer = nil
        scanStartedAt = nil
        scanEndsAt = nil
        scanRemainingSeconds = 0
        let shouldFlushDeviceUpdate = isScanning || pendingDevicesChangeNotify
        if isScanning {
            central?.stopScan()
            isScanning = false
        }
        if shouldFlushDeviceUpdate {
            SharedDebugTrace.log("蓝牙扫描停止：devices=\(devices.count)")
            notifyDevicesChanged(throttled: false)
        }
    }

    func forgetDevices(olderThan interval: TimeInterval) {
        let cutoff = Date().addingTimeInterval(-interval)
        devices.removeAll { $0.lastSeen < cutoff }
        notifyDevicesChanged(throttled: false)
    }

    func clearDevices() {
        devices.removeAll()
        SharedDebugTrace.log("蓝牙扫描结果已清空")
        notifyDevicesChanged(throttled: false)
    }

    func runAvailabilityDiagnostics(duration: TimeInterval = 10, keepScanningAfterDiagnostics: Bool) {
        diagnosticsTimer?.invalidate()
        diagnosticsEndsAt = Date().addingTimeInterval(duration)
        diagnosticsStartedTemporaryScan = !isScanning && !keepScanningAfterDiagnostics
        diagnosticsDiscoveryCount = 0

        SharedDebugTrace.log([
            "蓝牙调试开始",
            "duration=\(Int(duration))s",
            "keepScanningAfterDiagnostics=\(keepScanningAfterDiagnostics)",
            "powerState=\(powerState.rawValue)",
            "authorization=\(Self.authorizationDebugDescription)",
            "isScanning=\(isScanning)",
            "devices=\(devices.count)",
            "lastError=\(lastError ?? "-")"
        ].joined(separator: " "))

        if isScanning {
            SharedDebugTrace.log("蓝牙调试：复用当前扫描，不修改扫描计时器")
            ensureCentralManagerReady()
        } else {
            startScanning(duration: keepScanningAfterDiagnostics ? nil : duration)
            SharedDebugTrace.log("蓝牙调试：已请求启动扫描，temporary=\(!keepScanningAfterDiagnostics)")
        }

        diagnosticsTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.finishAvailabilityDiagnostics()
        }
    }
}

private extension BluetoothScanner {
    func ensureCentralManagerReady(forceRecreate: Bool = false) {
        if forceRecreate {
            SharedDebugTrace.log("蓝牙 central 准备重建：hasCentral=\(central != nil) scheduled=\(centralCreationScheduled)")
            central?.delegate = nil
            central = nil
            powerState = .unknown
            SharedDebugTrace.log("蓝牙 central 已重建前清理")
        }

        guard central == nil, !centralCreationScheduled else {
            return
        }

        SharedDebugTrace.log("蓝牙 central 准备：开始异步创建")
        centralCreationScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.centralCreationScheduled = false
            guard self.central == nil else {
                return
            }
            SharedDebugTrace.log("创建 CBCentralManager")
            self.central = CBCentralManager(delegate: self, queue: .main)
        }
    }

    @objc func handleApplicationDidBecomeActive() {
        guard shouldRetryAuthorizationAfterActivation else {
            return
        }

        shouldRetryAuthorizationAfterActivation = false
        ensureCentralManagerReady(forceRecreate: true)
    }

    func configureScanTimer(duration: TimeInterval?) {
        scanTimer?.invalidate()
        scanTimer = nil

        guard let duration else {
            scanEndsAt = nil
            scanRemainingSeconds = 0
            return
        }

        scanEndsAt = Date().addingTimeInterval(duration)
        updateScanRemaining()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateScanRemaining()
        }
    }

    func updateScanRemaining() {
        guard let scanEndsAt else {
            scanRemainingSeconds = 0
            return
        }

        let remaining = max(0, Int(ceil(scanEndsAt.timeIntervalSinceNow)))
        scanRemainingSeconds = remaining
        if remaining <= 0 {
            stopScanning()
        }
    }

    func notifyDevicesChanged(throttled: Bool) {
        guard throttled else {
            devicesChangeNotifyTimer?.invalidate()
            devicesChangeNotifyTimer = nil
            pendingDevicesChangeNotify = false
            lastDevicesChangeNotifyAt = Date()
            onDevicesChanged?()
            return
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastDevicesChangeNotifyAt)
        guard elapsed < devicesChangeNotifyInterval else {
            devicesChangeNotifyTimer?.invalidate()
            devicesChangeNotifyTimer = nil
            pendingDevicesChangeNotify = false
            lastDevicesChangeNotifyAt = now
            onDevicesChanged?()
            return
        }

        guard !pendingDevicesChangeNotify else {
            return
        }

        pendingDevicesChangeNotify = true
        devicesChangeNotifyTimer = Timer.scheduledTimer(withTimeInterval: devicesChangeNotifyInterval - elapsed, repeats: false) { [weak self] _ in
            guard let self else {
                return
            }
            self.devicesChangeNotifyTimer = nil
            self.pendingDevicesChangeNotify = false
            self.lastDevicesChangeNotifyAt = Date()
            self.onDevicesChanged?()
        }
    }

    func compactLikelyDuplicateDevices() {
        guard devices.count > 1 else {
            return
        }

        var compacted: [DiscoveredDevice] = []
        for device in devices {
            if let index = compacted.firstIndex(where: { $0.isLikelySameAdvertisement(as: device) }) {
                compacted[index] = compacted[index].mergingAdvertisementUpdate(device)
            } else {
                compacted.append(device)
            }
        }

        guard compacted.count != devices.count else {
            return
        }

        devices = compacted
        notifyDevicesChanged(throttled: false)
    }

    func finishAvailabilityDiagnostics() {
        let shouldStopTemporaryScan = diagnosticsStartedTemporaryScan && isScanning
        SharedDebugTrace.log([
            "蓝牙调试结束",
            "powerState=\(powerState.rawValue)",
            "authorization=\(Self.authorizationDebugDescription)",
            "isScanning=\(isScanning)",
            "temporaryScan=\(diagnosticsStartedTemporaryScan)",
            "advertisements=\(diagnosticsDiscoveryCount)",
            "devices=\(devices.count)",
            "lastError=\(lastError ?? "-")"
        ].joined(separator: " "))

        diagnosticsTimer?.invalidate()
        diagnosticsTimer = nil
        diagnosticsEndsAt = nil
        diagnosticsStartedTemporaryScan = false

        if shouldStopTemporaryScan {
            stopScanning()
            SharedDebugTrace.log("蓝牙调试：临时扫描已停止")
        }
    }

    func logDebugAdvertisement(
        identifier: String,
        displayName: String,
        localName: String?,
        manufacturerData: Data?,
        serviceUUIDs: [String],
        solicitedServiceUUIDs: [String],
        overflowServiceUUIDs: [String],
        serviceDataHex: [String: String],
        txPowerLevel: Int?,
        isConnectable: Bool?,
        advertisementKeys: [String],
        rssi: Int
    ) {
        guard let diagnosticsEndsAt, Date() <= diagnosticsEndsAt else {
            return
        }

        diagnosticsDiscoveryCount += 1
        SharedDebugTrace.log([
            "蓝牙调试发现广播",
            "index=\(diagnosticsDiscoveryCount)",
            "id=\(identifier)",
            "name=\(displayName.isEmpty ? "-" : displayName)",
            "localName=\(localName ?? "-")",
            "rssi=\(rssi)",
            "manufacturerID=\(manufacturerData?.manufacturerCompanyID.map { String(format: "0x%04X", $0) } ?? "-")",
            "manufacturerData=\(manufacturerData?.hexString ?? "-")",
            "serviceUUIDs=\(serviceUUIDs.isEmpty ? "-" : serviceUUIDs.joined(separator: ","))",
            "solicitedServiceUUIDs=\(solicitedServiceUUIDs.isEmpty ? "-" : solicitedServiceUUIDs.joined(separator: ","))",
            "overflowServiceUUIDs=\(overflowServiceUUIDs.isEmpty ? "-" : overflowServiceUUIDs.joined(separator: ","))",
            "serviceData=\(serviceDataHex.isEmpty ? "-" : serviceDataHex.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: ","))",
            "txPower=\(txPowerLevel.map(String.init) ?? "-")",
            "connectable=\(isConnectable.map(String.init) ?? "-")",
            "keys=\(advertisementKeys.joined(separator: ","))"
        ].joined(separator: " "))
    }
}

extension BluetoothScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let previousState = powerState
        switch central.state {
        case .unknown:
            powerState = .unknown
        case .resetting:
            powerState = .resetting
        case .unsupported:
            powerState = .unsupported
            lastError = "这台 Mac 不支持当前蓝牙扫描能力。"
        case .unauthorized:
            switch CBCentralManager.authorization {
            case .notDetermined:
                powerState = .unknown
                lastError = "正在等待系统蓝牙权限确认。"
                shouldRetryAuthorizationAfterActivation = true
            case .restricted, .denied:
                powerState = .unauthorized
                lastError = "蓝牙权限未授权，请在系统设置中允许 Auto Locker 使用蓝牙。"
            case .allowedAlways:
                powerState = .unknown
                lastError = nil
            @unknown default:
                powerState = .unauthorized
                lastError = "蓝牙权限未授权，请在系统设置中允许 Auto Locker 使用蓝牙。"
            }
        case .poweredOff:
            powerState = .poweredOff
            lastError = "蓝牙已关闭。"
        case .poweredOn:
            powerState = .poweredOn
            lastError = nil
            if shouldScanWhenReady {
                startScanning(duration: pendingScanDuration)
            }
        @unknown default:
            powerState = .unknown
            lastError = "系统返回了未知蓝牙状态。"
        }
        SharedDebugTrace.log([
            "蓝牙状态更新",
            "centralState=\(Self.centralStateDebugDescription(central.state))",
            "previous=\(previousState.rawValue)",
            "mapped=\(powerState.rawValue)",
            "authorization=\(Self.authorizationDebugDescription)",
            "shouldScanWhenReady=\(shouldScanWhenReady)",
            "pendingDuration=\(pendingScanDuration.map { String(format: "%.1f", $0) } ?? "-")",
            "isScanning=\(isScanning)",
            "lastError=\(lastError ?? "-")"
        ].joined(separator: " "))
        onStateChanged?()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let identifier = peripheral.identifier.uuidString
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let displayName = peripheral.name ?? localName ?? ""
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let serviceUUIDs = uuidStrings(from: advertisementData[CBAdvertisementDataServiceUUIDsKey])
        let solicitedServiceUUIDs = uuidStrings(from: advertisementData[CBAdvertisementDataSolicitedServiceUUIDsKey])
        let overflowServiceUUIDs = uuidStrings(from: advertisementData[CBAdvertisementDataOverflowServiceUUIDsKey])
        let serviceDataHex = serviceDataHex(from: advertisementData[CBAdvertisementDataServiceDataKey])
        let txPowerLevel = intValue(from: advertisementData[CBAdvertisementDataTxPowerLevelKey])
        let isConnectable = boolValue(from: advertisementData[CBAdvertisementDataIsConnectable])
        let advertisementKeys = advertisementData.keys.sorted()
        let now = Date()

        let discovered = DiscoveredDevice(
            id: peripheral.identifier,
            identifier: identifier,
            name: displayName,
            localName: localName,
            manufacturerDataHex: manufacturerData?.hexString,
            manufacturerCompanyID: manufacturerData?.manufacturerCompanyID,
            serviceUUIDs: serviceUUIDs,
            solicitedServiceUUIDs: solicitedServiceUUIDs,
            overflowServiceUUIDs: overflowServiceUUIDs,
            serviceDataHex: serviceDataHex,
            txPowerLevel: txPowerLevel,
            isConnectable: isConnectable,
            advertisementKeys: advertisementKeys,
            rssi: RSSI.intValue,
            lastSeen: now
        )

        if let index = devices.firstIndex(where: { $0.id == discovered.id || $0.isLikelySameAdvertisement(as: discovered) }) {
            let merged = devices[index].mergingAdvertisementUpdate(discovered)
            devices[index] = merged
            devices.removeAll { $0.id != merged.id && $0.isLikelySameAdvertisement(as: merged) }
        } else {
            devices.append(discovered)
        }
        logDebugAdvertisement(
            identifier: identifier,
            displayName: displayName,
            localName: localName,
            manufacturerData: manufacturerData,
            serviceUUIDs: serviceUUIDs,
            solicitedServiceUUIDs: solicitedServiceUUIDs,
            overflowServiceUUIDs: overflowServiceUUIDs,
            serviceDataHex: serviceDataHex,
            txPowerLevel: txPowerLevel,
            isConnectable: isConnectable,
            advertisementKeys: advertisementKeys,
            rssi: RSSI.intValue
        )
        notifyDevicesChanged(throttled: true)
    }
}

extension BluetoothScanner {
    static var authorizationDebugDescription: String {
        switch CBCentralManager.authorization {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .allowedAlways:
            return "allowedAlways"
        @unknown default:
            return "unknown"
        }
    }

    private static func centralStateDebugDescription(_ state: CBManagerState) -> String {
        switch state {
        case .unknown:
            return "unknown"
        case .resetting:
            return "resetting"
        case .unsupported:
            return "unsupported"
        case .unauthorized:
            return "unauthorized"
        case .poweredOff:
            return "poweredOff"
        case .poweredOn:
            return "poweredOn"
        @unknown default:
            return "unknown"
        }
    }
}

private extension BluetoothScanner {
    func uuidStrings(from value: Any?) -> [String] {
        guard let uuids = value as? [CBUUID] else {
            return []
        }
        return uuids.map(\.uuidString).sorted()
    }

    func serviceDataHex(from value: Any?) -> [String: String] {
        guard let serviceData = value as? [CBUUID: Data] else {
            return [:]
        }

        var result: [String: String] = [:]
        for (uuid, data) in serviceData {
            result[uuid.uuidString] = data.hexString
        }
        return result
    }

    func intValue(from value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        return value as? Int
    }

    func boolValue(from value: Any?) -> Bool? {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return nil
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02X", $0) }.joined()
    }

    var manufacturerCompanyID: UInt16? {
        let bytes = Array(prefix(2))
        guard bytes.count == 2 else {
            return nil
        }
        return UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
    }
}
