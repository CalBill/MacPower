import Foundation

enum EnergyMotionFrameRate: Int, CaseIterable, Identifiable, Sendable {
    case hz15 = 15
    case hz24 = 24
    case hz30 = 30
    case hz45 = 45
    case hz60 = 60
    case hz75 = 75
    case hz90 = 90
    case hz120 = 120

    var id: Int { rawValue }

    var framesPerSecond: Double { Double(rawValue) }

    var title: String { "\(rawValue) Hz" }

    static func resolved(stored raw: Int?) -> EnergyMotionFrameRate {
        guard let raw, let rate = EnergyMotionFrameRate(rawValue: raw) else { return .hz60 }
        return rate
    }
}
