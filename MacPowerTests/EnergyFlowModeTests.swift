import SwiftUI
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

final class HeldLoadWattsTests: XCTestCase {
    func testUnplugDropoutKeepsLastRealLoad() {
        XCTAssertEqual(HeldLoadWatts.hold(current: 0, previous: 18.4), 18.4)
        XCTAssertEqual(HeldLoadWatts.hold(current: 0.1, previous: 9), 9)
    }

    func testRealSampleReplacesHeldLoad() {
        XCTAssertEqual(HeldLoadWatts.hold(current: 12.2, previous: 18.4), 12.2)
        XCTAssertEqual(HeldLoadWatts.hold(current: 0.5, previous: 9), 0.5)
    }

    func testMissingHistoryDoesNotInventLoad() {
        XCTAssertEqual(HeldLoadWatts.hold(current: 0, previous: nil), 0)
        XCTAssertEqual(HeldLoadWatts.hold(current: 0.2, previous: 0.1), 0.2)
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

    func testSheenSpeedIncreasesWithWatts() {
        let slow = FlowRibbon.sheenSpeed(watts: 8)
        let mid = FlowRibbon.sheenSpeed(watts: 22)
        let fast = FlowRibbon.sheenSpeed(watts: 70)
        XCTAssertGreaterThan(mid, slow)
        XCTAssertGreaterThan(fast, mid)
        XCTAssertGreaterThan(slow, 0)
    }

    func testFilamentSpeedIncreasesWithWattsAndIsFasterThanSheen() {
        let slow = FlowRibbon.filamentSpeed(watts: 8)
        let mid = FlowRibbon.filamentSpeed(watts: 22)
        let fast = FlowRibbon.filamentSpeed(watts: 70)
        XCTAssertGreaterThan(mid, slow)
        XCTAssertGreaterThan(fast, mid)
        XCTAssertGreaterThan(FlowRibbon.filamentSpeed(watts: 22), FlowRibbon.sheenSpeed(watts: 22))
    }

    func testParticleCountIsCapped() {
        XCTAssertEqual(FlowRibbon.particleCount(laneWidth: 96), 67)
        XCTAssertEqual(FlowRibbon.particleCount(laneWidth: 10), 28)
        XCTAssertEqual(FlowRibbon.particleCount(laneWidth: 400), 72)
    }

    func testFilamentCountIsSmall() {
        XCTAssertEqual(FlowRibbon.filamentCount(laneWidth: 96), 9)
        XCTAssertEqual(FlowRibbon.filamentCount(laneWidth: 10), 6)
        XCTAssertEqual(FlowRibbon.filamentCount(laneWidth: 400), 14)
    }

    func testZeroWattsDoesNotNaN() {
        let widths = FlowRibbon.splitWidths(first: 0, second: 0, trunk: 20)
        XCTAssertEqual(widths.0 + widths.1, 20, accuracy: 0.001)
        XCTAssertGreaterThan(widths.0, 0)
        XCTAssertGreaterThan(widths.1, 0)
    }

    func testStraightCapsuleIsSingleSubpath() {
        let path = ForkOutline.capsule(
            from: CGPoint(x: 16, y: 48),
            to: CGPoint(x: 400, y: 48),
            width: 96
        )
        XCTAssertEqual(path.subpathCount, 1)
        XCTAssertEqual(path.boundingRect, CGRect(x: 0, y: 0, width: 416, height: 96), accuracy: 0.01)
    }

    func testForkCapsNormalizeToSingleSilhouette() {
        let path = ForkOutline.splitPath(
            left: CGPoint(x: 16, y: 60),
            top: CGPoint(x: 400, y: 16),
            bot: CGPoint(x: 400, y: 104),
            topW: 32,
            botW: 64
        )
        XCTAssertEqual(path.subpathCount, 1)
    }

    func testWattLabelSitsInTheRightHandBody() {
        XCTAssertGreaterThan(FlowRibbon.wattLabelT, 0.5)
        XCTAssertLessThan(FlowRibbon.wattLabelT, 0.85)
        XCTAssertEqual(FlowRibbon.wattLabelT, 0.72, accuracy: 0.001)
    }

    func testCollapseDoesNotDeflateCapsuleCorners() {
        let trunk: CGFloat = 96
        let topW: CGFloat = 40
        let botW: CGFloat = 56
        let top = CGPoint(x: 16, y: 20)
        let bot = CGPoint(x: 16, y: 100)
        let right = CGPoint(x: 344, y: 60)
        let remaining: CGFloat = 40
        let mergeT = remaining / (right.x - top.x)
        let path = ForkOutline.mergePath(
            top: top,
            bot: bot,
            right: right,
            topW: topW,
            botW: botW,
            mergeT: mergeT,
            collapse: FlowRibbon.forkCollapse(remainingLength: remaining, minimum: trunk)
        )
        let destination = ForkOutline.capsule(
            from: CGPoint(x: top.x, y: right.y),
            to: right,
            width: trunk
        )
        let inset: CGFloat = 6
        XCTAssertTrue(
            path.contains(CGPoint(x: top.x + 20, y: destination.boundingRect.minY + inset)),
            "top-left capsule corner caved in during collapse"
        )
        XCTAssertTrue(
            path.contains(CGPoint(x: top.x + 20, y: destination.boundingRect.maxY - inset)),
            "bottom-left capsule corner caved in during collapse"
        )
    }

    func testCollapseDoesNotPunchAHoleThroughTheRibbon() {
        let left = CGPoint(x: 16, y: 60)
        let top = CGPoint(x: 344, y: 20)
        let bot = CGPoint(x: 344, y: 100)
        let minimum: CGFloat = 96
        for step in 0...12 {
            let phase = CGFloat(step) / 12
            let splitT = FlowRibbon.forkT + (1 - FlowRibbon.forkT) * phase
            let remaining = (top.x - left.x) * (1 - splitT)
            let path = ForkOutline.splitPath(
                left: left,
                top: top,
                bot: bot,
                topW: 40,
                botW: 56,
                splitT: splitT,
                collapse: FlowRibbon.forkCollapse(remainingLength: remaining, minimum: minimum)
            )
            XCTAssertTrue(
                path.contains(CGPoint(x: left.x + 24, y: left.y)),
                "trunk holed at phase \(phase)"
            )
            let splitX = left.x + (top.x - left.x) * splitT
            if splitX - left.x > 20 {
                XCTAssertTrue(
                    path.contains(CGPoint(x: splitX - 10, y: left.y)),
                    "crotch holed at phase \(phase)"
                )
            }
        }
    }

    func testForkCollapsePinchesShortBranchesInsteadOfSnapping() {
        XCTAssertEqual(FlowRibbon.forkCollapse(remainingLength: 80, minimum: 64), 0)
        XCTAssertEqual(FlowRibbon.forkCollapse(remainingLength: 0, minimum: 64), 1)
        XCTAssertEqual(FlowRibbon.forkCollapse(remainingLength: 32, minimum: 64), 1)
        XCTAssertEqual(FlowRibbon.forkCollapse(remainingLength: 48, minimum: 64), 0.5, accuracy: 0.001)
        XCTAssertEqual(FlowRibbon.forkCollapse(remainingLength: -4, minimum: 64), 1)
    }

    func testYCapsuleCloseIsOpeningPlayedBackwards() {
        XCTAssertEqual(FlowRibbon.splitT(open: 0), 1)
        XCTAssertEqual(FlowRibbon.splitT(open: 1), FlowRibbon.forkT, accuracy: 0.0001)
        XCTAssertEqual(
            FlowRibbon.splitT(open: 0.3),
            1 - (1 - FlowRibbon.forkT) * 0.3,
            accuracy: 0.0001
        )
        XCTAssertGreaterThan(FlowRibbon.splitT(open: 0.2), FlowRibbon.splitT(open: 0.8))
        XCTAssertEqual(FlowRibbon.mergeT(open: 0), 0)
        XCTAssertEqual(FlowRibbon.mergeT(open: 1), 1 - FlowRibbon.forkT)
        XCTAssertEqual(FlowRibbon.mergeT(open: 0.4), (1 - FlowRibbon.forkT) * 0.4, accuracy: 0.0001)
        XCTAssertLessThan(FlowRibbon.mergeT(open: 0.2), FlowRibbon.mergeT(open: 0.8))
    }

    func testCollapsedForkMatchesCapsuleBounds() {
        let collapsed = ForkOutline.splitPath(
            left: CGPoint(x: 16, y: 60),
            top: CGPoint(x: 400, y: 16),
            bot: CGPoint(x: 400, y: 104),
            topW: 32,
            botW: 64,
            splitT: 0.9,
            collapse: 1
        )
        let capsule = ForkOutline.capsule(
            from: CGPoint(x: 16, y: 60),
            to: CGPoint(x: 400, y: 60),
            width: 96
        )
        XCTAssertEqual(collapsed.boundingRect, capsule.boundingRect, accuracy: 0.01)
        XCTAssertEqual(collapsed.subpathCount, 1)
    }

    func testCollapseDoesNotBridgeForksWithATrunkBar() {
        let size = CGSize(width: 360, height: 120)
        let trunk = FlowRibbon.trunkWidth(totalWatts: 1)
        let inset = FlowRibbon.capRadius(for: trunk)
        let topW: CGFloat = 40
        let botW: CGFloat = 56
        let left = CGPoint(x: inset, y: size.height / 2)
        let top = CGPoint(x: size.width - inset, y: topW / 2)
        let bot = CGPoint(x: size.width - inset, y: size.height - botW / 2)
        let gap = CGPoint(x: size.width - inset - 8, y: size.height / 2 - 8)

        let open = ForkOutline.splitPath(
            left: left, top: top, bot: bot, topW: topW, botW: botW, splitT: FlowRibbon.forkT, collapse: 0
        )
        XCTAssertFalse(open.contains(gap), "the charging Y must keep a gap between the two end ports")

        let early = ForkOutline.splitPath(
            left: left, top: top, bot: bot, topW: topW, botW: botW, splitT: 0.55, collapse: 0.08
        )
        XCTAssertFalse(
            early.contains(gap),
            "collapse must pinch the two ports together, not drop in a trunk-height bar that fills the gap"
        )

        let closed = ForkOutline.splitPath(
            left: left, top: top, bot: bot, topW: topW, botW: botW, splitT: 1, collapse: 1
        )
        XCTAssertTrue(closed.contains(CGPoint(x: size.width / 2, y: size.height / 2)))
    }

    func testChargingMergeKeepsRightEdgeUntilCapsule() {
        let size = CGSize(width: 360, height: 96)
        let trunk = FlowRibbon.trunkWidth(totalWatts: 1)
        let inset = FlowRibbon.capRadius(for: trunk)
        let topW: CGFloat = 40
        let botW: CGFloat = 56
        let left = CGPoint(x: inset, y: size.height / 2)
        let top = CGPoint(x: size.width - inset, y: topW / 2)
        let bot = CGPoint(x: size.width - inset, y: size.height - botW / 2)
        let destination = ForkOutline.capsule(
            from: left,
            to: CGPoint(x: top.x, y: left.y),
            width: trunk
        )
        let expectedMaxX = destination.boundingRect.maxX
        let minimum = max(trunk, FlowRibbon.nodeDiameter * 2)

        var previousMaxX: CGFloat?
        var worstJump: CGFloat = 0
        for step in 0...120 {
            let phase = CGFloat(step) / 120
            let splitT = FlowRibbon.forkT + (1 - FlowRibbon.forkT) * phase
            let remaining = (size.width - inset * 2) * (1 - splitT)
            let path = ForkOutline.splitPath(
                left: left,
                top: top,
                bot: bot,
                topW: 40,
                botW: 56,
                splitT: splitT,
                collapse: FlowRibbon.forkCollapse(remainingLength: remaining, minimum: minimum)
            )
            let maxX = path.boundingRect.maxX
            XCTAssertEqual(maxX, expectedMaxX, accuracy: 1.2, "right edge receded at phase \(phase)")
            if let previousMaxX {
                worstJump = max(worstJump, abs(maxX - previousMaxX))
            }
            previousMaxX = maxX
        }
        XCTAssertLessThan(worstJump, 1.2, "right edge jumped \(worstJump) during Y merge")
    }

    func testRibbonOverlayHidesWattMotionBeforeIncomingAppears() {
        let start = FlowRibbonOverlay.opacities(progress: 0)
        XCTAssertEqual(start.outgoing, 1, accuracy: 0.001)
        XCTAssertEqual(start.incoming, 0, accuracy: 0.001)

        let mid = FlowRibbonOverlay.opacities(progress: 0.5)
        XCTAssertEqual(mid.outgoing, 0, accuracy: 0.001)
        XCTAssertEqual(mid.incoming, 0, accuracy: 0.001)

        let end = FlowRibbonOverlay.opacities(progress: 1)
        XCTAssertEqual(end.outgoing, 0, accuracy: 0.001)
        XCTAssertEqual(end.incoming, 1, accuracy: 0.001)
    }

    func testRibbonOverlayDoesNotCrossfadeWattMotion() {
        XCTAssertEqual(FlowRibbonOverlay.opacities(progress: 0.26).outgoing, 0, accuracy: 0.001)
        XCTAssertEqual(FlowRibbonOverlay.opacities(progress: 0.26).incoming, 0, accuracy: 0.001)
        XCTAssertEqual(FlowRibbonOverlay.opacities(progress: 0.62).outgoing, 0, accuracy: 0.001)
        XCTAssertEqual(FlowRibbonOverlay.opacities(progress: 0.62).incoming, 0, accuracy: 0.001)
        XCTAssertGreaterThan(FlowRibbonOverlay.opacities(progress: 0.8).incoming, 0.2)
        XCTAssertEqual(FlowRibbonOverlay.opacities(progress: 0.8).outgoing, 0, accuracy: 0.001)
    }
}

private extension Path {
    var subpathCount: Int {
        var count = 0
        cgPath.applyWithBlock { element in
            if element.pointee.type == .moveToPoint {
                count += 1
            }
        }
        return count
    }
}

private func XCTAssertEqual(_ rect: CGRect, _ expected: CGRect, accuracy: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(rect.origin.x, expected.origin.x, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(rect.origin.y, expected.origin.y, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(rect.width, expected.width, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(rect.height, expected.height, accuracy: accuracy, file: file, line: line)
}

final class EnergyMotionStyleTests: XCTestCase {
    func testMotionOptionsAndDefault() {
        XCTAssertEqual(EnergyMotionStyle.allCases, [
            .sheen,
            .filaments, .filamentsSolid, .filamentsWhite,
            .particles, .particlesSolid, .particlesWhite,
            .off
        ])
        XCTAssertTrue(EnergyMotionStyle.sheen.needsAnimation)
        XCTAssertTrue(EnergyMotionStyle.filaments.needsAnimation)
        XCTAssertTrue(EnergyMotionStyle.particlesSolid.needsAnimation)
        XCTAssertFalse(EnergyMotionStyle.off.needsAnimation)
        XCTAssertTrue(EnergyMotionStyle.sheen.usesCanvasTimeline)
        XCTAssertTrue(EnergyMotionStyle.filamentsWhite.usesCanvasTimeline)
        XCTAssertFalse(EnergyMotionStyle.off.usesCanvasTimeline)
        XCTAssertEqual(EnergyMotionStyle.filaments.pigment, .gradient)
        XCTAssertEqual(EnergyMotionStyle.particlesSolid.pigment, .solid)
        XCTAssertEqual(EnergyMotionStyle.filamentsWhite.pigment, .white)
    }

    func testMotionStylePersists() {
        let defaults = UserDefaults(suiteName: "MacPower.MotionStyleTests")!
        defaults.removePersistentDomain(forName: "MacPower.MotionStyleTests")
        let first = AppSettings(defaults: defaults)
        XCTAssertEqual(first.motionStyle, .sheen)
        first.motionStyle = .particlesSolid
        let second = AppSettings(defaults: defaults)
        XCTAssertEqual(second.motionStyle, .particlesSolid)
        defaults.removePersistentDomain(forName: "MacPower.MotionStyleTests")
    }

    func testLegacyBandAndCometMapToSheen() {
        let suite = "MacPower.MotionMigrateTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set("band", forKey: "motionStyle")
        XCTAssertEqual(AppSettings(defaults: defaults).motionStyle, .sheen)
        defaults.set("comet", forKey: "motionStyle")
        XCTAssertEqual(AppSettings(defaults: defaults).motionStyle, .sheen)
        defaults.set("filaments", forKey: "motionStyle")
        XCTAssertEqual(AppSettings(defaults: defaults).motionStyle, .filaments)
        XCTAssertEqual(EnergyMotionStyle.resolved(stored: nil), .sheen)
        XCTAssertEqual(EnergyMotionStyle.resolved(stored: "unknown"), .sheen)
        defaults.removePersistentDomain(forName: suite)
    }

    func testLegacyEnergyMotionKeyMigrates() {
        let suite = "MacPower.MotionLegacyKeyTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set("particles", forKey: "energyMotion")
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.motionStyle, .particles)
        XCTAssertEqual(defaults.string(forKey: "motionStyle"), "particles")
        XCTAssertNil(defaults.string(forKey: "energyMotion"))
        defaults.removePersistentDomain(forName: suite)
    }

    func testDecodeNeverCrashesOnLegacyCases() throws {
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(EnergyMotionStyle.self, from: Data("\"band\"".utf8)), .sheen)
        XCTAssertEqual(try decoder.decode(EnergyMotionStyle.self, from: Data("\"comet\"".utf8)), .sheen)
        XCTAssertEqual(try decoder.decode(EnergyMotionStyle.self, from: Data("\"spark\"".utf8)), .sheen)
        XCTAssertEqual(try decoder.decode(EnergyMotionStyle.self, from: Data("\"powder\"".utf8)), .particles)
        XCTAssertEqual(try decoder.decode(EnergyMotionStyle.self, from: Data("\"unknown\"".utf8)), .sheen)
        XCTAssertEqual(try decoder.decode(EnergyMotionStyle.self, from: Data("\"sheen\"".utf8)), .sheen)
        XCTAssertEqual(try decoder.decode(EnergyMotionStyle.self, from: Data("\"filamentsSolid\"".utf8)), .filamentsSolid)
        let encoded = try JSONEncoder().encode(EnergyMotionStyle.filaments)
        XCTAssertEqual(try decoder.decode(EnergyMotionStyle.self, from: encoded), .filaments)
    }

    func testMotionFrameRateDefaultsTo60AndPersists() {
        let suite = "MacPower.MotionFrameRateTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let first = AppSettings(defaults: defaults)
        XCTAssertEqual(first.motionFrameRate, .hz60)
        XCTAssertEqual(EnergyMotionFrameRate.allCases.map(\.rawValue), [15, 24, 30, 45, 60, 75, 90, 120])
        first.motionFrameRate = .hz30
        let second = AppSettings(defaults: defaults)
        XCTAssertEqual(second.motionFrameRate, .hz30)
        XCTAssertEqual(EnergyMotionFrameRate.resolved(stored: 24), .hz24)
        XCTAssertEqual(EnergyMotionFrameRate.resolved(stored: 7), .hz60)
        XCTAssertEqual(EnergyMotionFrameRate.resolved(stored: nil), .hz60)
        defaults.removePersistentDomain(forName: suite)
    }

    func testPulseFlowIconsDefaultsOnAndPersists() {
        let suite = "MacPower.PulseFlowIconsTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let first = AppSettings(defaults: defaults)
        XCTAssertTrue(first.pulseFlowIcons)
        first.pulseFlowIcons = false
        let second = AppSettings(defaults: defaults)
        XCTAssertFalse(second.pulseFlowIcons)
        defaults.removePersistentDomain(forName: suite)
    }

    func testShowPopoverArrowDefaultsOnAndPersists() {
        let suite = "MacPower.PopoverArrowTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let first = AppSettings(defaults: defaults)
        XCTAssertTrue(first.showPopoverArrow)
        first.showPopoverArrow = false
        let second = AppSettings(defaults: defaults)
        XCTAssertFalse(second.showPopoverArrow)
        defaults.removePersistentDomain(forName: suite)
    }

    func testLanguageDefaultsToSystemAndPersists() {
        let suite = "MacPower.LanguageTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let first = AppSettings(defaults: defaults)
        XCTAssertEqual(first.language, .system)
        first.language = .simplifiedChinese
        XCTAssertEqual(defaults.string(forKey: "appLanguage"), "zh-Hans")
        XCTAssertNil(defaults.persistentDomain(forName: suite)?["AppleLanguages"])
        let second = AppSettings(defaults: defaults)
        XCTAssertEqual(second.language, .simplifiedChinese)
        first.language = .system
        XCTAssertEqual(defaults.string(forKey: "appLanguage"), "system")
        XCTAssertEqual(AppSettings(defaults: defaults).language, .system)
        defaults.removePersistentDomain(forName: suite)
    }

    func testClearsLegacyAppleLanguages() {
        let suite = "MacPower.LanguageAppleLanguagesTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(["ja"], forKey: "AppleLanguages")
        defaults.set("en", forKey: "appLanguage")
        _ = AppSettings(defaults: defaults)
        XCTAssertNil(defaults.persistentDomain(forName: suite)?["AppleLanguages"])
        defaults.removePersistentDomain(forName: suite)
    }

    func testUnknownLanguageFallsBackToSystem() {
        XCTAssertEqual(AppLanguage.resolved(stored: nil), .system)
        XCTAssertEqual(AppLanguage.resolved(stored: ""), .system)
        XCTAssertEqual(AppLanguage.resolved(stored: "nope"), .system)
        XCTAssertEqual(AppLanguage.allCases.map(\.rawValue), [
            "system", "zh-Hans", "zh-Hant", "en", "ja", "ko", "fr", "de", "es", "pt-BR", "it", "ru"
        ])
    }
}

final class LocalizationTests: XCTestCase {
    func testExplicitLanguagesReadMatchingLproj() {
        XCTAssertEqual(Localization.string("settings.title", language: .english), "Settings")
        XCTAssertEqual(Localization.string("settings.title", language: .simplifiedChinese), "设置")
        XCTAssertEqual(Localization.string("settings.title", language: .traditionalChinese), "設定")
        XCTAssertEqual(Localization.string("settings.title", language: .japanese), "設定")
        XCTAssertEqual(Localization.string("energy.supplyPower", language: .japanese), "使用中の電力")
        XCTAssertEqual(
            Localization.string("ring.caption.battery %lld", language: .simplifiedChinese, Int64(87)),
            "电量：87%"
        )
        XCTAssertEqual(
            Localization.string("ring.caption.battery %lld", language: .japanese, Int64(87)),
            "バッテリー: 87%"
        )
        XCTAssertEqual(
            Localization.bundle(for: .brazilianPortuguese).bundlePath.hasSuffix("pt-BR.lproj"),
            true
        )
        XCTAssertEqual(
            Localization.string("settings.updates.automatic", language: .simplifiedChinese),
            "自动检查更新"
        )
        XCTAssertEqual(
            Localization.string("settings.about.version %@", language: .english, "1.2.4"),
            "Version 1.2.4"
        )
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

final class SystemSnapshotTests: XCTestCase {
    func testCPUUsageIgnoresIdleDelta() {
        let previous = CPUTickSample.Ticks(user: 0, system: 0, idle: 0, nice: 0)
        let current = CPUTickSample.Ticks(user: 20, system: 10, idle: 70, nice: 0)
        XCTAssertEqual(CPUTickSample.usagePercent(previous: previous, current: current), 30, accuracy: 0.01)
    }

    func testCPUUsageZeroWhenNoDelta() {
        let ticks = CPUTickSample.Ticks(user: 4, system: 2, idle: 10, nice: 0)
        XCTAssertEqual(CPUTickSample.usagePercent(previous: ticks, current: ticks), 0)
    }

    func testResolvedPercentKeepsLastWhenTicksUnchanged() throws {
        let ticks = CPUTickSample.Ticks(user: 4, system: 2, idle: 10, nice: 0)
        let resolved = CPUTickSample.resolvedPercent(previous: ticks, current: ticks, lastPublished: 37)
        XCTAssertEqual(try XCTUnwrap(resolved), 37)
    }

    func testResolvedPercentUsesDeltaWhenTicksAdvance() throws {
        let previous = CPUTickSample.Ticks(user: 0, system: 0, idle: 0, nice: 0)
        let current = CPUTickSample.Ticks(user: 20, system: 10, idle: 70, nice: 0)
        let resolved = CPUTickSample.resolvedPercent(previous: previous, current: current, lastPublished: 8)
        XCTAssertEqual(try XCTUnwrap(resolved), 30, accuracy: 0.01)
    }

    func testResolvedPercentIsNilWithoutDeltaOrLastValue() {
        let ticks = CPUTickSample.Ticks(user: 1, system: 1, idle: 1, nice: 0)
        XCTAssertNil(CPUTickSample.resolvedPercent(previous: ticks, current: ticks, lastPublished: nil))
        XCTAssertNil(CPUTickSample.resolvedPercent(previous: nil, current: ticks, lastPublished: nil))
    }

    func testResolvedPercentKeepsLastWhenSampleMissing() throws {
        let ticks = CPUTickSample.Ticks(user: 1, system: 1, idle: 1, nice: 0)
        XCTAssertEqual(try XCTUnwrap(CPUTickSample.resolvedPercent(previous: ticks, current: nil, lastPublished: 22)), 22)
        XCTAssertEqual(try XCTUnwrap(CPUTickSample.resolvedPercent(previous: nil, current: ticks, lastPublished: 22)), 22)
    }

    func testMemoryOccupancy() {
        XCTAssertEqual(MemoryOccupancy.usagePercent(usedBytes: 8, totalBytes: 32), 25)
        XCTAssertEqual(MemoryOccupancy.usagePercent(usedBytes: 10, totalBytes: 0), 0)
        XCTAssertEqual(MemoryOccupancy.usagePercent(usedBytes: 50, totalBytes: 40), 100)
    }
}

final class MenuBarIconStyleTests: XCTestCase {
    func testOutlineVariantsMatchFilledBehaviors() {
        XCTAssertEqual(MenuBarIconStyle.allCases, [
            .systemFill, .systemPercentInside, .classicBeside,
            .outlineFill, .outlinePercentInside, .outlineClassicBeside
        ])
        XCTAssertTrue(MenuBarIconStyle.systemPercentInside.showsPercentInside)
        XCTAssertTrue(MenuBarIconStyle.outlinePercentInside.showsPercentInside)
        XCTAssertTrue(MenuBarIconStyle.classicBeside.showsPercentBeside)
        XCTAssertTrue(MenuBarIconStyle.outlineClassicBeside.showsPercentBeside)
        XCTAssertTrue(MenuBarIconStyle.outlineFill.isOutlined)
        XCTAssertFalse(MenuBarIconStyle.systemFill.isOutlined)
        XCTAssertFalse(MenuBarIconStyle.systemFill.showsPercentInside)
        XCTAssertFalse(MenuBarIconStyle.outlineFill.showsPercentBeside)
    }
}

final class RingColorTests: XCTestCase {
    func testLoadFillBands() {
        let theme = AppTheme.resolved(palette: .semantic, colorScheme: .dark)
        XCTAssertEqual(theme.loadFill(percent: 0), theme.charging)
        XCTAssertEqual(theme.loadFill(percent: 59.9), theme.charging)
        XCTAssertEqual(theme.loadFill(percent: 60), theme.lowBatteryYellow)
        XCTAssertEqual(theme.loadFill(percent: 74.9), theme.lowBatteryYellow)
        XCTAssertEqual(theme.loadFill(percent: 75), theme.discharging)
        XCTAssertEqual(theme.loadFill(percent: 89.9), theme.discharging)
        XCTAssertEqual(theme.loadFill(percent: 90), theme.lowBatteryRed)
        XCTAssertEqual(theme.loadFill(percent: 100), theme.lowBatteryRed)
    }

    func testBatteryLevelFillBands() {
        let theme = AppTheme.resolved(palette: .semantic, colorScheme: .dark)
        XCTAssertEqual(theme.batteryLevelFill(percent: 100), theme.charging)
        XCTAssertEqual(theme.batteryLevelFill(percent: 40), theme.charging)
        XCTAssertEqual(theme.batteryLevelFill(percent: 39.9), theme.lowBatteryYellow)
        XCTAssertEqual(theme.batteryLevelFill(percent: 25), theme.lowBatteryYellow)
        XCTAssertEqual(theme.batteryLevelFill(percent: 24.9), theme.discharging)
        XCTAssertEqual(theme.batteryLevelFill(percent: 10), theme.discharging)
        XCTAssertEqual(theme.batteryLevelFill(percent: 9.9), theme.lowBatteryRed)
        XCTAssertEqual(theme.batteryLevelFill(percent: 0), theme.lowBatteryRed)
    }
}

final class RibbonMorphTests: XCTestCase {
    func testDirectUnplugStartsChargingClose() {
        let decision = RibbonMorph.decide(
            from: nil,
            startedAt: nil,
            duration: 1.65,
            previous: stub(.charging),
            nextMode: .discharging,
            now: Date()
        )
        guard case .start(let from) = decision else {
            return XCTFail("expected a new close, got \(decision)")
        }
        XCTAssertEqual(from.flowMode, .charging)
    }

    func testUnplugHoldThenDischargeKeepsTheSameChargingClose() {
        let charging = stub(.charging)
        let startedAt = Date()
        let later = startedAt.addingTimeInterval(0.12)
        let decision = RibbonMorph.decide(
            from: charging,
            startedAt: startedAt,
            duration: 1.65,
            previous: stub(.adapterHold),
            nextMode: .discharging,
            now: later
        )
        XCTAssertEqual(decision, .keepGoing)
    }

    func testUnplugDischargeThenHoldKeepsTheSameChargingClose() {
        let charging = stub(.charging)
        let startedAt = Date()
        let decision = RibbonMorph.decide(
            from: charging,
            startedAt: startedAt,
            duration: 1.65,
            previous: stub(.discharging),
            nextMode: .adapterHold,
            now: startedAt.addingTimeInterval(0.4)
        )
        XCTAssertEqual(decision, .keepGoing)
    }

    func testPluginDuringUnplugReversesElapsedTime() {
        let startedAt = Date()
        let elapsed: TimeInterval = 0.55
        let decision = RibbonMorph.decide(
            from: stub(.charging),
            startedAt: startedAt,
            duration: 1.65,
            previous: stub(.discharging),
            nextMode: .charging,
            now: startedAt.addingTimeInterval(elapsed)
        )
        guard case .reverse(let from, let reversedElapsed) = decision else {
            return XCTFail("expected a reverse, got \(decision)")
        }
        XCTAssertEqual(from.flowMode, .discharging)
        XCTAssertEqual(reversedElapsed, elapsed, accuracy: 0.001)
    }

    func testFinishedMorphStartsFresh() {
        let startedAt = Date()
        let decision = RibbonMorph.decide(
            from: stub(.charging),
            startedAt: startedAt,
            duration: 1.65,
            previous: stub(.discharging),
            nextMode: .charging,
            now: startedAt.addingTimeInterval(2)
        )
        guard case .start(let from) = decision else {
            return XCTFail("expected a fresh morph, got \(decision)")
        }
        XCTAssertEqual(from.flowMode, .discharging)
    }

    private func stub(_ mode: EnergyFlowMode) -> PowerSnapshot {
        var snapshot = PowerSnapshot.empty
        snapshot.hasBattery = true
        snapshot.flowMode = mode
        snapshot.externalConnected = mode != .discharging
        snapshot.isCharging = mode == .charging
        return snapshot
    }
}
