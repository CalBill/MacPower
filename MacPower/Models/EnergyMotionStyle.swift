import Foundation

enum FlowMotionPigment: Equatable, Sendable {
    case gradient
    case solid
    case white
}

enum EnergyMotionStyle: String, CaseIterable, Identifiable, Sendable, Codable {
    case sheen
    case filaments
    case filamentsSolid
    case filamentsWhite
    case particles
    case particlesSolid
    case particlesWhite
    case off

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .sheen: "settings.motion.sheen"
        case .filaments: "settings.motion.filaments"
        case .filamentsSolid: "settings.motion.filamentsSolid"
        case .filamentsWhite: "settings.motion.filamentsWhite"
        case .particles: "settings.motion.particles"
        case .particlesSolid: "settings.motion.particlesSolid"
        case .particlesWhite: "settings.motion.particlesWhite"
        case .off: "settings.motion.off"
        }
    }

    var needsAnimation: Bool { self != .off }

    var usesCanvasTimeline: Bool { self != .off }

    var framesPerSecond: Double { self == .off ? 1 : 60 }

    var pigment: FlowMotionPigment? {
        switch self {
        case .filaments, .particles: .gradient
        case .filamentsSolid, .particlesSolid: .solid
        case .filamentsWhite, .particlesWhite: .white
        case .sheen, .off: nil
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
