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
                        InfoLine(title: "定位权限", value: store.locationAuthorizationLabel)

                        if let currentNetworkRuleValue {
                            InfoLine(title: "可添加依据", value: "\(currentNetworkMatchBasisLabel) · \(currentNetworkRuleValue)")
                        }

                        if !store.locationPermissionAllowsWiFiReading {
                            Label(locationPermissionMessage, systemImage: "location.slash")
                                .foregroundStyle(.orange)

                            if store.locationAuthorizationState == .notDetermined {
                                Button("请求定位权限") {
                                    store.requestLocationPermission()
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Text("如已拒绝，请在“系统设置 > 隐私与安全性 > 定位服务”中允许 Auto Locker 访问定位。")
                                    .foregroundStyle(.secondary)
                            }
                        } else if store.currentWiFiDisplay == nil {
                            Label("定位权限已授权，但当前仍未读到 SSID/BSSID。请确认设备已真正接入 Wi-Fi，并尝试刷新。", systemImage: "wifi.exclamationmark")
                                .foregroundStyle(.orange)
                        }

                        Button("刷新当前网络") {
                            store.refreshNetworkContext()
                        }

                        HStack {
                            Button("加入白名单") {
                                addCurrentNetwork(to: \.whitelistSSIDs)
                            }
                            .disabled(currentNetworkRuleValue == nil || currentNetworkAlreadyInWhitelist)

                            Button("加入黑名单") {
                                addCurrentNetwork(to: \.blacklistSSIDs)
                            }
                            .disabled(currentNetworkRuleValue == nil || currentNetworkAlreadyInBlacklist)
                        }

                        if currentNetworkAlreadyInWhitelist || currentNetworkAlreadyInBlacklist {
                            Text(currentNetworkMembershipSummary)
                                .foregroundStyle(.secondary)
                        }

                        if let bssid = store.currentBSSID, store.currentSSID != nil {
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
                        ruleBasisDescription(
                            title: "判断依据",
                            emphasis: currentRuleBasisDescription
                        )
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
                        ruleBasisDescription(
                            title: "判断依据",
                            emphasis: currentRuleBasisDescription
                        )
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
        .onAppear {
            DispatchQueue.main.async {
                store.refreshNetworkContext()
                store.requestLocationPermissionIfNeeded()
            }
        }
    }

    private var locationPermissionMessage: String {
        switch store.locationAuthorizationState {
        case .notDetermined:
            return "读取当前 Wi-Fi 名称前，macOS 可能会要求定位权限。"
        case .restricted:
            return "当前系统限制了定位权限，Wi-Fi 名称可能无法读取。"
        case .denied:
            return "定位权限已被拒绝，当前 Wi-Fi 名称可能无法读取。"
        case .authorizedWhenInUse, .authorizedAlways:
            return ""
        }
    }

    private var currentNetworkRuleValue: String? {
        normalizedRuleValue(store.currentSSID) ?? normalizedRuleValue(store.currentBSSID)
    }

    private var currentNetworkMatchBasisLabel: String {
        if normalizedRuleValue(store.currentSSID) != nil {
            return "SSID"
        }
        if normalizedRuleValue(store.currentBSSID) != nil {
            return "BSSID"
        }
        return "不可用"
    }

    private var currentRuleBasisDescription: String {
        if let ssid = normalizedRuleValue(store.currentSSID) {
            return "当前一键添加会写入 SSID：\(ssid)"
        }
        if let bssid = normalizedRuleValue(store.currentBSSID) {
            return "当前未读到 SSID，一键添加会改写入 BSSID：\(bssid)"
        }
        return "优先按 SSID 精确匹配；当只拿到 BSSID 或你手动填入 BSSID 时，会按 BSSID 精确匹配。"
    }

    private var currentNetworkAlreadyInWhitelist: Bool {
        containsCurrentNetwork(in: store.networkRules.whitelistSSIDs)
    }

    private var currentNetworkAlreadyInBlacklist: Bool {
        containsCurrentNetwork(in: store.networkRules.blacklistSSIDs)
    }

    private var currentNetworkMembershipSummary: String {
        var targets: [String] = []
        if currentNetworkAlreadyInWhitelist {
            targets.append("白名单")
        }
        if currentNetworkAlreadyInBlacklist {
            targets.append("黑名单")
        }
        guard !targets.isEmpty else {
            return ""
        }
        return "当前网络已在\(targets.joined(separator: "、"))中。"
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

    @ViewBuilder
    private func ruleBasisDescription(title: String, emphasis: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title)：优先按 SSID 精确匹配；当只拿到 BSSID 或你手动填入 BSSID 时，会按 BSSID 精确匹配。")
                .foregroundStyle(.secondary)
            Text(emphasis)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func addCurrentNetwork(to keyPath: WritableKeyPath<NetworkRules, [String]>) {
        guard let value = currentNetworkRuleValue else {
            return
        }

        let normalizedCurrentValue = normalizedRuleValue(value)
        guard let normalizedCurrentValue else {
            return
        }

        var list = store.networkRules[keyPath: keyPath]
        let containsValue = list.contains { normalizedRuleValue($0) == normalizedCurrentValue }
        if !containsValue {
            list.append(value)
            store.networkRules[keyPath: keyPath] = list
        }
    }

    private func containsCurrentNetwork(in values: [String]) -> Bool {
        guard let currentNetworkRuleValue else {
            return false
        }
        let normalizedCurrentValue = normalizedRuleValue(currentNetworkRuleValue)
        return values.contains { normalizedRuleValue($0) == normalizedCurrentValue }
    }

    private func normalizedRuleValue(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
