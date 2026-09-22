import Foundation

/// What a right-click on the menu-bar status item should do.
enum MenuBarRightClickAction: String, CaseIterable, Identifiable, Sendable {
    /// Show a status menu (Quit). Default for new installs.
    case statusMenu
    /// Same as left-click: toggle the monitoring popover.
    case openPanel

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .statusMenu: "settings.menuBar.rightClick.statusMenu"
        case .openPanel: "settings.menuBar.rightClick.openPanel"
        }
    }

    static func resolved(stored raw: String?) -> MenuBarRightClickAction {
        guard let raw, let action = MenuBarRightClickAction(rawValue: raw) else {
            return .statusMenu
        }
        return action
    }
}
