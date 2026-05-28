import XCTest
@testable import CodexKeyringInfrastructure

final class ChatGPTOAuthLoginServicePersistenceFailureTests: ChatGPTOAuthLoginServiceTestCase {
    func testLoginRejectsDirectoryAuthDestination() async throws {
        let tempDirectory = try makeOAuthTempDirectory()

        let codexDirectory = tempDirectory.appendingPathComponent("codex", isDirectory: true)
        let authFileURL = codexDirectory.appendingPathComponent("auth.json", isDirectory: true)
        try FileManager.default.createDirectory(at: authFileURL, withIntermediateDirectories: true)

        OAuthLoginURLProtocol.setHandler { _ in
            try .json([
                "id_token": try oauthTestJWT(payload: [:]),
                "access_token": "access-token",
                "refresh_token": "refresh-token"
            ])
        }

        let service = try makeOAuthLoginService(
            authFileURL: authFileURL,
            codexDirectory: codexDirectory
        )

        do {
            try await completeOAuthLogin(service)
            XCTFail("Expected login to reject a directory auth destination.")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Auth destination is not a file"))
        }

        var isDirectory = ObjCBool(false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: authFileURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }
}
