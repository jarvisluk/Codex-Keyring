import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringInfrastructure

final class LiveCodexAuthInstallerTests: XCTestCase {
    private let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("LiveCodexAuthInstallerTests-\(UUID().uuidString)", isDirectory: true)
    private lazy var codexDirectory = tempDirectory.appendingPathComponent("codex", isDirectory: true)
    private lazy var backupsDirectory = tempDirectory.appendingPathComponent("backups", isDirectory: true)
    private lazy var stagingDirectory = tempDirectory.appendingPathComponent("staging", isDirectory: true)
    private lazy var liveAuthURL = codexDirectory.appendingPathComponent("auth.json")

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

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

    func testStageRequiredLiveAuthWritesPrivatePermissions() async throws {
        try writeAuthFile(liveAuthURL, contents: #"{"tokens":{"access_token":"live"}}"#)

        let stagedURL = try await makeInstaller().stageRequiredLiveAuth(prefix: "login")

        XCTAssertEqual(try String(contentsOf: stagedURL, encoding: .utf8), #"{"tokens":{"access_token":"live"}}"#)
        XCTAssertEqual(try filePermissions(at: stagedURL), 0o600)
        XCTAssertEqual(try filePermissions(at: stagingDirectory), 0o700)
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

    func testStageLiveAuthIfPresentReturnsNilWhenLiveAuthIsMissing() async throws {
        let stagedURL = try await makeInstaller().stageLiveAuthIfPresent(prefix: "login")

        XCTAssertNil(stagedURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stagingDirectory.path))
    }

    func testStageRequiredLiveAuthRejectsMissingLiveAuth() async throws {
        do {
            _ = try await makeInstaller().stageRequiredLiveAuth(prefix: "login")
            XCTFail("Expected missing live auth to be rejected.")
        } catch CodexKeyringError.authFileMissing(let url) {
            XCTAssertEqual(url, liveAuthURL)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStageLiveAuthIfPresentRejectsDirectoryLiveAuth() async throws {
        try FileManager.default.createDirectory(at: liveAuthURL, withIntermediateDirectories: true)

        do {
            _ = try await makeInstaller().stageLiveAuthIfPresent(prefix: "login")
            XCTFail("Expected directory live auth to be rejected.")
        } catch CodexKeyringError.fileSystemFailure(let reason) {
            XCTAssertTrue(reason.contains("Live auth path is not a file"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStageRequiredLiveAuthRejectsDirectoryLiveAuth() async throws {
        try FileManager.default.createDirectory(at: liveAuthURL, withIntermediateDirectories: true)

        do {
            _ = try await makeInstaller().stageRequiredLiveAuth(prefix: "login")
            XCTFail("Expected directory live auth to be rejected.")
        } catch CodexKeyringError.fileSystemFailure(let reason) {
            XCTAssertTrue(reason.contains("Live auth path is not a file"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRestoreWithoutPreviousAuthRejectsDirectoryLiveAuth() async throws {
        try FileManager.default.createDirectory(at: liveAuthURL, withIntermediateDirectories: true)

        do {
            try await makeInstaller().restoreLiveAuth(from: nil)
            XCTFail("Expected directory live auth to be rejected.")
        } catch CodexKeyringError.fileSystemFailure(let reason) {
            XCTAssertTrue(reason.contains("Live auth path is not a file"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        var isDirectory = ObjCBool(false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: liveAuthURL.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    private func makeInstaller(
        clock: Clock = SystemClock(),
        ioQueue: DispatchQueue = DispatchQueue(label: "tests.LiveCodexAuthInstaller.\(UUID().uuidString)")
    ) -> LiveCodexAuthInstaller {
        LiveCodexAuthInstaller(
            liveAuthFileURL: liveAuthURL,
            codexDirectory: codexDirectory,
            backupsDirectory: backupsDirectory,
            loginStagingDirectory: stagingDirectory,
            clock: clock,
            ioQueue: ioQueue
        )
    }

    private func writeAuthFile(_ url: URL, contents: String) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contents.utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
    }

    private func filePermissions(at url: URL) throws -> Int {
        let value = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        )
        return value.intValue & 0o777
    }
}
