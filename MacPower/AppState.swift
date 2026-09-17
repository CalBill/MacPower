import AppKit
import Observation
import ServiceManagement
import SwiftUI

@MainActor
@Observable
final class AppState {
    var snapshot: PowerSnapshot = .empty
    var metrics: SystemSnapshot = .empty
    var settings = AppSettings()
    var launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    var isPopoverOpen = false
    var launchAtLoginError: String?
    @ObservationIgnored
    var onLanguageChange: (() -> Void)?
    @ObservationIgnored
    var onPopoverChromeChange: (() -> Void)?

    let telemetry = PowerTelemetryService()
    let metricsService = SystemMetricsService()

    private var settingsWindow: NSWindow?

    init() {
        telemetry.onChange = { [weak self] snapshot in
            self?.snapshot = snapshot
        }
        metricsService.onChange = { [weak self] metrics in
            self?.metrics = metrics
        }
        telemetry.start()
        metricsService.start()
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    func setPopoverOpen(_ open: Bool) {
        isPopoverOpen = open
        telemetry.setPopoverOpen(open)
        metricsService.setPopoverOpen(open)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
    }

    func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: SettingsView(appState: self))
        hosting.sizingOptions = [.intrinsicContentSize]
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.title = Localization.string("settings.title", language: settings.language)
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }

    func refreshLocalizedChrome() {
        settingsWindow?.title = Localization.string("settings.title", language: settings.language)
        onLanguageChange?()
    }

    func menuBarFillColor(appearance: NSAppearance) -> NSColor {
        var color = NSColor.black
        appearance.performAsCurrentDrawingAppearance {
            if settings.lowBatteryTintEnabled,
               snapshot.flowMode == .discharging || snapshot.flowMode == .underpowered {
                if snapshot.percent <= 10 {
                    color = NSColor.systemRed
                    return
                }
                if snapshot.percent <= 20 {
                    color = NSColor.systemYellow
                    return
                }
            }
            color = NSColor.black
        }
        return color
    }
}
