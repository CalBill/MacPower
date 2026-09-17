import Foundation

enum MenuBarIconStyle: String, CaseIterable, Identifiable, Sendable {
    case systemFill
    case systemPercentInside
    case classicBeside

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .systemFill: "settings.icon.systemFill"
        case .systemPercentInside: "settings.icon.percentInside"
        case .classicBeside: "settings.icon.classic"
        }
    }
}
