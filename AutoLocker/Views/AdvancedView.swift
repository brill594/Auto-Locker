import SwiftUI

struct AdvancedView: View {
    @EnvironmentObject private var store: AutoLockerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle(
                    title: "高级",
                    subtitle: "调整扫描频率、自动恢复和识别字段优先级。"
                )

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Stepper(
                            "前台扫描参考周期 \(store.advanced.foregroundScanIntervalSeconds) 秒",
                            value: $store.advanced.foregroundScanIntervalSeconds,
                            in: 3...120
                        )
                        NumberInputRow(
                            title: "信标页手动扫描时长",
                            value: $store.advanced.discoveryScanDurationSeconds,
                            range: 5...120,
                            step: 5,
                            suffix: "秒",
                            fieldWidth: 88
                        )
                        Stepper(
                            "后台扫描参考周期 \(store.advanced.backgroundScanIntervalSeconds) 秒",
                            value: $store.advanced.backgroundScanIntervalSeconds,
                            in: 10...300,
                            step: 5
                        )
                        Stepper(
                            "低频扫描周期 \(store.advanced.lowFrequencyScanIntervalSeconds) 秒",
                            value: $store.advanced.lowFrequencyScanIntervalSeconds,
                            in: 30...600,
                            step: 10
                        )
                        Text("CoreBluetooth 扫描由系统调度；手动扫描时长用于信标页发现设备，低频扫描周期仅作为解锁/唤醒后的恢复保护参考，不会拉长实时离开判定。")
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                } label: {
                    Label("扫描策略", systemImage: "dot.radiowaves.left.and.right")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle("应用重新打开后自动恢复上次守护状态", isOn: $store.advanced.autoRestoreGuard)
                        Text("锁屏后回到会话时，应用会重新检查暂停策略和蓝牙状态。")
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                } label: {
                    Label("自动恢复", systemImage: "arrow.clockwise")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(store.advanced.fieldPriority.enumerated()), id: \.element) { index, field in
                            HStack {
                                Text("\(index + 1). \(field.label)")
                                Spacer()
                                Button("上移") {
                                    movePriority(from: index, offset: -1)
                                }
                                .disabled(index == 0)
                                Button("下移") {
                                    movePriority(from: index, offset: 1)
                                }
                                .disabled(index == store.advanced.fieldPriority.count - 1)
                            }
                        }
                    }
                    .padding(4)
                } label: {
                    Label("识别字段优先级", systemImage: "list.number")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoLine(title: "状态文件", value: FileLocations.stateFile.path)
                        InfoLine(title: "发现设备数", value: "\(store.scanner.devices.count)")
                        InfoLine(title: "绑定信标数", value: "\(store.beacons.count)")
                        InfoLine(title: "日志条数", value: "\(store.logs.count)")
                        InfoLine(title: "蓝牙状态", value: store.scanner.powerState.label)
                    }
                    .padding(4)
                } label: {
                    Label("调试信息", systemImage: "ladybug")
                }
            }
            .padding(24)
        }
    }

    private func movePriority(from index: Int, offset: Int) {
        let target = index + offset
        guard store.advanced.fieldPriority.indices.contains(index),
              store.advanced.fieldPriority.indices.contains(target)
        else {
            return
        }
        store.advanced.fieldPriority.swapAt(index, target)
    }
}
