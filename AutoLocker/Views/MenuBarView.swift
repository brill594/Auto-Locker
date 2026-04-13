import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var store: AutoLockerStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack {
            Label(store.status.label, systemImage: store.status.systemImage)
            Text(store.currentPresenceSummary())

            if let pause = store.activePause {
                Text(pause.label)
            }

            Divider()

            Button(store.guardEnabled ? "关闭守护" : "开启守护") {
                store.setGuardEnabled(!store.guardEnabled)
            }

            Menu("暂停") {
                Button("15 分钟") { store.pause(.fifteenMinutes) }
                Button("30 分钟") { store.pause(.thirtyMinutes) }
                Button("1 小时") { store.pause(.oneHour) }
                Divider()
                Button("直到手动恢复") { store.pause(.manual) }
                Button("下次解锁后恢复") { store.pause(.nextUnlock) }
                Button("离开当前 Wi-Fi 后恢复") { store.pause(.wifiLeaves) }
                Button("今天结束前") { store.pause(.endOfDay) }
                Button("自定义时间点...") {
                    store.selectedSection = .overview
                    openMainWindow()
                }
            }
            .disabled(!store.guardEnabled)

            Button("恢复守护") {
                store.resumeGuard()
            }
            .disabled(store.activePause == nil)

            Divider()

            Menu("绑定信标状态") {
                if store.beacons.isEmpty {
                    Text("尚未绑定信标")
                } else {
                    ForEach(store.beacons.prefix(8)) { beacon in
                        let value = beacon.lastRSSI.map { "\($0) dBm" } ?? "未检测到"
                        Text("\(beacon.displayName): \(value)")
                    }
                }
            }

            Divider()

            Button("打开主窗口") {
                openMainWindow()
            }

            Button("打开日志") {
                store.selectedSection = .logs
                openMainWindow()
            }

            Divider()

            Button("退出 Auto Locker") {
                NSApp.terminate(nil)
            }
        }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
