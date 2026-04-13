import AppKit
import Combine
import Foundation

final class AutoLockerStore: ObservableObject {
    @Published var selectedSection: AppSection = .overview
    @Published var guardEnabled = false
    @Published var status: GuardRuntimeState = .disabled
    @Published var unavailableReason: String?
    @Published var beacons: [Beacon] = []
    @Published var rules = GuardRules()
    @Published var networkRules = NetworkRules()
    @Published var advanced = AdvancedSettings()
    @Published var logs: [EventLog] = []
    @Published var activePause: ActivePause?
    @Published var promptReason = ""
    @Published var countdownRemaining = 0
    @Published var timerLockEnd: Date?
    @Published var timerLockDurationMinutes = 10
    @Published var stabilitySession: StabilityTestSession?
    @Published var lastStabilityResult: StabilityTestResult?

    let scanner = BluetoothScanner()
    let wifiMonitor = WiFiMonitor()

    private let promptPresenter = PromptPresenter()
    private var cancellables: Set<AnyCancellable> = []
    private var evaluationTimer: Timer?
    private var promptTimer: Timer?
    private var saveWorkItem: DispatchWorkItem?
    private let saveQueue = DispatchQueue(label: "AutoLocker.saveQueue", qos: .utility)
    private var missingStartedAt: Date?
    private var consecutiveMisses = 0
    private var guardScanGraceUntil: Date?
    private var guardScanGraceResetsAbsence = true
    private var recoveredScanForCurrentAbsence = false
    private var networkSuppressionSSID: String?
    private var lastUnavailableLogReason: String?

    init() {
        load()
        configureCallbacks()
        configureAutosave()
        configureSystemObservers()
        wifiMonitor.start()
        startEvaluationTimer()

        if guardEnabled && advanced.autoRestoreGuard {
            refreshAvailability(reason: "应用启动后自动恢复守护")
        } else {
            guardEnabled = false
            status = .disabled
        }
    }

    deinit {
        evaluationTimer?.invalidate()
        promptTimer?.invalidate()
        saveWorkItem?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    var currentSSID: String? {
        wifiMonitor.currentSSID
    }

    var currentBSSID: String? {
        wifiMonitor.currentBSSID
    }

    var currentWiFiDisplay: String? {
        let ssid = currentSSID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let bssid = currentBSSID?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (ssid?.isEmpty == false ? ssid : nil, bssid?.isEmpty == false ? bssid : nil) {
        case let (ssid?, bssid?):
            return "\(ssid) · \(bssid)"
        case let (ssid?, nil):
            return ssid
        case let (nil, bssid?):
            return bssid
        default:
            return nil
        }
    }

    var timerRemainingSeconds: Int? {
        guard let timerLockEnd else {
            return nil
        }
        return max(0, Int(timerLockEnd.timeIntervalSinceNow))
    }

    var recentEvent: EventLog? {
        logs.first
    }

    var riskWarnings: [String] {
        var warnings: [String] = []
        if rules.delaySeconds < 10 {
            warnings.append("离开延迟较短，蓝牙广播不稳定时可能误锁。")
        }
        if rules.detectionMode == .rssiThreshold && rules.rssiThreshold > -70 {
            warnings.append("RSSI 阈值偏高，移动姿态变化可能触发误锁。")
        }
        if beacons.contains(where: { $0.selectedFields.isEmpty }) {
            warnings.append("存在未选择识别字段的信标。")
        }
        return warnings
    }

    func startManualScan(durationOverride: Int? = nil) {
        if guardEnabled {
            scanner.startScanning()
            addLog(.scan, reason: "守护已开启，保持持续蓝牙扫描")
        } else {
            let duration = max(5, durationOverride ?? advanced.discoveryScanDurationSeconds)
            scanner.startScanning(duration: TimeInterval(duration))
            addLog(.scan, reason: "用户启动蓝牙扫描：\(duration) 秒")
        }
    }

    func stopManualScan() {
        guard !guardEnabled else {
            return
        }
        scanner.stopScanning()
        addLog(.scan, reason: "用户暂停蓝牙扫描")
    }

    func clearDiscoveredDevices() {
        scanner.clearDevices()
        addLog(.scan, reason: "清空扫描结果")
    }

    func setGuardEnabled(_ enabled: Bool) {
        if enabled {
            guardEnabled = true
            scanner.startScanning()
            refreshAvailability(reason: "用户开启守护")
        } else {
            guardEnabled = false
            activePause = nil
            status = .disabled
            promptTimer?.invalidate()
            promptPresenter.close()
            scanner.stopScanning()
            resetAbsenceCounters()
            addLog(.settings, reason: "用户关闭守护")
        }
    }

    func bind(_ device: DiscoveredDevice) {
        if beacons.contains(where: { $0.expectedIdentifier == device.identifier }) {
            return
        }
        if !guardEnabled && scanner.isScanning {
            scanner.stopScanning()
        }
        var beacon = Beacon(from: device)
        beacon.isPrimary = beacons.isEmpty
        beacons.append(beacon)
        rules.requiredBeaconCount = min(max(1, rules.requiredBeaconCount), max(1, beacons.count))
        addLog(.settings, reason: "绑定信标：\(beacon.displayName)", relatedBeacons: [beacon])
        refreshAvailability(reason: "绑定信标后刷新守护状态")
    }

    func removeBeacon(_ beacon: Beacon) {
        beacons.removeAll { $0.id == beacon.id }
        if !beacons.contains(where: \.isPrimary), !beacons.isEmpty {
            beacons[0].isPrimary = true
        }
        rules.requiredBeaconCount = min(max(1, rules.requiredBeaconCount), max(1, beacons.count))
        addLog(.settings, reason: "移除信标：\(beacon.displayName)")
        refreshAvailability(reason: "移除信标后刷新守护状态")
    }

    func setPrimary(_ beacon: Beacon) {
        for index in beacons.indices {
            beacons[index].isPrimary = beacons[index].id == beacon.id
        }
        addLog(.settings, reason: "设为主信标：\(beacon.displayName)")
    }

    func updateBeacon(_ beacon: Beacon) {
        guard let index = beacons.firstIndex(where: { $0.id == beacon.id }) else {
            return
        }
        beacons[index] = beacon
        addLog(.settings, reason: "更新信标识别依据：\(beacon.displayName)", relatedBeacons: [beacon])
    }

    func pause(_ mode: PauseMode, customUntil: Date? = nil) {
        let now = Date()
        let until: Date?
        switch mode {
        case .fifteenMinutes:
            until = now.addingTimeInterval(15 * 60)
        case .thirtyMinutes:
            until = now.addingTimeInterval(30 * 60)
        case .oneHour:
            until = now.addingTimeInterval(60 * 60)
        case .endOfDay:
            until = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now)
        case .custom:
            if let customUntil, customUntil <= now {
                until = Calendar.current.date(byAdding: .day, value: 1, to: customUntil)
            } else {
                until = customUntil
            }
        case .manual, .nextUnlock, .wifiLeaves:
            until = nil
        }

        promptTimer?.invalidate()
        promptPresenter.close()
        activePause = ActivePause(mode: mode, startedAt: now, until: until, wifiSSID: currentSSID ?? currentBSSID)
        status = .paused
        resetAbsenceCounters()
        addLog(.pause, reason: activePause?.label ?? mode.label)
    }

