import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class ChatGPTQuotaClientRefreshLiveAuthRecoveryTests: ChatGPTQuotaClientTestCase {
    func testExpiredActiveTokenUpdatesLiveAuthBeforeSnapshotWriteFailure() async throws {
        let expiredAccess = try makeQuotaJWT(payload: [
            "exp": Date().addingTimeInterval(-3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "account-123",
                "chatgpt_plan_type": "plus"
            ]
        ])
        let freshAccess = try makeQuotaJWT(payload: [
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "https://api.openai.com/auth": [
                "chatgpt_account_id": "account-123",
                "chatgpt_plan_type": "pro"
            ]
        ])
        let snapshotURL = try writeQuotaAuthJSON(accessToken: expiredAccess, refreshToken: "refresh-old")
        let snapshotDirectory = snapshotURL.deletingLastPathComponent()
        let liveDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexKeyringLive-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: liveDirectory, withIntermediateDirectories: true)
        let liveURL = liveDirectory.appendingPathComponent("auth.json")
        try FileManager.default.copyItem(at: snapshotURL, to: liveURL)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: snapshotDirectory.path)
            try? FileManager.default.removeItem(at: snapshotDirectory)
            try? FileManager.default.removeItem(at: liveDirectory)
        }

        ChatGPTQuotaMockURLProtocol.setHandler { request in
            switch request.url?.path {
            case "/oauth/token":
                try FileManager.default.removeItem(at: snapshotURL)
                try FileManager.default.removeItem(at: snapshotDirectory)
                FileManager.default.createFile(
                    atPath: snapshotDirectory.path,
                    contents: Data("not a directory".utf8)
                )
                return try .json([
                    "access_token": freshAccess,
                    "refresh_token": "refresh-new"
                ])
            default:
                XCTFail("unexpected request: \(request.url?.absoluteString ?? "<nil>")")
                return .status(404)
            }
        }

        let client = try makeClient()
        do {
            _ = try await client.queryQuota(
                for: request(snapshotURL: snapshotURL, liveAuthFileURL: liveURL)
            )
            XCTFail("Expected snapshot persistence to fail.")
        } catch CodexKeyringError.fileSystemFailure(let reason) {
            XCTAssertTrue(reason.contains("Could not write refreshed auth snapshot"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(ChatGPTQuotaMockURLProtocol.requests.map { $0.url?.path }, ["/oauth/token"])
        XCTAssertEqual(try quotaTokenValue("access_token", in: liveURL), freshAccess)
        XCTAssertEqual(try quotaTokenValue("refresh_token", in: liveURL), "refresh-new")
    }
}
