import XCTest
@testable import CodexKeyringDomain

final class RefreshAccountQuotasUseCaseGuardTests: XCTestCase {
    func testRefreshAccountQuotasDoesNotQueryWhenNetworkAPIsDisabled() async throws {
        let saved = account(id: UUID(), alias: "plus", metadata: metadata(email: "p@example.com", fingerprint: "p"))
        let repository = accountRepository(accounts: [saved], activeAccountID: saved.id)
        let quotaQuery = MockQuotaQuery { request in
            AccountQuotaQueryResult(state: .available(quotaSnapshot(accountID: request.account.id)))
        }

        let result = try await refreshAccountQuotasUseCase(repository: repository, query: quotaQuery)()

        XCTAssertTrue(result.states.isEmpty)
        XCTAssertTrue(quotaQuery.requests.isEmpty)
    }

    func testRefreshAccountQuotasSkipsApiKeyAndKeepsOtherFailuresIsolated() async throws {
        let good = account(id: UUID(), alias: "good", metadata: metadata(email: "good@example.com", fingerprint: "good"))
        let apiMetadata = AuthMetadata(
            email: "api",
            plan: "API key",
            authMode: "api-key",
            accountIdentifier: "api-key",
            fingerprint: "api",
            tokenExpiresAt: nil
        )
        let api = account(id: UUID(), alias: "api", metadata: apiMetadata)
        let failing = account(id: UUID(), alias: "failing", metadata: metadata(email: "fail@example.com", fingerprint: "fail"))
        let repository = accountRepository(
            accounts: [good, api, failing],
            activeAccountID: good.id,
            settings: quotaEnabledSettings()
        )
        let quotaQuery = MockQuotaQuery { request in
            if request.account.id == failing.id {
                throw CodexKeyringError.quotaQueryFailed(reason: "network down")
            }
            return AccountQuotaQueryResult(state: .available(quotaSnapshot(accountID: request.account.id)))
        }

        let result = try await refreshAccountQuotasUseCase(repository: repository, query: quotaQuery)()

        XCTAssertEqual(quotaQuery.requests.map(\.account.id), [good.id, failing.id])
        XCTAssertEqual(result.states[good.id]?.phase, .available)
        XCTAssertEqual(result.states[api.id]?.phase, .unsupported)
        XCTAssertEqual(result.states[failing.id]?.phase, .error)
    }
}
