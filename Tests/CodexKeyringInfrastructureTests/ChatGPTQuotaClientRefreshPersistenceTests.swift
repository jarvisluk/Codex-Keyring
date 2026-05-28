import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class ChatGPTQuotaClientRefreshPersistenceTests: ChatGPTQuotaClientTestCase {
    func testExpiredAccessTokenRefreshesAndWritesSnapshotAndLiveAuth() async throws {
        let expiredAccess = try makeQuotaJWT(payload: [
            "exp": Date().addingTimeInterval(-3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "account-123",
                "chatgpt_plan_type": "plus"
            ]
        ])
        let freshExpiry = Date().addingTimeInterval(3600).timeIntervalSince1970
        let freshAccess = try makeQuotaJWT(payload: [
            "exp": freshExpiry,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "account-123",
                "chatgpt_plan_type": "pro"
            ]
        ])
        let snapshotURL = try writeQuotaAuthJSON(accessToken: expiredAccess, refreshToken: "refresh-old")
        let liveDirectory = snapshotURL.deletingLastPathComponent().appendingPathComponent("live", isDirectory: true)
        try FileManager.default.createDirectory(at: liveDirectory, withIntermediateDirectories: true)
        let liveURL = liveDirectory.appendingPathComponent("auth.json")
        try FileManager.default.copyItem(at: snapshotURL, to: liveURL)

        ChatGPTQuotaMockURLProtocol.setHandler { request in
            switch request.url?.path {
            case "/oauth/token":
                return try .json([
                    "access_token": freshAccess,
                    "refresh_token": "refresh-new"
                ])
            case "/backend-api/wham/usage":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(freshAccess)")
                return try .json([
                    "plan_type": "pro",
                    "rate_limit": [
                        "primary_window": [
                            "used_percent": 20,
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
        let result = try await client.queryQuota(
            for: request(snapshotURL: snapshotURL, liveAuthFileURL: liveURL)
        )

        XCTAssertEqual(ChatGPTQuotaMockURLProtocol.requests.map { $0.url?.path }, ["/oauth/token", "/backend-api/wham/usage"])
        XCTAssertEqual(result.updatedMetadata?.plan, "pro")
        XCTAssertEqual(result.updatedMetadata?.tokenExpiresAt, Date(timeIntervalSince1970: freshExpiry))
        XCTAssertEqual(result.state.snapshot?.primaryBucket?.remainingPercent, 80)
        XCTAssertEqual(try quotaTokenValue("access_token", in: snapshotURL), freshAccess)
        XCTAssertEqual(try quotaTokenValue("refresh_token", in: snapshotURL), "refresh-new")
        XCTAssertEqual(try quotaTokenValue("access_token", in: liveURL), freshAccess)
        XCTAssertEqual(try quotaTokenValue("refresh_token", in: liveURL), "refresh-new")
        XCTAssertEqual(try quotaFilePermissions(at: snapshotURL), 0o600)
        XCTAssertEqual(try quotaFilePermissions(at: liveURL), 0o600)
        XCTAssertEqual(try quotaFilePermissions(at: snapshotURL.deletingLastPathComponent()), 0o700)
        XCTAssertEqual(try quotaFilePermissions(at: liveDirectory), 0o700)
    }
}
