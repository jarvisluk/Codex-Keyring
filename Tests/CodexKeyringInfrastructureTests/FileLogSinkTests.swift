import XCTest
@testable import CodexKeyringInfrastructure

final class FileLogSinkTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileLogSinkTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
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
    }

    func testReplacesNewlinesInMessage() throws {
        let sink = FileLogSink(
            directory: tempDirectory,
            fileName: "test.log"
        )
        sink.write(LogRecord(category: "store", level: .error, message: "line1\nline2\r\nline3"))
        sink.flush()

        let contents = try String(contentsOf: sink.currentFileURL, encoding: .utf8)
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.filter { !$0.isEmpty }.count, 1)
        XCTAssertTrue(contents.contains("line1 line2 line3"))
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
}
