import SwiftUI

struct NetworkRulesView: View {
    @EnvironmentObject private var store: AutoLockerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionTitle(
                    title: "网络规则",
                    subtitle: "用 Wi-Fi 规则暂停或启用守护，并为后续位置规则保留扩展入口。"
                )

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoLine(title: "当前 Wi-Fi", value: store.currentWiFiDisplay ?? "未连接或不可读")
                        if let bssid = store.currentBSSID, let ssid = store.currentSSID {
                            InfoLine(title: "当前 BSSID", value: bssid)
                            Text("规则默认按 SSID 匹配；BSSID 仅作为补充信息和兜底读取。多个 Wi-Fi 请用逗号分隔。")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("规则默认按 SSID 匹配；多个 Wi-Fi 请用逗号分隔。")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(4)
                } label: {
                    Label("当前网络", systemImage: "wifi")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("例如 Office WiFi, Home WiFi", text: ssidListBinding(\.whitelistSSIDs))
                        Picker("命中白名单时", selection: $store.networkRules.whitelistBehavior) {
                            ForEach(NetworkRuleBehavior.allCases) { behavior in
                                Text(behavior.label).tag(behavior)
                            }
                        }
                        Text("常用场景：家中或可信网络中暂不触发自动锁屏。")
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                } label: {
                    Label("白名单", systemImage: "checkmark.shield")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("例如 Office Guest, Lab", text: ssidListBinding(\.blacklistSSIDs))
                        Picker("命中黑名单时", selection: $store.networkRules.blacklistBehavior) {
                            ForEach(NetworkRuleBehavior.allCases) { behavior in
                                Text(behavior.label).tag(behavior)
                            }
                        }
                        Text("当前实现支持在黑名单网络中自动启用守护。")
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                } label: {
                    Label("黑名单", systemImage: "exclamationmark.shield")
                }
            }
            .padding(24)
        }
    }

    private func ssidListBinding(_ keyPath: WritableKeyPath<NetworkRules, [String]>) -> Binding<String> {
        Binding(
            get: {
                store.networkRules[keyPath: keyPath].joined(separator: ", ")
            },
            set: { value in
                store.networkRules[keyPath: keyPath] = value
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        )
    }
}
