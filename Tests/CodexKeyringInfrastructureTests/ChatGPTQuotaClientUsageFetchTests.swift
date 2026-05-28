import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class ChatGPTQuotaClientUsageFetchTests: ChatGPTQuotaClientTestCase {
    func testFetchesUsageWithHeadersAndParsesBuckets() async throws {
        let accessToken = try makeQuotaJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "account-123",
                "chatgpt_plan_type": "plus"
            ],
            "https://api.openai.com/profile": [
                "email": "token@example.com"
            ]
        ])
        let snapshotURL = try writeQuotaAuthJSON(accessToken: accessToken)
        ChatGPTQuotaMockURLProtocol.setHandler { request in
            XCTAssertEqual(request.url?.path, "/backend-api/wham/usage")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(accessToken)")
            XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "account-123")
            XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "CodexKeyring")
            return try .json([
                "plan_type": "pro",
                "email": "person@example.com",
                "rate_limit": [
                    "primary_window": [
                        "used_percent": 35,
                        "limit_window_seconds": 7 * 24 * 60 * 60,
                        "reset_at": 1_735_693_200
                    ],
                    "secondary_window": [
                        "used_percent": 10,
                        "limit_window_seconds": 5 * 60 * 60,
                        "reset_at": 1_735_434_000
                    ]
                ],
                "credits": [
                    "has_credits": true,
                    "unlimited": false,
                    "balance": "12.5"
                ],
                "additional_rate_limits": [
                    [
                        "limit_name": "codex_other",
                        "metered_feature": "codex_other",
                        "rate_limit": [
                            "primary_window": [
                                "used_percent": 88,
                                "limit_window_seconds": 30 * 60,
                                "reset_at": 1_735_433_000
                            ]
                        ]
                    ]
                ]
            ])
        }

        let client = try makeClient()
        let result = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
        let snapshot = try XCTUnwrap(result.state.snapshot)
        let primary = try XCTUnwrap(snapshot.primaryBucket)
        let other = try XCTUnwrap(snapshot.buckets.first(where: { $0.limitID == "codex_other" }))

        XCTAssertEqual(ChatGPTQuotaMockURLProtocol.requests.count, 1)
        XCTAssertEqual(snapshot.planType, "pro")
        XCTAssertEqual(snapshot.email, "person@example.com")
        XCTAssertEqual(primary.windows.map(\.windowDurationMinutes), [7 * 24 * 60, 5 * 60])
        XCTAssertEqual(primary.remainingPercent, 65)
        XCTAssertEqual(primary.credits?.balance, "12.5")
        XCTAssertEqual(primary.health, .ready)
        XCTAssertEqual(other.health, .low)
    }
}
