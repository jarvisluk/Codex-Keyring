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

    func testAppSettingsDefaultsMissingDockIconToShown() throws {
        let decoded = try decodeSettings("{}")

        XCTAssertTrue(decoded.showDockIcon)
    }

    func testAppSettingsHonoursExplicitlyHiddenDockIcon() throws {
        let decoded = try decodeSettings("""
        {
          "showDockIcon": false
        }
        """)

        XCTAssertFalse(decoded.showDockIcon)
    }

    func testAppSettingsDefaultsRestartCodexAppOn() {
        let defaults = AppSettings()
        XCTAssertTrue(defaults.restartCodexAppAfterSwitch)
        XCTAssertEqual(defaults.defaultsVersion, AppSettings.currentDefaultsVersion)
    }

    func testAppSettingsDefaultsPreserveAgentPreferencesOn() {
        let defaults = AppSettings()
        XCTAssertTrue(defaults.preserveAgentPreferencesPerAccount)
    }

    func testAppSettingsDefaultsDockIconShown() {
        let defaults = AppSettings()
        XCTAssertTrue(defaults.showDockIcon)
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
        XCTAssertEqual(decoded.defaultsVersion, 0)
    }

    func testAppSettingsRespectsExplicitRestartFalse() throws {
        let decoded = try decodeSettings("""
        {
          "restartCodexAppAfterSwitch": false
        }
        """)
        XCTAssertFalse(decoded.restartCodexAppAfterSwitch)
    }

    func testAppSettingsMigratesLegacyDefaultsToRestartOn() throws {
        let legacy = try decodeSettings("""
        {
          "restartCodexAppAfterSwitch": false
        }
        """)

        let migration = legacy.migratedToCurrentDefaults()

        XCTAssertTrue(migration.didMigrate)
        XCTAssertTrue(migration.settings.restartCodexAppAfterSwitch)
        XCTAssertEqual(migration.settings.defaultsVersion, AppSettings.currentDefaultsVersion)
    }

    func testAppSettingsKeepsExplicitCurrentRestartOff() {
        let current = AppSettings(restartCodexAppAfterSwitch: false)

        let migration = current.migratedToCurrentDefaults()

        XCTAssertFalse(migration.didMigrate)
        XCTAssertFalse(migration.settings.restartCodexAppAfterSwitch)
    }
}
