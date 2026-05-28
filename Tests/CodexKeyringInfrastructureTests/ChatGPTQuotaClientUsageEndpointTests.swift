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
}
