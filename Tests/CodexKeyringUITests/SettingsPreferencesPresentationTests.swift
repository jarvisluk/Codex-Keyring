import XCTest
@testable import CodexKeyringUI

final class SettingsPreferencesPresentationTests: XCTestCase {
    func testSettingsPreferencesPresentationExplainsRestartDependency() {
        let enabled = SettingsPreferencesPresentation(
            restartCodexAppAfterSwitch: true,
            quotaRefreshIntervalMinutes: 15
        )
        let disabled = SettingsPreferencesPresentation(
            restartCodexAppAfterSwitch: false,
            quotaRefreshIntervalMinutes: 30
        )

        XCTAssertTrue(enabled.agentPreferencesNote.contains("restarts Codex App"))
        XCTAssertTrue(disabled.agentPreferencesNote.contains("require Restart Codex App"))
        XCTAssertTrue(enabled.quotaAPI.quotaRefreshNote.contains("15 minutes"))
        XCTAssertTrue(disabled.quotaAPI.quotaRefreshNote.contains("30 minutes"))
    }

    func testSettingsPreferencesPresentationCarriesControlAvailability() {
        let presentation = SettingsPreferencesPresentation(
            restartCodexAppAfterSwitch: true,
            quotaRefreshIntervalMinutes: 15,
            canToggleLaunchAtLogin: true,
            canToggleShowDockIcon: true,
            canToggleRestartCodexAppAfterSwitch: false,
            canTogglePreserveAgentPreferencesPerAccount: true,
            canToggleAllowNetworkQuotaAPIs: false,
            canEditQuotaRefreshInterval: true
        )

        XCTAssertTrue(presentation.canToggleLaunchAtLogin)
        XCTAssertTrue(presentation.canToggleShowDockIcon)
        XCTAssertFalse(presentation.canToggleRestartCodexAppAfterSwitch)
        XCTAssertTrue(presentation.canTogglePreserveAgentPreferencesPerAccount)
        XCTAssertFalse(presentation.quotaAPI.canToggleAllowNetworkQuotaAPIs)
        XCTAssertTrue(presentation.quotaAPI.canEditQuotaRefreshInterval)
        XCTAssertEqual(
            presentation.quotaAPI.intervalOptions,
            [
                SettingsQuotaRefreshIntervalOption(minutes: 5),
                SettingsQuotaRefreshIntervalOption(minutes: 15),
                SettingsQuotaRefreshIntervalOption(minutes: 30)
            ]
        )
    }
}
