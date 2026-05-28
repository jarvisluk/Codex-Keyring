import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

func authMetadata(from account: CodexAccount) -> AuthMetadata {
    AuthMetadata(
        email: account.email,
        plan: account.plan,
        authMode: account.authMode,
        accountIdentifier: account.accountIdentifier,
        fingerprint: account.fingerprint,
        tokenExpiresAt: account.tokenExpiresAt
    )
}

@MainActor
func completeAccountStoreSwitch(
    store: AccountStore,
    repository: BlockingAccountRepository,
    to account: CodexAccount,
    restartCodexApp: Bool = true
) async throws {
    try await waitForRefreshStarted(repository: repository, store: store)
    repository.resumeNextLoad()
    try await waitUntil("initial refresh completed") {
        !store.isOperationInProgress
    }

    store.switchTo(account, restartCodexApp: restartCodexApp)
    try await waitUntil("switch started") {
        repository.loadCallCount == 2 && store.isOperationInProgress
    }
    repository.resumeNextLoad()
    try await waitUntil("switch completed") {
        !store.isOperationInProgress
    }
}

@MainActor
struct AccountStoreSwitchTestFixture {
    let old: CodexAccount
    let new: CodexAccount
    let repository: BlockingAccountRepository
    let store: AccountStore

    init(
        old: CodexAccount = makeAccount(id: UUID(), alias: "old"),
        new: CodexAccount = makeAccount(id: UUID(), alias: "new"),
        settings: AppSettings = AppSettings(restartCodexAppAfterSwitch: true),
        snapshotExists: Bool = true,
        authReader: (any AuthFileReading)? = nil,
        appController: any CodexAppControlling = RelaunchingAppController(),
        agentPreferencesPort: any CodexAgentPreferencesPorting = NoopCodexAgentPreferencesPort()
    ) {
        self.old = old
        self.new = new
        repository = BlockingAccountRepository(
            manifest: AccountManifest(
                accounts: [old, new],
                activeAccountID: old.id,
                settings: settings
            ),
            snapshotExists: snapshotExists
        )

        let resolvedAuthReader: any AuthFileReading
        if let authReader {
            resolvedAuthReader = authReader
        } else {
            resolvedAuthReader = StaticAuthReader(metadata: authMetadata(from: old))
        }

        store = makeStore(
            repository: repository,
            authReader: resolvedAuthReader,
            appController: appController,
            agentPreferencesPort: agentPreferencesPort
        )
    }

    func completeInitialRefreshAndSwitch(restartCodexApp: Bool = true) async throws {
        try await completeAccountStoreSwitch(
            store: store,
            repository: repository,
            to: new,
            restartCodexApp: restartCodexApp
        )
    }

    func assertSwitchedToNew(
        statusContains expectedMessages: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(store.activeAccountID, new.id, file: file, line: line)
        XCTAssertNil(store.lastError, file: file, line: line)

        for expectedMessage in expectedMessages {
            XCTAssertTrue(
                store.statusMessage.contains(expectedMessage),
                "Expected status message to contain '\(expectedMessage)', got '\(store.statusMessage)'",
                file: file,
                line: line
            )
        }
    }
}
