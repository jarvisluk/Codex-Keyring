import XCTest
@testable import CodexKeyringInfrastructure

final class ChatGPTOAuthLoginServiceConfigurationTests: XCTestCase {
    func testOpenAIIssuerUsesAuthEndpoint() {
        XCTAssertEqual(
            ChatGPTOAuthLoginService.openAIIssuer.absoluteString,
            "https://auth.openai.com"
        )
    }
}
