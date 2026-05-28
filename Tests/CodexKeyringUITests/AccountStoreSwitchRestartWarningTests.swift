import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreSwitchRestartWarningTests: XCTestCase {
    func testSwitchAppliesStateAndWarningWhenRestartFails() async throws {
        let old = makeAccount(id: UUID(), alias: "old")
        let new = makeAccount(id: UUID(), alias: "new")
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
                installer.liveAuthFileURL: authMetadata(from: old),
                repository.snapshotURL(named: new.snapshotFileName): authMetadata(from: new)
            ]),
            installer: installer,
            appController: FailingRestartAppController(reason: "launch denied")
        )

        try await completeAccountStoreSwitch(store: store, repository: repository, to: new)

        XCTAssertEqual(store.activeAccountID, new.id)
        XCTAssertNil(store.lastError)
        XCTAssertEqual(
            store.statusMessage,
            "Switched Codex CLI auth to new, but Codex App could not be restarted: launch denied"
        )
    }
}
