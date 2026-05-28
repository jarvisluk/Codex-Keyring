import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class ChatGPTQuotaClientRefreshOnlyTests: ChatGPTQuotaClientTestCase {
    func testRefreshOnlySnapshotRefreshesBeforeFetchingUsage() async throws {
        let snapshotURL = try writeRefreshOnlyQuotaAuthJSON(refreshToken: "refresh-only")
        let freshExpiry = Date().addingTimeInterval(3600).timeIntervalSince1970
        let freshAccess = try makeQuotaJWT(payload: [
            "exp": freshExpiry,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "account-refresh",
                "chatgpt_plan_type": "team"
            ],
            "https://api.openai.com/profile": [
                "email": "refresh@example.com"
            ]
        ])

        ChatGPTQuotaMockURLProtocol.setHandler { request in
            switch request.url?.path {
            case "/oauth/token":
                return try .json([
                    "access_token": freshAccess,
                    "refresh_token": "refresh-next"
                ])
            case "/backend-api/wham/usage":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(freshAccess)")
                XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "account-refresh")
                return try .json([
                    "plan_type": "team",
                    "email": "refresh@example.com",
                    "rate_limit": [
                        "primary_window": [
                            "used_percent": 40,
                            "limit_window_seconds": 5 * 60 * 60,
                            "reset_at": 1_735_434_000
                        ]
                    ]
                ])
            default:
                XCTFail("unexpected request: \(request.url?.absoluteString ?? "<nil>")")
                return .status(404)
            }
        }

        let client = try makeClient()
        let result = try await client.queryQuota(for: request(snapshotURL: snapshotURL))

        XCTAssertEqual(ChatGPTQuotaMockURLProtocol.requests.map { $0.url?.path }, ["/oauth/token", "/backend-api/wham/usage"])
        XCTAssertEqual(result.updatedMetadata?.email, "refresh@example.com")
        XCTAssertEqual(result.updatedMetadata?.plan, "team")
        XCTAssertEqual(result.updatedMetadata?.accountIdentifier, "account-refresh")
        XCTAssertEqual(result.updatedMetadata?.tokenExpiresAt, Date(timeIntervalSince1970: freshExpiry))
        XCTAssertEqual(result.state.snapshot?.primaryBucket?.remainingPercent, 60)
        XCTAssertEqual(try quotaTokenValue("access_token", in: snapshotURL), freshAccess)
        XCTAssertEqual(try quotaTokenValue("refresh_token", in: snapshotURL), "refresh-next")
        XCTAssertEqual(try quotaTokenValue("account_id", in: snapshotURL), "account-refresh")
    }
}
