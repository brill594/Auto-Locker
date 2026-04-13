import AppKit
import CoreLocation
import CoreWLAN
import Foundation
import UserNotifications

final class WiFiMonitor: ObservableObject {
    @Published private(set) var currentSSID: String?
    @Published private(set) var currentBSSID: String?

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
        let interfaces = CWWiFiClient.shared().interfaces() ?? []
        let activeInterface = interfaces.first {
            ($0.ssid() ?? "").isEmpty == false || ($0.bssid() ?? "").isEmpty == false
        }

        currentSSID = activeInterface?.ssid()
        currentBSSID = activeInterface?.bssid()
    }
}

final class LocationPermissionMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationState: LocationAuthorizationState = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        refresh()
    }

    func start() {
        refresh()
    }

    func refresh() {
        authorizationState = Self.map(manager.authorizationStatus)
    }

    func requestAuthorizationIfNeeded() {
        refresh()
        guard authorizationState == .notDetermined else {
            return
        }
        manager.requestWhenInUseAuthorization()
    }

    func requestAuthorization() {
        refresh()
        guard authorizationState == .notDetermined else {
            return
        }
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationState = Self.map(manager.authorizationStatus)
    }

    private static func map(_ status: CLAuthorizationStatus) -> LocationAuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
        case .authorizedAlways:
            return .authorizedAlways
        @unknown default:
            return .notDetermined
        }
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
