import Foundation
import XCTest
@testable import CodexKeyringDomain

func exampleLoginURL(
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> URL {
    try XCTUnwrap(URL(string: "https://example.test/login"), file: file, line: line)
}

func metadata(
    email: String,
    fingerprint: String,
    accountIdentifier: String? = nil
) -> AuthMetadata {
    AuthMetadata(
        email: email,
        plan: "plus",
        authMode: "chatgpt",
        accountIdentifier: accountIdentifier ?? fingerprint,
        fingerprint: fingerprint,
        tokenExpiresAt: nil
    )
}

func account(id: UUID, alias: String, metadata: AuthMetadata) -> CodexAccount {
    CodexAccount(
        id: id,
        alias: alias,
        email: metadata.email,
        plan: metadata.plan,
        authMode: metadata.authMode,
        accountIdentifier: metadata.accountIdentifier,
        snapshotFileName: "\(id.uuidString).auth.json",
        fingerprint: metadata.fingerprint,
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 1),
        tokenExpiresAt: metadata.tokenExpiresAt
    )
}

func quotaSnapshot(accountID: UUID) -> AccountQuotaSnapshot {
    AccountQuotaSnapshot(
        accountID: accountID,
        planType: "plus",
        email: "person@example.com",
        fetchedAt: Date(timeIntervalSince1970: 100),
        buckets: [
            QuotaBucket(
                limitID: "codex",
                limitName: nil,
                planType: "plus",
                windows: [
                    QuotaWindow(
                        usedPercent: 20,
                        windowDurationMinutes: 5 * 60,
                        resetsAt: Date(timeIntervalSince1970: 200)
                    )
                ],
                credits: nil,
                rateLimitReachedType: nil
            )
        ],
        endpoint: "https://chatgpt.test/backend-api/wham/usage"
    )
}

func quotaEnabledSettings() -> AppSettings {
    AppSettings(allowNetworkQuotaAPIs: true)
}

func decodeSettings(_ json: String) throws -> AppSettings {
    try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
}

func testAuthURL(_ fileName: String) -> URL {
    URL(fileURLWithPath: "/tmp/\(fileName)")
}
