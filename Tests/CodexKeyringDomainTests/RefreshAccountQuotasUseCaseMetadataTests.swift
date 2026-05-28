import XCTest
@testable import CodexKeyringDomain

final class RefreshAccountQuotasUseCaseMetadataTests: XCTestCase {
    func testRefreshAccountQuotasUpdatesManifestWhenTokenRefreshChangesMetadata() async throws {
        let original = metadata(email: "old@example.com", fingerprint: "old")
        let refreshed = AuthMetadata(
            email: "new@example.com",
            plan: "pro",
            authMode: "chatgpt",
            accountIdentifier: "account-new",
            fingerprint: "new-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 456)
        )
        let saved = account(id: UUID(), alias: "saved", metadata: original)
        let repository = accountRepository(
            accounts: [saved],
            activeAccountID: saved.id,
            settings: quotaEnabledSettings()
        )
        let quotaQuery = MockQuotaQuery { request in
            AccountQuotaQueryResult(
                state: .available(quotaSnapshot(accountID: request.account.id)),
                updatedMetadata: refreshed
            )
        }

        _ = try await refreshAccountQuotasUseCase(
            repository: repository,
            query: quotaQuery,
            clock: FixedClock(Date(timeIntervalSince1970: 999))
        )()

        let manifest = try await repository.load()
        let updated = try XCTUnwrap(manifest.accounts.first)
        XCTAssertEqual(updated.email, "new@example.com")
        XCTAssertEqual(updated.plan, "pro")
        XCTAssertEqual(updated.accountIdentifier, "account-new")
        XCTAssertEqual(updated.fingerprint, "new-fingerprint")
        XCTAssertEqual(updated.updatedAt, Date(timeIntervalSince1970: 999))
    }

    func testRefreshAccountQuotasDoesNotOverwriteUsefulMetadataWithPlaceholders() async throws {
        let original = AuthMetadata(
            email: "known@example.com",
            plan: "plus",
            authMode: "chatgpt",
            accountIdentifier: "account-known",
            fingerprint: "old-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 100)
        )
        let refreshed = AuthMetadata(
            email: "Unknown account",
            plan: "chatgpt",
            authMode: "chatgpt",
            accountIdentifier: "",
            fingerprint: "new-fingerprint",
            tokenExpiresAt: Date(timeIntervalSince1970: 456)
        )
        let saved = account(id: UUID(), alias: "saved", metadata: original)
        let repository = accountRepository(
            accounts: [saved],
            activeAccountID: saved.id,
            settings: quotaEnabledSettings()
        )
        let quotaQuery = MockQuotaQuery { request in
            AccountQuotaQueryResult(
                state: .available(quotaSnapshot(accountID: request.account.id)),
                updatedMetadata: refreshed
            )
        }

        _ = try await refreshAccountQuotasUseCase(
            repository: repository,
            query: quotaQuery,
            clock: FixedClock(Date(timeIntervalSince1970: 999))
        )()

        let manifest = try await repository.load()
        let updated = try XCTUnwrap(manifest.accounts.first)
        XCTAssertEqual(updated.email, "known@example.com")
        XCTAssertEqual(updated.plan, "plus")
        XCTAssertEqual(updated.accountIdentifier, "account-known")
        XCTAssertEqual(updated.fingerprint, "new-fingerprint")
        XCTAssertEqual(updated.tokenExpiresAt, Date(timeIntervalSince1970: 456))
        XCTAssertEqual(updated.updatedAt, Date(timeIntervalSince1970: 999))
    }
}
