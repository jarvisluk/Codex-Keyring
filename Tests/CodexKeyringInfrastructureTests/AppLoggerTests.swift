import XCTest
@testable import CodexKeyringInfrastructure

final class AppLoggerTests: XCTestCase {
    private let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("AppLoggerTests-\(UUID().uuidString)", isDirectory: true)

    override func setUpWithError() throws {
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testFileSinkReceivesFullMessageWhenUnifiedLoggingIsPrivate() throws {
        let sink = FileLogSink(directory: tempDirectory, fileName: "app.log")
        let logger = AppLogger(category: "test", sink: sink)
        let message = "switching alias=private@example.com path=/Users/me/.codex/auth.json"

        logger.info(message)
        sink.flush()

        let contents = try String(contentsOf: sink.currentFileURL, encoding: .utf8)
        XCTAssertTrue(contents.contains(message))
    }
}
