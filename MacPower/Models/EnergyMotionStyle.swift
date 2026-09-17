import Foundation

enum EnergyMotionStyle: String, CaseIterable, Identifiable, Sendable, Codable {
    case sheen
    case filaments
    case particles
    case off

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .sheen: "settings.motion.sheen"
        case .filaments: "settings.motion.filaments"
        case .particles: "settings.motion.particles"
        case .off: "settings.motion.off"
        }
    }

    var needsAnimation: Bool { self != .off }

    var usesCanvasTimeline: Bool {
        switch self {
        case .sheen, .filaments, .particles: true
        case .off: false
        }
    }

    var framesPerSecond: Double {
        switch self {
        case .sheen, .filaments, .particles: 60
        case .off: 1
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = EnergyMotionStyle.resolved(stored: raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// Maps persisted values, including deleted light-band / comet styles and old keys.
    static func resolved(stored raw: String?) -> EnergyMotionStyle {
        guard let raw, !raw.isEmpty else { return .sheen }
        if let style = EnergyMotionStyle(rawValue: raw) {
            return style
        }
        switch raw {
        case "band", "comet", "spark", "lightBand":
            return .sheen
        case "powder":
            return .particles
        default:
            return .sheen
        }
    }
}
