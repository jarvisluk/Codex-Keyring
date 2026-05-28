import XCTest
@testable import CodexKeyringDomain

final class AddAccountUseCaseUpdateIdentityTests: XCTestCase {
    func testAddAccountUpdateMatchesStableIdentifierWhenFingerprintRotates() async throws {
        let original = AuthMetadata(
            email: "person@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "old-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 100)
        )
        let rotated = AuthMetadata(
            email: "person@example.com",
            plan: "pro",
            authMode: "chatgpt",
            accountIdentifier: "account-123",
            fingerprint: "new-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 200)
        )
        let existingID = UUID()
        let saved = account(id: existingID, alias: "person", metadata: original)
        let importURL = testAuthURL("import-auth.json")
        let registry = AuthFileRegistry([importURL: rotated])
        let repository = accountRepository(accounts: [saved], activeAccountID: saved.id)

        let result = try await addAccountUseCase(repository: repository, registry: registry)(
            sourceURL: importURL,
            requestedAlias: nil,
            activate: true
        )

        let manifest = try await repository.load()
        let updated = try XCTUnwrap(manifest.accounts.first)
        XCTAssertTrue(result.wasUpdate)
        XCTAssertEqual(manifest.accounts.count, 1)
        XCTAssertEqual(repository.snapshotWriteCount, 1)
        XCTAssertEqual(repository.lastSnapshotWrite?.accountID, existingID)
        XCTAssertEqual(updated.id, existingID)
        XCTAssertEqual(updated.alias, "person")
        XCTAssertEqual(updated.plan, "pro")
        XCTAssertEqual(updated.fingerprint, "new-fingerprint")
        XCTAssertEqual(updated.tokenExpiresAt, Date(timeIntervalSince1970: 200))
    }

    func testAddAccountDoesNotMatchApiKeyPlaceholderIdentifierAcrossFingerprints() async throws {
        let first = AuthMetadata(
            email: "API key account",
            plan: "API key",
            authMode: "api-key",
            accountIdentifier: "api-key",
            fingerprint: "first-key",
            tokenExpiresAt: nil
        )
        let second = AuthMetadata(
            email: "API key account",
            plan: "API key",
            authMode: "api-key",
            accountIdentifier: " API-Key ",
            fingerprint: "second-key",
            tokenExpiresAt: nil
        )
        let saved = account(id: UUID(), alias: "first-api", metadata: first)
        let importURL = testAuthURL("import-auth.json")
        let registry = AuthFileRegistry([importURL: second])
        let repository = accountRepository(accounts: [saved], activeAccountID: saved.id)

        let result = try await addAccountUseCase(repository: repository, registry: registry)(
            sourceURL: importURL,
            requestedAlias: "second-api",
            activate: true
        )

        let manifest = try await repository.load()
        XCTAssertFalse(result.wasUpdate)
        XCTAssertEqual(manifest.accounts.count, 2)
        XCTAssertEqual(manifest.accounts.map(\.alias), ["first-api", "second-api"])
        XCTAssertEqual(Set(manifest.accounts.map(\.fingerprint)), ["first-key", "second-key"])
    }
}
