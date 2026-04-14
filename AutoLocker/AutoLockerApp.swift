import AppKit
import SwiftUI

#if !BACKGROUND_AGENT
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationController.requestAuthorization()
        AppLauncher.registerBackgroundAgentIfPossible()
        SharedDebugTrace.log("主应用启动完成")
        AppLauncher.launchBackgroundAgentIfNeeded(reason: "主应用启动")
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        SharedDebugTrace.log("主应用即将退出，尝试交接后台 Agent")
        AppLauncher.launchBackgroundAgentIfNeeded(reason: "主应用退出交接")
    }
}

@main
struct AutoLockerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AutoLockerStore

    init() {
        let store = AutoLockerStore()
        if let pendingSection = AppLauncher.consumePendingMainAppSection() {
            store.selectedSection = pendingSection
        }
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1040, minHeight: 700)
        }
        .windowResizability(.contentMinSize)
    }
}
#endif
