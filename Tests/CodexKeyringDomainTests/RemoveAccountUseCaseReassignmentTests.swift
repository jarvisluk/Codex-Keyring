import XCTest
@testable import CodexKeyringDomain

final class RemoveAccountUseCaseReassignmentTests: XCTestCase {
    func testRemoveAccountReassignsActiveByStableIdentifierAfterRotation() async throws {
        let removedMeta = metadata(email: "old@example.com", fingerprint: "old")
        let identifier = "user-B"
        let stored = AuthMetadata(
            email: "b@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fp-B-v1",
            tokenExpiresAt: nil
        )
        let live = AuthMetadata(
            email: "b@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: identifier,
            fingerprint: "fp-B-v2",
            tokenExpiresAt: nil
        )
        let oldAccount = account(id: UUID(), alias: "old", metadata: removedMeta)
        let currentAccount = account(id: UUID(), alias: "current", metadata: stored)
        let liveURL = testAuthURL("live-auth.json")
        let registry = AuthFileRegistry([liveURL: live])
        let repository = accountRepository(
            accounts: [oldAccount, currentAccount],
            activeAccountID: oldAccount.id
        )

        let result = try await removeAccountUseCase(
            repository: repository,
            registry: registry,
            liveAuthFileURL: liveURL
        )(accountID: oldAccount.id)

        let manifest = try await repository.load()
        XCTAssertEqual(manifest.accounts.map(\.id), [currentAccount.id])
        XCTAssertEqual(manifest.activeAccountID, currentAccount.id)
        XCTAssertEqual(result.state.activeAccount?.id, currentAccount.id)
        XCTAssertEqual(result.state.currentAuthMetadata?.fingerprint, "fp-B-v2")
        XCTAssertEqual(repository.saveCount, 1)
        XCTAssertEqual(repository.deletedSnapshots, [oldAccount.snapshotFileName])
    }
}
