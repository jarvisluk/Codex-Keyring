import XCTest
@testable import CodexKeyringInfrastructure

final class FileLogSinkTests: XCTestCase {
    private let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("FileLogSinkTests-\(UUID().uuidString)", isDirectory: true)

    override func setUpWithError() throws {
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testWritesEntryToCurrentFile() throws {
        let sink = FileLogSink(
            directory: tempDirectory,
            fileName: "test.log",
            maxFileBytes: 4_096,
            maxFiles: 3
        )
        sink.write(LogRecord(category: "store", level: .info, message: "hello world"))
        sink.flush()

        let contents = try String(contentsOf: sink.currentFileURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("[INFO "), "expected INFO marker, got: \(contents)")
        XCTAssertTrue(contents.contains("hello world"))
        XCTAssertTrue(contents.contains("store"))
        XCTAssertEqual(try filePermissions(at: sink.currentFileURL), 0o600)
        XCTAssertEqual(try filePermissions(at: tempDirectory), 0o700)
    }

    func testReplacesNewlinesInMessage() throws {
        let sink = FileLogSink(
            directory: tempDirectory,
            fileName: "test.log"
        )
        sink.write(LogRecord(category: "store", level: .error, message: "line1\nline2\r\nline3\rline4"))
        sink.flush()

        let contents = try String(contentsOf: sink.currentFileURL, encoding: .utf8)
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.filter { !$0.isEmpty }.count, 1)
        XCTAssertTrue(contents.contains("line1 line2 line3 line4"))
    }

    func testRotatesWhenExceedingMaxBytes() throws {
        let sink = FileLogSink(
            directory: tempDirectory,
            fileName: "test.log",
            maxFileBytes: 4_096,
            maxFiles: 3
        )
        let bigMessage = String(repeating: "A", count: 2_000)
        for _ in 0..<6 {
            sink.write(LogRecord(category: "store", level: .info, message: bigMessage))
        }
        sink.flush()

        let urls = sink.snapshotFileURLs()
        XCTAssertGreaterThanOrEqual(urls.count, 2, "expected rotation to create at least one historical file")

        let manager = FileManager.default
        XCTAssertTrue(manager.fileExists(atPath: sink.currentFileURL.path))
        XCTAssertTrue(
            manager.fileExists(atPath: tempDirectory.appendingPathComponent("test.log.1").path),
            "expected test.log.1 after rotation"
        )
        for url in urls {
            XCTAssertEqual(try filePermissions(at: url), 0o600)
        }
    }

    func testRotationCapsRetainedFiles() throws {
        let sink = FileLogSink(
            directory: tempDirectory,
            fileName: "test.log",
            maxFileBytes: 4_096,
            maxFiles: 3
        )
        let chunk = String(repeating: "B", count: 1_500)
        for _ in 0..<40 {
            sink.write(LogRecord(category: "store", level: .info, message: chunk))
        }
        sink.flush()

        let manager = FileManager.default
        XCTAssertTrue(manager.fileExists(atPath: sink.currentFileURL.path))
        XCTAssertTrue(manager.fileExists(atPath: tempDirectory.appendingPathComponent("test.log.1").path))
        XCTAssertTrue(manager.fileExists(atPath: tempDirectory.appendingPathComponent("test.log.2").path))
        XCTAssertFalse(
            manager.fileExists(atPath: tempDirectory.appendingPathComponent("test.log.3").path),
            "rotation should not keep more files than maxFiles"
        )
        for url in sink.snapshotFileURLs() {
            XCTAssertEqual(try filePermissions(at: url), 0o600)
        }
    }

    func testExportCombinedConcatenatesFilesOldestFirst() throws {
        let sink = FileLogSink(
            directory: tempDirectory,
            fileName: "test.log",
            maxFileBytes: 4_096,
            maxFiles: 3
        )
        let chunk = String(repeating: "C", count: 1_500)
        for index in 0..<6 {
            sink.write(LogRecord(category: "store", level: .info, message: "\(index)-\(chunk)"))
        }
        sink.flush()

        let exportURL = tempDirectory.appendingPathComponent("combined.log")
        try sink.exportCombined(to: exportURL, header: "# header\n")

        let exported = try String(contentsOf: exportURL, encoding: .utf8)
        XCTAssertTrue(exported.hasPrefix("# header\n"))
        XCTAssertEqual(try filePermissions(at: exportURL), 0o600)

        let indexLines = exported
            .split(separator: "\n")
            .compactMap { line -> Int? in
                guard let openIndex = line.firstIndex(of: "0"),
                      openIndex == line.firstIndex(where: { $0.isNumber })
                else { return nil }
                let trimmed = line.drop(while: { !$0.isNumber })
                guard let dash = trimmed.firstIndex(of: "-") else { return nil }
                return Int(trimmed[..<dash])
            }
        let strictlyIndexed = indexLines.filter { (0..<6).contains($0) }
        XCTAssertEqual(strictlyIndexed.sorted(), strictlyIndexed, "exported lines should be chronologically ordered")
    }

    func testExportCombinedWithoutAnyLogProducesHeaderOnly() throws {
        let sink = FileLogSink(
            directory: tempDirectory,
            fileName: "test.log"
        )

        let exportURL = tempDirectory.appendingPathComponent("empty.log")
        try sink.exportCombined(to: exportURL, header: "# only-header\n")

        let exported = try String(contentsOf: exportURL, encoding: .utf8)
        XCTAssertEqual(exported, "# only-header\n")
        XCTAssertEqual(try filePermissions(at: exportURL), 0o600)
    }

    func testExportCombinedTightensExistingDestinationPermissions() throws {
        let sink = FileLogSink(
            directory: tempDirectory,
            fileName: "test.log"
        )
        sink.write(LogRecord(category: "store", level: .info, message: "fresh export"))
        sink.flush()
        let exportURL = tempDirectory.appendingPathComponent("combined.log")
        try "previous export\n".write(to: exportURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: exportURL.path)

        try sink.exportCombined(to: exportURL, header: "# header\n")

        let exported = try String(contentsOf: exportURL, encoding: .utf8)
        XCTAssertTrue(exported.contains("fresh export"))
        XCTAssertFalse(exported.contains("previous export"))
        XCTAssertEqual(try filePermissions(at: exportURL), 0o600)
    }

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

    func testResetRemovesAllFiles() throws {
        let sink = FileLogSink(
            directory: tempDirectory,
            fileName: "test.log",
            maxFileBytes: 4_096,
            maxFiles: 3
        )
        for _ in 0..<5 {
            sink.write(LogRecord(category: "store", level: .info, message: String(repeating: "D", count: 1_500)))
        }
        sink.flush()
        XCTAssertFalse(sink.snapshotFileURLs().isEmpty)

        sink.reset()
        XCTAssertTrue(sink.snapshotFileURLs().isEmpty)
    }

    private func filePermissions(at url: URL) throws -> Int {
        let value = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        )
        return value.intValue & 0o777
    }

    private func temporaryExportFiles(for destination: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: destination.deletingLastPathComponent(),
            includingPropertiesForKeys: nil
        )
        .filter { $0.lastPathComponent.hasPrefix(".\(destination.lastPathComponent).tmp-") }
    }
}
