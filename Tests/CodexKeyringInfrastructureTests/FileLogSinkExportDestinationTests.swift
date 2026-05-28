import XCTest
@testable import CodexKeyringInfrastructure

final class FileLogSinkExportDestinationTests: FileLogSinkTestCase {
    func testExportCombinedRejectsCurrentLogDestination() throws {
        let sink = FileLogSink(
            directory: tempDirectory,
            fileName: "test.log"
        )
        sink.write(LogRecord(category: "store", level: .info, message: "keep me"))
        sink.flush()

        XCTAssertThrowsError(try sink.exportCombined(to: sink.currentFileURL)) { error in
            XCTAssertEqual(
                error as? FileLogSinkError,
                .exportFailed(reason: "Choose a destination outside Codex Keyring's active log files.")
            )
        }

        let contents = try String(contentsOf: sink.currentFileURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("keep me"))
    }

    func testExportCombinedRejectsLogRotationDestinationsEvenBeforeTheyExist() throws {
        let sink = FileLogSink(
            directory: tempDirectory,
            fileName: "test.log",
            maxFiles: 3
        )
        let manager = FileManager.default
        let retainedURL = tempDirectory.appendingPathComponent("test.log.1")

        XCTAssertFalse(manager.fileExists(atPath: sink.currentFileURL.path))
        XCTAssertFalse(manager.fileExists(atPath: retainedURL.path))

        for destination in [sink.currentFileURL, retainedURL] {
            XCTAssertThrowsError(try sink.exportCombined(to: destination)) { error in
                XCTAssertEqual(
                    error as? FileLogSinkError,
                    .exportFailed(reason: "Choose a destination outside Codex Keyring's active log files.")
                )
            }
        }

        XCTAssertFalse(manager.fileExists(atPath: sink.currentFileURL.path))
        XCTAssertFalse(manager.fileExists(atPath: retainedURL.path))
    }

    func testExportCombinedRejectsDirectoryDestinationWithoutDeletingIt() throws {
        let sink = FileLogSink(
            directory: tempDirectory,
            fileName: "test.log"
        )
        sink.write(LogRecord(category: "store", level: .info, message: "keep me"))
        sink.flush()
        let exportDirectory = tempDirectory.appendingPathComponent("export-target", isDirectory: true)
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        let marker = exportDirectory.appendingPathComponent("marker.txt")
        try "do not delete".write(to: marker, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try sink.exportCombined(to: exportDirectory)) { error in
            XCTAssertEqual(
                error as? FileLogSinkError,
                .exportFailed(reason: "Choose a file destination, not a directory.")
            )
        }

        var isDirectory = ObjCBool(false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportDirectory.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "do not delete")
    }
}
