import Foundation
import XCTest
@testable import CodexKeyringUI

final class SettingsFinderDestinationTests: XCTestCase {
    func testSettingsFinderDestinationSelectsExistingLogFile() {
        let logsDirectory = URL(fileURLWithPath: "/tmp/codex-keyring/logs", isDirectory: true)
        let logFile = logsDirectory.appendingPathComponent("current.log")

        let destination = SettingsFinderDestination.logs(
            directory: logsDirectory,
            currentLogFile: logFile,
            fileExists: { $0 == logFile.path }
        )

        XCTAssertEqual(destination.directoryToPrepare, logsDirectory)
        XCTAssertEqual(destination.action, .selectFile(logFile))
    }

    func testSettingsFinderDestinationOpensLogDirectoryWhenCurrentFileIsMissing() {
        let logsDirectory = URL(fileURLWithPath: "/tmp/codex-keyring/logs", isDirectory: true)
        let logFile = logsDirectory.appendingPathComponent("current.log")

        let destination = SettingsFinderDestination.logs(
            directory: logsDirectory,
            currentLogFile: logFile,
            fileExists: { _ in false }
        )

        XCTAssertEqual(destination.directoryToPrepare, logsDirectory)
        XCTAssertEqual(destination.action, .openDirectory(logsDirectory))
    }

    func testSettingsFinderDestinationOpensParentForMissingFileLocation() {
        let authFile = URL(fileURLWithPath: "/tmp/codex/auth.json")
        let parent = authFile.deletingLastPathComponent()

        let destination = SettingsFinderDestination.location(
            path: authFile.path,
            kind: .file,
            fileExists: { _ in false }
        )

        XCTAssertEqual(destination.directoryToPrepare, parent)
        XCTAssertEqual(destination.action, .openDirectory(parent))
    }
}
