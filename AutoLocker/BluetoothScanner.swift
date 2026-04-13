import Combine
import CoreBluetooth
import Foundation

final class BluetoothScanner: NSObject, ObservableObject {
    @Published private(set) var devices: [DiscoveredDevice] = []
    @Published private(set) var powerState: BluetoothPowerState = .unknown
    @Published private(set) var isScanning = false
    @Published private(set) var scanEndsAt: Date?
    @Published private(set) var scanRemainingSeconds = 0
    @Published private(set) var lastError: String?

    var onDevicesChanged: (() -> Void)?
    var onStateChanged: (() -> Void)?

    private var central: CBCentralManager!
    private var shouldScanWhenReady = false
    private var pendingScanDuration: TimeInterval?
    private var scanTimer: Timer?
    private var devicesChangeNotifyTimer: Timer?
    private var pendingDevicesChangeNotify = false
    private var lastDevicesChangeNotifyAt = Date.distantPast
    private let devicesChangeNotifyInterval: TimeInterval = 0.25

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    deinit {
        scanTimer?.invalidate()
        devicesChangeNotifyTimer?.invalidate()
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

    func startScanning(duration: TimeInterval? = nil) {
        shouldScanWhenReady = true
        pendingScanDuration = duration
        guard powerState == .poweredOn else {
            return
        }
        if !isScanning {
            compactLikelyDuplicateDevices()
            central.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
            isScanning = true
        }
        configureScanTimer(duration: duration)
        lastError = nil
    }

    func restartScanning(duration: TimeInterval? = nil) {
        shouldScanWhenReady = true
        pendingScanDuration = duration
        guard powerState == .poweredOn else {
            return
        }

        if isScanning {
            central.stopScan()
            isScanning = false
        }
        compactLikelyDuplicateDevices()
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        isScanning = true
        configureScanTimer(duration: duration)
        lastError = nil
    }

    func stopScanning() {
        shouldScanWhenReady = false
        pendingScanDuration = nil
        scanTimer?.invalidate()
        scanTimer = nil
        scanEndsAt = nil
        scanRemainingSeconds = 0
        let shouldFlushDeviceUpdate = isScanning || pendingDevicesChangeNotify
        if isScanning {
            central.stopScan()
            isScanning = false
        }
        if shouldFlushDeviceUpdate {
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
        notifyDevicesChanged(throttled: false)
    }
}

private extension BluetoothScanner {
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
}

extension BluetoothScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            powerState = .unknown
        case .resetting:
            powerState = .resetting
        case .unsupported:
            powerState = .unsupported
            lastError = "这台 Mac 不支持当前蓝牙扫描能力。"
        case .unauthorized:
            powerState = .unauthorized
            lastError = "蓝牙权限未授权，请在系统设置中允许 Auto Locker 使用蓝牙。"
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
            advertisementKeys: advertisementData.keys.sorted(),
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
        notifyDevicesChanged(throttled: true)
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