    func resumeGuard(reason: String = "用户手动恢复守护") {
        activePause = nil
        resetAbsenceCounters()
        if guardEnabled {
            refreshAvailability(reason: reason)
        } else {
            status = .disabled
        }
        addLog(.resume, reason: reason)
    }

    func cancelPendingLock() {
        promptTimer?.invalidate()
        promptPresenter.close()
        let reason = "用户取消本次锁屏"
        addLog(.cancel, reason: reason)

        let cutoff = Date().addingTimeInterval(TimeInterval(-rules.cancelWindowMinutes * 60))
        let recentCancels = logs.filter { $0.type == .cancel && $0.timestamp >= cutoff }.count
        if recentCancels >= rules.cancelThreshold {
            NotificationController.send(
                title: "Auto Locker",
                body: "近期频繁取消锁屏，可临时进入暂停模式减少误触发。"
            )
        }

        status = guardEnabled ? .guarding : .disabled
        promptReason = ""
        countdownRemaining = 0
        resetAbsenceCounters()
    }

    func performLock(reason: String, bypassPrompt: Bool = false) {
        promptTimer?.invalidate()
        promptPresenter.close()
        promptReason = ""
        countdownRemaining = 0
        resetAbsenceCounters()

        addLog(.lock, reason: reason)
        let error = LockController.lockScreen()
        if let error {
            addLog(.unavailable, reason: error)
            status = .unavailable
            unavailableReason = error
        } else if guardEnabled {
            status = .guarding
        } else {
            status = .disabled
        }
    }

    func startTimerLock(minutes: Int) {
        let clamped = max(1, minutes)
        timerLockDurationMinutes = clamped
        timerLockEnd = Date().addingTimeInterval(TimeInterval(clamped * 60))
        addLog(.timer, reason: "启动定时锁屏：\(clamped) 分钟")
    }

    func cancelTimerLock() {
        timerLockEnd = nil
        addLog(.timer, reason: "取消定时锁屏")
    }

    func deleteLog(_ log: EventLog) {
        logs.removeAll { $0.id == log.id }
    }

