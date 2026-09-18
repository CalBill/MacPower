import XCTest
@testable import MacPower

final class AppVersionTests: XCTestCase {
    func testTagPrefixDoesNotCountAsNewer() {
        XCTAssertFalse(AppVersion.isNewer("v1.2.4", than: "1.2.4"))
        XCTAssertFalse(AppVersion.isNewer("1.2.4", than: "v1.2.4"))
    }

    func testLaterPatchIsNewer() {
        XCTAssertTrue(AppVersion.isNewer("1.2.5", than: "1.2.4"))
        XCTAssertFalse(AppVersion.isNewer("1.2.4", than: "1.2.5"))
    }

    func testNumericComponentsBeatStringOrder() {
        XCTAssertTrue(AppVersion.isNewer("1.10.0", than: "1.9.0"))
        XCTAssertTrue(AppVersion.isNewer("2.0.0", than: "1.9.9"))
    }

    func testMissingPatchTreatsAsZero() {
        XCTAssertFalse(AppVersion.isNewer("1.2", than: "1.2.0"))
        XCTAssertTrue(AppVersion.isNewer("1.2.1", than: "1.2"))
    }
}

final class GitHubLatestReleaseTests: XCTestCase {
    func testDecodesTagAndHTMLURL() throws {
        let json = """
        {"tag_name":"v1.2.5","html_url":"https://github.com/RyanStarFox/MacPower/releases/tag/v1.2.5"}
        """
        let release = try GitHubLatestRelease.decode(Data(json.utf8))
        XCTAssertEqual(release.tagName, "v1.2.5")
        XCTAssertEqual(release.htmlURL.absoluteString, "https://github.com/RyanStarFox/MacPower/releases/tag/v1.2.5")
    }

    func testRejectsMissingURL() {
        let json = """
        {"tag_name":"v1.2.5"}
        """
        XCTAssertThrowsError(try GitHubLatestRelease.decode(Data(json.utf8)))
    }
}

final class UpdateCheckPolicyTests: XCTestCase {
    func testDisabledNeverChecks() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertFalse(UpdateCheckPolicy.shouldCheck(enabled: false, reason: .launch, lastCheck: nil, now: now))
        XCTAssertFalse(UpdateCheckPolicy.shouldCheck(enabled: false, reason: .periodic, lastCheck: nil, now: now))
        XCTAssertFalse(UpdateCheckPolicy.shouldCheck(enabled: false, reason: .userEnabled, lastCheck: nil, now: now))
    }

    func testLaunchAndToggleAlwaysCheckWhenEnabled() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let recent = now.addingTimeInterval(-3_600)
        XCTAssertTrue(UpdateCheckPolicy.shouldCheck(enabled: true, reason: .launch, lastCheck: recent, now: now))
        XCTAssertTrue(UpdateCheckPolicy.shouldCheck(enabled: true, reason: .userEnabled, lastCheck: recent, now: now))
    }

    func testPeriodicSkipsInsideTwentyFourHours() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let recent = now.addingTimeInterval(-3_600)
        XCTAssertFalse(UpdateCheckPolicy.shouldCheck(enabled: true, reason: .periodic, lastCheck: recent, now: now))
        XCTAssertTrue(UpdateCheckPolicy.shouldCheck(enabled: true, reason: .periodic, lastCheck: nil, now: now))
    }

    func testPeriodicChecksAfterTwentyFourHours() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let stale = now.addingTimeInterval(-UpdateCheckPolicy.interval)
        XCTAssertTrue(UpdateCheckPolicy.shouldCheck(enabled: true, reason: .periodic, lastCheck: stale, now: now))
        XCTAssertEqual(UpdateCheckPolicy.interval, 86_400)
    }
}

final class AutoUpdateSettingsTests: XCTestCase {
    func testAutomaticallyCheckForUpdatesDefaultsOnAndPersists() {
        let suite = "MacPower.AutoUpdateTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let first = AppSettings(defaults: defaults)
        XCTAssertTrue(first.automaticallyCheckForUpdates)
        first.automaticallyCheckForUpdates = false
        let second = AppSettings(defaults: defaults)
        XCTAssertFalse(second.automaticallyCheckForUpdates)
        defaults.removePersistentDomain(forName: suite)
    }
}
