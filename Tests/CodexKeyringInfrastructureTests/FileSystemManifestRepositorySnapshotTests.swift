import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class FileSystemManifestRepositorySnapshotTests: FileSystemManifestRepositoryTestCase {
    func testWriteSnapshotCopiesAndDeleteSnapshotRemovesAccountFile() async throws {
        let repository = makeRepository()
        let accountID = UUID()
        let contents = #"{"tokens":{"access_token":"abc"}}"#
        let source = try writeSnapshotSource(contents: contents)

        let fileName = try await repository.writeSnapshot(from: source, for: accountID)
        let destination = repository.snapshotURL(named: fileName)

        XCTAssertEqual(fileName, snapshotFileName(for: accountID))
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), contents)
        XCTAssertTrue(repository.snapshotExists(named: fileName))
        XCTAssertEqual(try filePermissions(at: destination), 0o600)

        try await repository.deleteSnapshot(named: fileName)

        XCTAssertFalse(repository.snapshotExists(named: fileName))
    }

    func testWriteSnapshotRejectsMissingSourceFile() async throws {
        let repository = makeRepository()
        let accountID = UUID()
        let source = tempDirectory.appendingPathComponent("missing-auth.json")

        await assertAuthFileMissing(source) {
            _ = try await repository.writeSnapshot(from: source, for: accountID)
        }

        let fileName = snapshotFileName(for: accountID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.snapshotURL(named: fileName).path))
    }

    func testWriteSnapshotRejectsDirectorySourcePath() async throws {
        let repository = makeRepository()
        let accountID = UUID()
        let source = tempDirectory.appendingPathComponent("auth.json", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)

        await assertFileSystemFailure(contains: "Snapshot source is not a file") {
            _ = try await repository.writeSnapshot(from: source, for: accountID)
        }

        let fileName = snapshotFileName(for: accountID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.snapshotURL(named: fileName).path))
    }

    func testSnapshotExistsTreatsDirectoryAtSnapshotPathAsMissing() async throws {
        let repository = makeRepository()
        let fileName = snapshotFileName(for: UUID())
        _ = try createSnapshotDirectory(named: fileName)

        XCTAssertFalse(repository.snapshotExists(named: fileName))
    }

    func testDeleteSnapshotRefusesDirectoryAtSnapshotPath() async throws {
        let repository = makeRepository()
        let fileName = snapshotFileName(for: UUID())
        let snapshotPath = try createSnapshotDirectory(named: fileName)

        await assertFileSystemFailure(contains: "Snapshot path is not a file") {
            try await repository.deleteSnapshot(named: fileName)
        }

        assertDirectoryExists(snapshotPath)
    }

    func testWriteSnapshotRefusesDirectoryAtDestination() async throws {
        let repository = makeRepository()
        let accountID = UUID()
        let source = try writeSnapshotSource()
        let fileName = snapshotFileName(for: accountID)
        let snapshotPath = try createSnapshotDirectory(named: fileName)

        await assertFileSystemFailure(contains: "Snapshot path is not a file") {
            _ = try await repository.writeSnapshot(from: source, for: accountID)
        }

        assertDirectoryExists(snapshotPath)
    }

    func testInvalidSnapshotFileNamesCannotEscapeAccountsDirectory() async throws {
        let repository = makeRepository()
        try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        let outside = appDirectory.appendingPathComponent("escape.auth.json")
        try Data("outside".utf8).write(to: outside)

        XCTAssertFalse(repository.snapshotExists(named: "../escape.auth.json"))
        XCTAssertFalse(repository.snapshotExists(named: "/tmp/escape.auth.json"))
        XCTAssertFalse(repository.snapshotExists(named: "nested/escape.auth.json"))
        XCTAssertFalse(repository.snapshotExists(named: "escape.txt"))
        XCTAssertFalse(repository.snapshotExists(named: "not-a-uuid.auth.json"))

        await assertFileSystemFailure(equals: "Invalid snapshot file name.") {
            try await repository.deleteSnapshot(named: "../escape.auth.json")
        }

        XCTAssertEqual(try String(contentsOf: outside, encoding: .utf8), "outside")
    }
}
