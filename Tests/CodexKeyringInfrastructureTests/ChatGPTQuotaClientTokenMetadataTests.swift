import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class ChatGPTQuotaClientTokenMetadataTests: ChatGPTQuotaClientTestCase {
    func testTokenMetadataTrimsJWTClaimsBeforeUsingThem() async throws {
        let accessToken = try makeQuotaJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": " account-from-token ",
                "chatgpt_plan_type": " team "
            ],
            "https://api.openai.com/profile": [
                "email": " token@example.com "
            ]
        ])
        let snapshotURL = try writeQuotaAuthJSON(accessToken: accessToken, accountID: nil)
        ChatGPTQuotaMockURLProtocol.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "account-from-token")
            return try .json([
                "rate_limit": [
                    "primary_window": [
                        "used_percent": 5,
                        "limit_window_seconds": 5 * 60 * 60,
                        "reset_at": 1_735_434_000
                    ]
                ]
            ])
        }

        let client = try makeClient()
        let result = try await client.queryQuota(for: request(snapshotURL: snapshotURL))

        XCTAssertEqual(result.state.snapshot?.planType, "team")
        XCTAssertEqual(result.state.snapshot?.email, "token@example.com")
        XCTAssertEqual(result.state.snapshot?.primaryBucket?.remainingPercent, 95)
    }

    func testQueryQuotaLoadsSnapshotOnConfiguredIOQueue() async throws {
        let oldAccessToken = try makeQuotaJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "old-account",
                "chatgpt_plan_type": "plus"
            ]
        ])
        let queuedAccessToken = try makeQuotaJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "queued-account",
                "chatgpt_plan_type": "pro"
            ]
        ])
        let snapshotURL = try writeQuotaAuthJSON(accessToken: oldAccessToken)
        let ioQueue = DispatchQueue(label: "tests.ChatGPTQuotaClient.suspended")
        let releaseQueue = blockSerialQueue(ioQueue, description: "quota client io queue")
        var didReleaseQueue = false
        defer {
            if !didReleaseQueue {
                releaseQueue()
            }
        }
        ChatGPTQuotaMockURLProtocol.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(queuedAccessToken)")
            XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "queued-account")
            return try .json([
                "plan_type": "pro",
                "rate_limit": [
                    "primary_window": [
                        "used_percent": 25,
                        "limit_window_seconds": 5 * 60 * 60,
                        "reset_at": 1_735_434_000
                    ]
                ]
            ])
        }

        let client = try makeClient(ioQueue: ioQueue)
        let quotaRequest = request(snapshotURL: snapshotURL)
        let queryStarted = expectation(description: "quota query started")
        let quotaTask = Task {
            queryStarted.fulfill()
            return try await client.queryQuota(for: quotaRequest)
        }
        await fulfillment(of: [queryStarted], timeout: 1)

        XCTAssertTrue(ChatGPTQuotaMockURLProtocol.requests.isEmpty)
        try overwriteQuotaAuthJSON(at: snapshotURL, accessToken: queuedAccessToken)

        releaseQueue()
        didReleaseQueue = true
        let result = try await quotaTask.value
        XCTAssertEqual(result.state.snapshot?.planType, "pro")
    }
}
