import XCTest
@testable import MacPower

final class EnergyFlowModeTests: XCTestCase {
    func testUnpluggedIsDischarging() {
        let mode = EnergyFlowMode.derive(
            hasBattery: true,
            externalConnected: false,
            isCharging: false,
            instantAmperageMilli: -1800,
            batteryWatts: -18
        )
        XCTAssertEqual(mode, .discharging)
    }

    func testChargingWhenPluggedAndCurrentPositive() {
        let mode = EnergyFlowMode.derive(
            hasBattery: true,
            externalConnected: true,
            isCharging: true,
            instantAmperageMilli: 3200,
            batteryWatts: 40
        )
        XCTAssertEqual(mode, .charging)
    }

    func testAdapterHoldWhenPluggedNotCharging() {
        let mode = EnergyFlowMode.derive(
            hasBattery: true,
            externalConnected: true,
            isCharging: false,
            instantAmperageMilli: 0,
            batteryWatts: 0.1
        )
        XCTAssertEqual(mode, .adapterHold)
    }

    func testUnderpoweredWhenPluggedAndCurrentNegative() {
        let mode = EnergyFlowMode.derive(
            hasBattery: true,
            externalConnected: true,
            isCharging: false,
            instantAmperageMilli: -2100,
            batteryWatts: -25
        )
        XCTAssertEqual(mode, .underpowered)
    }
}

final class FlowRibbonTests: XCTestCase {
    func testTrunkWidthIsTripleNodeDiameter() {
        XCTAssertEqual(FlowRibbon.nodeDiameter, 32)
        XCTAssertEqual(FlowRibbon.trunkWidth(totalWatts: 9.1), FlowRibbon.nodeDiameter * 3)
        XCTAssertEqual(FlowRibbon.trunkWidth(totalWatts: 4), FlowRibbon.nodeDiameter * 3)
        XCTAssertEqual(FlowRibbon.trunkWidth(totalWatts: 100), FlowRibbon.nodeDiameter * 3)
    }

    func testCapRadiusIsRoundedRectUntilThinnerThanNode() {
        XCTAssertEqual(FlowRibbon.capRadius(for: 20), 10)
        XCTAssertEqual(FlowRibbon.capRadius(for: 32), 16)
        XCTAssertEqual(FlowRibbon.capRadius(for: 96), 16)
        XCTAssertEqual(FlowRibbon.endInset(for: 96), 16)
    }

    func testSplitWidthsPreserveRatioAndSum() {
        let trunk: CGFloat = 40
        let widths = FlowRibbon.splitWidths(first: 15.52, second: 20.16, trunk: trunk)
        XCTAssertEqual(widths.0 + widths.1, trunk, accuracy: 0.001)
        XCTAssertEqual(Double(widths.0 / widths.1), 15.52 / 20.16, accuracy: 0.001)
    }

    func testParticleSpeedIncreasesWithWatts() {
        let slow = FlowRibbon.particleSpeed(watts: 8)
        let mid = FlowRibbon.particleSpeed(watts: 22)
        let fast = FlowRibbon.particleSpeed(watts: 70)
        XCTAssertGreaterThan(mid, slow)
        XCTAssertGreaterThan(fast, mid)
        XCTAssertGreaterThan(slow, 0)
    }

    func testZeroWattsDoesNotNaN() {
        let widths = FlowRibbon.splitWidths(first: 0, second: 0, trunk: 20)
        XCTAssertEqual(widths.0 + widths.1, 20, accuracy: 0.001)
        XCTAssertGreaterThan(widths.0, 0)
        XCTAssertGreaterThan(widths.1, 0)
    }
}

final class TimeEstimateTests: XCTestCase {
    func testSentinelIsUnknown() {
        XCTAssertNil(TimeEstimateService.sanitizedSystemMinutes(65535))
        XCTAssertNil(TimeEstimateService.sanitizedSystemMinutes(0))
        XCTAssertEqual(TimeEstimateService.sanitizedSystemMinutes(64), 64)
    }

    func testFullTimeUsesChargeRateWhenSystemMissing() {
        let minutes = TimeEstimateService.timeToFullMinutes(
            isCharging: true,
            systemMinutes: nil,
            missingCapacityWh: 20,
            chargeWatts: 40
        )
        XCTAssertEqual(minutes, 30)
    }

    func testFullTimeNilWhenNotCharging() {
        XCTAssertNil(
            TimeEstimateService.timeToFullMinutes(
                isCharging: false,
                systemMinutes: 40,
                missingCapacityWh: 20,
                chargeWatts: 40
            )
        )
    }

    func testEmptyTimeNilNearZeroWatts() {
        XCTAssertNil(
            TimeEstimateService.minutesFromEnergy(wattHours: 40, watts: 0.1)
        )
    }

    func testEmptyTimeFromEnergy() {
        XCTAssertEqual(
            TimeEstimateService.minutesFromEnergy(wattHours: 40, watts: 20),
            120
        )
    }

    func testPrefersSystemMinutesWhenOnBattery() {
        let minutes = TimeEstimateService.timeToEmptyMinutes(
            isOnBattery: true,
            systemMinutes: 90,
            remainingCapacityWh: 40,
            averageLoadWatts: 10
        )
        XCTAssertEqual(minutes, 90)
    }

    func testComputedRuntimeWhenPluggedUsesAverageLoad() {
        let minutes = TimeEstimateService.timeToEmptyMinutes(
            isOnBattery: false,
            systemMinutes: 90,
            remainingCapacityWh: 40,
            averageLoadWatts: 10
        )
        XCTAssertEqual(minutes, 240)
    }

    func testNominalVoltageWhileCharging() {
        let charging = TimeEstimateService.wattHours(milliAmpHours: 2000, voltageMilli: 13000, preferNominal: true)
        let discharging = TimeEstimateService.wattHours(milliAmpHours: 2000, voltageMilli: 11550, preferNominal: false)
        XCTAssertEqual(charging, 2 * 11.55, accuracy: 0.01)
        XCTAssertEqual(discharging, 2 * 11.55, accuracy: 0.01)
    }
}
