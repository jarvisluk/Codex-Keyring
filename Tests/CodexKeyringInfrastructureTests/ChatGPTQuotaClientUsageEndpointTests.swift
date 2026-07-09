import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class ChatGPTQuotaClientUsageEndpointTests: ChatGPTQuotaClientTestCase {
    func testDefaultBaseURLUsesChatGPTBackendAPIEndpoint() {
        XCTAssertEqual(
            ChatGPTQuotaClient.defaultBaseURL.absoluteString,
            "https://chatgpt.com/backend-api"
        )
    }

    func testUsageURLPreservesNestedBasePathWithTrailingSlash() async throws {
        let accessToken = try makeQuotaJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970
        ])
        let snapshotURL = try writeQuotaAuthJSON(accessToken: accessToken)
        ChatGPTQuotaMockURLProtocol.setHandler { request in
            XCTAssertEqual(request.url?.absoluteString, "https://chatgpt.test/backend-api/wham/usage")
            XCTAssertEqual(request.url?.path, "/backend-api/wham/usage")
            return try .json([
                "rate_limit": [
                    "primary_window": [
                        "used_percent": 15,
                        "limit_window_seconds": 5 * 60 * 60,
                        "reset_at": 1_735_434_000
                    ]
                ]
            ])
        }

        let client = try makeClient(baseURL: quotaTestURL("https://chatgpt.test/backend-api/"))
        let result = try await client.queryQuota(for: request(snapshotURL: snapshotURL))

        XCTAssertEqual(ChatGPTQuotaMockURLProtocol.requests.map { $0.url?.path }, ["/backend-api/wham/usage"])
        XCTAssertEqual(result.state.snapshot?.endpoint, "https://chatgpt.test/backend-api/wham/usage")
        XCTAssertEqual(result.state.snapshot?.primaryBucket?.remainingPercent, 85)
    }

    func testResetCreditsURLPreservesNestedBasePathAndHeaders() async throws {
        let accessToken = try makeQuotaJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970
        ])
        let snapshotURL = try writeQuotaAuthJSON(accessToken: accessToken, accountID: "account-123")
        ChatGPTQuotaMockURLProtocol.setHandler { request in
            switch request.url?.path {
            case "/backend-api/wham/usage":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(accessToken)")
                XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "account-123")
                return try .json([
                    "rate_limit": [
                        "primary_window": [
                            "used_percent": 15,
                            "limit_window_seconds": 5 * 60 * 60,
                            "reset_at": 1_735_434_000
                        ]
                    ],
                    "rate_limit_reset_credits": [
                        "available_count": 1
                    ]
                ])
            case "/backend-api/wham/rate-limit-reset-credits":
                XCTAssertEqual(
                    request.url?.absoluteString,
                    "https://chatgpt.test/backend-api/wham/rate-limit-reset-credits"
                )
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(accessToken)")
                XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "account-123")
                return try .json([
                    "available_count": 1,
                    "credits": [
                        [
                            "id": "credit-1",
                            "title": "Rate limit reset",
                            "description": "Reset Codex quota",
                            "status": "available",
                            "expires_at": 1_800_000_000
                        ]
                    ]
                ])
            default:
                XCTFail("unexpected request: \(request.url?.absoluteString ?? "<nil>")")
                return .status(404)
            }
        }

        let client = try makeClient(baseURL: quotaTestURL("https://chatgpt.test/backend-api/"))
        let result = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
        let resetCredits = try XCTUnwrap(result.state.snapshot?.rateLimitResetCredits)

        XCTAssertEqual(
            ChatGPTQuotaMockURLProtocol.requests.map { $0.url?.path },
            [
                "/backend-api/wham/usage",
                "/backend-api/wham/rate-limit-reset-credits"
            ]
        )
        XCTAssertEqual(resetCredits.endpoint, "https://chatgpt.test/backend-api/wham/rate-limit-reset-credits")
        XCTAssertEqual(resetCredits.visibleAvailableCount, 1)
        XCTAssertEqual(resetCredits.availableCredits.map(\.id), ["credit-1"])
        XCTAssertEqual(resetCredits.nextExpirationDate, Date(timeIntervalSince1970: 1_800_000_000))
    }
}
