import AppKit
import CoreWLAN
import Foundation
import UserNotifications

final class WiFiMonitor: ObservableObject {
    @Published private(set) var currentSSID: String?

    private var timer: Timer?

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        currentSSID = CWWiFiClient.shared().interface()?.ssid()
    }
}

enum LockController {
    static func lockScreen() -> String? {
        let cgSessionPath = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        if FileManager.default.isExecutableFile(atPath: cgSessionPath) {
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: cgSessionPath)
                process.arguments = ["-suspend"]
                try process.run()
                return nil
            } catch {
                return "CGSession 锁屏失败：\(error.localizedDescription)"
            }
        }

        let screenSaverPath = "/System/Library/CoreServices/ScreenSaverEngine.app"
        let opened = NSWorkspace.shared.open(URL(fileURLWithPath: screenSaverPath))
        return opened ? nil : "无法打开系统屏幕保护程序。"
    }
}

enum NotificationController {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

enum FileLocations {
    static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Auto Locker", isDirectory: true)
    }

    static var stateFile: URL {
        applicationSupportDirectory.appendingPathComponent("state.json")
    }
}
