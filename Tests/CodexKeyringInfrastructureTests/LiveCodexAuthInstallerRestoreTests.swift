import XCTest
@testable import CodexKeyringDomain

final class LiveCodexAuthInstallerRestoreTests: LiveCodexAuthInstallerTestCase {
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
}
