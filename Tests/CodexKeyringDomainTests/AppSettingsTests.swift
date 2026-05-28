import XCTest
@testable import CodexKeyringDomain

final class AppSettingsTests: XCTestCase {
    func testAppSettingsDecodesLegacyManifestWithoutPreserveAgentPrefs() throws {
        let decoded = try decodeSettings("""
        {
          "restartCodexAppAfterSwitch": true,
          "launchAtLogin": false,
          "allowNetworkQuotaAPIs": false
        }
        """)
        XCTAssertTrue(decoded.restartCodexAppAfterSwitch)
        // Legacy manifests inherit the new default-on behavior.
        XCTAssertTrue(decoded.preserveAgentPreferencesPerAccount)
    }

    func testAppSettingsHonoursExplicitlyDisabledPreserveAgentPrefs() throws {
        let decoded = try decodeSettings("""
        {
          "restartCodexAppAfterSwitch": true,
          "launchAtLogin": false,
          "allowNetworkQuotaAPIs": false,
          "preserveAgentPreferencesPerAccount": false
        }
        """)
        XCTAssertFalse(decoded.preserveAgentPreferencesPerAccount)
    }

    func testAppSettingsDefaultsRestartCodexAppOn() {
        let defaults = AppSettings()
        XCTAssertTrue(defaults.restartCodexAppAfterSwitch)
    }

    func testAppSettingsDefaultsPreserveAgentPreferencesOn() {
        let defaults = AppSettings()
        XCTAssertTrue(defaults.preserveAgentPreferencesPerAccount)
    }

    func testAppSettingsDefaultsQuotaRefreshInterval() {
        let defaults = AppSettings()
        XCTAssertEqual(defaults.quotaRefreshIntervalMinutes, 15)
    }

    func testAppSettingsDeclaresQuotaRefreshIntervalOptions() {
        XCTAssertEqual(AppSettings.quotaRefreshIntervalOptions, [5, 15, 30])
    }

    func testAppSettingsNormalizesQuotaRefreshInterval() throws {
        let decoded = try decodeSettings("""
        {
          "allowNetworkQuotaAPIs": true,
          "quotaRefreshIntervalMinutes": 7
        }
        """)
        XCTAssertEqual(decoded.quotaRefreshIntervalMinutes, 15)
    }

    func testAppSettingsDecodesMissingRestartAsTrue() throws {
        let decoded = try decodeSettings("{}")
        XCTAssertTrue(decoded.restartCodexAppAfterSwitch)
    }

    func testAppSettingsRespectsExplicitRestartFalse() throws {
        let decoded = try decodeSettings("""
        {
          "restartCodexAppAfterSwitch": false
        }
        """)
        XCTAssertFalse(decoded.restartCodexAppAfterSwitch)
    }
}
