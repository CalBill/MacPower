import AppKit
import SwiftUI

@main
struct MacPowerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState?
    private var statusItemController: StatusItemController?
    private var snapshotWatch: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let state = AppState()
        appState = state
        statusItemController = StatusItemController(appState: state)
        snapshotWatch = Task { [weak self, weak state] in
            guard let state else { return }
            var last = state.snapshot
            var lastStyle = state.settings.iconStyle
            var lastTint = state.settings.lowBatteryTintEnabled
            var lastGlyphs = state.settings.showChargeGlyphs
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                let snapshot = state.snapshot
                let style = state.settings.iconStyle
                let tint = state.settings.lowBatteryTintEnabled
                let glyphs = state.settings.showChargeGlyphs
                if snapshot != last || style != lastStyle || tint != lastTint || glyphs != lastGlyphs {
                    last = snapshot
                    lastStyle = style
                    lastTint = tint
                    lastGlyphs = glyphs
                    self?.statusItemController?.refreshIcon()
                }
            }
        }
        statusItemController?.refreshIcon()
    }

    func applicationWillTerminate(_ notification: Notification) {
        snapshotWatch?.cancel()
        appState?.telemetry.stop()
    }
}
