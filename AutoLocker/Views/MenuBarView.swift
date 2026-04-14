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

            Button("恢复守护") {
                store.resumeGuard()
            }
            .disabled(store.activePause == nil)

            Divider()

            Button("打开主窗口") {
                openMainWindow(section: .overview)
            }

            Button("打开日志") {
                openMainWindow(section: .logs)
            }

            Divider()

            Button("退出 Auto Locker") {
                AppLauncher.quitAllFromMenuBar()
            }
        }
    }

    private func openMainWindow(section: AppSection) {
        store.selectedSection = section

        switch AutoLockerProcessContext.currentMode {
        case .foregroundApp:
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        case .backgroundAgent:
            AppLauncher.openMainApp(section: section)
        }
    }
}
