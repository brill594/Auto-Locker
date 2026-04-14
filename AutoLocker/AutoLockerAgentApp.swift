import AppKit
import SwiftUI

#if BACKGROUND_AGENT
final class AgentAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationController.requestAuthorization()
        SharedDebugTrace.log("后台 Agent 启动完成")
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct AutoLockerAgentApp: App {
    @NSApplicationDelegateAdaptor(AgentAppDelegate.self) private var appDelegate
    @StateObject private var store = AutoLockerStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            Label("Auto Locker", systemImage: store.status.systemImage)
        }
        .menuBarExtraStyle(.menu)
    }
}
#endif
