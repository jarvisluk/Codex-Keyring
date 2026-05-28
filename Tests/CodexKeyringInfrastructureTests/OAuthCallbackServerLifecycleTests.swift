import Foundation
import XCTest
@testable import CodexKeyringInfrastructure

final class OAuthCallbackServerLifecycleTests: OAuthCallbackServerTestCase {
    func testTimeoutClosesCallbackServer() async throws {
        let server = try await OAuthCallbackServer.start(
            expectedState: "expected-state",
            candidatePorts: [0]
        )
        let redirectURI = await server.redirectURI

        do {
            _ = try await server.waitForCode(timeout: .milliseconds(10))
            XCTFail("Expected callback wait to time out.")
        } catch OAuthCallbackServer.ServerError.timedOut {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await request(redirectURI, query: "code=late-code&state=expected-state")
            XCTFail("Expected timed-out callback server to be closed.")
        } catch {
            XCTAssertTrue(
                (error as NSError).domain == NSURLErrorDomain,
                "Unexpected request error after timeout: \(error)"
            )
        }
    }

    func testCancellingWaitClosesCallbackServer() async throws {
        let server = try await OAuthCallbackServer.start(
            expectedState: "expected-state",
            candidatePorts: [0]
        )
        let redirectURI = await server.redirectURI
        let waitTask = Task {
            try await server.waitForCode(timeout: .seconds(30))
        }
        try await Task.sleep(nanoseconds: 50_000_000)

        waitTask.cancel()

        do {
            _ = try await waitTask.value
            XCTFail("Expected cancelled callback wait to fail.")
        } catch OAuthCallbackServer.ServerError.cancelled {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await request(redirectURI, query: "code=late-code&state=expected-state")
            XCTFail("Expected cancelled callback server to be closed.")
        } catch {
            XCTAssertTrue(
                (error as NSError).domain == NSURLErrorDomain,
                "Unexpected request error after cancellation: \(error)"
            )
        }
    }
}
