import XCTest
@testable import CodexKeyringDomain

extension FileSystemManifestRepositoryTestCase {
    func assertAuthFileMissing(
        _ expectedURL: URL,
        file: StaticString = #filePath,
        line: UInt = #line,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected auth file missing error.", file: file, line: line)
        } catch CodexKeyringError.authFileMissing(let url) {
            XCTAssertEqual(url, expectedURL, file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }

    func assertFileSystemFailure(
        contains expectedText: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected file system failure.", file: file, line: line)
        } catch CodexKeyringError.fileSystemFailure(let reason) {
            XCTAssertTrue(
                reason.contains(expectedText),
                "Unexpected reason: \(reason)",
                file: file,
                line: line
            )
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }

    func assertFileSystemFailure(
        equals expectedReason: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected file system failure.", file: file, line: line)
        } catch CodexKeyringError.fileSystemFailure(let reason) {
            XCTAssertEqual(reason, expectedReason, file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }
}
