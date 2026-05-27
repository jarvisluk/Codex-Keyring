import XCTest
@testable import CodexKeyringUI

final class PrivateDirectoryAccessTests: XCTestCase {
    private let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PrivateDirectoryAccessTests-\(UUID().uuidString)", isDirectory: true)

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testEnsureExistsCreatesDirectoryWithOwnerOnlyPermissions() throws {
        let directory = tempDirectory.appendingPathComponent("Logs", isDirectory: true)

        try PrivateDirectoryAccess.ensureExists(at: directory)

        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
        XCTAssertEqual(try filePermissions(at: directory), 0o700)
    }

    func testEnsureExistsTightensExistingDirectoryPermissions() throws {
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempDirectory.path)

        try PrivateDirectoryAccess.ensureExists(at: tempDirectory)

        XCTAssertEqual(try filePermissions(at: tempDirectory), 0o700)
    }

    private func filePermissions(at url: URL) throws -> Int {
        let value = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        )
        return value.intValue & 0o777
    }
}