    func clearLogs() {
        logs.removeAll()
    }

    func exportLogs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "auto-locker-logs.json"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else {
                return
            }
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(self.logs)
                try data.write(to: url, options: .atomic)
            } catch {
                self.addLog(.unavailable, reason: "导出日志失败：\(error.localizedDescription)")
            }
        }
    }

    func exportScanDiagnostics() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "auto-locker-scan-diagnostics.json"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else {
                return
            }
            do {
                let payload = ScanDiagnosticsExport(
                    exportedAt: Date(),
                    bluetoothState: self.scanner.powerState,
                    isScanning: self.scanner.isScanning,
                    devices: self.scanner.devices
                )
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(payload)
                try data.write(to: url, options: .atomic)
                self.addLog(.scan, reason: "导出扫描诊断：\(url.lastPathComponent)")
            } catch {
                self.addLog(.unavailable, reason: "导出扫描诊断失败：\(error.localizedDescription)")
            }
        }
    }

    func startStabilityTest(for beacon: Beacon) {
        stabilitySession = StabilityTestSession(beaconID: beacon.id)
        lastStabilityResult = nil
        addLog(.stability, reason: "开始稳定性测试：\(beacon.displayName)", relatedBeacons: [beacon])
    }

    func stopStabilityTest() {
        guard let session = stabilitySession else {
            return
        }
        finishStabilityTest(session)
    }

    func fieldIsSelected(_ field: MatchField, for beacon: Beacon) -> Bool {
        beacon.selectedFields.contains(field)
    }

    func setField(_ field: MatchField, selected: Bool, for beacon: Beacon) {
        var updated = beacon
        if selected {
            if !updated.selectedFields.contains(field) {
                updated.selectedFields.append(field)
            }
        } else {
            updated.selectedFields.removeAll { $0 == field }
        }
        updateBeacon(updated)
    }

    func currentPresenceSummary() -> String {
        let now = Date()
        let count = beacons.filter { presence(for: $0, now: now, updateBeaconState: false).isPresent }.count
        if beacons.isEmpty {
            return "尚未绑定信标"
        }
        return "\(count)/\(beacons.count) 个信标在场"
    }

    func runtimeStatus(for beacon: Beacon) -> BeaconRuntimeStatus {
        let freshnessSeconds = Int(ceil(guardPresenceFreshnessSeconds))
        guard !beacon.selectedFields.isEmpty else {
            return BeaconRuntimeStatus(
                state: .notConfigured,
                ageSeconds: nil,
                rssi: nil,
                freshnessSeconds: freshnessSeconds,
                rssiThreshold: nil
            )
        }

        let now = Date()
        let device = scanner.devices.first(where: { deviceMatches($0, beacon: beacon) })
        let relatedMatch = device == nil ? closestRelatedDevice(for: beacon) : nil
        let statusDevice = device ?? relatedMatch?.device
        let age = runtimeAge(now: now, device: statusDevice, beacon: beacon)
        let rssi = statusDevice?.rssi ?? beacon.lastRSSI
        let scanHasSettled = scanner.scanStartedAt.map {
            now.timeIntervalSince($0) >= guardPresenceFreshnessSeconds
        } ?? false

        guard scanner.powerState == .poweredOn else {
            return BeaconRuntimeStatus(
                state: .bluetoothUnavailable,
                ageSeconds: age,
                rssi: rssi,
                freshnessSeconds: freshnessSeconds,
                rssiThreshold: nil
            )
        }

        guard scanner.isScanning else {
            return BeaconRuntimeStatus(
                state: .scanPaused,
                ageSeconds: age,
                rssi: rssi,
                freshnessSeconds: freshnessSeconds,
                rssiThreshold: nil
            )
        }

        guard let device else {
            if let relatedMatch, scanHasSettled {
                return BeaconRuntimeStatus(
                    state: .fieldMismatch,
                    ageSeconds: age,
                    rssi: rssi,
                    freshnessSeconds: freshnessSeconds,
                    rssiThreshold: nil,
                    mismatchedFields: relatedMatch.report.problemFields.map(\.label)
                )
            }
            return BeaconRuntimeStatus(
                state: scanHasSettled ? .notDetected : .scanning,
                ageSeconds: age,
                rssi: rssi,
                freshnessSeconds: freshnessSeconds,
                rssiThreshold: nil
            )
        }

        let isFresh = now.timeIntervalSince(device.lastSeen) <= guardPresenceFreshnessSeconds
        guard isFresh else {
            return BeaconRuntimeStatus(
                state: scanHasSettled ? .stale : .scanning,
                ageSeconds: age,
                rssi: device.rssi,
                freshnessSeconds: freshnessSeconds,
                rssiThreshold: nil
            )
        }

        if rules.detectionMode == .rssiThreshold, device.rssi < rules.rssiThreshold {
            return BeaconRuntimeStatus(
                state: .weakSignal,
                ageSeconds: age,
                rssi: device.rssi,
                freshnessSeconds: freshnessSeconds,
                rssiThreshold: rules.rssiThreshold
            )
        }

        return BeaconRuntimeStatus(
            state: .present,
            ageSeconds: age,
            rssi: device.rssi,
            freshnessSeconds: freshnessSeconds,
            rssiThreshold: rules.detectionMode == .rssiThreshold ? rules.rssiThreshold : nil
        )
    }

    private func runtimeAge(now: Date, device: DiscoveredDevice?, beacon: Beacon) -> Int? {
        let lastSeen = device?.lastSeen ?? beacon.lastSeen
        return lastSeen.map { max(0, Int(now.timeIntervalSince($0))) }
    }

    private func matchReport(for device: DiscoveredDevice, beacon: Beacon) -> BeaconMatchReport {
        guard !beacon.selectedFields.isEmpty else {
            return BeaconMatchReport()
        }

        var matched = 0
        var missing = 0
        var problemFields: [MatchField] = []

        for field in beacon.selectedFields {
            switch field {
            case .name:
                guard let expected = normalized(beacon.expectedName), !expected.isEmpty else {
                    missing += 1
                    continue
                }
                guard let actual = normalized(device.displayName), !actual.isEmpty else {
                    missing += 1
                    problemFields.append(field)
                    continue
                }
                if actual == expected {
                    matched += 1
                } else {
                    problemFields.append(field)
                }
            case .identifier:
                guard let expected = normalized(beacon.expectedIdentifier), !expected.isEmpty else {
                    missing += 1
                    continue
                }
                guard let actual = normalized(device.identifier), !actual.isEmpty else {
                    missing += 1
                    problemFields.append(field)
                    continue
                }
                if actual == expected {
                    matched += 1
                } else {
                    problemFields.append(field)
                }
            case .manufacturerData:
                guard let expected = normalized(beacon.expectedManufacturerDataHex), !expected.isEmpty else {
                    missing += 1
                    continue
                }
                guard let actual = normalized(device.manufacturerDataHex), !actual.isEmpty else {
                    missing += 1
                    problemFields.append(field)
                    continue
                }
                if actual == expected {
                    matched += 1
                } else {
                    problemFields.append(field)
                }
            }
        }

        return BeaconMatchReport(matchedCount: matched, missingCount: missing, problemFields: problemFields)
    }

    private func closestRelatedDevice(for beacon: Beacon) -> (device: DiscoveredDevice, report: BeaconMatchReport)? {
        let candidates = scanner.devices.compactMap { device -> (DiscoveredDevice, BeaconMatchReport, Int)? in
            let score = relatedDeviceScore(for: device, beacon: beacon)
            guard score > 0 else {
                return nil
            }
            return (device, matchReport(for: device, beacon: beacon), score)
        }

        let best = candidates.sorted { lhs, rhs in
            if lhs.2 != rhs.2 {
                return lhs.2 > rhs.2
            }
            if lhs.1.matchedCount != rhs.1.matchedCount {
                return lhs.1.matchedCount > rhs.1.matchedCount
            }
            if lhs.1.problemFields.count != rhs.1.problemFields.count {
                return lhs.1.problemFields.count < rhs.1.problemFields.count
            }
            return lhs.0.lastSeen > rhs.0.lastSeen
        }.first

        return best.map { ($0.0, $0.1) }
    }

    private func relatedDeviceScore(for device: DiscoveredDevice, beacon: Beacon) -> Int {
        var score = 0
        if normalized(device.identifier) == normalized(beacon.expectedIdentifier) {
            score += 4
        }
        if normalized(device.displayName) == normalized(beacon.expectedName) {
            score += 2
        }
        return score
    }

    private func configureCallbacks() {
        scanner.onDevicesChanged = { [weak self] in
            guard let self else {
                return
            }
            self.objectWillChange.send()
            self.evaluateGuard(trigger: "蓝牙扫描更新")
        }

        scanner.onStateChanged = { [weak self] in
            guard let self else {
                return
            }
            self.objectWillChange.send()
            self.refreshAvailability(reason: "蓝牙状态变化：\(self.scanner.powerState.label)")
        }
    }

    private func configureAutosave() {
        Publishers.MergeMany(
            $guardEnabled.map { _ in () }.eraseToAnyPublisher(),
            $beacons.map { _ in () }.eraseToAnyPublisher(),
            $rules.map { _ in () }.eraseToAnyPublisher(),
            $networkRules.map { _ in () }.eraseToAnyPublisher(),
            $advanced.map { _ in () }.eraseToAnyPublisher(),
            $logs.map { _ in () }.eraseToAnyPublisher(),
            $activePause.map { _ in () }.eraseToAnyPublisher()
        )
        .dropFirst()
        .sink { [weak self] _ in
            self?.scheduleSave()
        }
        .store(in: &cancellables)
    }

    private func configureSystemObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSessionBecameActive),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSessionBecameInactive),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    private func startEvaluationTimer() {
        evaluationTimer?.invalidate()
        evaluationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        wifiMonitor.refresh()
        evaluateTimerLock()
        evaluateStabilityTestSample()
        evaluateGuard(trigger: "周期检查")
    }

    private func evaluateTimerLock() {
        guard let timerLockEnd else {
            return
        }
        objectWillChange.send()
        if Date() >= timerLockEnd {
            self.timerLockEnd = nil
            performLock(reason: "定时锁屏倒计时结束", bypassPrompt: true)
        }
    }

    private func refreshAvailability(reason: String) {
        if !guardEnabled {
            status = .disabled
            unavailableReason = nil
            return
        }

        if beacons.isEmpty {
            markUnavailable("无已绑定信标")
            return
        }

        switch scanner.powerState {
        case .poweredOn:
            unavailableReason = nil
            lastUnavailableLogReason = nil
            scanner.startScanning()
            status = activePause == nil ? .guarding : .paused
            if reason.contains("用户开启") || reason.contains("自动恢复") {
                addLog(.resume, reason: reason)
            }
        case .unknown, .resetting:
            scanner.startScanning()
            markUnavailable("蓝牙状态初始化中")
        case .unsupported:
            markUnavailable("这台 Mac 不支持当前蓝牙扫描能力")
        case .unauthorized:
            markUnavailable("蓝牙权限未授予")
        case .poweredOff:
            markUnavailable("蓝牙已关闭")
        }
    }

    private func markUnavailable(_ reason: String) {
        status = .unavailable
        unavailableReason = reason
        if lastUnavailableLogReason != reason {
            addLog(.unavailable, reason: reason)
            lastUnavailableLogReason = reason
        }
    }

    private var guardScanRecoveryGraceSeconds: TimeInterval {
        max(15, Double(rules.delaySeconds), min(Double(advanced.lowFrequencyScanIntervalSeconds), 60))
    }

    private var guardPresenceFreshnessSeconds: TimeInterval {
        let delay = max(1, Double(rules.delaySeconds))
        return max(5, min(delay / 2, 10))
    }

    private var guardPreLockConfirmationSeconds: TimeInterval {
        5
    }

    private func guardScanGraceIsActive(now: Date) -> Bool {
        guard let guardScanGraceUntil else {
            return false
        }
        if now < guardScanGraceUntil {
            return true
        }
        self.guardScanGraceUntil = nil
        guardScanGraceResetsAbsence = true
        return false
    }

    private func recoverGuardScanningAfterSystemInterruption(
        reason: String,
        resetScanRecovery: Bool = true,
        graceSeconds: TimeInterval? = nil,
        resetAbsenceDuringGrace: Bool = true
    ) {
        guard guardEnabled else {
            return
        }

        let now = Date()
        let alreadyInGrace = guardScanGraceUntil.map { now < $0 } ?? false
        if scanner.powerState == .poweredOn {
            scanner.restartScanning()
        } else {
            scanner.startScanning()
        }

        let graceSeconds = graceSeconds ?? guardScanRecoveryGraceSeconds
        guardScanGraceUntil = now.addingTimeInterval(graceSeconds)
        guardScanGraceResetsAbsence = resetAbsenceDuringGrace
        if resetAbsenceDuringGrace {
            resetAbsenceCounters(resetScanRecovery: resetScanRecovery)
        }
        status = activePause == nil ? .guarding : .paused

        if !alreadyInGrace {
            addLog(.scan, reason: "\(reason)，\(Int(graceSeconds)) 秒内暂缓离开判定")
        }
    }

    private func evaluateGuard(trigger: String) {
        if status == .prompting {
            return
        }

        applyBlacklistRuleIfNeeded()

        guard guardEnabled else {
            status = .disabled
            return
        }

        refreshAvailability(reason: trigger)
        guard status == .guarding || status == .paused else {
            return
        }

        if resolvePauseIfNeeded() {
            return
        }

        if shouldSuppressForNetwork() {
            return
        }

        guard status == .guarding else {
            return
        }

        let now = Date()
        if guardScanGraceIsActive(now: now) {
            if guardScanGraceResetsAbsence {
                resetAbsenceCounters(resetScanRecovery: false)
            }
            return
        }

        let presences = beacons.map { presence(for: $0, now: now) }
        let presentCount = presences.filter(\.isPresent).count
        let shouldBePresent = requiredPresentCount()
        let isPresent: Bool
        switch rules.multiBeaconLogic {
        case .any:
            isPresent = presentCount >= 1
        case .all:
            isPresent = presentCount == beacons.count
        case .atLeast:
            isPresent = presentCount >= shouldBePresent
        }

        if isPresent {
            resetAbsenceCounters()
            return
        }

        if missingStartedAt == nil {
            missingStartedAt = now
            consecutiveMisses = 1
        } else {
            consecutiveMisses += 1
        }

        let elapsed = now.timeIntervalSince(missingStartedAt ?? now)
        let enoughTime = elapsed >= TimeInterval(rules.delaySeconds)
        let enoughMisses = rules.debounceStrategy == .delayOnly || consecutiveMisses >= rules.requiredConsecutiveMisses

        if enoughTime && enoughMisses {
            if !recoveredScanForCurrentAbsence && scanner.powerState == .poweredOn {
                recoveredScanForCurrentAbsence = true
                recoverGuardScanningAfterSystemInterruption(
                    reason: "离开判定前重启蓝牙扫描确认",
                    resetScanRecovery: false,
                    graceSeconds: guardPreLockConfirmationSeconds,
                    resetAbsenceDuringGrace: false
                )
                return
            }

            let reason = "离开条件满足：\(presentCount)/\(beacons.count) 个信标在场，规则为 \(rules.summary)"
            beginPreLockPrompt(reason: reason)
        }
    }

    private func applyBlacklistRuleIfNeeded() {
        let blacklist = normalizedList(networkRules.blacklistSSIDs)
        guard let matchedNetwork = matchedCurrentNetwork(in: blacklist),
              networkRules.blacklistBehavior == .enableGuard,
              !guardEnabled,
              !beacons.isEmpty,
              scanner.powerState == .poweredOn
        else {
            return
        }

        guardEnabled = true
        status = .guarding
        scanner.startScanning()
        addLog(.network, reason: "命中 Wi-Fi 黑名单，自动启用守护：\(matchedNetwork)")
    }

    private func resolvePauseIfNeeded() -> Bool {
        guard let pause = activePause else {
            return false
        }

        let now = Date()
        switch pause.mode {
        case .manual, .nextUnlock:
            status = .paused
            return true
        case .wifiLeaves:
            if let pausedNetwork = pause.wifiSSID, !currentNetworkKeys().contains(normalized(pausedNetwork) ?? "") {
                resumeGuard(reason: "已离开暂停时的 Wi-Fi：\(pausedNetwork)")
                return false
            }
            status = .paused
            return true
        case .fifteenMinutes, .thirtyMinutes, .oneHour, .endOfDay, .custom:
            if let until = pause.until, now >= until {
                resumeGuard(reason: "暂停时间结束，自动恢复守护")
                return false
            }
            status = .paused
            return true
        }
    }

    private func shouldSuppressForNetwork() -> Bool {
        let whitelist = normalizedList(networkRules.whitelistSSIDs)
        guard let matchedNetwork = matchedCurrentNetwork(in: whitelist) else {
            if networkSuppressionSSID != nil {
                networkSuppressionSSID = nil
                status = .guarding
                addLog(.network, reason: "离开白名单网络，恢复守护")
            }
            return false
        }

        if networkSuppressionSSID != matchedNetwork {
            networkSuppressionSSID = matchedNetwork
            addLog(.network, reason: "命中 Wi-Fi 白名单，\(networkRules.whitelistBehavior.label)：\(matchedNetwork)")
        }

        switch networkRules.whitelistBehavior {
        case .suppressLock, .pauseGuard:
            status = .paused
            resetAbsenceCounters()
            return true
        case .enableGuard:
            status = .guarding
            return false
        }
    }

    private func beginPreLockPrompt(reason: String) {
        status = .prompting
        promptReason = reason
        countdownRemaining = max(1, rules.preLockCountdownSeconds)
        addLog(.prompt, reason: reason)
        NotificationController.send(title: "Auto Locker 即将锁屏", body: "\(countdownRemaining) 秒后锁屏，可在提示窗口中取消。")
        promptPresenter.show(store: self)

        promptTimer?.invalidate()
        promptTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.countdownRemaining -= 1
            if self.countdownRemaining <= 0 {
                timer.invalidate()
                self.performLock(reason: self.promptReason)
            }
        }
    }

    private func requiredPresentCount() -> Int {
        switch rules.multiBeaconLogic {
        case .any:
            return min(1, beacons.count)
        case .all:
            return beacons.count
        case .atLeast:
            return min(max(1, rules.requiredBeaconCount), max(1, beacons.count))
        }
    }

    private func presence(
        for beacon: Beacon,
        now: Date,
        updateBeaconState: Bool = true
    ) -> (isPresent: Bool, device: DiscoveredDevice?) {
        guard let device = scanner.devices.first(where: { deviceMatches($0, beacon: beacon) }) else {
            return (false, nil)
        }

        if updateBeaconState, let index = beacons.firstIndex(where: { $0.id == beacon.id }) {
            beacons[index].lastSeen = device.lastSeen
            beacons[index].lastRSSI = device.rssi
            beacons[index].manufacturerCompanyID = device.manufacturerCompanyID
            beacons[index].manufacturerName = device.manufacturerName
            beacons[index].manufacturerInfo = device.manufacturerDisplayName ?? device.manufacturerDataHex
        }

        let freshness = guardPresenceFreshnessSeconds
        let isFresh = now.timeIntervalSince(device.lastSeen) <= freshness
        guard isFresh else {
            return (false, device)
        }

        switch rules.detectionMode {
        case .missing:
            return (true, device)
        case .rssiThreshold:
            return (device.rssi >= rules.rssiThreshold, device)
        }
    }

    private func deviceMatches(_ device: DiscoveredDevice, beacon: Beacon) -> Bool {
        matchReport(for: device, beacon: beacon).matches(for: beacon)
    }

    private func resetAbsenceCounters(resetScanRecovery: Bool = true) {
        missingStartedAt = nil
        consecutiveMisses = 0
        if resetScanRecovery {
            recoveredScanForCurrentAbsence = false
        }
    }

    private func evaluateStabilityTestSample() {
        guard var session = stabilitySession,
              let beacon = beacons.first(where: { $0.id == session.beaconID })
        else {
            return
        }

        let now = Date()
        let sample = presence(for: beacon, now: now, updateBeaconState: false).device
        session.samples.append((date: now, rssi: sample?.rssi))
        stabilitySession = session

        if now.timeIntervalSince(session.startedAt) >= session.duration {
            finishStabilityTest(session)
        }
    }

    private func finishStabilityTest(_ session: StabilityTestSession) {
        let rssis = session.samples.compactMap(\.rssi)
        let seen = rssis.count
        let total = max(1, session.samples.count)
        let continuityScore = Int((Double(seen) / Double(total)) * 70)
        let averageRSSI = rssis.isEmpty ? nil : Double(rssis.reduce(0, +)) / Double(rssis.count)
        let spread = rssis.isEmpty ? nil : (rssis.max() ?? 0) - (rssis.min() ?? 0)
        let stabilityScore = max(0, 30 - min(30, spread ?? 30))
        let score = min(100, continuityScore + stabilityScore)
        let recommendation: String

        if score >= 80 {
            recommendation = "建议作为主要信标使用。"
        } else if score >= 55 {
            recommendation = "可作为次信标，建议提高延迟或搭配多个信标。"
        } else {
            recommendation = "不建议单独作为锁屏依据。"
        }

        let result = StabilityTestResult(
            beaconID: session.beaconID,
            startedAt: session.startedAt,
            endedAt: Date(),
            sampleCount: total,
            seenSamples: seen,
            averageRSSI: averageRSSI,
            rssiSpread: spread,
            score: score,
            recommendation: recommendation
        )
        stabilitySession = nil
        lastStabilityResult = result
        addLog(.stability, reason: "稳定性测试完成：评分 \(score)，\(recommendation)")
    }

    private func addLog(
        _ type: LogEventType,
        reason: String,
        relatedBeacons: [Beacon]? = nil,
        debug: [String: String] = [:]
    ) {
        let beaconSource = relatedBeacons ?? beacons
        let entry = EventLog(
            type: type,
            reason: reason,
            beaconSnapshots: beaconSource.map {
                BeaconSnapshot(
                    id: $0.id,
                    displayName: $0.displayName,
                    manufacturerName: $0.manufacturerDisplayName,
                    selectedFields: $0.selectedFields,
                    lastRSSI: $0.lastRSSI,
                    lastSeen: $0.lastSeen
                )
            },
            networkSnapshot: NetworkSnapshot(
                ssid: currentWiFiDisplay,
                whitelistHit: matchedCurrentNetwork(in: normalizedList(networkRules.whitelistSSIDs)) != nil,
                blacklistHit: matchedCurrentNetwork(in: normalizedList(networkRules.blacklistSSIDs)) != nil
            ),
            ruleSnapshot: GuardRuleSnapshot(
                detectionMode: rules.detectionMode,
                delaySeconds: rules.delaySeconds,
                rssiThreshold: rules.rssiThreshold,
                debounceStrategy: rules.debounceStrategy,
                multiBeaconLogic: rules.multiBeaconLogic,
                requiredBeaconCount: rules.requiredBeaconCount,
                preLockCountdownSeconds: rules.preLockCountdownSeconds
            ),
            debug: debug
        )
        logs.insert(entry, at: 0)
    }

    private func load() {
        do {
            let url = FileLocations.stateFile
            guard FileManager.default.fileExists(atPath: url.path) else {
                return
            }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let state = try decoder.decode(PersistedState.self, from: data)
            guardEnabled = state.guardEnabled
            beacons = state.beacons.map(normalizeLoadedBeacon)
            rules = state.rules
            networkRules = state.networkRules
            advanced = state.advanced
            logs = state.logs
            activePause = state.activePause
        } catch {
            logs = [
                EventLog(
                    type: .unavailable,
                    reason: "读取本地状态失败：\(error.localizedDescription)",
                    beaconSnapshots: [],
                    networkSnapshot: NetworkSnapshot(ssid: nil, whitelistHit: false, blacklistHit: false),
                    ruleSnapshot: GuardRuleSnapshot(
                        detectionMode: rules.detectionMode,
                        delaySeconds: rules.delaySeconds,
                        rssiThreshold: rules.rssiThreshold,
                        debounceStrategy: rules.debounceStrategy,
                        multiBeaconLogic: rules.multiBeaconLogic,
                        requiredBeaconCount: rules.requiredBeaconCount,
                        preLockCountdownSeconds: rules.preLockCountdownSeconds
                    ),
                    debug: [:]
                )
            ]
        }
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.save()
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    private func save() {
        let state = PersistedState(
            guardEnabled: guardEnabled,
            beacons: beacons,
            rules: rules,
            networkRules: networkRules,
            advanced: advanced,
            logs: logs,
            activePause: activePause
        )
        let applicationSupportDirectory = FileLocations.applicationSupportDirectory
        let stateFile = FileLocations.stateFile

        saveQueue.async { [weak self] in
            do {
                try FileManager.default.createDirectory(
                    at: applicationSupportDirectory,
                    withIntermediateDirectories: true
                )
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(state)
                try data.write(to: stateFile, options: .atomic)
            } catch {
                DispatchQueue.main.async {
                    self?.unavailableReason = "保存本地状态失败：\(error.localizedDescription)"
                }
            }
        }
    }

    @objc private func handleSessionBecameActive() {
        if activePause?.mode == .nextUnlock {
            resumeGuard(reason: "检测到用户解锁，自动恢复守护")
        }

        if guardEnabled {
            recoverGuardScanningAfterSystemInterruption(reason: "用户解锁后恢复蓝牙扫描")
        }
    }

    @objc private func handleSessionBecameInactive() {
        guard guardEnabled else {
            return
        }

        guardScanGraceUntil = .distantFuture
        guardScanGraceResetsAbsence = true
        resetAbsenceCounters()
        if status == .prompting {
            promptTimer?.invalidate()
            promptPresenter.close()
            promptReason = ""
            countdownRemaining = 0
            status = .guarding
        }
    }

    @objc private func handleSystemDidWake() {
        recoverGuardScanningAfterSystemInterruption(reason: "系统唤醒后恢复蓝牙扫描")
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        return trimmed.lowercased()
    }

    private func normalizedList(_ values: [String]) -> Set<String> {
        Set(values.compactMap { normalized($0) })
    }

    private func normalizeLoadedBeacon(_ beacon: Beacon) -> Beacon {
        var beacon = beacon
        let legacyDefaultFields: Set<MatchField> = [.identifier, .name, .manufacturerData]
        if Set(beacon.selectedFields) == legacyDefaultFields {
            beacon.selectedFields = Beacon.defaultSelectedFields(expectedName: beacon.expectedName ?? beacon.displayName)
        }
        return beacon
    }

    private func currentNetworkKeys() -> Set<String> {
        var keys: Set<String> = []
        if let ssid = normalized(currentSSID) {
            keys.insert(ssid)
        }
        if let bssid = normalized(currentBSSID) {
            keys.insert(bssid)
        }
        return keys
    }

    private func matchedCurrentNetwork(in configuredValues: Set<String>) -> String? {
        if let ssid = normalized(currentSSID), configuredValues.contains(ssid) {
            return currentSSID ?? currentBSSID
        }
        if let bssid = normalized(currentBSSID), configuredValues.contains(bssid) {
            return currentBSSID ?? currentSSID
        }
        return nil
    }
}

private struct BeaconMatchReport {
    var matchedCount = 0
    var missingCount = 0
    var problemFields: [MatchField] = []

    func matches(for beacon: Beacon) -> Bool {
        problemFields.isEmpty && matchedCount > 0 && missingCount <= beacon.missingTolerance
    }
}
