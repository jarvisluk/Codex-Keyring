import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class ChatGPTOAuthLoginServiceAuthorizationFailureTests: ChatGPTOAuthLoginServiceTestCase {
    func testBrowserOpenFailureDoesNotEchoAuthorizationURL() async throws {
        let tempDirectory = try makeOAuthTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let authFileURL = tempDirectory.appendingPathComponent("codex/auth.json")
        let service = try makeOAuthLoginService(
            authFileURL: authFileURL,
            codexDirectory: tempDirectory.appendingPathComponent("codex", isDirectory: true)
        )

        do {
            try await service.loginWithChatGPT { authorizeURL in
                let leakedURLString = authorizeURL.absoluteString
                XCTAssertTrue(leakedURLString.contains("code_challenge="))
                XCTAssertTrue(leakedURLString.contains("state="))
                throw CodexKeyringError.codexLoginFailed(reason: "open failed: \(leakedURLString)")
            }
            XCTFail("Expected browser open failure.")
        } catch CodexKeyringError.codexLoginFailed(let reason) {
            XCTAssertEqual(reason, "Could not open browser for Codex login.")
            XCTAssertFalse(reason.contains("code_challenge"))
            XCTAssertFalse(reason.contains("state="))
            XCTAssertFalse(reason.contains("client_id"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: authFileURL.path))
        XCTAssertTrue(OAuthLoginURLProtocol.requests.isEmpty)
    }

    func testInvalidAuthorizationIssuerFailsWithoutOpeningBrowser() async throws {
        let tempDirectory = try makeOAuthTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let service = try makeOAuthLoginService(
            issuer: "auth.test",
            authFileURL: tempDirectory.appendingPathComponent("codex/auth.json"),
            codexDirectory: tempDirectory.appendingPathComponent("codex", isDirectory: true)
        )

        do {
            try await service.loginWithChatGPT { _ in
                XCTFail("Browser should not open when the authorization URL is invalid.")
            }
            XCTFail("Expected invalid issuer failure")
        } catch CodexKeyringError.codexLoginFailed(let reason) {
            XCTAssertEqual(reason, "Authorization issuer must include a scheme and host.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
