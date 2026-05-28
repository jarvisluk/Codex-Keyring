import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class ChatGPTQuotaClientRefreshTokenFailureTests: ChatGPTQuotaClientTestCase {
    func testWhitespaceOnlySnapshotTokensRequireReloginBeforeNetworkRequest() async throws {
        let snapshotURL = try writeQuotaAuthJSON(accessToken: " \n\t ", refreshToken: "   ")
        let client = try makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected whitespace-only tokens to require relogin.")
        } catch CodexKeyringError.quotaRequiresRelogin(let reason) {
            XCTAssertEqual(reason, "The saved auth snapshot has no access or refresh token.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(ChatGPTQuotaMockURLProtocol.requests.isEmpty)
    }

    func testEmptyRefreshAccessTokenFailsBeforeWritingSnapshot() async throws {
        let snapshotURL = try writeExpiredQuotaAuthJSON()
        let originalData = try Data(contentsOf: snapshotURL)
        setRefreshTokenResponse([
            "access_token": "",
            "refresh_token": "refresh-new"
        ])

        let client = try makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected empty refresh access token to fail.")
        } catch CodexKeyringError.quotaQueryFailed(let reason) {
            XCTAssertEqual(reason, "Token refresh returned no access token.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(ChatGPTQuotaMockURLProtocol.requests.map { $0.url?.path }, ["/oauth/token"])
        XCTAssertEqual(try Data(contentsOf: snapshotURL), originalData)
    }

    func testRefreshTokenReusedLeavesSnapshotUnchanged() async throws {
        let snapshotURL = try writeExpiredQuotaAuthJSON()
        let originalData = try Data(contentsOf: snapshotURL)
        setRefreshTokenResponse(
            [
                "error": [
                    "code": "refresh_token_reused"
                ]
            ],
            statusCode: 401
        )

        let client = try makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected refresh token reuse to throw")
        } catch CodexKeyringError.quotaRequiresRelogin(let reason) {
            XCTAssertTrue(reason.contains("already used"))
        }
        XCTAssertEqual(try Data(contentsOf: snapshotURL), originalData)
    }
}
