import XCTest
@testable import CodexKeyringInfrastructure

final class OAuthCallbackServerSuccessTests: OAuthCallbackServerTestCase {
    func testCallbackBeforeWaiterStillReturnsCode() async throws {
        let server = try await OAuthCallbackServer.start(
            expectedState: "expected-state",
            candidatePorts: [0]
        )

        let response = try await request(
            await server.redirectURI,
            query: "code=auth-code&state=expected-state"
        )

        XCTAssertEqual(response.statusCode, 200)

        let result = try await server.waitForCode(timeout: .seconds(1))
        XCTAssertEqual(result.code, "auth-code")
        XCTAssertEqual(result.state, "expected-state")
    }
}
