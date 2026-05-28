import XCTest
@testable import CodexKeyringInfrastructure

final class FileLogSinkExportContentTests: FileLogSinkTestCase {
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
}
