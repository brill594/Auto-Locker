import SwiftUI

struct LogView: View {
    @EnvironmentObject private var store: AutoLockerStore
    @State private var selectedLogID: EventLog.ID?

    private var selectedLog: EventLog? {
        store.logs.first { $0.id == selectedLogID } ?? store.logs.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(
                title: "日志",
                subtitle: "记录提示、取消、暂停、恢复、锁屏和规则命中，便于回溯触发原因。"
            )

            HStack {
                Button("导出 JSON") {
                    store.exportLogs()
                }
                Button("清空全部", role: .destructive) {
                    store.clearLogs()
                    selectedLogID = nil
                }
                .disabled(store.logs.isEmpty)
                Spacer()
                Text("\(store.logs.count) 条事件")
                    .foregroundStyle(.secondary)
            }

            if store.logs.isEmpty {
                EmptyState(
                    systemImage: "list.bullet.rectangle",
                    title: "暂无日志",
                    message: "扫描、绑定信标、暂停或锁屏时会生成结构化日志。"
                )
                Spacer()
            } else {
                HSplitView {
                    List(store.logs, selection: $selectedLogID) { log in
                        LogRow(log: log)
                            .tag(log.id)
                    }
                    .frame(minWidth: 360)

                    if let log = selectedLog {
                        LogDetail(log: log) {
                            store.deleteLog(log)
                            selectedLogID = store.logs.first?.id
                        }
                        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(24)
        .onAppear {
            selectedLogID = selectedLogID ?? store.logs.first?.id
        }
    }
}

private struct LogRow: View {
    let log: EventLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.type.label)
                    .font(.headline)
                Spacer()
                Text(log.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(log.displayReason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

private struct LogDetail: View {
    let log: EventLog
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.type.label)
                            .font(.title2.weight(.semibold))
                        Text(log.timestamp.autoLockerShortText)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("删除", role: .destructive, action: onDelete)
                }

                GroupBox("触发原因") {
                    Text(log.displayReason)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                }

                GroupBox("网络快照") {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoLine(title: "Wi-Fi", value: log.networkSnapshot.ssid ?? "无")
                        InfoLine(title: "白名单命中", value: log.networkSnapshot.whitelistHit ? "是" : "否")
                        InfoLine(title: "黑名单命中", value: log.networkSnapshot.blacklistHit ? "是" : "否")
                    }
                    .padding(4)
                }

                GroupBox("规则快照") {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoLine(title: "判定模式", value: log.ruleSnapshot.detectionMode.label)
                        InfoLine(title: "延迟", value: "\(log.ruleSnapshot.delaySeconds) 秒")
                        InfoLine(title: "RSSI 阈值", value: "\(log.ruleSnapshot.rssiThreshold) dBm")
                        InfoLine(title: "抗抖", value: log.ruleSnapshot.debounceStrategy.label)
                        InfoLine(title: "多信标", value: log.ruleSnapshot.multiBeaconLogic.label)
                        InfoLine(title: "提示倒计时", value: "\(log.ruleSnapshot.preLockCountdownSeconds) 秒")
                    }
                    .padding(4)
                }

                GroupBox("关联信标") {
                    if log.beaconSnapshots.isEmpty {
                        Text("无关联信标")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(log.beaconSnapshots, id: \.id) { beacon in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(beacon.displayName)
                                        .font(.headline)
                                    Text(beacon.selectedFields.map(\.label).joined(separator: "、"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("厂商 \(beacon.manufacturerName ?? "未识别")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("RSSI \(beacon.lastRSSI.map(String.init) ?? "无")，最后出现 \(beacon.lastSeen?.autoLockerShortText ?? "无")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(4)
                    }
                }

                if !log.debug.isEmpty {
                    GroupBox("调试字段") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(log.debug.keys.sorted(), id: \.self) { key in
                                InfoLine(title: key, value: log.debug[key] ?? "")
                            }
                        }
                        .padding(4)
                    }
                }
            }
            .padding(.trailing, 8)
        }
    }
}
