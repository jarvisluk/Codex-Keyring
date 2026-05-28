import XCTest
@testable import CodexKeyringDomain

final class UpdateSettingsUseCaseTests: XCTestCase {
    func testUpdateSettingsPersistsRestartPreference() async throws {
        let repository = settingsRepository(
            AppSettings(
                restartCodexAppAfterSwitch: true,
                launchAtLogin: true,
                allowNetworkQuotaAPIs: true,
                quotaRefreshIntervalMinutes: 30
            )
        )

        let settings = try await UpdateSettingsUseCase(repository: repository)
            .setRestartCodexAppAfterSwitch(false)

        let saved = try await repository.load()
        XCTAssertFalse(settings.restartCodexAppAfterSwitch)
        XCTAssertFalse(saved.settings.restartCodexAppAfterSwitch)
        XCTAssertTrue(saved.settings.launchAtLogin)
        XCTAssertTrue(saved.settings.allowNetworkQuotaAPIs)
        XCTAssertEqual(saved.settings.quotaRefreshIntervalMinutes, 30)
    }

    func testUpdateSettingsSkipsSaveWhenValueIsUnchanged() async throws {
        let repository = settingsRepository(
            AppSettings(
                restartCodexAppAfterSwitch: false,
                launchAtLogin: false,
                allowNetworkQuotaAPIs: true,
                quotaRefreshIntervalMinutes: 15
            )
        )

        let settings = try await UpdateSettingsUseCase(repository: repository)
            .setRestartCodexAppAfterSwitch(false)

        XCTAssertFalse(settings.restartCodexAppAfterSwitch)
        XCTAssertEqual(repository.saveCount, 0)
    }

    func testUpdateSettingsSkipsSaveWhenIntervalNormalizesToCurrentValue() async throws {
        let repository = settingsRepository(AppSettings(quotaRefreshIntervalMinutes: 15))

        let settings = try await UpdateSettingsUseCase(repository: repository)
            .setQuotaRefreshIntervalMinutes(7)

        XCTAssertEqual(settings.quotaRefreshIntervalMinutes, 15)
        XCTAssertEqual(repository.saveCount, 0)
    }
}
