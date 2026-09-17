import Foundation

enum ThemePalette: String, CaseIterable, Identifiable, Sendable {
    case semantic
    case system
    case highContrast
    case glassMono

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .semantic: "settings.palette.semantic"
        case .system: "settings.palette.system"
        case .highContrast: "settings.palette.highContrast"
        case .glassMono: "settings.palette.glassMono"
        }
    }
}
