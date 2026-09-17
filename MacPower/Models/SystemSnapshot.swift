import Foundation

struct SystemSnapshot: Equatable, Sendable {
    var cpuPercent: Double
    var gpuPercent: Double
    var memoryPercent: Double

    static let empty = SystemSnapshot(cpuPercent: 0, gpuPercent: 0, memoryPercent: 0)
}

enum CPUTickSample: Equatable, Sendable {
    struct Ticks: Equatable, Sendable {
        var user: Double
        var system: Double
        var idle: Double
        var nice: Double
    }

    static func usagePercent(previous: Ticks, current: Ticks) -> Double {
        let user = max(0, current.user - previous.user)
        let system = max(0, current.system - previous.system)
        let idle = max(0, current.idle - previous.idle)
        let nice = max(0, current.nice - previous.nice)
        let total = user + system + idle + nice
        guard total > 0 else { return 0 }
        return min(100, (user + system + nice) / total * 100)
    }

    /// Returns a CPU percent only when ticks actually advanced.
    /// Identical samples would otherwise look like 0% and flash the UI.
    static func resolvedPercent(previous: Ticks?, current: Ticks?, lastPublished: Double?) -> Double? {
        guard let previous, let current else { return lastPublished }
        let user = max(0, current.user - previous.user)
        let system = max(0, current.system - previous.system)
        let idle = max(0, current.idle - previous.idle)
        let nice = max(0, current.nice - previous.nice)
        guard user + system + idle + nice > 0 else { return lastPublished }
        return usagePercent(previous: previous, current: current)
    }
}

enum MemoryOccupancy: Equatable, Sendable {
    static func usagePercent(usedBytes: UInt64, totalBytes: UInt64) -> Double {
        guard totalBytes > 0 else { return 0 }
        return min(100, Double(usedBytes) / Double(totalBytes) * 100)
    }
}
