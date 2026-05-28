import XCTest
@testable import CodexKeyringInfrastructure

final class AuthFileParserIOTests: XCTestCase {
    func testAsyncReadRunsOnConfiguredIOQueue() async throws {
        let url = try writeAuthParserJSON([
            "OPENAI_API_KEY": "sk-test"
        ])
        let ioQueue = DispatchQueue(label: "tests.AuthFileParser.suspended")
        let releaseQueue = blockSerialQueue(ioQueue, description: "auth parser io queue")
        var didReleaseQueue = false
        defer {
            if !didReleaseQueue {
                releaseQueue()
            }
        }
        let parser = AuthFileParser(ioQueue: ioQueue)

        let readStarted = expectation(description: "async auth read started")
        let readTask = Task {
            readStarted.fulfill()
            return try await parser.read(from: url)
        }
        await fulfillment(of: [readStarted], timeout: 1)
        let replacementToken = try makeAuthParserJWT(payload: [
            "email": "queued@example.com"
        ])
        let replacement = try JSONSerialization.data(withJSONObject: [
            "auth_mode": "chatgpt",
            "tokens": [
                "id_token": replacementToken
            ]
        ])
        try replacement.write(to: url)

        releaseQueue()
        didReleaseQueue = true
        let metadata = try await readTask.value
        XCTAssertEqual(metadata.email, "queued@example.com")
    }
}
