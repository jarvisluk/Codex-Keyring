import XCTest
@testable import CodexKeyringDomain

final class LiveCodexAuthInstallerStagingTests: LiveCodexAuthInstallerTestCase {
    func testStageRequiredLiveAuthWritesPrivatePermissions() async throws {
        try writeAuthFile(liveAuthURL, contents: #"{"tokens":{"access_token":"live"}}"#)

        let stagedURL = try await makeInstaller().stageRequiredLiveAuth(prefix: "login")

        XCTAssertEqual(try String(contentsOf: stagedURL, encoding: .utf8), #"{"tokens":{"access_token":"live"}}"#)
        XCTAssertEqual(try filePermissions(at: stagedURL), 0o600)
        XCTAssertEqual(try filePermissions(at: stagingDirectory), 0o700)
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
}
