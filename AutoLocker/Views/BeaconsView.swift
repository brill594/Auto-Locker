import SwiftUI

struct BeaconsView: View {
    @EnvironmentObject private var store: AutoLockerStore
    @State private var searchText = ""
    @State private var sortField: BeaconSortField = .discoveryOrder
    @State private var sortDirection: BeaconSortDirection = .ascending

    private var filteredDevices: [DiscoveredDevice] {
        sortDevices(store.scanner.devices.filter { $0.matchesBeaconSearch(searchText) })
    }

    private var filteredBeaconIDs: [Beacon.ID] {
        sortBeacons(store.beacons.filter { $0.matchesBeaconSearch(searchText) }).map(\.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle(
                    title: "信标",
                    subtitle: "扫描附近蓝牙设备，绑定一个或多个作为在场判断依据。"
                )

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("搜索设备名、厂商、厂商数据、Service UUID / Data、系统标识符", text: $searchText)
                                .textFieldStyle(.plain)
                            if !searchText.isEmpty {
                                Button("清除") {
                                    searchText = ""
                                }
                            }
                        }
                        .padding(10)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))

                        HStack {
                            Picker("排序", selection: $sortField) {
                                ForEach(BeaconSortField.allCases) { field in
                                    Text(field.label).tag(field)
                                }
                            }
                            .frame(maxWidth: 280)

                            Picker("方向", selection: $sortDirection) {
                                ForEach(BeaconSortDirection.allCases) { direction in
                                    Text(direction.label).tag(direction)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }

                        Text("macOS 的 CoreBluetooth 不暴露真实 MAC 地址；这里会搜索系统设备标识符、设备名、厂商名、Manufacturer Data、Service UUID 和 Service Data。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                } label: {
                    Label("搜索", systemImage: "magnifyingglass")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label(store.scanner.scanStatusText, systemImage: store.scanner.isScanning ? "dot.radiowaves.left.and.right" : "pause.circle")
                            Spacer()
                            if store.scanner.isScanning && !store.guardEnabled {
                                Button("暂停扫描") {
                                    store.stopManualScan()
                                }
                            } else {
                                Button(store.guardEnabled ? "守护中持续扫描" : "扫描 \(store.advanced.discoveryScanDurationSeconds) 秒") {
                                    store.startManualScan()
                                }
                                .disabled(store.guardEnabled && store.scanner.isScanning)
                                .buttonStyle(.borderedProminent)
                            }
                        }

                        HStack {
                            Button("长扫描 30 秒") {
                                store.startManualScan(durationOverride: 30)
                            }
                            .disabled(store.guardEnabled || store.scanner.isScanning)
                            Button("诊断扫描 120 秒") {
                                store.startManualScan(durationOverride: 120)
                            }
                            .disabled(store.guardEnabled || store.scanner.isScanning)
                            Button("清空结果") {
                                store.clearDiscoveredDevices()
                            }
                            .disabled(store.scanner.devices.isEmpty || store.scanner.isScanning)
                            Button("导出诊断") {
                                store.exportScanDiagnostics()
                            }
                            .disabled(store.scanner.devices.isEmpty)
                            Spacer()
                        }

                        Stepper(
                            "手动扫描时长 \(store.advanced.discoveryScanDurationSeconds) 秒",
                            value: $store.advanced.discoveryScanDurationSeconds,
                            in: 5...120,
                            step: 5
                        )
                        .disabled(store.guardEnabled)

                        Text(store.guardEnabled ? "守护开启时需要持续扫描；关闭守护后，手动扫描会按时长自动暂停，便于选择设备。" : "扫描结束后列表会停止刷新，便于选择并绑定设备。")
                            .foregroundStyle(.secondary)
                        Text("如果设备在 nRF Connect 中显示为 Google / Service Data UUID FEF3，可使用诊断扫描并搜索 FEF3 或 Google。")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let error = store.scanner.lastError {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }

                        HStack {
                            Text("已发现 \(store.scanner.devices.count) 个设备，当前显示 \(filteredDevices.count) 个")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }

                        if store.scanner.devices.isEmpty {
                            EmptyState(
                                systemImage: "dot.radiowaves.left.and.right",
                                title: "尚未发现蓝牙设备",
                                message: "点击开始扫描，并确认系统已授予蓝牙权限。"
                            )
                        } else if filteredDevices.isEmpty {
                            EmptyState(
                                systemImage: "magnifyingglass",
                                title: "没有匹配的附近设备",
                                message: "可按设备名、厂商名、厂商数据或系统设备标识符搜索。"
                            )
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredDevices) { device in
                                    HStack(spacing: 12) {
                                        ManufacturerIconView(systemName: device.manufacturerIconSystemName)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(device.displayName)
                                                .font(.headline)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            Text(device.manufacturerDisplayName ?? "厂商未识别")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            Text(device.summary)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                                .truncationMode(.middle)
                                            if !device.rawFieldSummary.isEmpty {
                                                Text(device.rawFieldSummary)
                                                    .font(.caption2.monospaced())
                                                    .foregroundStyle(.tertiary)
                                                    .lineLimit(2)
                                                    .truncationMode(.middle)
                                                    .textSelection(.enabled)
                                            }
                                            Text(device.identifier)
                                                .font(.caption2.monospaced())
                                                .foregroundStyle(.tertiary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        Spacer()
                                        if store.beacons.contains(where: { $0.expectedIdentifier == device.identifier }) {
                                            Text("已绑定")
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Button("绑定") {
                                                store.bind(device)
                                            }
                                        }
                                    }
                                    .padding(10)
                                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                    .padding(4)
                } label: {
                    Label("附近设备", systemImage: "magnifyingglass")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        if store.beacons.isEmpty {
                            EmptyState(
                                systemImage: "lock.open",
                                title: "尚未绑定信标",
                                message: "至少绑定一个信标后，守护才可启用。"
                            )
                        } else if filteredBeaconIDs.isEmpty {
                            EmptyState(
                                systemImage: "magnifyingglass",
                                title: "没有匹配的已绑定信标",
                                message: "可按设备名、厂商名、厂商数据或系统设备标识符搜索。"
                            )
                        } else {
                            ForEach(filteredBeaconIDs, id: \.self) { beaconID in
                                if let binding = beaconBinding(for: beaconID) {
                                    BeaconEditor(beacon: binding)
                                        .environmentObject(store)
                                }
                            }
                        }
                    }
                    .padding(4)
                } label: {
                    Label("已绑定信标", systemImage: "lock.shield")
                }

                if let session = store.stabilitySession,
                   let beacon = store.beacons.first(where: { $0.id == session.beaconID }) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(beacon.displayName)
                                .font(.headline)
                            ProgressView(value: 120 - Double(session.remainingSeconds), total: 120)
                            HStack {
                                Text("剩余 \(session.remainingSeconds) 秒")
                                    .monospacedDigit()
                                Spacer()
                                Button("结束并生成结果") {
                                    store.stopStabilityTest()
                                }
                            }
                        }
                        .padding(4)
                    } label: {
                        Label("稳定性测试中", systemImage: "waveform.path.ecg")
                    }
                }

                if let result = store.lastStabilityResult,
                   let beacon = store.beacons.first(where: { $0.id == result.beaconID }) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(beacon.displayName)
                                .font(.headline)
                            InfoLine(title: "评分", value: "\(result.score)/100")
                            InfoLine(title: "检测连续性", value: "\(result.seenSamples)/\(result.sampleCount)")
                            InfoLine(title: "平均 RSSI", value: result.averageRSSI.map { String(format: "%.1f dBm", $0) } ?? "无样本")
                            InfoLine(title: "RSSI 波动", value: result.rssiSpread.map { "\($0) dB" } ?? "无样本")
                            Text(result.recommendation)
                                .foregroundStyle(result.score >= 80 ? .green : .orange)
                        }
                        .padding(4)
                    } label: {
                        Label("最近稳定性测试", systemImage: "checkmark.seal")
                    }
                }
            }
            .padding(24)
        }
    }

    private func beaconBinding(for id: Beacon.ID) -> Binding<Beacon>? {
        guard let index = store.beacons.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        return $store.beacons[index]
    }

    private func sortDevices(_ devices: [DiscoveredDevice]) -> [DiscoveredDevice] {
        devices.enumerated().sorted { lhs, rhs in
            let result = compareDevices(lhs, rhs)
            if result == .orderedSame {
                return lhs.offset < rhs.offset
            }
            return sortDirection == .ascending ? result == .orderedAscending : result == .orderedDescending
        }
        .map(\.element)
    }

    private func sortBeacons(_ beacons: [Beacon]) -> [Beacon] {
        beacons.enumerated().sorted { lhs, rhs in
            let result = compareBeacons(lhs, rhs)
            if result == .orderedSame {
                return lhs.offset < rhs.offset
            }
            return sortDirection == .ascending ? result == .orderedAscending : result == .orderedDescending
        }
        .map(\.element)
    }

    private func compareDevices(
        _ lhs: EnumeratedSequence<[DiscoveredDevice]>.Element,
        _ rhs: EnumeratedSequence<[DiscoveredDevice]>.Element
    ) -> ComparisonResult {
        switch sortField {
        case .discoveryOrder:
            return compare(lhs.offset, rhs.offset)
        case .manufacturerName:
            return compareOptionalText(lhs.element.manufacturerDisplayName, rhs.element.manufacturerDisplayName)
        case .rssi:
            return compare(lhs.element.rssi, rhs.element.rssi)
        case .deviceName:
            return compareText(lhs.element.displayName, rhs.element.displayName)
        case .lastSeen:
            return compare(lhs.element.lastSeen, rhs.element.lastSeen)
        }
    }

    private func compareBeacons(
        _ lhs: EnumeratedSequence<[Beacon]>.Element,
        _ rhs: EnumeratedSequence<[Beacon]>.Element
    ) -> ComparisonResult {
        switch sortField {
        case .discoveryOrder:
            return compare(lhs.offset, rhs.offset)
        case .manufacturerName:
            return compareOptionalText(lhs.element.manufacturerDisplayName, rhs.element.manufacturerDisplayName)
        case .rssi:
            return compareOptionalInt(lhs.element.lastRSSI, rhs.element.lastRSSI)
        case .deviceName:
            return compareText(lhs.element.displayName, rhs.element.displayName)
        case .lastSeen:
            return compareOptionalDate(lhs.element.lastSeen, rhs.element.lastSeen)
        }
    }

    private func compareText(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.localizedStandardCompare(rhs)
    }

    private func compareOptionalText(_ lhs: String?, _ rhs: String?) -> ComparisonResult {
        guard let lhs, !lhs.isEmpty else {
            if rhs == nil || rhs?.isEmpty == true {
                return .orderedSame
            }
            return sortDirection == .ascending ? .orderedDescending : .orderedAscending
        }
        guard let rhs, !rhs.isEmpty else {
            return sortDirection == .ascending ? .orderedAscending : .orderedDescending
        }
        return compareText(lhs, rhs)
    }

    private func compareOptionalInt(_ lhs: Int?, _ rhs: Int?) -> ComparisonResult {
        guard let lhs else {
            if rhs == nil {
                return .orderedSame
            }
            return sortDirection == .ascending ? .orderedDescending : .orderedAscending
        }
        guard let rhs else {
            return sortDirection == .ascending ? .orderedAscending : .orderedDescending
        }
        return compare(lhs, rhs)
    }

    private func compareOptionalDate(_ lhs: Date?, _ rhs: Date?) -> ComparisonResult {
        guard let lhs else {
            if rhs == nil {
                return .orderedSame
            }
            return sortDirection == .ascending ? .orderedDescending : .orderedAscending
        }
        guard let rhs else {
            return sortDirection == .ascending ? .orderedAscending : .orderedDescending
        }
        return compare(lhs, rhs)
    }

    private func compare<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        if lhs < rhs {
            return .orderedAscending
        }
        if lhs > rhs {
            return .orderedDescending
        }
        return .orderedSame
    }
}

