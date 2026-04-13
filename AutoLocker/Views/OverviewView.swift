import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var store: AutoLockerStore
    @State private var customPauseUntil = Date().addingTimeInterval(30 * 60)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle(
                    title: "Auto Locker",
                    subtitle: "基于蓝牙信标、网络规则和定时器自动锁定这台 Mac。"
                )

                HStack(alignment: .top, spacing: 18) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                StatusPill(state: store.status)
                                Spacer()
                                Toggle("守护", isOn: Binding(
                                    get: { store.guardEnabled },
                                    set: { store.setGuardEnabled($0) }
                                ))
                                .toggleStyle(.switch)
                            }

                            InfoLine(title: "信标", value: store.currentPresenceSummary())
                            InfoLine(title: "蓝牙", value: store.scanner.powerState.label)
                            InfoLine(title: "当前 Wi-Fi", value: store.currentSSID ?? "未连接或不可读")
                            InfoLine(title: "规则", value: store.rules.summary)

                            if let reason = store.unavailableReason, store.status == .unavailable {
                                Label(reason, systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(.red)
                            }

                            if let pause = store.activePause {
                                Label(pause.label, systemImage: "clock.badge.pause")
                                    .foregroundStyle(.orange)
                                Button("恢复守护") {
                                    store.resumeGuard()
                                }
                            }

                            ForEach(store.riskWarnings, id: \.self) { warning in
                                Label(warning, systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(4)
                    } label: {
                        Label("当前状态", systemImage: "gauge.with.dots.needle.67percent")
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            if let event = store.recentEvent {
                                Text(event.type.label)
                                    .font(.title3.weight(.semibold))
                                Text(event.displayReason)
                                    .foregroundStyle(.secondary)
                                Text(event.timestamp.autoLockerShortText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button("打开日志") {
                                    store.selectedSection = .logs
                                }
                            } else {
                                EmptyState(
                                    systemImage: "list.bullet.rectangle",
                                    title: "暂无事件",
                                    message: "开启扫描、绑定信标或触发锁屏后，事件会记录在这里。"
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                    } label: {
                        Label("最近事件", systemImage: "clock.arrow.circlepath")
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("不依赖蓝牙检测，到点后主动触发系统锁屏。")
                            .foregroundStyle(.secondary)

                        HStack {
                            Stepper(
                                "倒计时 \(store.timerLockDurationMinutes) 分钟",
                                value: $store.timerLockDurationMinutes,
                                in: 1...240
                            )

                            Spacer()

                            if let remaining = store.timerRemainingSeconds {
                                Text("\(remaining / 60)分 \(remaining % 60)秒")
                                    .font(.title3.monospacedDigit().weight(.semibold))
                                    .contentTransition(.numericText())
                                Button("取消") {
                                    store.cancelTimerLock()
                                }
                            } else {
                                Button("开始定时锁屏") {
                                    store.startTimerLock(minutes: store.timerLockDurationMinutes)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .padding(4)
                } label: {
                    Label("定时锁屏", systemImage: "timer")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("暂停只影响守护触发，不会关闭定时锁屏。")
                            .foregroundStyle(.secondary)

                        HStack {
                            Button("15 分钟") { store.pause(.fifteenMinutes) }
                            Button("30 分钟") { store.pause(.thirtyMinutes) }
                            Button("1 小时") { store.pause(.oneHour) }
                            Button("直到手动恢复") { store.pause(.manual) }
                            Button("今天结束前") { store.pause(.endOfDay) }
                        }

                        HStack {
                            Button("下次解锁后恢复") { store.pause(.nextUnlock) }
                            Button("离开当前 Wi-Fi 后恢复") { store.pause(.wifiLeaves) }
                                .disabled(store.currentSSID == nil)
                            DatePicker("自定义恢复时间", selection: $customPauseUntil, displayedComponents: [.hourAndMinute])
                            Button("暂停至该时间") {
                                store.pause(.custom, customUntil: customPauseUntil)
                            }
                        }
                    }
                    .padding(4)
                } label: {
                    Label("暂停守护", systemImage: "clock.badge.pause")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoLine(title: "识别模式", value: store.rules.detectionMode.label)
                        InfoLine(title: "离开延迟", value: "\(store.rules.delaySeconds) 秒")
                        InfoLine(title: "抗抖策略", value: store.rules.debounceStrategy.label)
                        InfoLine(title: "多信标逻辑", value: store.rules.multiBeaconLogic == .atLeast ? "至少 \(store.rules.requiredBeaconCount) 个在场" : store.rules.multiBeaconLogic.label)
                        InfoLine(title: "预锁屏提示", value: "\(store.rules.preLockCountdownSeconds) 秒")
                    }
                    .padding(4)
                } label: {
                    Label("启用规则摘要", systemImage: "slider.horizontal.3")
                }
            }
            .padding(24)
        }
    }
}
