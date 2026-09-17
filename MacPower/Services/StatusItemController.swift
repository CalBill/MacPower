import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private let popover = NSPopover()

    init(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let hosting = NSHostingController(rootView: PopoverRootView(appState: appState))
        hosting.sizingOptions = [.intrinsicContentSize]
        popover.contentViewController = hosting

        if let button = statusItem.button {
            button.imagePosition = .imageLeft
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        refreshIcon()
    }

    func refreshIcon() {
        guard let button = statusItem.button else { return }
        let appearance = button.effectiveAppearance
        let fill = appState.menuBarFillColor(appearance: appearance)
        let image = MenuBarBatteryRenderer.image(
            snapshot: appState.snapshot,
            style: appState.settings.iconStyle,
            fillColor: fill,
            appearance: appearance,
            showChargeGlyphs: appState.settings.showChargeGlyphs
        )
        button.image = image
        let usesColor = fill != NSColor.black && appState.settings.lowBatteryTintEnabled
        image.isTemplate = !usesColor
        if appState.settings.iconStyle == .classicBeside {
            button.title = " \(Int(appState.snapshot.percent.rounded()))%"
        } else {
            button.title = ""
        }
        button.toolTip = tooltip
    }

    private var tooltip: String {
        let percent = Int(appState.snapshot.percent.rounded())
        return "\(percent)%"
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidShow(_ notification: Notification) {
        appState.setPopoverOpen(true)
    }

    func popoverDidClose(_ notification: Notification) {
        appState.setPopoverOpen(false)
    }
}
