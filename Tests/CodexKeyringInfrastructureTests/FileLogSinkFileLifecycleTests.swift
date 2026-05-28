import XCTest
@testable import CodexKeyringInfrastructure

final class FileLogSinkFileLifecycleTests: FileLogSinkTestCase {
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
