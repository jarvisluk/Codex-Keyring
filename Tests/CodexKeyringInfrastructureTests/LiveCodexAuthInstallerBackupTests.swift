import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class LiveCodexAuthInstallerBackupTests: LiveCodexAuthInstallerTestCase {
    func testBackupCurrentWritesPrivatePermissions() async throws {
        try writeAuthFile(liveAuthURL, contents: #"{"tokens":{"access_token":"live"}}"#)

        let maybeBackupURL = try await makeInstaller().backupCurrent()
        let backupURL = try XCTUnwrap(maybeBackupURL)

        XCTAssertEqual(try String(contentsOf: backupURL, encoding: .utf8), #"{"tokens":{"access_token":"live"}}"#)
        XCTAssertEqual(try filePermissions(at: backupURL), 0o600)
        XCTAssertEqual(try filePermissions(at: backupsDirectory), 0o700)
    }

    func testBackupCurrentAvoidsTimestampCollisions() async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let timestamp = DisplayFormatters.fileTimestamp.string(from: date)
        let installer = makeInstaller(clock: FixedClock(date))
        try writeAuthFile(liveAuthURL, contents: #"{"tokens":{"access_token":"first"}}"#)

        let firstBackup = try await installer.backupCurrent()
        let firstBackupURL = try XCTUnwrap(firstBackup)
        try writeAuthFile(liveAuthURL, contents: #"{"tokens":{"access_token":"second"}}"#)
        let secondBackup = try await installer.backupCurrent()
        let secondBackupURL = try XCTUnwrap(secondBackup)

        XCTAssertEqual(firstBackupURL.lastPathComponent, "auth-\(timestamp).json")
        XCTAssertEqual(secondBackupURL.lastPathComponent, "auth-\(timestamp)-1.json")
        XCTAssertEqual(try String(contentsOf: firstBackupURL, encoding: .utf8), #"{"tokens":{"access_token":"first"}}"#)
        XCTAssertEqual(try String(contentsOf: secondBackupURL, encoding: .utf8), #"{"tokens":{"access_token":"second"}}"#)
        XCTAssertEqual(try filePermissions(at: firstBackupURL), 0o600)
        XCTAssertEqual(try filePermissions(at: secondBackupURL), 0o600)
    }

    func testBackupCurrentRunsOnConfiguredIOQueue() async throws {
        try writeAuthFile(liveAuthURL, contents: #"{"tokens":{"access_token":"live"}}"#)
        let ioQueue = DispatchQueue(label: "tests.LiveCodexAuthInstaller.suspended")
        let releaseQueue = blockSerialQueue(ioQueue, description: "auth installer io queue")
        var didReleaseQueue = false
        defer {
            if !didReleaseQueue {
                releaseQueue()
            }
        }
        let installer = makeInstaller(ioQueue: ioQueue)

        let backupStarted = expectation(description: "backup started")
        let backupTask = Task {
            backupStarted.fulfill()
            return try await installer.backupCurrent()
        }
        await fulfillment(of: [backupStarted], timeout: 1)

        XCTAssertFalse(FileManager.default.fileExists(atPath: backupsDirectory.path))

        releaseQueue()
        didReleaseQueue = true
        let maybeBackupURL = try await backupTask.value
        let backupURL = try XCTUnwrap(maybeBackupURL)
        XCTAssertEqual(try String(contentsOf: backupURL, encoding: .utf8), #"{"tokens":{"access_token":"live"}}"#)
    }

    func testBackupCurrentRejectsDirectoryLiveAuth() async throws {
        try FileManager.default.createDirectory(at: liveAuthURL, withIntermediateDirectories: true)

        do {
            _ = try await makeInstaller().backupCurrent()
            XCTFail("Expected directory live auth to be rejected.")
        } catch CodexKeyringError.backupFailed(let reason) {
            XCTAssertTrue(reason.contains("Live auth path is not a file"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
