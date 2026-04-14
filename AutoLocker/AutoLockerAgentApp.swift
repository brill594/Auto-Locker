import AppKit
import SwiftUI

#if BACKGROUND_AGENT
final class AgentAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard AgentProcessLock.isHeldByCurrentProcess || AgentProcessLock.acquireForCurrentAgent() else {
            SharedDebugTrace.log("后台 Agent 未持有进程锁，退出")
            NSApp.terminate(nil)
            return
        }

        NotificationController.requestAuthorization()
        SharedDebugTrace.log("后台 Agent 启动完成")
        SharedDebugTrace.log("代码签名诊断：\(CodeSigningDiagnostics.debugSummary())")
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        AgentProcessLock.release()
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
