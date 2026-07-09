import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class ChatGPTQuotaClientUsagePayloadTests: ChatGPTQuotaClientTestCase {
    func testParsesCodexRateLimitsPayloadIntoFiveHourAndWeeklyWindows() async throws {
        let accessToken = try makeQuotaJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970
        ])
        let snapshotURL = try writeQuotaAuthJSON(accessToken: accessToken)
        ChatGPTQuotaMockURLProtocol.setHandler { _ in
            try .json([
                "rate_limits": [
                    "limit_id": "codex",
                    "limit_name": NSNull(),
                    "primary": [
                        "used_percent": 12,
                        "window_minutes": 5 * 60,
                        "resets_at": 1_778_325_473
                    ],
                    "secondary": [
                        "used_percent": 57,
                        "window_minutes": 7 * 24 * 60,
                        "resets_at": 1_778_589_620
                    ],
                    "credits": NSNull(),
                    "plan_type": "team",
                    "rate_limit_reached_type": NSNull()
                ]
            ])
        }

        let client = try makeClient()
        let result = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
        let primary = try XCTUnwrap(result.state.snapshot?.primaryBucket)

        XCTAssertEqual(primary.windows.map(\.windowDurationMinutes), [5 * 60, 7 * 24 * 60])
        XCTAssertEqual(primary.windows.map(\.remainingPercent), [88, 43])
        XCTAssertEqual(primary.planType, "team")
        XCTAssertFalse(primary.isUnlimited)
        XCTAssertEqual(primary.health, .ready)
    }

    func testBusinessRateLimitsWithoutWindowsParsesAsUnlimited() async throws {
        let accessToken = try makeQuotaJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970
        ])
        let snapshotURL = try writeQuotaAuthJSON(accessToken: accessToken)
        ChatGPTQuotaMockURLProtocol.setHandler { _ in
            try .json([
                "rate_limits": [
                    "limit_id": "codex",
                    "limit_name": NSNull(),
                    "primary": NSNull(),
                    "secondary": NSNull(),
                    "credits": [
                        "has_credits": false,
                        "unlimited": false,
                        "balance": NSNull()
                    ],
                    "plan_type": "business",
                    "rate_limit_reached_type": NSNull()
                ]
            ])
        }

        let client = try makeClient()
        let result = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
        let primary = try XCTUnwrap(result.state.snapshot?.primaryBucket)

        XCTAssertEqual(primary.planType, "business")
        XCTAssertTrue(primary.windows.isEmpty)
        XCTAssertTrue(primary.isUnlimited)
        XCTAssertEqual(primary.health, .ready)
    }

    func testUsesUsageResetCreditsSummaryWhenDetailsEndpointIsUnavailable() async throws {
        let accessToken = try makeQuotaJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970
        ])
        let snapshotURL = try writeQuotaAuthJSON(accessToken: accessToken)
        ChatGPTQuotaMockURLProtocol.setHandler { request in
            switch request.url?.path {
            case "/backend-api/wham/usage":
                return try .json([
                    "rate_limits": [
                        "limit_id": "codex",
                        "limit_name": NSNull(),
                        "primary": [
                            "used_percent": 12,
                            "window_minutes": 5 * 60,
                            "resets_at": 1_778_325_473
                        ],
                        "secondary": NSNull(),
                        "credits": NSNull(),
                        "plan_type": "plus",
                        "rate_limit_reached_type": NSNull()
                    ],
                    "rate_limit_reset_credits": [
                        "available_count": "2"
                    ]
                ])
            case "/backend-api/wham/rate-limit-reset-credits":
                return .status(404)
            default:
                XCTFail("unexpected request: \(request.url?.absoluteString ?? "<nil>")")
                return .status(404)
            }
        }

        let client = try makeClient()
        let result = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
        let resetCredits = try XCTUnwrap(result.state.snapshot?.rateLimitResetCredits)

        XCTAssertEqual(resetCredits.visibleAvailableCount, 2)
        XCTAssertTrue(resetCredits.credits.isEmpty)
        XCTAssertNil(resetCredits.nextExpirationDate)
        XCTAssertEqual(resetCredits.endpoint, "https://chatgpt.test/backend-api/wham/usage")
    }
}
