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
        #if DEBUG
        if ReadmeAssetCapture.startIfNeeded() { return }
        #endif
        NSApp.setActivationPolicy(.accessory)
        let state = AppState()
        appState = state
        statusItemController = StatusItemController(appState: state)
        state.onLanguageChange = { [weak statusItemController] in
            statusItemController?.applyLocalization()
        }
        state.onPopoverChromeChange = { [weak statusItemController] in
            statusItemController?.applyArrowVisibility()
        }
        snapshotWatch = Task { [weak self, weak state] in
            guard let state else { return }
            var last = MenuBarIconKey(state)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                let key = MenuBarIconKey(state)
                guard key != last else { continue }
                last = key
                self?.statusItemController?.refreshIcon()
            }
        }
        statusItemController?.refreshIcon()
    }

    func applicationWillTerminate(_ notification: Notification) {
        snapshotWatch?.cancel()
        appState?.stopAutomaticUpdateChecks()
        appState?.telemetry.stop()
        appState?.metricsService.stop()
    }
}

/// Only fields that actually change the menu-bar glyph. Watts jitter must not redraw it.
private struct MenuBarIconKey: Equatable {
    var percent: Int
    var flowMode: EnergyFlowMode
    var style: MenuBarIconStyle
    var lowBatteryTint: Bool
    var showChargeGlyphs: Bool
    var language: AppLanguage

    @MainActor
    init(_ state: AppState) {
        percent = Int(state.snapshot.percent.rounded(.towardZero))
        flowMode = state.snapshot.flowMode
        style = state.settings.iconStyle
        lowBatteryTint = state.settings.lowBatteryTintEnabled
        showChargeGlyphs = state.settings.showChargeGlyphs
        language = state.settings.language
    }
}

