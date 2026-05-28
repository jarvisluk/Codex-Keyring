import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class ChatGPTQuotaClientSnapshotValidationTests: ChatGPTQuotaClientTestCase {
    func testMissingSnapshotThrowsDomainMissingErrorBeforeNetworkRequest() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexKeyringQuotaTests-\(UUID().uuidString)", isDirectory: true)
        let snapshotURL = directory.appendingPathComponent("auth.json")
        let client = try makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected missing snapshot to fail.")
        } catch CodexKeyringError.authFileMissing(let url) {
            XCTAssertEqual(url, snapshotURL)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(ChatGPTQuotaMockURLProtocol.requests.isEmpty)
    }

    func testDirectorySnapshotThrowsDomainUnreadableErrorBeforeNetworkRequest() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexKeyringQuotaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshotURL = directory.appendingPathComponent("auth.json", isDirectory: true)
        try FileManager.default.createDirectory(at: snapshotURL, withIntermediateDirectories: true)
        let client = try makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected directory snapshot to fail.")
        } catch CodexKeyringError.authFileUnreadable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(ChatGPTQuotaMockURLProtocol.requests.isEmpty)
    }

    func testMalformedSnapshotJSONThrowsDomainUnreadableErrorBeforeNetworkRequest() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexKeyringQuotaTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshotURL = directory.appendingPathComponent("auth.json")
        try Data("{".utf8).write(to: snapshotURL)
        let client = try makeClient()

        do {
            _ = try await client.queryQuota(for: request(snapshotURL: snapshotURL))
            XCTFail("Expected malformed snapshot to fail.")
        } catch CodexKeyringError.authFileUnreadable {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(ChatGPTQuotaMockURLProtocol.requests.isEmpty)
    }
}
