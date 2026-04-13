import AppKit
import SwiftUI

#if !BACKGROUND_AGENT
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var shouldLaunchBackgroundAgentOnTerminate = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationController.requestAuthorization()
        AppLauncher.registerBackgroundAgentIfPossible()
        AppLauncher.terminateRunningAgentIfNeeded()
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        shouldLaunchBackgroundAgentOnTerminate = true
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard shouldLaunchBackgroundAgentOnTerminate else {
            return
        }
        AppLauncher.launchBackgroundAgentIfNeeded()
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
