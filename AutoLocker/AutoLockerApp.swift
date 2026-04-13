import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationController.requestAuthorization()
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct AutoLockerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = AutoLockerStore()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1040, minHeight: 700)
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
        } label: {
            Label("Auto Locker", systemImage: store.status.systemImage)
        }
        .menuBarExtraStyle(.menu)
    }
}
