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

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    deinit {
        scanTimer?.invalidate()
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
            central.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
            isScanning = true
        }
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
        guard isScanning else {
            return
        }
        central.stopScan()
        isScanning = false
    }

    func forgetDevices(olderThan interval: TimeInterval) {
        let cutoff = Date().addingTimeInterval(-interval)
        devices.removeAll { $0.lastSeen < cutoff }
        onDevicesChanged?()
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
        let now = Date()

        let discovered = DiscoveredDevice(
            id: peripheral.identifier,
            identifier: identifier,
            name: displayName,
            localName: localName,
            manufacturerDataHex: manufacturerData?.hexString,
            manufacturerCompanyID: manufacturerData?.manufacturerCompanyID,
            rssi: RSSI.intValue,
            lastSeen: now
        )

        if let index = devices.firstIndex(where: { $0.id == discovered.id }) {
            devices[index] = discovered
        } else {
            devices.append(discovered)
        }
        onDevicesChanged?()
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
