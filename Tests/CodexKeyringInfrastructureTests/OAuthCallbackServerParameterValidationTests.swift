import XCTest
@testable import CodexKeyringInfrastructure

final class OAuthCallbackServerParameterValidationTests: OAuthCallbackServerTestCase {
    func testDuplicateCallbackParameterIsRejectedWithoutCrashing() async throws {
        let result = try await callbackFailure(
            query: "code=first&code=second&state=expected-state"
        )

        guard case OAuthCallbackServer.ServerError.duplicateParameter(let name) = result.error else {
            return XCTFail("Unexpected error: \(result.error)")
        }
        XCTAssertEqual(name, "code")
    }
}
