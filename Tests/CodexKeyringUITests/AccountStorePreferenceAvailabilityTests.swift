import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStorePreferenceAvailabilityTests: XCTestCase {
    func testPreferenceAvailabilityTracksBusyStateAndCurrentValues() async throws {
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [],
                activeAccountID: nil,
                settings: AppSettings()
            )
        )
        let launchAtLoginController = RecordingLaunchAtLoginController()
        let store = makeStore(
            repository: repository,
            launchAtLoginController: launchAtLoginController
        )

        try await waitForRefreshStarted(repository: repository, store: store)

        XCTAssertFalse(store.canEditPreferences)
        XCTAssertFalse(store.canSetRestartCodexAppAfterSwitch(to: false))
        XCTAssertFalse(store.canSetAllowNetworkQuotaAPIs(to: true))
        XCTAssertFalse(store.canSetQuotaRefreshInterval(to: 5))
        XCTAssertFalse(store.canSetPreserveAgentPreferencesPerAccount(to: false))
        XCTAssertFalse(store.canSetLaunchAtLogin(to: true))

        try await finishPendingRefresh("initial refresh completed", repository: repository, store: store)

        XCTAssertTrue(store.canEditPreferences)
        XCTAssertTrue(store.canSetRestartCodexAppAfterSwitch(to: false))
        XCTAssertFalse(store.canSetRestartCodexAppAfterSwitch(to: true))
        XCTAssertTrue(store.canSetAllowNetworkQuotaAPIs(to: true))
        XCTAssertFalse(store.canEditQuotaRefreshInterval)
        XCTAssertFalse(store.canSetQuotaRefreshInterval(to: 5))
        XCTAssertTrue(store.canSetPreserveAgentPreferencesPerAccount(to: false))
        XCTAssertFalse(store.canSetPreserveAgentPreferencesPerAccount(to: true))
        XCTAssertTrue(store.canSetLaunchAtLogin(to: true))
        XCTAssertFalse(store.canSetLaunchAtLogin(to: false))
    }

    func testPreferenceMutationsAreIgnoredWhileBusyOrUnchanged() async throws {
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [],
                activeAccountID: nil,
                settings: AppSettings()
            )
        )
        let launchAtLoginController = RecordingLaunchAtLoginController()
        let store = makeStore(
            repository: repository,
            launchAtLoginController: launchAtLoginController
        )

        try await waitForRefreshStarted(repository: repository, store: store)

        store.setRestartCodexAppAfterSwitch(false)
        store.setAllowNetworkQuotaAPIs(true)
        store.setQuotaRefreshIntervalMinutes(5)
        store.setPreserveAgentPreferencesPerAccount(false)
        store.setLaunchAtLogin(true)

        XCTAssertEqual(repository.loadCallCount, 1)
        XCTAssertEqual(launchAtLoginController.setEnabledValues, [])

        try await finishPendingRefresh("initial refresh completed", repository: repository, store: store)

        store.setRestartCodexAppAfterSwitch(true)
        store.setAllowNetworkQuotaAPIs(false)
        store.setQuotaRefreshIntervalMinutes(15)
        store.setPreserveAgentPreferencesPerAccount(true)
        store.setLaunchAtLogin(false)

        XCTAssertEqual(repository.loadCallCount, 1)
        XCTAssertEqual(launchAtLoginController.setEnabledValues, [])

        store.setRestartCodexAppAfterSwitch(false)
        try await waitUntil("restart setting update started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("restart setting update completed") {
            !store.isOperationInProgress
        }
        XCTAssertFalse(store.settings.restartCodexAppAfterSwitch)

        store.setLaunchAtLogin(true)
        try await waitUntil("launch setting update started") {
            repository.loadCallCount == 3 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("launch setting update completed") {
            !store.isOperationInProgress
        }

        XCTAssertTrue(store.settings.launchAtLogin)
        XCTAssertEqual(launchAtLoginController.setEnabledValues, [true])
    }
}
