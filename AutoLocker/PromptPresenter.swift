import AppKit
import SwiftUI

final class PromptPresenter {
    private var panel: NSPanel?

    func show(store: AutoLockerStore) {
        if panel != nil {
            return
        }

        let rootView = PromptOverlayView()
            .environmentObject(store)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Auto Locker"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: rootView)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.panel = panel
    }

    func close() {
        panel?.close()
        panel = nil
    }
}

private struct PromptOverlayView: View {
    @EnvironmentObject private var store: AutoLockerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "lock.trianglebadge.exclamationmark")
                    .font(.system(size: 34))
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading, spacing: 4) {
                    Text("即将锁定屏幕")
                        .font(.title2.weight(.semibold))
                    Text(store.promptReason.isEmpty ? "离开规则已触发。" : store.promptReason)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text("\(store.countdownRemaining) 秒后锁屏")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()

            HStack {
                Button("取消本次锁屏") {
                    store.cancelPendingLock()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("暂停 15 分钟") {
                    store.pause(.fifteenMinutes)
                }

                Button("立即锁屏") {
                    store.performLock(reason: "用户在提示窗口中立即锁屏")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420, height: 220)
    }
}
