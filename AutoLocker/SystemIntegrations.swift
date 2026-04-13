import AppKit
import CoreLocation
import CoreWLAN
import Foundation
import ServiceManagement
import UserNotifications

enum AutoLockerProcessMode {
    case foregroundApp
    case backgroundAgent
}

enum AutoLockerProcessContext {
    static var currentMode: AutoLockerProcessMode {
        Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool == true
            ? .backgroundAgent
            : .foregroundApp
    }
}

enum AppLauncher {
    static let mainBundleIdentifier = "com.brilliant.AutoLocker"
    static let agentBundleIdentifier = "com.brilliant.AutoLocker.Agent"

    static func registerBackgroundAgentIfPossible() {
        guard AutoLockerProcessContext.currentMode == .foregroundApp else {
            return
        }

        if #available(macOS 13.0, *) {
            do {
                try SMAppService.loginItem(identifier: agentBundleIdentifier).register()
            } catch {
                NSLog("AutoLocker: failed to register login item: \(error.localizedDescription)")
            }
        }
    }

    static func terminateRunningAgentIfNeeded() {
        guard AutoLockerProcessContext.currentMode == .foregroundApp else {
            return
        }

        let runningAgents = NSRunningApplication.runningApplications(withBundleIdentifier: agentBundleIdentifier)
        for app in runningAgents where app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            app.terminate()
        }
    }

    static func launchBackgroundAgentIfNeeded() {
        guard AutoLockerProcessContext.currentMode == .foregroundApp,
              let agentURL = bundledAgentURL
        else {
            return
        }

        let runningAgents = NSRunningApplication.runningApplications(withBundleIdentifier: agentBundleIdentifier)
        guard runningAgents.isEmpty else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.openApplication(at: agentURL, configuration: configuration) { _, error in
            if let error {
                NSLog("AutoLocker: failed to launch background agent: \(error.localizedDescription)")
            }
        }
    }

    static func openMainApp(section: AppSection = .overview) {
        storePendingMainAppSection(section)

        guard let mainAppURL else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: mainAppURL, configuration: configuration) { _, error in
            if let error {
                NSLog("AutoLocker: failed to open main app: \(error.localizedDescription)")
            }
        }
    }

    static func consumePendingMainAppSection() -> AppSection? {
        let url = FileLocations.mainAppLaunchRequestFile
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        defer {
            try? FileManager.default.removeItem(at: url)
        }

        do {
            let data = try Data(contentsOf: url)
            guard let rawValue = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  let section = AppSection(rawValue: rawValue)
            else {
                return nil
            }
            return section
        } catch {
            NSLog("AutoLocker: failed to read pending main app section: \(error.localizedDescription)")
            return nil
        }
    }

    private static var bundledAgentURL: URL? {
        guard AutoLockerProcessContext.currentMode == .foregroundApp else {
            return nil
        }

        let url = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Library")
            .appendingPathComponent("LoginItems")
            .appendingPathComponent("AutoLockerAgent.app")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static var mainAppURL: URL? {
        switch AutoLockerProcessContext.currentMode {
        case .foregroundApp:
            return Bundle.main.bundleURL
        case .backgroundAgent:
            return Bundle.main.bundleURL.deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
        }
    }

    private static func storePendingMainAppSection(_ section: AppSection) {
        let directory = FileLocations.applicationSupportDirectory
        let requestFile = FileLocations.mainAppLaunchRequestFile

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            guard let data = section.rawValue.data(using: .utf8) else {
                return
            }
            try data.write(to: requestFile, options: .atomic)
        } catch {
            NSLog("AutoLocker: failed to store pending main app section: \(error.localizedDescription)")
        }
    }
}

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

    static var mainAppLaunchRequestFile: URL {
        applicationSupportDirectory.appendingPathComponent("launch-request.txt")
    }
}
