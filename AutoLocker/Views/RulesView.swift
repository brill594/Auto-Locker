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

                        NumberInputRow(
                            title: "离开条件持续",
                            value: $store.rules.delaySeconds,
                            range: 5...600,
                            step: 5,
                            suffix: "秒",
                            fieldWidth: 88
                        )

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
                            NumberInputRow(
                                title: "RSSI 阈值",
                                value: $store.rules.rssiThreshold,
                                range: -100 ... -40,
                                suffix: "dBm",
                                fieldWidth: 88
                            )
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
                            NumberInputRow(
                                title: "连续丢失次数",
                                value: $store.rules.requiredConsecutiveMisses,
                                range: 2...20,
                                suffix: "次",
                                fieldWidth: 72
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
                            NumberInputRow(
                                title: "至少在场信标",
                                value: $store.rules.requiredBeaconCount,
                                range: 1...max(1, store.beacons.count),
                                suffix: "个",
                                fieldWidth: 72
                            )
                        }
                    }
                    .padding(4)
                } label: {
                    Label("多信标规则", systemImage: "point.3.connected.trianglepath.dotted")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        NumberInputRow(
                            title: "提示倒计时",
                            value: $store.rules.preLockCountdownSeconds,
                            range: 3...120,
                            suffix: "秒",
                            fieldWidth: 80
                        )

                        NumberInputRow(
                            title: "建议暂停阈值",
                            value: $store.rules.cancelThreshold,
                            range: 1...10,
                            suffix: "次",
                            fieldWidth: 72
                        )

                        NumberInputRow(
                            title: "频繁取消窗口",
                            value: $store.rules.cancelWindowMinutes,
                            range: 5...60,
                            step: 5,
                            suffix: "分钟",
                            fieldWidth: 80
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
