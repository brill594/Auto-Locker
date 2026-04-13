import SwiftUI

struct BeaconsView: View {
    @EnvironmentObject private var store: AutoLockerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle(
                    title: "信标",
                    subtitle: "扫描附近蓝牙设备，绑定一个或多个作为在场判断依据。"
                )

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

                        Stepper(
                            "手动扫描时长 \(store.advanced.discoveryScanDurationSeconds) 秒",
                            value: $store.advanced.discoveryScanDurationSeconds,
                            in: 5...120,
                            step: 5
                        )
                        .disabled(store.guardEnabled)

                        Text(store.guardEnabled ? "守护开启时需要持续扫描；关闭守护后，手动扫描会按时长自动暂停，便于选择设备。" : "扫描结束后列表会停止刷新，便于选择并绑定设备。")
                            .foregroundStyle(.secondary)

                        if let error = store.scanner.lastError {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }

                        if store.scanner.devices.isEmpty {
                            EmptyState(
                                systemImage: "dot.radiowaves.left.and.right",
                                title: "尚未发现蓝牙设备",
                                message: "点击开始扫描，并确认系统已授予蓝牙权限。"
                            )
                        } else {
                            VStack(spacing: 8) {
                                ForEach(store.scanner.devices.prefix(40)) { device in
                                    HStack(spacing: 12) {
                                        Image(systemName: "antenna.radiowaves.left.and.right")
                                            .foregroundStyle(.secondary)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(device.displayName)
                                                .font(.headline)
                                            Text(device.manufacturerDisplayName ?? "厂商未识别")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(device.summary)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(device.identifier)
                                                .font(.caption2.monospaced())
                                                .foregroundStyle(.tertiary)
                                        }
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
                        } else {
                            ForEach($store.beacons) { $beacon in
                                BeaconEditor(beacon: $beacon)
                                    .environmentObject(store)
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
}

private struct BeaconEditor: View {
    @EnvironmentObject private var store: AutoLockerStore
    @Binding var beacon: Beacon

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
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
