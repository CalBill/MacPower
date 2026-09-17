import AppKit
import Observation
import ServiceManagement
import SwiftUI

@MainActor
@Observable
final class AppState {
    var snapshot: PowerSnapshot = .empty
    var settings = AppSettings()
    var launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    var isPopoverOpen = false
    var launchAtLoginError: String?

    let telemetry = PowerTelemetryService()

    private var settingsWindow: NSWindow?

    init() {
        telemetry.onChange = { [weak self] snapshot in
            self?.snapshot = snapshot
        }
        telemetry.start()
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    func setPopoverOpen(_ open: Bool) {
        isPopoverOpen = open
        telemetry.setPopoverOpen(open)
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
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "settings.title")
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(appState: self))
        window.center()
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
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
