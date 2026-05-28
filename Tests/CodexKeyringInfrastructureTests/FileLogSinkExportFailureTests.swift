import XCTest
@testable import CodexKeyringInfrastructure

final class FileLogSinkExportFailureTests: FileLogSinkTestCase {
    func testExportCombinedReportsUnreadableRetainedLogFile() throws {
        let sink = FileLogSink(
            directory: tempDirectory,
            fileName: "test.log",
            maxFiles: 3
        )
        sink.write(LogRecord(category: "store", level: .info, message: "current survives"))
        sink.flush()
        let retainedDirectory = tempDirectory.appendingPathComponent("test.log.1", isDirectory: true)
        try FileManager.default.createDirectory(at: retainedDirectory, withIntermediateDirectories: true)
        let exportURL = tempDirectory.appendingPathComponent("combined.log")

        XCTAssertThrowsError(try sink.exportCombined(to: exportURL)) { error in
            guard case FileLogSinkError.exportFailed(let reason) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertTrue(reason.contains("Could not read \(retainedDirectory.path)"))
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: exportURL.path))
        XCTAssertTrue(try temporaryExportFiles(for: exportURL).isEmpty)
    }

    func testExportCombinedPreservesExistingDestinationWhenReadFails() throws {
        let sink = FileLogSink(
            directory: tempDirectory,
            fileName: "test.log",
            maxFiles: 3
        )
        sink.write(LogRecord(category: "store", level: .info, message: "current survives"))
        sink.flush()
        let retainedDirectory = tempDirectory.appendingPathComponent("test.log.1", isDirectory: true)
        try FileManager.default.createDirectory(at: retainedDirectory, withIntermediateDirectories: true)
        let exportURL = tempDirectory.appendingPathComponent("combined.log")
        try "previous export\n".write(to: exportURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try sink.exportCombined(to: exportURL)) { error in
            guard case FileLogSinkError.exportFailed(let reason) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertTrue(reason.contains("Could not read \(retainedDirectory.path)"))
        }

        XCTAssertEqual(try String(contentsOf: exportURL, encoding: .utf8), "previous export\n")
        XCTAssertTrue(try temporaryExportFiles(for: exportURL).isEmpty)
    }
}
