import XCTest
@testable import CodexKeyringDomain

final class AddAccountUseCaseCreationTests: XCTestCase {
    func testAddAccountCanSaveWithoutActivatingCurrentAccount() async throws {
        let old = metadata(email: "old@example.com", fingerprint: "old")
        let new = metadata(email: "new@example.com", fingerprint: "new")
        let oldAccount = account(id: UUID(), alias: "old", metadata: old)
        let liveURL = testAuthURL("live-auth.json")
        let newURL = testAuthURL("new-auth.json")
        let registry = AuthFileRegistry([liveURL: old, newURL: new])
        let repository = accountRepository(
            accounts: [oldAccount],
            activeAccountID: oldAccount.id
        )

        let result = try await addAccountUseCase(
            repository: repository,
            registry: registry,
            liveAuthFileURL: liveURL,
            clock: FixedClock(Date(timeIntervalSince1970: 100))
        )(
            sourceURL: newURL,
            requestedAlias: nil,
            activate: false
        )

        let saved = try await repository.load()
        XCTAssertEqual(saved.activeAccountID, oldAccount.id)
        XCTAssertEqual(result.state.activeAccountID, oldAccount.id)
        XCTAssertEqual(saved.accounts.map(\.alias).sorted(), ["new", "old"])
        XCTAssertEqual(result.state.currentAuthMetadata?.fingerprint, "old")
    }
}
