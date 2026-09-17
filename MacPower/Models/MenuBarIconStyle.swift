import Foundation

enum MenuBarIconStyle: String, CaseIterable, Identifiable, Sendable {
    case systemFill
    case systemPercentInside
    case classicBeside
    case outlineFill
    case outlinePercentInside
    case outlineClassicBeside

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .systemFill: "settings.icon.systemFill"
        case .systemPercentInside: "settings.icon.percentInside"
        case .classicBeside: "settings.icon.classic"
        case .outlineFill: "settings.icon.outlineFill"
        case .outlinePercentInside: "settings.icon.outlinePercentInside"
        case .outlineClassicBeside: "settings.icon.outlineClassic"
        }
    }

    var showsPercentInside: Bool {
        self == .systemPercentInside || self == .outlinePercentInside
    }

    var showsPercentBeside: Bool {
        self == .classicBeside || self == .outlineClassicBeside
    }

    var isOutlined: Bool {
        switch self {
        case .outlineFill, .outlinePercentInside, .outlineClassicBeside: true
        default: false
        }
    }
}
