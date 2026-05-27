import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreTests: XCTestCase {
    func testOperationBusyStateCoversSettingUpdates() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1
                && store.isRefreshInProgress
                && store.isOperationInProgress
        }

        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        store.setRestartCodexAppAfterSwitch(false)
        try await waitUntil("setting update started") {
            repository.loadCallCount == 2
                && store.isOperationInProgress
        }

        repository.resumeNextLoad()
        try await waitUntil("setting update finished") {
            !store.isOperationInProgress
        }

        XCTAssertFalse(store.settings.restartCodexAppAfterSwitch)
        XCTAssertEqual(store.statusMessage, "Codex App restart after switching disabled.")
    }

    func testStartupErrorSurvivesSuccessfulInitialRefresh() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let startupError = CodexKeyringError.fileSystemFailure(
            reason: "Could not prepare Codex Keyring storage directories: permission denied"
        )
        let store = makeStore(repository: repository, startupError: startupError)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }

        XCTAssertEqual(store.lastError, startupError.localizedDescription)
        XCTAssertEqual(store.statusMessage, startupError.localizedDescription)

        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        XCTAssertEqual(store.lastError, startupError.localizedDescription)
        XCTAssertEqual(store.statusMessage, startupError.localizedDescription)
    }

    func testLiveAuthChangesCoalesceWhileSyncIsPending() async throws {
        let metadata = AuthMetadata(
            email: "person@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "fingerprint",
            tokenExpiresAt: nil
        )
        let account = CodexAccount(
            id: UUID(),
            alias: "person",
            email: metadata.email,
            plan: metadata.plan,
            authMode: metadata.authMode,
            accountIdentifier: metadata.accountIdentifier,
            snapshotFileName: "person.auth.json",
            fingerprint: metadata.fingerprint,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            tokenExpiresAt: nil
        )
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [account],
                activeAccountID: account.id,
                settings: AppSettings()
            )
        )
        let watcher = ManualLiveAuthWatcher()
        let store = makeStore(
            repository: repository,
            authReader: StaticAuthReader(metadata: metadata),
            liveAuthWatcher: watcher
        )

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            repository.loadCallCount == 1 && !store.isOperationInProgress
        }

        watcher.trigger()
        try await waitUntil("first live auth sync started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }

        watcher.trigger()
        watcher.trigger()
        repository.resumeNextLoad()
        try await waitUntil("coalesced follow-up sync started") {
            repository.loadCallCount == 3 && store.isOperationInProgress
        }

        repository.resumeNextLoad()
        try await waitUntil("coalesced live auth sync completed") {
            !store.isOperationInProgress
        }

        XCTAssertEqual(repository.loadCallCount, 3)
    }

    func testAddCurrentAccountSkipsWhenCurrentAuthIsUnreadable() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }

        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        store.addCurrentAccount(alias: nil)

        XCTAssertEqual(store.statusMessage, "No readable Codex auth.json to save.")
        XCTAssertEqual(repository.loadCallCount, 1)
        XCTAssertFalse(store.isOperationInProgress)
    }

    func testAddCurrentAccountShowsWarningWhenAgentPreferencesCannotBeSaved() async throws {
        let metadata = AuthMetadata(
            email: "new@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "new-account",
            fingerprint: "new-fingerprint",
            tokenExpiresAt: nil
        )
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [],
                activeAccountID: nil,
                settings: AppSettings(preserveAgentPreferencesPerAccount: true)
            )
        )
        let store = makeStore(
            repository: repository,
            authReader: StaticAuthReader(metadata: metadata),
            agentPreferencesPort: ThrowingAgentPreferencesPort(
                error: CodexKeyringError.fileSystemFailure(reason: "permission denied")
            )
        )

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        store.addCurrentAccount(alias: "new")
        try await waitUntil("add current auth started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("add current auth completed") {
            !store.isOperationInProgress
        }

        XCTAssertNil(store.lastError)
        XCTAssertEqual(store.accounts.first?.alias, "new")
        XCTAssertTrue(store.statusMessage.contains("Saved current Codex auth as new."))
        XCTAssertTrue(store.statusMessage.contains("Agent settings were not saved for this account"))
        XCTAssertTrue(store.statusMessage.contains("permission denied"))
    }

    func testSuccessfulRetryClearsPreviousError() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }

        repository.resumeNextLoad(throwing: CodexKeyringError.fileSystemFailure(reason: "disk full"))
        try await waitUntil("initial refresh failed") {
            store.lastError == "Local storage operation failed: disk full"
                && !store.isOperationInProgress
        }

        store.refresh()
        try await waitUntil("retry refresh started") {
            repository.loadCallCount == 2 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("retry refresh completed") {
            !store.isOperationInProgress
        }

        XCTAssertNil(store.lastError)
        XCTAssertEqual(store.statusMessage, "Refreshed accounts.")
    }

    func testReportedUserFacingErrorSetsStatusAndClearsOnSuccessfulRetry() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        store.reportUserFacingError(CodexKeyringError.fileSystemFailure(reason: "Could not open folder"))

        XCTAssertEqual(store.lastError, "Local storage operation failed: Could not open folder")
        XCTAssertEqual(store.statusMessage, "Local storage operation failed: Could not open folder")

        store.refresh()
        try await waitUntil("retry refresh started") {
            repository.loadCallCount == 2 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("retry refresh completed") {
            !store.isOperationInProgress
        }

        XCTAssertNil(store.lastError)
        XCTAssertEqual(store.statusMessage, "Refreshed accounts.")
    }

    func testClearErrorResetsMatchingStatusMessage() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        store.reportUserFacingError(CodexKeyringError.fileSystemFailure(reason: "Could not open folder"))
        store.clearError()

        XCTAssertNil(store.lastError)
        XCTAssertEqual(store.statusMessage, "Ready.")
    }

    func testClearErrorPreservesDifferentStatusMessage() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad(throwing: CodexKeyringError.fileSystemFailure(reason: "disk full"))
        try await waitUntil("initial refresh failed") {
            store.lastError == "Local storage operation failed: disk full"
                && !store.isOperationInProgress
        }

        store.statusMessage = "Retry queued."
        store.clearError()

        XCTAssertNil(store.lastError)
        XCTAssertEqual(store.statusMessage, "Retry queued.")
    }

    func testLiveAuthWatcherDoesNotClearExistingUserError() async throws {
        let metadata = AuthMetadata(
            email: "person@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "fingerprint",
            tokenExpiresAt: nil
        )
        let repository = BlockingAccountRepository(manifest: .empty)
        let watcher = ManualLiveAuthWatcher()
        let store = makeStore(
            repository: repository,
            authReader: StaticAuthReader(metadata: metadata),
            liveAuthWatcher: watcher
        )

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad(throwing: CodexKeyringError.fileSystemFailure(reason: "disk full"))
        try await waitUntil("initial refresh failed") {
            store.lastError == "Local storage operation failed: disk full"
                && !store.isOperationInProgress
        }

        watcher.trigger()
        try await waitUntil("watcher sync started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("watcher sync completed") {
            !store.isOperationInProgress
        }

        XCTAssertEqual(store.lastError, "Local storage operation failed: disk full")
    }

    func testSuccessfulLogExportClearsPreviousError() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let logService = RecordingLogService()
        let store = makeStore(repository: repository, logService: logService)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad(throwing: CodexKeyringError.fileSystemFailure(reason: "disk full"))
        try await waitUntil("initial refresh failed") {
            store.lastError == "Local storage operation failed: disk full"
                && !store.isOperationInProgress
        }

        let destination = URL(fileURLWithPath: "/tmp/codex-keyring-export.log.txt")
        store.exportLogs(to: destination)

        try await waitUntil("log export completed") {
            store.statusMessage == "Logs exported to \(destination.path)."
        }

        XCTAssertNil(store.lastError)
        XCTAssertEqual(logService.exportedURLs, [destination])
    }

    func testLogExportShowsBusyStateAndIgnoresDuplicateRequests() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let logService = BlockingLogService()
        let store = makeStore(repository: repository, logService: logService)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }
        XCTAssertTrue(store.canExportLogs)

        let firstDestination = URL(fileURLWithPath: "/tmp/codex-keyring-first.log.txt")
        let secondDestination = URL(fileURLWithPath: "/tmp/codex-keyring-second.log.txt")
        store.exportLogs(to: firstDestination)

        try await waitUntil("log export started") {
            logService.exportStartedCount == 1
                && store.isLogExportInProgress
        }
        XCTAssertFalse(store.canExportLogs)
        XCTAssertTrue(store.isStatusBusy)
        XCTAssertFalse(store.isOperationInProgress)

        store.exportLogs(to: secondDestination)

        XCTAssertEqual(logService.exportStartedCount, 1)
        XCTAssertEqual(logService.exportedURLs, [firstDestination])

        logService.resumeExport()
        try await waitUntil("log export completed") {
            !store.isLogExportInProgress
                && store.statusMessage == "Logs exported to \(firstDestination.path)."
        }
        XCTAssertFalse(store.isOperationInProgress)
        XCTAssertFalse(store.isStatusBusy)
        XCTAssertTrue(store.canExportLogs)

        XCTAssertEqual(logService.exportedURLs, [firstDestination])
    }

    func testFailedLogExportRestoresAvailabilityAndShowsError() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let logService = FailingLogService(
            error: CodexKeyringError.fileSystemFailure(reason: "permission denied")
        )
        let store = makeStore(repository: repository, logService: logService)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        let destination = URL(fileURLWithPath: "/tmp/codex-keyring-denied.log.txt")
        store.exportLogs(to: destination)

        try await waitUntil("log export failed") {
            !store.isLogExportInProgress
                && store.lastError == "Local storage operation failed: permission denied"
        }

        XCTAssertEqual(store.statusMessage, "Local storage operation failed: permission denied")
        XCTAssertFalse(store.isStatusBusy)
        XCTAssertTrue(store.canExportLogs)
        XCTAssertEqual(logService.exportedURLs, [destination])
    }

    func testActionAvailabilityTracksAccountsAndBusyState() async throws {
        let accountID = UUID()
        let account = makeAccount(id: accountID)
        let enabledSettings = AppSettings(allowNetworkQuotaAPIs: true)
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [],
                activeAccountID: nil,
                settings: enabledSettings
            ),
            snapshotExists: true
        )
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        XCTAssertFalse(store.canLoginNewAccount)
        XCTAssertFalse(store.canImportAccount)
        XCTAssertFalse(store.canRefreshAccounts)
        XCTAssertFalse(store.canRefreshQuotas)
        XCTAssertTrue(store.isStatusBusy)

        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed without accounts") {
            !store.isOperationInProgress
        }

        XCTAssertTrue(store.canLoginNewAccount)
        XCTAssertTrue(store.canImportAccount)
        XCTAssertTrue(store.canRefreshAccounts)
        XCTAssertFalse(store.canRefreshQuotas)
        XCTAssertFalse(store.isStatusBusy)

        store.refresh()
        try await waitUntil("refresh with first account started") {
            repository.loadCallCount == 2 && store.isRefreshInProgress
        }
        XCTAssertFalse(store.canLoginNewAccount)
        XCTAssertFalse(store.canImportAccount)
        XCTAssertFalse(store.canRefreshAccounts)
        XCTAssertFalse(store.canRefreshQuotas)
        let manifestWithAccount = AccountManifest(
            accounts: [account],
            activeAccountID: account.id,
            settings: enabledSettings
        )
        repository.resumeNextLoad(returning: manifestWithAccount)

        try await waitUntil("automatic quota refresh started") {
            repository.loadCallCount == 3 && store.isQuotaRefreshInProgress
        }
        XCTAssertFalse(store.canLoginNewAccount)
        XCTAssertFalse(store.canImportAccount)
        XCTAssertFalse(store.canRefreshAccounts)
        XCTAssertFalse(store.canRefreshQuotas)
        XCTAssertFalse(store.canSwitch(to: account))
        XCTAssertFalse(store.canRemove(account))
        XCTAssertFalse(store.canBeginRename(account))
        XCTAssertFalse(store.canRename(account, to: "renamed"))
        XCTAssertTrue(store.isStatusBusy)

        repository.resumeNextLoad(returning: manifestWithAccount)
        try await waitUntil("automatic quota refresh completed") {
            store.canRefreshQuotas && !store.isStatusBusy
        }

        XCTAssertEqual(store.accounts.map(\.id), [accountID])
        XCTAssertTrue(store.canRefreshAccounts)
        XCTAssertTrue(store.canSwitch(to: account))
        XCTAssertTrue(store.canRemove(account))
        XCTAssertTrue(store.canBeginRename(account))
        XCTAssertTrue(store.canRename(account, to: "renamed"))
    }

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

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isOperationInProgress
        }

        XCTAssertFalse(store.canEditPreferences)
        XCTAssertFalse(store.canSetRestartCodexAppAfterSwitch(to: false))
        XCTAssertFalse(store.canSetAllowNetworkQuotaAPIs(to: true))
        XCTAssertFalse(store.canSetQuotaRefreshInterval(to: 5))
        XCTAssertFalse(store.canSetPreserveAgentPreferencesPerAccount(to: false))
        XCTAssertFalse(store.canSetLaunchAtLogin(to: true))

        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

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

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isOperationInProgress
        }

        store.setRestartCodexAppAfterSwitch(false)
        store.setAllowNetworkQuotaAPIs(true)
        store.setQuotaRefreshIntervalMinutes(5)
        store.setPreserveAgentPreferencesPerAccount(false)
        store.setLaunchAtLogin(true)

        XCTAssertEqual(repository.loadCallCount, 1)
        XCTAssertEqual(launchAtLoginController.setEnabledValues, [])

        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

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

    func testLoginBusyStateBlocksOtherAccountActions() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let loginService = BlockingLoginService()
        let store = makeStore(
            repository: repository,
            loginService: loginService
        )

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        store.loginNewCodexAccount()
        try await waitUntil("login flow started") {
            loginService.startedCount == 1
                && store.isLoginInProgress
                && store.isOperationInProgress
        }

        XCTAssertFalse(store.canLoginNewAccount)
        XCTAssertFalse(store.canImportAccount)
        XCTAssertFalse(store.canRefreshAccounts)
        XCTAssertFalse(store.canRefreshQuotas)
        XCTAssertFalse(store.canAddCurrentLogin)
        XCTAssertTrue(store.isStatusBusy)

        store.refresh()
        store.importAccount(from: URL(fileURLWithPath: "/tmp/imported-auth.json"))
        XCTAssertEqual(repository.loadCallCount, 1)

        loginService.fail(with: CodexKeyringError.codexLoginFailed(reason: "cancelled"))
        try await waitUntil("login flow failed") {
            !store.isLoginInProgress
                && !store.isOperationInProgress
                && store.lastError == "Codex login failed: cancelled"
        }

        XCTAssertTrue(store.canLoginNewAccount)
        XCTAssertTrue(store.canImportAccount)
        XCTAssertTrue(store.canRefreshAccounts)
        XCTAssertFalse(store.canRefreshQuotas)
    }

    func testLoginSuccessShowsTemporaryCleanupWarning() async throws {
        let oldMetadata = AuthMetadata(
            email: "old@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "old",
            fingerprint: "old",
            tokenExpiresAt: nil
        )
        let newMetadata = AuthMetadata(
            email: "new@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "new",
            fingerprint: "new",
            tokenExpiresAt: nil
        )
        let liveURL = URL(fileURLWithPath: "/tmp/auth.json")
        let preLoginURL = URL(fileURLWithPath: "/tmp/pre-login.json")
        let newLoginURL = URL(fileURLWithPath: "/tmp/new-login.json")
        let repository = BlockingAccountRepository(manifest: .empty)
        let installer = StagedLoginInstaller(
            liveAuthFileURL: liveURL,
            preLoginURL: preLoginURL,
            newLoginURL: newLoginURL,
            cleanupError: CodexKeyringError.fileSystemFailure(reason: "cleanup denied")
        )
        let store = makeStore(
            repository: repository,
            authReader: MappedAuthReader([
                liveURL: oldMetadata,
                newLoginURL: newMetadata
            ]),
            loginService: NoopLoginService(),
            installer: installer
        )

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        store.loginNewCodexAccount()
        try await waitUntil("login add account load started") {
            repository.loadCallCount == 2 && store.isLoginInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("login refresh state load started") {
            repository.loadCallCount == 3 && store.isLoginInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("login completed") {
            !store.isOperationInProgress
        }

        XCTAssertNil(store.lastError)
        XCTAssertEqual(store.accounts.map(\.alias), ["new"])
        XCTAssertTrue(store.statusMessage.contains("Saved new Codex login as new."))
        XCTAssertTrue(store.statusMessage.contains("Temporary login files could not be cleaned up"))
        XCTAssertTrue(store.statusMessage.contains("/tmp/pre-login.json"))
        XCTAssertTrue(store.statusMessage.contains("/tmp/new-login.json"))
        XCTAssertTrue(store.statusMessage.contains("cleanup denied"))
    }

    func testDirectAccountMutationsAreIgnoredWhileBusy() async throws {
        let account = makeAccount(id: UUID())
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [account],
                activeAccountID: account.id,
                settings: AppSettings(allowNetworkQuotaAPIs: true)
            ),
            snapshotExists: true
        )
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }

        store.switchTo(account, restartCodexApp: true)
        store.rename(account, to: "renamed")
        store.remove(account)

        XCTAssertEqual(repository.loadCallCount, 1)
        XCTAssertFalse(store.canSwitch(to: account))
        XCTAssertFalse(store.canBeginRename(account))
        XCTAssertFalse(store.canRename(account, to: "renamed"))
        XCTAssertFalse(store.canRemove(account))

        repository.resumeNextLoad()
        try await waitUntil("automatic quota refresh started") {
            repository.loadCallCount == 2 && store.isQuotaRefreshInProgress
        }

        store.switchTo(account, restartCodexApp: true)
        store.rename(account, to: "renamed")
        store.remove(account)

        XCTAssertEqual(repository.loadCallCount, 2)

        repository.resumeNextLoad()
        try await waitUntil("quota refresh completed") {
            !store.isStatusBusy
        }

        XCTAssertTrue(store.canSwitch(to: account))
        XCTAssertTrue(store.canBeginRename(account))
        XCTAssertTrue(store.canRename(account, to: "renamed"))
        XCTAssertTrue(store.canRemove(account))
    }

    func testSwitchAppliesStateAndWarningWhenRestartFails() async throws {
        let old = makeAccount(id: UUID(), alias: "old")
        let new = makeAccount(id: UUID(), alias: "new")
        let oldMetadata = AuthMetadata(
            email: old.email,
            plan: old.plan,
            authMode: old.authMode,
            accountIdentifier: old.accountIdentifier,
            fingerprint: old.fingerprint,
            tokenExpiresAt: old.tokenExpiresAt
        )
        let newMetadata = AuthMetadata(
            email: new.email,
            plan: new.plan,
            authMode: new.authMode,
            accountIdentifier: new.accountIdentifier,
            fingerprint: new.fingerprint,
            tokenExpiresAt: new.tokenExpiresAt
        )
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [old, new],
                activeAccountID: old.id,
                settings: AppSettings(restartCodexAppAfterSwitch: true)
            ),
            snapshotExists: true
        )
        let installer = NoopInstaller()
        let store = makeStore(
            repository: repository,
            authReader: MappedAuthReader([
                installer.liveAuthFileURL: oldMetadata,
                repository.snapshotURL(named: new.snapshotFileName): newMetadata
            ]),
            installer: installer,
            appController: FailingRestartAppController(reason: "launch denied")
        )

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        store.switchTo(new, restartCodexApp: true)
        try await waitUntil("switch started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("switch completed") {
            !store.isOperationInProgress
        }

        XCTAssertEqual(store.activeAccountID, new.id)
        XCTAssertNil(store.lastError)
        XCTAssertEqual(
            store.statusMessage,
            "Switched Codex CLI auth to new, but Codex App could not be restarted: launch denied"
        )
    }

    func testSwitchShowsWarningWhenOutgoingAgentPreferencesCannotBeSaved() async throws {
        let old = makeAccount(id: UUID(), alias: "old")
        let new = makeAccount(id: UUID(), alias: "new")
        let oldMetadata = AuthMetadata(
            email: old.email,
            plan: old.plan,
            authMode: old.authMode,
            accountIdentifier: old.accountIdentifier,
            fingerprint: old.fingerprint,
            tokenExpiresAt: old.tokenExpiresAt
        )
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [old, new],
                activeAccountID: old.id,
                settings: AppSettings(
                    restartCodexAppAfterSwitch: true,
                    preserveAgentPreferencesPerAccount: true
                )
            ),
            snapshotExists: true
        )
        let store = makeStore(
            repository: repository,
            authReader: StaticAuthReader(metadata: oldMetadata),
            appController: RelaunchingAppController(),
            agentPreferencesPort: ThrowingAgentPreferencesPort(
                error: CodexKeyringError.fileSystemFailure(reason: "permission denied")
            )
        )

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        store.switchTo(new, restartCodexApp: true)
        try await waitUntil("switch started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("switch completed") {
            !store.isOperationInProgress
        }

        XCTAssertEqual(store.activeAccountID, new.id)
        XCTAssertNil(store.lastError)
        XCTAssertTrue(store.statusMessage.contains("Codex App was restarted"))
        XCTAssertTrue(store.statusMessage.contains("Agent settings could not be fully updated"))
        XCTAssertTrue(store.statusMessage.contains("permission denied"))
    }

    func testSwitchShowsWarningWhenIncomingAgentPreferencesCannotBeApplied() async throws {
        let old = makeAccount(id: UUID(), alias: "old")
        var new = makeAccount(id: UUID(), alias: "new")
        new.agentPreferences = AccountAgentPreferences(model: "gpt-5.5")
        let oldMetadata = AuthMetadata(
            email: old.email,
            plan: old.plan,
            authMode: old.authMode,
            accountIdentifier: old.accountIdentifier,
            fingerprint: old.fingerprint,
            tokenExpiresAt: old.tokenExpiresAt
        )
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [old, new],
                activeAccountID: old.id,
                settings: AppSettings(
                    restartCodexAppAfterSwitch: true,
                    preserveAgentPreferencesPerAccount: true
                )
            ),
            snapshotExists: true
        )
        let store = makeStore(
            repository: repository,
            authReader: StaticAuthReader(metadata: oldMetadata),
            appController: RelaunchingAppController(),
            agentPreferencesPort: ApplyThrowingAgentPreferencesPort(
                error: CodexKeyringError.fileSystemFailure(reason: "config denied")
            )
        )

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        store.switchTo(new, restartCodexApp: true)
        try await waitUntil("switch started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("switch completed") {
            !store.isOperationInProgress
        }

        XCTAssertEqual(store.activeAccountID, new.id)
        XCTAssertNil(store.lastError)
        XCTAssertTrue(store.statusMessage.contains("Codex App was restarted"))
        XCTAssertTrue(store.statusMessage.contains("Agent settings could not be fully updated"))
        XCTAssertTrue(store.statusMessage.contains("config denied"))
    }

    func testSwitchShowsWarningWhenProjectArrangementCannotBePreserved() async throws {
        let old = makeAccount(id: UUID(), alias: "old")
        let new = makeAccount(id: UUID(), alias: "new")
        let oldMetadata = AuthMetadata(
            email: old.email,
            plan: old.plan,
            authMode: old.authMode,
            accountIdentifier: old.accountIdentifier,
            fingerprint: old.fingerprint,
            tokenExpiresAt: old.tokenExpiresAt
        )
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [old, new],
                activeAccountID: old.id,
                settings: AppSettings(restartCodexAppAfterSwitch: true)
            ),
            snapshotExists: true
        )
        let store = makeStore(
            repository: repository,
            authReader: StaticAuthReader(metadata: oldMetadata),
            appController: RelaunchingAppController(),
            agentPreferencesPort: ProjectArrangementThrowingAgentPreferencesPort(
                error: CodexKeyringError.fileSystemFailure(reason: "global state denied")
            )
        )

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        store.switchTo(new, restartCodexApp: true)
        try await waitUntil("switch started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("switch completed") {
            !store.isOperationInProgress
        }

        XCTAssertEqual(store.activeAccountID, new.id)
        XCTAssertNil(store.lastError)
        XCTAssertTrue(store.statusMessage.contains("Codex App was restarted"))
        XCTAssertTrue(store.statusMessage.contains("Codex project list layout could not be preserved"))
        XCTAssertTrue(store.statusMessage.contains("global state denied"))
    }

    func testImportReleasesAccessScopeImmediatelyWhenBusy() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let scope = RecordingURLAccessScope()
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isOperationInProgress
        }

        store.importAccount(
            from: URL(fileURLWithPath: "/tmp/imported-auth.json"),
            accessScope: scope.makeScope()
        )

        XCTAssertEqual(scope.stopCount, 1)
        XCTAssertEqual(repository.loadCallCount, 1)
    }

    func testImportKeepsAccessScopeUntilAsyncOperationFinishes() async throws {
        let repository = BlockingAccountRepository(manifest: .empty)
        let scope = RecordingURLAccessScope()
        let metadata = AuthMetadata(
            email: "imported@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "imported-account",
            fingerprint: "imported-fingerprint",
            tokenExpiresAt: nil
        )
        let store = makeStore(
            repository: repository,
            authReader: StaticAuthReader(metadata: metadata)
        )

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        store.importAccount(
            from: URL(fileURLWithPath: "/tmp/imported-auth.json"),
            accessScope: scope.makeScope()
        )
        try await waitUntil("import load started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }

        XCTAssertEqual(scope.stopCount, 0)

        repository.resumeNextLoad()
        try await waitUntil("import completed") {
            !store.isOperationInProgress
        }

        XCTAssertEqual(scope.stopCount, 1)
        XCTAssertEqual(store.accounts.map(\.email), ["imported@example.com"])
    }

    func testImportAccountDoesNotMarkImportedSnapshotActive() async throws {
        let active = makeAccount(id: UUID(), alias: "current")
        let liveMetadata = AuthMetadata(
            email: active.email,
            plan: active.plan,
            authMode: active.authMode,
            accountIdentifier: active.accountIdentifier,
            fingerprint: active.fingerprint,
            tokenExpiresAt: active.tokenExpiresAt
        )
        let importedMetadata = AuthMetadata(
            email: "imported@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "imported-account",
            fingerprint: "imported-fingerprint",
            tokenExpiresAt: nil
        )
        let importURL = URL(fileURLWithPath: "/tmp/imported-auth.json")
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [active],
                activeAccountID: active.id,
                settings: AppSettings()
            )
        )
        let store = makeStore(
            repository: repository,
            authReader: MappedAuthReader([
                URL(fileURLWithPath: "/tmp/auth.json"): liveMetadata,
                importURL: importedMetadata
            ])
        )

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        store.importAccount(from: importURL)
        try await waitUntil("import load started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("import completed") {
            !store.isOperationInProgress
        }

        XCTAssertEqual(store.accounts.map(\.email).sorted(), ["current@example.com", "imported@example.com"])
        XCTAssertEqual(store.activeAccountID, active.id)
        XCTAssertEqual(store.activeAccount?.id, active.id)
        XCTAssertEqual(store.currentAuthMetadata?.fingerprint, active.fingerprint)
        XCTAssertEqual(
            store.statusMessage,
            "Imported account imported. Current Codex auth was not switched."
        )
    }

    func testRefreshPrunesQuotaStatesForRemovedAccounts() async throws {
        let accountID = UUID()
        let account = makeAccount(id: accountID)
        let enabledSettings = AppSettings(allowNetworkQuotaAPIs: true)
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [account],
                activeAccountID: account.id,
                settings: enabledSettings
            ),
            snapshotExists: true
        )
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()

        try await waitUntil("automatic quota refresh started") {
            repository.loadCallCount == 2 && store.isQuotaRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("automatic quota refresh completed") {
            store.quotaStates[accountID] != nil && !store.isOperationInProgress
        }

        store.refresh()
        try await waitUntil("refresh after account removal started") {
            repository.loadCallCount == 3 && store.isRefreshInProgress
        }
        repository.resumeNextLoad(returning: AccountManifest(
            accounts: [],
            activeAccountID: nil,
            settings: enabledSettings
        ))
        try await waitUntil("refresh after account removal completed") {
            !store.isOperationInProgress
        }

        XCTAssertTrue(store.accounts.isEmpty)
        XCTAssertTrue(store.quotaStates.isEmpty)
    }

    func testRenameCanClearAliasAndFallsBackToEmail() async throws {
        let accountID = UUID()
        let account = makeAccount(
            id: accountID,
            alias: "nickname",
            email: "person@example.com"
        )
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [account],
                activeAccountID: accountID,
                settings: AppSettings()
            )
        )
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        XCTAssertTrue(store.canRename(account, to: "  "))

        store.rename(account, to: "  ")
        try await waitUntil("rename started") {
            repository.loadCallCount == 2 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("rename completed") {
            store.accounts.first?.alias == "" && !store.isOperationInProgress
        }

        XCTAssertEqual(store.accounts.first?.displayName, "person@example.com")
        XCTAssertEqual(store.statusMessage, "Cleared alias. Account will show as person@example.com.")
    }

    func testRefreshQuotasSkipsWhenNoAccountsAreSaved() async throws {
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [],
                activeAccountID: nil,
                settings: AppSettings(allowNetworkQuotaAPIs: true)
            )
        )
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed") {
            !store.isOperationInProgress
        }

        store.refreshQuotasNow()

        XCTAssertEqual(store.statusMessage, "No saved accounts to refresh quotas for.")
        XCTAssertEqual(repository.loadCallCount, 1)
        XCTAssertTrue(store.quotaStates.isEmpty)
        XCTAssertFalse(store.isQuotaRefreshInProgress)
        XCTAssertFalse(store.isOperationInProgress)
    }

    func testRefreshQuotasSkipsWhenNetworkAPIsAreDisabled() async throws {
        let accountID = UUID()
        let account = makeAccount(id: accountID)
        let enabledSettings = AppSettings(allowNetworkQuotaAPIs: true)
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [account],
                activeAccountID: account.id,
                settings: enabledSettings
            ),
            snapshotExists: true
        )
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()

        try await waitUntil("automatic quota refresh started") {
            repository.loadCallCount == 2 && store.isQuotaRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("automatic quota refresh completed") {
            store.quotaStates[accountID] != nil && !store.isOperationInProgress
        }

        store.lastError = "Previous export failed."
        store.setAllowNetworkQuotaAPIs(false)

        try await waitUntil("network quota setting update started") {
            repository.loadCallCount == 3 && store.isOperationInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("network quota setting update completed") {
            !store.isOperationInProgress
        }

        XCTAssertNil(store.lastError)
        XCTAssertTrue(store.quotaStates.isEmpty)
        XCTAssertEqual(store.statusMessage, "Network quota API calls disabled.")

        store.lastError = "Stale failure."
        store.refreshQuotasNow()

        XCTAssertNil(store.lastError)
        XCTAssertTrue(store.quotaStates.isEmpty)
        XCTAssertEqual(store.statusMessage, "Network quota API calls are disabled.")
        XCTAssertEqual(repository.loadCallCount, 3)
        XCTAssertFalse(store.isQuotaRefreshInProgress)
        XCTAssertFalse(store.isOperationInProgress)
    }

    func testQuotaRefreshExplainsWhenOnlyAPIKeyAccountsAreSaved() async throws {
        let accountID = UUID()
        var account = makeAccount(id: accountID)
        account.plan = "API key"
        account.authMode = "api-key"
        let enabledSettings = AppSettings(allowNetworkQuotaAPIs: true)
        let manifest = AccountManifest(
            accounts: [account],
            activeAccountID: account.id,
            settings: enabledSettings
        )
        let repository = BlockingAccountRepository(
            manifest: manifest,
            snapshotExists: true
        )
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()

        try await waitUntil("automatic quota refresh started") {
            repository.loadCallCount == 2 && store.isQuotaRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("automatic quota refresh completed") {
            store.quotaStates[accountID]?.phase == .unsupported
                && !store.isOperationInProgress
        }

        XCTAssertEqual(store.statusMessage, "No ChatGPT/Codex OAuth accounts expose quota.")
    }

    func testQuotaRefreshFailureMarksLoadingStatesAsErrors() async throws {
        let accountID = UUID()
        let account = makeAccount(id: accountID)
        let enabledSettings = AppSettings(allowNetworkQuotaAPIs: true)
        let manifest = AccountManifest(
            accounts: [account],
            activeAccountID: account.id,
            settings: enabledSettings
        )
        let repository = BlockingAccountRepository(
            manifest: manifest,
            snapshotExists: true
        )
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()

        try await waitUntil("automatic quota refresh started") {
            repository.loadCallCount == 2
                && store.isQuotaRefreshInProgress
                && store.quotaStates[accountID]?.phase == .loading
        }

        repository.resumeNextLoad(throwing: CodexKeyringError.fileSystemFailure(reason: "disk full"))
        try await waitUntil("automatic quota refresh failed") {
            store.quotaStates[accountID]?.phase == .error
                && !store.isQuotaRefreshInProgress
                && !store.isOperationInProgress
        }

        XCTAssertEqual(
            store.quotaStates[accountID]?.message,
            "Local storage operation failed: disk full"
        )
        XCTAssertEqual(store.lastError, "Local storage operation failed: disk full")
        XCTAssertEqual(store.statusMessage, "Local storage operation failed: disk full")
    }

    func testAutomaticQuotaRefreshPreservesExistingVisibleError() async throws {
        let accountID = UUID()
        let account = makeAccount(id: accountID)
        let enabledSettings = AppSettings(allowNetworkQuotaAPIs: true)
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [account],
                activeAccountID: accountID,
                settings: enabledSettings
            ),
            snapshotExists: true
        )
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }

        store.lastError = "Previous visible failure."
        store.statusMessage = "Previous visible failure."
        repository.resumeNextLoad()

        try await waitUntil("automatic quota refresh started") {
            repository.loadCallCount == 2
                && store.isQuotaRefreshInProgress
                && store.quotaStates[accountID]?.phase == .loading
        }

        XCTAssertEqual(store.lastError, "Previous visible failure.")
        XCTAssertEqual(store.statusMessage, "Previous visible failure.")

        repository.resumeNextLoad()
        try await waitUntil("automatic quota refresh completed") {
            store.quotaStates[accountID] != nil
                && !store.isOperationInProgress
        }

        XCTAssertEqual(store.lastError, "Previous visible failure.")
        XCTAssertEqual(store.statusMessage, "Previous visible failure.")
    }

    func testRefreshKeepsAutomaticQuotaRefreshStatusWhileQueued() async throws {
        let accountID = UUID()
        let account = makeAccount(id: accountID)
        let enabledSettings = AppSettings(allowNetworkQuotaAPIs: true)
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [account],
                activeAccountID: accountID,
                settings: enabledSettings
            ),
            snapshotExists: true
        )
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }

        repository.resumeNextLoad()
        try await waitUntil("automatic quota refresh started") {
            repository.loadCallCount == 2
                && store.isQuotaRefreshInProgress
                && store.quotaStates[accountID]?.phase == .loading
        }

        XCTAssertEqual(store.statusMessage, "Refreshing account quotas...")

        repository.resumeNextLoad()
        try await waitUntil("automatic quota refresh completed") {
            !store.isOperationInProgress
        }
    }

    func testQuotaAutoRefreshStartsWhenFirstAccountAppears() async throws {
        let accountID = UUID()
        let account = makeAccount(id: accountID)
        let enabledSettings = AppSettings(allowNetworkQuotaAPIs: true)
        let repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [],
                activeAccountID: nil,
                settings: enabledSettings
            ),
            snapshotExists: true
        )
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial refresh completed without quota load") {
            repository.loadCallCount == 1 && !store.isOperationInProgress
        }

        store.refresh()
        try await waitUntil("refresh with first account started") {
            repository.loadCallCount == 2 && store.isRefreshInProgress
        }
        let manifestWithAccount = AccountManifest(
            accounts: [account],
            activeAccountID: account.id,
            settings: enabledSettings
        )
        repository.resumeNextLoad(returning: manifestWithAccount)

        try await waitUntil("automatic quota refresh for first account started") {
            repository.loadCallCount == 3 && store.isQuotaRefreshInProgress
        }
        repository.resumeNextLoad(returning: manifestWithAccount)
        try await waitUntil("automatic quota refresh for first account completed") {
            store.quotaStates[accountID] != nil && !store.isOperationInProgress
        }
    }

    func testQuotaAutoRefreshRunsWhenAdditionalAccountAppears() async throws {
        let firstID = UUID()
        let secondID = UUID()
        let first = makeAccount(id: firstID, alias: "first")
        let second = makeAccount(id: secondID, alias: "second")
        let enabledSettings = AppSettings(allowNetworkQuotaAPIs: true)
        let initialManifest = AccountManifest(
            accounts: [first],
            activeAccountID: first.id,
            settings: enabledSettings
        )
        let repository = BlockingAccountRepository(
            manifest: initialManifest,
            snapshotExists: true
        )
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()

        try await waitUntil("initial quota refresh started") {
            repository.loadCallCount == 2 && store.isQuotaRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial quota refresh completed") {
            store.quotaStates[firstID] != nil && !store.isOperationInProgress
        }

        let expandedManifest = AccountManifest(
            accounts: [first, second],
            activeAccountID: first.id,
            settings: enabledSettings
        )
        store.refresh()
        try await waitUntil("refresh with additional account started") {
            repository.loadCallCount == 3 && store.isRefreshInProgress
        }
        repository.resumeNextLoad(returning: expandedManifest)

        try await waitUntil("quota refresh for additional account started") {
            repository.loadCallCount == 4 && store.isQuotaRefreshInProgress
        }
        repository.resumeNextLoad(returning: expandedManifest)
        try await waitUntil("quota refresh for additional account completed") {
            store.quotaStates[secondID] != nil && !store.isOperationInProgress
        }
    }

    func testQuotaAutoRefreshDoesNotRunWhenOnlyAccountsAreRemoved() async throws {
        let firstID = UUID()
        let secondID = UUID()
        let first = makeAccount(id: firstID, alias: "first")
        let second = makeAccount(id: secondID, alias: "second")
        let enabledSettings = AppSettings(allowNetworkQuotaAPIs: true)
        let initialManifest = AccountManifest(
            accounts: [first, second],
            activeAccountID: first.id,
            settings: enabledSettings
        )
        let repository = BlockingAccountRepository(
            manifest: initialManifest,
            snapshotExists: true
        )
        let store = makeStore(repository: repository)

        try await waitUntil("initial refresh started") {
            repository.loadCallCount == 1 && store.isRefreshInProgress
        }
        repository.resumeNextLoad()

        try await waitUntil("initial quota refresh started") {
            repository.loadCallCount == 2 && store.isQuotaRefreshInProgress
        }
        repository.resumeNextLoad()
        try await waitUntil("initial quota refresh completed") {
            store.quotaStates[firstID] != nil
                && store.quotaStates[secondID] != nil
                && !store.isOperationInProgress
        }

        let reducedManifest = AccountManifest(
            accounts: [first],
            activeAccountID: first.id,
            settings: enabledSettings
        )
        store.refresh()
        try await waitUntil("refresh after account removal started") {
            repository.loadCallCount == 3 && store.isRefreshInProgress
        }
        repository.resumeNextLoad(returning: reducedManifest)
        try await waitUntil("refresh after account removal completed") {
            !store.isOperationInProgress
        }

        XCTAssertEqual(repository.loadCallCount, 3)
        XCTAssertEqual(store.accounts.map(\.id), [firstID])
        XCTAssertNotNil(store.quotaStates[firstID])
        XCTAssertNil(store.quotaStates[secondID])
    }

    private func makeStore(
        repository: BlockingAccountRepository,
        authReader: any AuthFileReading = MissingAuthReader(),
        liveAuthWatcher: any LiveAuthWatching = NoopLiveAuthWatcher(),
        loginService: any CodexLoginServicing = NoopLoginService(),
        installer: any CodexAuthInstalling = NoopInstaller(),
        logService: (any AppLogService)? = nil,
        launchAtLoginController: any LaunchAtLoginControlling = NoopLaunchAtLoginController(),
        appController: any CodexAppControlling = NoopAppController(),
        agentPreferencesPort: any CodexAgentPreferencesPorting = NoopCodexAgentPreferencesPort(),
        startupError: Error? = nil
    ) -> AccountStore {
        AccountStore(
            repository: repository,
            installer: installer,
            authReader: authReader,
            appController: appController,
            launchAtLoginController: launchAtLoginController,
            loginService: loginService,
            agentPreferencesPort: agentPreferencesPort,
            storageLocations: AccountStorageLocations(
                codexAuthPath: "/tmp/auth.json",
                applicationSupportPath: "/tmp/CodexKeyring",
                accountsDirectoryPath: "/tmp/CodexKeyring/Accounts",
                backupsDirectoryPath: "/tmp/CodexKeyring/Backups",
                logsDirectoryPath: "/tmp/CodexKeyring/Logs",
                currentLogFilePath: "/tmp/CodexKeyring/Logs/current.log"
            ),
            openAuthURL: { _ in },
            logService: logService,
            liveAuthWatcher: liveAuthWatcher,
            startupError: startupError
        )
    }

    private func makeAccount(id: UUID, alias: String = "person", email: String? = nil) -> CodexAccount {
        CodexAccount(
            id: id,
            alias: alias,
            email: email ?? "\(alias)@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "\(alias)-account",
            snapshotFileName: "\(alias).auth.json",
            fingerprint: "\(alias)-fingerprint",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            tokenExpiresAt: nil
        )
    }

    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 1,
        predicate: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() {
            if Date() >= deadline {
                XCTFail("Timed out waiting for \(description)")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

private final class BlockingAccountRepository: AccountRepository, @unchecked Sendable {
    private let queue = DispatchQueue(label: "tests.AccountStore.BlockingAccountRepository")
    private var manifest: AccountManifest
    private let snapshotExistsValue: Bool
    private var pendingLoads: [CheckedContinuation<AccountManifest, Error>] = []
    private var _loadCallCount = 0

    init(manifest: AccountManifest, snapshotExists: Bool = false) {
        self.manifest = manifest
        self.snapshotExistsValue = snapshotExists
    }

    var loadCallCount: Int {
        queue.sync { _loadCallCount }
    }

    func load() async throws -> AccountManifest {
        try await withCheckedThrowingContinuation { continuation in
            queue.sync {
                _loadCallCount += 1
                pendingLoads.append(continuation)
            }
        }
    }

    func save(_ manifest: AccountManifest) async throws {
        queue.sync {
            self.manifest = manifest
        }
    }

    func writeSnapshot(from source: URL, for accountID: UUID) async throws -> String {
        "\(accountID.uuidString).auth.json"
    }

    func deleteSnapshot(named fileName: String) async throws {}

    func snapshotURL(named fileName: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(fileName)")
    }

    func snapshotExists(named fileName: String) -> Bool {
        snapshotExistsValue
    }

    func resumeNextLoad(returning overrideManifest: AccountManifest? = nil) {
        let (continuation, value) = queue.sync {
            precondition(!pendingLoads.isEmpty, "No pending load to resume")
            return (pendingLoads.removeFirst(), overrideManifest ?? manifest)
        }
        continuation.resume(returning: value)
    }

    func resumeNextLoad(throwing error: Error) {
        let continuation = queue.sync {
            precondition(!pendingLoads.isEmpty, "No pending load to resume")
            return pendingLoads.removeFirst()
        }
        continuation.resume(throwing: error)
    }
}

private struct NoopInstaller: CodexAuthInstalling {
    let liveAuthFileURL = URL(fileURLWithPath: "/tmp/auth.json")

    func install(snapshot: URL) async throws {}
    func backupCurrent() async throws -> URL? { nil }
    func stageLiveAuthIfPresent(prefix: String) async throws -> URL? { nil }
    func stageRequiredLiveAuth(prefix: String) async throws -> URL { liveAuthFileURL }
    func restoreLiveAuth(from stagedURL: URL?) async throws {}
    func removeStagedAuth(_ url: URL?) async throws {}
}

private struct StagedLoginInstaller: CodexAuthInstalling {
    let liveAuthFileURL: URL
    let preLoginURL: URL?
    let newLoginURL: URL
    let cleanupError: Error?

    func install(snapshot: URL) async throws {}
    func backupCurrent() async throws -> URL? { nil }

    func stageLiveAuthIfPresent(prefix: String) async throws -> URL? {
        preLoginURL
    }

    func stageRequiredLiveAuth(prefix: String) async throws -> URL {
        newLoginURL
    }

    func restoreLiveAuth(from stagedURL: URL?) async throws {}

    func removeStagedAuth(_ url: URL?) async throws {
        if let cleanupError {
            throw cleanupError
        }
    }
}

private struct MissingAuthReader: AuthFileReading {
    func read(from url: URL) async throws -> AuthMetadata {
        throw CodexKeyringError.authFileMissing(url)
    }
}

private struct StaticAuthReader: AuthFileReading {
    var metadata: AuthMetadata

    func read(from url: URL) async throws -> AuthMetadata {
        metadata
    }
}

private struct MappedAuthReader: AuthFileReading {
    var metadataByURL: [URL: AuthMetadata]

    init(_ metadataByURL: [URL: AuthMetadata]) {
        self.metadataByURL = metadataByURL
    }

    func read(from url: URL) async throws -> AuthMetadata {
        guard let metadata = metadataByURL[url] else {
            throw CodexKeyringError.authFileMissing(url)
        }
        return metadata
    }
}

private final class RecordingLogService: AppLogService, @unchecked Sendable {
    private let lock = NSLock()
    private var _exportedURLs: [URL] = []

    let logsDirectoryURL = URL(fileURLWithPath: "/tmp/CodexKeyring/Logs", isDirectory: true)
    let currentLogFileURL = URL(fileURLWithPath: "/tmp/CodexKeyring/Logs/current.log")

    var exportedURLs: [URL] {
        lock.withLock { _exportedURLs }
    }

    func debug(_ message: String) {}
    func info(_ message: String) {}
    func notice(_ message: String) {}
    func warning(_ message: String) {}
    func error(_ message: String) {}

    func exportLogs(to destination: URL) throws {
        lock.withLock {
            _exportedURLs.append(destination)
        }
    }
}

private final class FailingLogService: AppLogService, @unchecked Sendable {
    private let lock = NSLock()
    private let error: Error
    private var _exportedURLs: [URL] = []

    let logsDirectoryURL = URL(fileURLWithPath: "/tmp/CodexKeyring/Logs", isDirectory: true)
    let currentLogFileURL = URL(fileURLWithPath: "/tmp/CodexKeyring/Logs/current.log")

    init(error: Error) {
        self.error = error
    }

    var exportedURLs: [URL] {
        lock.withLock { _exportedURLs }
    }

    func debug(_ message: String) {}
    func info(_ message: String) {}
    func notice(_ message: String) {}
    func warning(_ message: String) {}
    func error(_ message: String) {}

    func exportLogs(to destination: URL) throws {
        lock.withLock {
            _exportedURLs.append(destination)
        }
        throw error
    }
}

private final class BlockingLogService: AppLogService, @unchecked Sendable {
    private let lock = NSLock()
    private let exportSemaphore = DispatchSemaphore(value: 0)
    private var _exportedURLs: [URL] = []
    private var _exportStartedCount = 0

    let logsDirectoryURL = URL(fileURLWithPath: "/tmp/CodexKeyring/Logs", isDirectory: true)
    let currentLogFileURL = URL(fileURLWithPath: "/tmp/CodexKeyring/Logs/current.log")

    var exportedURLs: [URL] {
        lock.withLock { _exportedURLs }
    }

    var exportStartedCount: Int {
        lock.withLock { _exportStartedCount }
    }

    func debug(_ message: String) {}
    func info(_ message: String) {}
    func notice(_ message: String) {}
    func warning(_ message: String) {}
    func error(_ message: String) {}

    func exportLogs(to destination: URL) throws {
        lock.withLock {
            _exportStartedCount += 1
            _exportedURLs.append(destination)
        }
        exportSemaphore.wait()
    }

    func resumeExport() {
        exportSemaphore.signal()
    }
}

private final class ManualLiveAuthWatcher: LiveAuthWatching, @unchecked Sendable {
    private let queue = DispatchQueue(label: "tests.AccountStore.ManualLiveAuthWatcher")
    private var handler: (@Sendable () -> Void)?

    func start(onChange handler: @escaping @Sendable () -> Void) {
        queue.sync {
            self.handler = handler
        }
    }

    func stop() {
        queue.sync {
            handler = nil
        }
    }

    func trigger() {
        let currentHandler = queue.sync { handler }
        currentHandler?()
    }
}

private struct NoopAppController: CodexAppControlling {
    var isRunning: Bool { false }

    func restartIfRunning(
        beforeRelaunch: @Sendable () async throws -> Void
    ) async throws -> CodexAppRestartOutcome {
        .wasNotRunning
    }
}

private struct RelaunchingAppController: CodexAppControlling {
    var isRunning: Bool { true }

    func restartIfRunning(
        beforeRelaunch: @Sendable () async throws -> Void
    ) async throws -> CodexAppRestartOutcome {
        try await beforeRelaunch()
        return .relaunched
    }
}

private struct FailingRestartAppController: CodexAppControlling {
    let reason: String
    var isRunning: Bool { true }

    func restartIfRunning(
        beforeRelaunch: @Sendable () async throws -> Void
    ) async throws -> CodexAppRestartOutcome {
        try await beforeRelaunch()
        throw CodexKeyringError.codexAppRelaunchFailed(reason: reason)
    }
}

private struct NoopLaunchAtLoginController: LaunchAtLoginControlling {
    var isSupported: Bool { true }
    var isEnabled: Bool { false }
    func setEnabled(_ enabled: Bool) throws {}
}

private final class RecordingLaunchAtLoginController: LaunchAtLoginControlling, @unchecked Sendable {
    private let lock = NSLock()
    private var enabled = false
    private var values: [Bool] = []

    var isSupported: Bool { true }

    var isEnabled: Bool {
        lock.withLock { enabled }
    }

    var setEnabledValues: [Bool] {
        lock.withLock { values }
    }

    func setEnabled(_ enabled: Bool) throws {
        lock.withLock {
            self.enabled = enabled
            values.append(enabled)
        }
    }
}

private struct ThrowingAgentPreferencesPort: CodexAgentPreferencesPorting {
    let error: Error

    func captureCurrent() async throws -> AccountAgentPreferences {
        throw error
    }

    func apply(_ preferences: AccountAgentPreferences) async throws {}
}

private struct ApplyThrowingAgentPreferencesPort: CodexAgentPreferencesPorting {
    let error: Error

    func captureCurrent() async throws -> AccountAgentPreferences {
        AccountAgentPreferences()
    }

    func apply(_ preferences: AccountAgentPreferences) async throws {
        throw error
    }
}

private struct ProjectArrangementThrowingAgentPreferencesPort: CodexAgentPreferencesPorting {
    let error: Error

    func captureCurrent() async throws -> AccountAgentPreferences {
        AccountAgentPreferences()
    }

    func apply(_ preferences: AccountAgentPreferences) async throws {}

    func captureProjectArrangement() async throws -> CodexProjectArrangement {
        throw error
    }
}

@MainActor
private final class RecordingURLAccessScope {
    private(set) var stopCount = 0

    func makeScope() -> URLAccessScope {
        URLAccessScope {
            self.stopCount += 1
        }
    }
}

private struct NoopLoginService: CodexLoginServicing {
    func loginWithChatGPT(
        openAuthURL: @escaping @Sendable (URL) async throws -> Void
    ) async throws {}
}

private final class BlockingLoginService: CodexLoginServicing, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var _startedCount = 0

    var startedCount: Int {
        lock.withLock { _startedCount }
    }

    func loginWithChatGPT(
        openAuthURL: @escaping @Sendable (URL) async throws -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                _startedCount += 1
                self.continuation = continuation
            }
        }
    }

    func fail(with error: Error) {
        let continuation = lock.withLock {
            let current = self.continuation
            self.continuation = nil
            return current
        }
        continuation?.resume(throwing: error)
    }
}
