import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class ChatGPTQuotaClientRefreshOAuthErrorSanitizationTests: ChatGPTQuotaClientTestCase {
    func testRefreshFailureSummarizesSafeOAuthDescription() async throws {
        let snapshotURL = try writeExpiredQuotaAuthJSON()
        let originalData = try Data(contentsOf: snapshotURL)
        setRefreshTokenResponse(
            [
                "error": "invalid_grant",
                "error_description": "refresh token expired"
            ],
            statusCode: 401
        )

        let client = try makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected refresh failure to require relogin.")
        } catch CodexKeyringError.quotaRequiresRelogin(let reason) {
            XCTAssertTrue(reason.contains("OAuth token endpoint returned HTTP 401"))
            XCTAssertTrue(reason.contains("invalid_grant"))
            XCTAssertTrue(reason.contains("refresh token expired"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(try Data(contentsOf: snapshotURL), originalData)
    }

    func testRefreshFailureDoesNotEchoSensitiveOAuthDescription() async throws {
        let snapshotURL = try writeExpiredQuotaAuthJSON()
        setRefreshTokenResponse(
            [
                "error": "invalid_grant",
                "error_description": "refresh_token=secret-refresh-token"
            ],
            statusCode: 401
        )

        let client = try makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected refresh failure to require relogin.")
        } catch CodexKeyringError.quotaRequiresRelogin(let reason) {
            XCTAssertTrue(reason.contains("OAuth token endpoint returned HTTP 401"))
            XCTAssertTrue(reason.contains("invalid_grant"))
            XCTAssertFalse(reason.contains("refresh_token"))
            XCTAssertFalse(reason.contains("secret-refresh-token"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
