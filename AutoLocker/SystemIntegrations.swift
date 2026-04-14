import AppKit
import CoreLocation
import CoreWLAN
import Foundation
import Security
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
    static let mainBundleIdentifier = "com.brilliant.autolocker"
    static let agentBundleIdentifier = "com.brilliant.autolocker.agent"
    private static let legacyAgentBundleIdentifiers = ["com.brilliant.AutoLocker.Agent"]

    static var hasBundledBackgroundAgent: Bool {
        bundledAgentURL != nil
    }

    static func registerBackgroundAgentIfPossible() {
        guard AutoLockerProcessContext.currentMode == .foregroundApp else {
            return
        }

        if #available(macOS 13.0, *) {
            do {
                try SMAppService.loginItem(identifier: agentBundleIdentifier).register()
                SharedDebugTrace.log("已注册登录项 Agent")
            } catch {
                SharedDebugTrace.log("注册登录项 Agent 失败：\(error.localizedDescription)")
                NSLog("AutoLocker: failed to register login item: \(error.localizedDescription)")
            }
        }
    }

    static func terminateRunningAgentIfNeeded() {
        guard AutoLockerProcessContext.currentMode == .foregroundApp else {
            return
        }

        for identifier in knownAgentBundleIdentifiers {
            let runningAgents = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            for app in runningAgents where app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                SharedDebugTrace.log("终止已有 Agent 进程 bundleID=\(identifier) pid=\(app.processIdentifier)")
                app.terminate()
            }
        }
    }

    static func isBackgroundAgentRunning() -> Bool {
        knownAgentBundleIdentifiers.contains { identifier in
            let runningAgents = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            return runningAgents.contains { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        }
    }

    static func launchBackgroundAgentIfNeeded(reason: String = "未提供原因") {
        guard AutoLockerProcessContext.currentMode == .foregroundApp else {
            return
        }

        guard let agentURL = bundledAgentURL else {
            SharedDebugTrace.log("跳过拉起 Agent：未找到内嵌 Agent，原因=\(reason)")
            return
        }

        for identifier in legacyAgentBundleIdentifiers {
            let legacyAgents = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            for app in legacyAgents {
                SharedDebugTrace.log("终止旧 Bundle ID Agent：bundleID=\(identifier) pid=\(app.processIdentifier)，原因=\(reason)")
                app.terminate()
            }
        }

        let runningAgents = NSRunningApplication.runningApplications(withBundleIdentifier: agentBundleIdentifier)
        guard runningAgents.isEmpty else {
            SharedDebugTrace.log("跳过拉起 Agent：已在运行，原因=\(reason)")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        SharedDebugTrace.log("开始拉起 Agent，原因=\(reason)")
        NSWorkspace.shared.openApplication(at: agentURL, configuration: configuration) { _, error in
            if let error {
                SharedDebugTrace.log("拉起 Agent 失败：\(error.localizedDescription)，原因=\(reason)")
                NSLog("AutoLocker: failed to launch background agent: \(error.localizedDescription)")
            } else {
                SharedDebugTrace.log("拉起 Agent 请求已提交，原因=\(reason)")
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
        SharedDebugTrace.log("请求打开主窗口，section=\(section.rawValue)")
        NSWorkspace.shared.openApplication(at: mainAppURL, configuration: configuration) { _, error in
            if let error {
                SharedDebugTrace.log("打开主窗口失败：\(error.localizedDescription)")
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

    private static var knownAgentBundleIdentifiers: [String] {
        [agentBundleIdentifier] + legacyAgentBundleIdentifiers
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

enum SharedDebugTrace {
    private static let queue = DispatchQueue(label: "AutoLocker.DebugTrace")
    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func log(_ message: String) {
        let process = AutoLockerProcessContext.currentMode == .backgroundAgent ? "agent" : "app"
        let pid = ProcessInfo.processInfo.processIdentifier
        let timestamp = formatter.string(from: Date())
        let line = "\(timestamp) [\(process) pid=\(pid)] \(message)\n"
        let url = FileLocations.debugTraceFile

        queue.async {
            do {
                try FileManager.default.createDirectory(
                    at: FileLocations.applicationSupportDirectory,
                    withIntermediateDirectories: true
                )
                if FileManager.default.fileExists(atPath: url.path) {
                    let handle = try FileHandle(forWritingTo: url)
                    defer { try? handle.close() }
                    handle.seekToEndOfFile()
                    if let data = line.data(using: .utf8) {
                        handle.write(data)
                    }
                } else if let data = line.data(using: .utf8) {
                    try data.write(to: url, options: .atomic)
                }
            } catch {
                NSLog("AutoLocker: failed to append debug trace: \(error.localizedDescription)")
            }
        }

        NSLog("AutoLocker trace: \(message)")
    }

    static func readAll() throws -> String {
        try queue.sync {
            let url = FileLocations.debugTraceFile
            guard FileManager.default.fileExists(atPath: url.path) else {
                return ""
            }
            return try String(contentsOf: url, encoding: .utf8)
        }
    }
}

enum CodeSigningDiagnostics {
    static func debugSummary() -> String {
        var parts = [
            "bundleID=\(Bundle.main.bundleIdentifier ?? "-")",
            "bundlePath=\(Bundle.main.bundlePath)",
            "executable=\(Bundle.main.executablePath ?? "-")"
        ]

        if let task = SecTaskCreateFromSelf(nil) {
            let teamID = SecTaskCopyValueForEntitlement(
                task,
                "com.apple.developer.team-identifier" as CFString,
                nil
            ) as? String
            parts.append("entitlementTeamID=\(teamID ?? "-")")
        } else {
            parts.append("entitlementTeamID=-")
        }

        var code: SecCode?
        let copySelfStatus = SecCodeCopySelf(SecCSFlags(), &code)
        parts.append("secCodeCopySelf=\(copySelfStatus)")

        guard copySelfStatus == errSecSuccess, let code else {
            return parts.joined(separator: " ")
        }

        var staticCode: SecStaticCode?
        let copyStaticStatus = SecCodeCopyStaticCode(code, SecCSFlags(), &staticCode)
        parts.append("secCodeCopyStaticCode=\(copyStaticStatus)")

        guard copyStaticStatus == errSecSuccess, let staticCode else {
            return parts.joined(separator: " ")
        }

        var signingInfo: CFDictionary?
        let signingInfoStatus = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInfo
        )
        parts.append("secCodeCopySigningInformation=\(signingInfoStatus)")

        guard signingInfoStatus == errSecSuccess,
              let info = signingInfo as? [String: Any]
        else {
            return parts.joined(separator: " ")
        }

        parts.append("signingIdentifier=\(info[kSecCodeInfoIdentifier as String] as? String ?? "-")")
        parts.append("teamID=\(info[kSecCodeInfoTeamIdentifier as String] as? String ?? "-")")
        if let flags = info[kSecCodeInfoFlags as String] {
            parts.append("signingFlags=\(flags)")
        }
        return parts.joined(separator: " ")
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

    static var runtimeStateFile: URL {
        applicationSupportDirectory.appendingPathComponent("runtime.json")
    }

    static var agentCommandFile: URL {
        applicationSupportDirectory.appendingPathComponent("agent-command.json")
    }

    static var mainAppLaunchRequestFile: URL {
        applicationSupportDirectory.appendingPathComponent("launch-request.txt")
    }

    static var debugTraceFile: URL {
        applicationSupportDirectory.appendingPathComponent("debug-trace.log")
    }
}
