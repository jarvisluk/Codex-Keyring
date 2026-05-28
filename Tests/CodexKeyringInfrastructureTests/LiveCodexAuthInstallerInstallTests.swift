import XCTest
@testable import CodexKeyringDomain

final class LiveCodexAuthInstallerInstallTests: LiveCodexAuthInstallerTestCase {
    func testInstallWritesLiveAuthWithPrivatePermissions() async throws {
        let snapshot = tempDirectory.appendingPathComponent("snapshot.auth.json")
        try writeAuthFile(snapshot, contents: #"{"tokens":{"access_token":"snapshot"}}"#)

        try await makeInstaller().install(snapshot: snapshot)

        XCTAssertEqual(try String(contentsOf: liveAuthURL, encoding: .utf8), #"{"tokens":{"access_token":"snapshot"}}"#)
        XCTAssertEqual(try filePermissions(at: liveAuthURL), 0o600)
        XCTAssertEqual(try filePermissions(at: codexDirectory), 0o700)
    }

    func testInstallReplacingExistingLiveAuthKeepsPrivatePermissions() async throws {
        let snapshot = tempDirectory.appendingPathComponent("snapshot.auth.json")
        try writeAuthFile(snapshot, contents: #"{"tokens":{"access_token":"snapshot"}}"#)
        try writeAuthFile(liveAuthURL, contents: #"{"tokens":{"access_token":"old"}}"#)

        try await makeInstaller().install(snapshot: snapshot)

        XCTAssertEqual(try String(contentsOf: liveAuthURL, encoding: .utf8), #"{"tokens":{"access_token":"snapshot"}}"#)
        XCTAssertEqual(try filePermissions(at: liveAuthURL), 0o600)
        XCTAssertEqual(try filePermissions(at: codexDirectory), 0o700)
    }

    func testInstallRejectsMissingSnapshot() async throws {
        let snapshot = tempDirectory.appendingPathComponent("missing.auth.json")

        do {
            try await makeInstaller().install(snapshot: snapshot)
            XCTFail("Expected missing snapshot to be rejected.")
        } catch CodexKeyringError.authFileMissing(let url) {
            XCTAssertEqual(url, snapshot)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: codexDirectory.path))
    }

    func testInstallRejectsDirectorySnapshot() async throws {
        let snapshot = tempDirectory.appendingPathComponent("snapshot.auth.json", isDirectory: true)
        try FileManager.default.createDirectory(at: snapshot, withIntermediateDirectories: true)

        do {
            try await makeInstaller().install(snapshot: snapshot)
            XCTFail("Expected directory snapshot to be rejected.")
        } catch CodexKeyringError.fileSystemFailure(let reason) {
            XCTAssertTrue(reason.contains("Snapshot is not a file"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInstallRejectsDirectoryLiveAuthDestination() async throws {
        let snapshot = tempDirectory.appendingPathComponent("snapshot.auth.json")
        try writeAuthFile(snapshot, contents: #"{"tokens":{"access_token":"snapshot"}}"#)
        try FileManager.default.createDirectory(at: liveAuthURL, withIntermediateDirectories: true)

        do {
            try await makeInstaller().install(snapshot: snapshot)
            XCTFail("Expected directory live auth destination to be rejected.")
        } catch CodexKeyringError.fileSystemFailure(let reason) {
            XCTAssertTrue(reason.contains("Live auth path is not a file"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        var isDirectory = ObjCBool(false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: liveAuthURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }
}
