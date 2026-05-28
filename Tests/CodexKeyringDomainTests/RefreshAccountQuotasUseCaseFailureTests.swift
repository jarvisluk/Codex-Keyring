import XCTest
@testable import CodexKeyringDomain

final class RefreshAccountQuotasUseCaseFailureTests: XCTestCase {
    func testRefreshAccountQuotasReportsMissingSnapshotFromQuery() async throws {
        let saved = account(id: UUID(), alias: "saved", metadata: metadata(email: "p@example.com", fingerprint: "p"))
        let repository = accountRepository(
            accounts: [saved],
            activeAccountID: saved.id,
            settings: quotaEnabledSettings()
        )
        let quotaQuery = MockQuotaQuery { _ in
            throw CodexKeyringError.authFileMissing(URL(fileURLWithPath: "/tmp/missing.auth.json"))
        }

        let result = try await refreshAccountQuotasUseCase(
            repository: repository,
            query: quotaQuery,
            clock: FixedClock(Date(timeIntervalSince1970: 123))
        )()

        XCTAssertEqual(quotaQuery.requests.map(\.account.id), [saved.id])
        XCTAssertEqual(result.states[saved.id]?.phase, .error)
        XCTAssertEqual(result.states[saved.id]?.message, "The saved auth snapshot is missing.")
        XCTAssertEqual(result.states[saved.id]?.updatedAt, Date(timeIntervalSince1970: 123))
    }

    func testRefreshAccountQuotasPreservesUnreadableSnapshotFailure() async throws {
        let saved = account(id: UUID(), alias: "saved", metadata: metadata(email: "p@example.com", fingerprint: "p"))
        let repository = accountRepository(
            accounts: [saved],
            activeAccountID: saved.id,
            settings: quotaEnabledSettings()
        )
        let quotaQuery = MockQuotaQuery { _ in
            throw CodexKeyringError.authFileUnreadable
        }

        let result = try await refreshAccountQuotasUseCase(
            repository: repository,
            query: quotaQuery,
            clock: FixedClock(Date(timeIntervalSince1970: 456))
        )()

        XCTAssertEqual(quotaQuery.requests.map(\.account.id), [saved.id])
        XCTAssertEqual(result.states[saved.id]?.phase, .error)
        XCTAssertEqual(result.states[saved.id]?.message, "The selected auth file is not readable JSON.")
        XCTAssertEqual(result.states[saved.id]?.updatedAt, Date(timeIntervalSince1970: 456))
    }
}
