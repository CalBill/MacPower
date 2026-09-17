import AppKit
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var hosting: NSHostingController<PopoverRootView>
    private var defaultArrowHeight: CGFloat?

    init(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        hosting = NSHostingController(rootView: PopoverRootView(appState: appState))
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        hosting.sizingOptions = [.intrinsicContentSize]
        popover.contentViewController = hosting
        applyAnchorPreference()

        if let button = statusItem.button {
            button.imagePosition = .imageLeft
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        refreshIcon()
    }

    func applyLocalization() {
        let replacement = NSHostingController(rootView: PopoverRootView(appState: appState))
        replacement.sizingOptions = [.intrinsicContentSize]
        popover.contentViewController = replacement
        hosting = replacement
        refreshIcon()
    }

    func applyArrowVisibility() {
        applyAnchorPreference()
        guard popover.isShown, let button = statusItem.button else { return }
        applyArrowHeight(hidden: !appState.settings.showPopoverArrow)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        hugMenuBarIfArrowHidden()
    }

    private func applyAnchorPreference() {
        let hide = !appState.settings.showPopoverArrow
        if popover.responds(to: NSSelectorFromString("setShouldHideAnchor:")) {
            popover.setValue(hide, forKey: "shouldHideAnchor")
        }
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
        if appState.settings.iconStyle.showsPercentBeside {
            button.title = " \(Int(appState.snapshot.percent.rounded()))%"
        } else {
            button.title = ""
        }
        button.toolTip = tooltip
    }

    private var tooltip: String {
        let percent = Int(appState.snapshot.percent.rounded())
        return Localization.string("battery.percent %lld", language: appState.settings.language, Int64(percent))
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        appState.setPopoverOpen(true)
        applyArrowVisibility()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        hugMenuBarIfArrowHidden()
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidShow(_ notification: Notification) {
        if !appState.isPopoverOpen {
            appState.setPopoverOpen(true)
        }
        hugMenuBarIfArrowHidden()
    }

    func popoverDidClose(_ notification: Notification) {
        appState.setPopoverOpen(false)
    }

    private func applyArrowHeight(hidden: Bool) {
        cacheDefaultArrowHeightIfNeeded(on: popover)
        let height: CGFloat = hidden ? 0 : (defaultArrowHeight ?? 13)
        setArrowHeight(height, on: popover)
        if let window = popover.contentViewController?.view.window {
            cacheDefaultArrowHeightIfNeeded(on: window)
            setArrowHeight(height, on: window)
        }
    }

    private func cacheDefaultArrowHeightIfNeeded(on object: NSObject) {
        guard defaultArrowHeight == nil else { return }
        guard object.responds(to: NSSelectorFromString("arrowHeight")) else { return }
        guard let height = object.value(forKey: "arrowHeight") as? CGFloat, height > 0 else { return }
        defaultArrowHeight = height
    }

    private func setArrowHeight(_ height: CGFloat, on object: NSObject) {
        guard object.responds(to: NSSelectorFromString("setArrowHeight:")) else { return }
        object.setValue(height, forKey: "arrowHeight")
    }

    /// `shouldHideAnchor` only skips drawing the triangle; AppKit still reserves its slot.
    /// Pull the panel up so its content sits against the menu-bar underside.
    private func hugMenuBarIfArrowHidden() {
        guard !appState.settings.showPopoverArrow else { return }
        applyArrowHeight(hidden: true)
        guard let content = popover.contentViewController?.view,
              let window = content.window else { return }
        let screen = window.screen
            ?? NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        guard let screen else { return }

        let contentOnScreen = window.convertToScreen(content.convert(content.bounds, to: nil))
        let delta = screen.visibleFrame.maxY - contentOnScreen.maxY
        guard delta > 0.5 else { return }
        window.setFrame(window.frame.offsetBy(dx: 0, dy: delta), display: true)
    }
}
