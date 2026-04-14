import AppKit
import SwiftUI

#if !BACKGROUND_AGENT
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var skipAgentHandoffOnTerminate = false
    private var delayingTerminationForAgentHandoff = false
    private var didRequestAgentHandoff = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AgentProcessLock.isHeldByAnotherProcess() {
            SharedDebugTrace.log("检测到已有 Agent 进程锁，保留当前 Agent")
        } else {
            AppLauncher.terminateRunningAgentIfNeeded()
        }
        AppLauncher.registerBackgroundAgentIfPossible()
        SharedDebugTrace.log("主应用启动完成")
        SharedDebugTrace.log("代码签名诊断：\(CodeSigningDiagnostics.debugSummary())")
        AppLauncher.launchBackgroundAgentIfNeeded(reason: "主应用启动")
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if AppLauncher.consumeFullQuitRequestIfNeeded() {
            skipAgentHandoffOnTerminate = true
            return .terminateNow
        }

        guard !delayingTerminationForAgentHandoff else {
            return .terminateNow
        }

        if AgentProcessLock.isHeldByAnotherProcess() {
            return .terminateNow
        }

        guard AppLauncher.hasBundledBackgroundAgent else {
            return .terminateNow
        }

        delayingTerminationForAgentHandoff = true
        didRequestAgentHandoff = true
        SharedDebugTrace.log("主应用准备退出，先拉起后台 Agent")
        var didReply = false
        let replyOnce: () -> Void = {
            guard !didReply else {
                return
            }
            didReply = true
            sender.reply(toApplicationShouldTerminate: true)
        }
        AppLauncher.launchBackgroundAgentIfNeeded(reason: "主应用退出交接") { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                replyOnce()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            replyOnce()
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        if skipAgentHandoffOnTerminate {
            SharedDebugTrace.log("主应用即将退出：收到全量退出请求，跳过交接后台 Agent")
            return
        }

        guard !didRequestAgentHandoff else {
            SharedDebugTrace.log("主应用即将退出：后台 Agent 交接请求已提交")
            return
        }

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
