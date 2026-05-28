import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class ChatGPTOAuthLoginServiceTokenResponseValidationTests: ChatGPTOAuthLoginServiceTestCase {
    func testTokenExchangeRejectsEmptyRequiredTokenFieldsBeforeWritingAuthFile() async throws {
        let fixture = try makeOAuthLoginServiceFixture()

        OAuthLoginURLProtocol.setHandler { _ in
            try .json([
                "id_token": "",
                "access_token": "access-token",
                "refresh_token": "refresh-token"
            ])
        }

        do {
            try await completeOAuthLogin(fixture.service)
            XCTFail("Expected empty token response fields to fail login.")
        } catch CodexKeyringError.codexLoginUnexpectedResponse(let reason) {
            XCTAssertEqual(reason, "Token response was missing required token fields.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.authFileURL.path))
    }
}
