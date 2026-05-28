import XCTest
@testable import CodexKeyringDomain
@testable import CodexKeyringUI

@MainActor
final class AccountLogExporterTests: XCTestCase {
    func testSuccessfulExportReportsDestination() async throws {
        let service = RecordingExportLogService()
        let destination = URL(fileURLWithPath: "/tmp/codex-keyring-export.log.txt")

        let result = await exportResult(service: service, destination: destination)

        let exportedURL = try XCTUnwrap(result.get())
        XCTAssertEqual(exportedURL, destination)
        XCTAssertEqual(service.exportedURLs, [destination])
        XCTAssertTrue(service.messages.contains("user requested log export to codex-keyring-export.log.txt"))
        XCTAssertTrue(service.messages.contains("log export complete at \(destination.path)"))
    }

    func testFailedExportReportsErrorAndLogsFailure() async {
        let error = CodexKeyringError.fileSystemFailure(reason: "permission denied")
        let service = RecordingExportLogService(error: error)
        let destination = URL(fileURLWithPath: "/tmp/codex-keyring-denied.log.txt")

        let result = await exportResult(service: service, destination: destination)

        XCTAssertThrowsError(try result.get()) { thrown in
            XCTAssertEqual(thrown.localizedDescription, error.localizedDescription)
        }
        XCTAssertEqual(service.exportedURLs, [destination])
        XCTAssertTrue(service.messages.contains("log export failed: \(error.localizedDescription)"))
    }

    private func exportResult(
        service: RecordingExportLogService,
        destination: URL
    ) async -> Result<URL, Error> {
        await withCheckedContinuation { continuation in
            AccountLogExporter.export(logService: service, to: destination) { result in
                continuation.resume(returning: result)
            }
        }
    }
}

private final class RecordingExportLogService: AppLogService, @unchecked Sendable {
    private let lock = NSLock()
    private let error: Error?
    private var _exportedURLs: [URL] = []
    private var _messages: [String] = []

    let logsDirectoryURL = URL(fileURLWithPath: "/tmp/CodexKeyring/Logs", isDirectory: true)
    let currentLogFileURL = URL(fileURLWithPath: "/tmp/CodexKeyring/Logs/current.log")

    init(error: Error? = nil) {
        self.error = error
    }

    var exportedURLs: [URL] {
        lock.withLock { _exportedURLs }
    }

    var messages: [String] {
        lock.withLock { _messages }
    }

    func debug(_ message: String) {}

    func info(_ message: String) {
        record(message)
    }

    func notice(_ message: String) {}

    func warning(_ message: String) {}

    func error(_ message: String) {
        record(message)
    }

    func exportLogs(to destination: URL) throws {
        lock.withLock {
            _exportedURLs.append(destination)
        }
        if let error {
            throw error
        }
    }

    private func record(_ message: String) {
        lock.withLock {
            _messages.append(message)
        }
    }
}