private enum BeaconSortField: String, CaseIterable, Identifiable {
    case discoveryOrder
    case manufacturerName
    case rssi
    case deviceName
    case lastSeen

    var id: String { rawValue }

    var label: String {
        switch self {
        case .discoveryOrder: return "发现顺序"
        case .manufacturerName: return "厂商名"
        case .rssi: return "信号强度"
        case .deviceName: return "设备名"
        case .lastSeen: return "最后出现"
        }
    }
}

private enum BeaconSortDirection: String, CaseIterable, Identifiable {
    case ascending
    case descending

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ascending: return "升序"
        case .descending: return "降序"
        }
    }
}

private struct BeaconEditor: View {
    @EnvironmentObject private var store: AutoLockerStore
    @Binding var beacon: Beacon

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                ManufacturerIconView(systemName: beacon.manufacturerIconSystemName)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        TextField("展示名称", text: $beacon.displayName)
                            .font(.headline)
                        if beacon.isPrimary {
                            Text("主信标")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.green.opacity(0.12), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }
                    Text(beacon.selectedFieldSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("稳定性测试") {
                    store.startStabilityTest(for: beacon)
                }
                Button("设为主信标") {
                    store.setPrimary(beacon)
                }
                .disabled(beacon.isPrimary)
                Button("移除", role: .destructive) {
                    store.removeBeacon(beacon)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("设备标识符")
                        .foregroundStyle(.secondary)
                    TextField("系统设备标识符", text: optionalText($beacon.expectedIdentifier))
                        .font(.system(.body, design: .monospaced))
                }
                GridRow {
                    Text("设备名")
                        .foregroundStyle(.secondary)
                    TextField("设备名", text: optionalText($beacon.expectedName))
                }
                GridRow {
                    Text("厂商名")
                        .foregroundStyle(.secondary)
                    Text(beacon.manufacturerDisplayName ?? "未识别")
                        .foregroundStyle(.secondary)
                }
                GridRow {
                    Text("Manufacturer Data")
                        .foregroundStyle(.secondary)
                    TextField("Manufacturer Data", text: optionalText($beacon.expectedManufacturerDataHex))
                        .font(.system(.body, design: .monospaced))
                }
                GridRow {
                    Text("缺失容忍")
                        .foregroundStyle(.secondary)
                    Stepper("\(beacon.missingTolerance) 个字段", value: $beacon.missingTolerance, in: 0...3)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("识别依据")
                    .font(.subheadline.weight(.medium))
                HStack {
                    ForEach(MatchField.allCases) { field in
                        Toggle(field.label, isOn: Binding(
                            get: { beacon.selectedFields.contains(field) },
                            set: { selected in
                                if selected {
                                    if !beacon.selectedFields.contains(field) {
                                        beacon.selectedFields.append(field)
                                    }
                                } else {
                                    beacon.selectedFields.removeAll { $0 == field }
                                }
                            }
                        ))
                    }
                }
            }
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func optionalText(_ value: Binding<String?>) -> Binding<String> {
        Binding<String>(
            get: { value.wrappedValue ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                value.wrappedValue = trimmed.isEmpty ? nil : trimmed
            }
        )
    }
}

private struct ManufacturerIconView: View {
    let systemName: String?

