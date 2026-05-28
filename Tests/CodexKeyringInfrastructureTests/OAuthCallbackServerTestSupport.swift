import Foundation
import XCTest
@testable import CodexKeyringInfrastructure

class OAuthCallbackServerTestCase: XCTestCase {
    func callbackFailure(
        query: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> (body: String, error: OAuthCallbackServer.ServerError) {
        let server = try await OAuthCallbackServer.start(
            expectedState: "expected-state",
            candidatePorts: [0]
        )
        let waitTask = Task {
            try await server.waitForCode(timeout: .seconds(1))
        }

        let result = try await requestData(await server.redirectURI, query: query)
        let body = String(data: result.data, encoding: .utf8) ?? ""
        XCTAssertEqual(result.response.statusCode, 400, file: file, line: line)

        do {
            _ = try await waitTask.value
            XCTFail("Expected callback request to fail.", file: file, line: line)
            throw OAuthCallbackTestFailure.callbackUnexpectedlySucceeded
        } catch let error as OAuthCallbackServer.ServerError {
            return (body, error)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
            throw error
        }
    }

    func request(_ redirectURI: String, query: String) async throws -> HTTPURLResponse {
        try await requestData(redirectURI, query: query).response
    }

    func requestData(
        _ redirectURI: String,
        query: String
    ) async throws -> (data: Data, response: HTTPURLResponse) {
        let url = try XCTUnwrap(URL(string: "\(redirectURI)?\(query)"))
        let (data, response) = try await URLSession.shared.data(from: url)
        return (data, try XCTUnwrap(response as? HTTPURLResponse))
    }
}

private enum OAuthCallbackTestFailure: Error {
    case callbackUnexpectedlySucceeded
}
