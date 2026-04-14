import Combine
import SwiftUI

struct AdvancedView: View {
    @EnvironmentObject private var store: AutoLockerStore
    @State private var isShowingBluetoothDebugLogs = false
    @State private var debugTraceText = ""
    @State private var isLoadingDebugTrace = false

    private let debugLogRefreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    private let debugLogMaxBytes = 120_000

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
                        InfoLine(title: "调试日志", value: FileLocations.debugTraceFile.path)
                        HStack {
                            Button("调试蓝牙并显示日志") {
                                startBluetoothDebug()
                            }
                            .buttonStyle(.borderedProminent)
                            Button("仅查看调试日志") {
                                showDebugLogs()
                            }
                            Spacer()
                        }
                        Text("蓝牙调试会向后台 Agent 发起 10 秒可用性检查，并显示共享调试追踪文件中的全部日志。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                } label: {
                    Label("调试信息", systemImage: "ladybug")
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $isShowingBluetoothDebugLogs) {
            BluetoothDebugLogSheet(
                logText: debugTraceText,
                logFilePath: FileLocations.debugTraceFile.path,
                isLoading: isLoadingDebugTrace,
                onRefresh: reloadDebugTrace,
                onClose: {
                    isShowingBluetoothDebugLogs = false
                }
            )
            .frame(minWidth: 760, minHeight: 560)
            .onAppear {
                DispatchQueue.main.async {
                    reloadDebugTrace()
                }
            }
        }
        .onReceive(debugLogRefreshTimer) { _ in
            guard isShowingBluetoothDebugLogs, !isLoadingDebugTrace else {
                return
            }
            reloadDebugTrace()
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

    private func startBluetoothDebug() {
        store.runBluetoothAvailabilityDebug()
        showDebugLogs()
        scheduleDelayedDebugLogRefresh()
    }

    private func showDebugLogs() {
        isShowingBluetoothDebugLogs = true
        DispatchQueue.main.async {
            reloadDebugTrace()
        }
    }

    private func reloadDebugTrace() {
        guard !isLoadingDebugTrace else {
            return
        }

        isLoadingDebugTrace = true
        DispatchQueue.global(qos: .utility).async {
            let text = store.readDebugTraceText(maxBytes: debugLogMaxBytes)
            DispatchQueue.main.async {
                debugTraceText = text
                isLoadingDebugTrace = false
            }
        }
    }

    private func scheduleDelayedDebugLogRefresh() {
        for delay in [0.3, 1.2, 10.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard isShowingBluetoothDebugLogs else {
                    return
                }
                reloadDebugTrace()
            }
        }
    }
}

private struct BluetoothDebugLogSheet: View {
    let logText: String
    let logFilePath: String
    let isLoading: Bool
    let onRefresh: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("蓝牙调试日志")
                        .font(.title2.weight(.semibold))
                    Text(logFilePath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("刷新日志", action: onRefresh)
                    .disabled(isLoading)
                Button("关闭", action: onClose)
            }

            Divider()

            TextEditor(text: .constant(logText))
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(20)
    }
}
