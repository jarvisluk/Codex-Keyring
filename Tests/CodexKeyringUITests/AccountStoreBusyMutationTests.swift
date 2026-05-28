import Foundation
import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountStoreBusyMutationTests: XCTestCase {
    func testDirectAccountMutationsAreIgnoredWhileBusy() async throws {
        let account = makeAccount(id: UUID())
        let repository = makeQuotaEnabledRepository(accounts: [account])
        let store = makeStore(repository: repository)

        try await waitForRefreshStarted(repository: repository, store: store)

        store.switchTo(account, restartCodexApp: true)
        store.rename(account, to: "renamed")
        store.remove(account)

        XCTAssertEqual(repository.loadCallCount, 1)
        XCTAssertFalse(store.canSwitch(to: account))
        XCTAssertFalse(store.canBeginRename(account))
        XCTAssertFalse(store.canRename(account, to: "renamed"))
        XCTAssertFalse(store.canRemove(account))

        repository.resumeNextLoad()
        try await waitForQuotaRefreshStarted(
            repository: repository,
            store: store,
            loadCallCount: 2
        )

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
}
