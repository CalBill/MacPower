import Foundation

enum EnergyFlowMode: String, Equatable, Sendable {
    case charging
    case adapterHold
    case discharging
    case underpowered

    static func derive(
        hasBattery: Bool,
        externalConnected: Bool,
        isCharging: Bool,
        instantAmperageMilli: Int,
        batteryWatts: Double,
        chargeThresholdWatts: Double = 0.4
    ) -> EnergyFlowMode {
        guard hasBattery else { return .adapterHold }

        if !externalConnected {
            return .discharging
        }

        if instantAmperageMilli < 0 || batteryWatts < -chargeThresholdWatts {
            return .underpowered
        }

        if isCharging && (instantAmperageMilli > 0 || batteryWatts > chargeThresholdWatts) {
            return .charging
        }

        return .adapterHold
    }
}
