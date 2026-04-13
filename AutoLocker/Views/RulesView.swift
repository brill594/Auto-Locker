import SwiftUI

struct RulesView: View {
    @EnvironmentObject private var store: AutoLockerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle(
                    title: "规则",
                    subtitle: "配置离开判断、抗抖、多信标逻辑和锁屏前提示。"
                )

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("判定模式", selection: $store.rules.detectionMode) {
                            ForEach(DetectionMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Stepper("离开条件持续 \(store.rules.delaySeconds) 秒后进入提示", value: $store.rules.delaySeconds, in: 5...600, step: 5)

                        if store.rules.detectionMode == .rssiThreshold {
                            Slider(
                                value: Binding(
                                    get: { Double(store.rules.rssiThreshold) },
                                    set: { store.rules.rssiThreshold = Int($0) }
                                ),
                                in: -100 ... -40,
                                step: 1
                            ) {
                                Text("RSSI 阈值")
                            }
                            InfoLine(title: "RSSI 阈值", value: "\(store.rules.rssiThreshold) dBm")
                        }
                    }
                    .padding(4)
                } label: {
                    Label("离开判断", systemImage: "figure.walk.departure")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("抗抖策略", selection: $store.rules.debounceStrategy) {
                            ForEach(DebounceStrategy.allCases) { strategy in
                                Text(strategy.label).tag(strategy)
                            }
                        }
                        .pickerStyle(.segmented)

                        if store.rules.debounceStrategy == .consecutiveMisses {
                            Stepper(
                                "连续丢失 \(store.rules.requiredConsecutiveMisses) 次后允许触发",
                                value: $store.rules.requiredConsecutiveMisses,
                                in: 2...20
                            )
                        }

                        Text("较短延迟适合稳定信标；如果使用耳机、手表等广播不稳定设备，建议提高延迟或启用连续丢失判定。")
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                } label: {
                    Label("抗抖", systemImage: "waveform.path")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("多信标逻辑", selection: $store.rules.multiBeaconLogic) {
                            ForEach(MultiBeaconLogic.allCases) { logic in
                                Text(logic.label).tag(logic)
                            }
                        }
                        .pickerStyle(.segmented)

                        if store.rules.multiBeaconLogic == .atLeast {
                            Stepper(
                                "至少 \(store.rules.requiredBeaconCount) 个信标在场",
                                value: $store.rules.requiredBeaconCount,
                                in: 1...max(1, store.beacons.count)
                            )
                        }
                    }
                    .padding(4)
                } label: {
                    Label("多信标规则", systemImage: "point.3.connected.trianglepath.dotted")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Stepper(
                            "提示倒计时 \(store.rules.preLockCountdownSeconds) 秒",
                            value: $store.rules.preLockCountdownSeconds,
                            in: 3...120
                        )

                        Stepper(
                            "\(store.rules.cancelWindowMinutes) 分钟内取消 \(store.rules.cancelThreshold) 次后建议暂停",
                            value: $store.rules.cancelThreshold,
                            in: 1...10
                        )

                        Stepper(
                            "频繁取消窗口 \(store.rules.cancelWindowMinutes) 分钟",
                            value: $store.rules.cancelWindowMinutes,
                            in: 5...60,
                            step: 5
                        )
                    }
                    .padding(4)
                } label: {
                    Label("锁屏前提示", systemImage: "bell.badge")
                }
            }
            .padding(24)
        }
    }
}
