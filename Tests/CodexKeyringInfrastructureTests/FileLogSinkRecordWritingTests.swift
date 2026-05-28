import XCTest
@testable import CodexKeyringInfrastructure

final class FileLogSinkRecordWritingTests: FileLogSinkTestCase {
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
}