    var body: some View {
        Image(systemName: systemName ?? "antenna.radiowaves.left.and.right")
            .font(.title3)
            .foregroundStyle(systemName == nil ? Color.secondary : Color.accentColor)
            .frame(width: 26, height: 26)
    }
}

private extension DiscoveredDevice {
    func matchesBeaconSearch(_ query: String) -> Bool {
        BeaconSearchMatcher.matches(query, fields: [
            displayName,
            name,
            localName,
            identifier,
            manufacturerDataHex,
            manufacturerName,
            manufacturerDisplayName,
            manufacturerCompanyID.map { String(format: "0x%04X", Int($0)) },
            serviceUUIDVendorName,
            serviceUUIDVendorMatch?.displayUUID,
            serviceUUIDs.joined(separator: " "),
            solicitedServiceUUIDs.joined(separator: " "),
            overflowServiceUUIDs.joined(separator: " "),
            serviceDataHex.keys.sorted().joined(separator: " "),
            serviceDataHex.values.sorted().joined(separator: " "),
            txPowerLevel.map { String($0) },
            isConnectable.map { $0 ? "connectable yes 可连接" : "connectable no 不可连接" },
            rawFieldSummary,
            advertisementKeys.joined(separator: " ")
        ])
    }
}

private extension Beacon {
    func matchesBeaconSearch(_ query: String) -> Bool {
        BeaconSearchMatcher.matches(query, fields: [
            displayName,
            manufacturerInfo,
            manufacturerName,
            manufacturerDisplayName,
            expectedIdentifier,
            expectedName,
            expectedManufacturerDataHex,
            manufacturerCompanyID.map { String(format: "0x%04X", Int($0)) }
        ])
    }
}

private enum BeaconSearchMatcher {
    static func matches(_ query: String, fields: [String?]) -> Bool {
        let normalizedQuery = query.normalizedBeaconSearchText
        guard !normalizedQuery.isEmpty else {
            return true
        }

        let compactQuery = query.compactBeaconSearchText
        return fields.contains { field in
            guard let field else {
                return false
            }
            return field.normalizedBeaconSearchText.contains(normalizedQuery)
                || (!compactQuery.isEmpty && field.compactBeaconSearchText.contains(compactQuery))
        }
    }
}

private extension String {
    var normalizedBeaconSearchText: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var compactBeaconSearchText: String {
        normalizedBeaconSearchText.filter { $0.isLetter || $0.isNumber }
    }
}
