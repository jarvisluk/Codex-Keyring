import Foundation
@testable import CodexKeyringDomain

final class RecordingLogService: AppLogService, @unchecked Sendable {
    private let lock = NSLock()
    private var _exportedURLs: [URL] = []

    let logsDirectoryURL = URL(fileURLWithPath: "/tmp/CodexKeyring/Logs", isDirectory: true)
    let currentLogFileURL = URL(fileURLWithPath: "/tmp/CodexKeyring/Logs/current.log")

    var exportedURLs: [URL] {
        lock.withLock { _exportedURLs }
    }

    func debug(_ message: String) {}
    func info(_ message: String) {}
    func notice(_ message: String) {}
    func warning(_ message: String) {}
    func error(_ message: String) {}

    func exportLogs(to destination: URL) throws {
        lock.withLock {
            _exportedURLs.append(destination)
        }
    }
}

final class FailingLogService: AppLogService, @unchecked Sendable {
    private let lock = NSLock()
    private let error: Error
    private var _exportedURLs: [URL] = []

    let logsDirectoryURL = URL(fileURLWithPath: "/tmp/CodexKeyring/Logs", isDirectory: true)
    let currentLogFileURL = URL(fileURLWithPath: "/tmp/CodexKeyring/Logs/current.log")

    init(error: Error) {
        self.error = error
    }

    var exportedURLs: [URL] {
        lock.withLock { _exportedURLs }
    }

    func debug(_ message: String) {}
    func info(_ message: String) {}
    func notice(_ message: String) {}
    func warning(_ message: String) {}
    func error(_ message: String) {}

    func exportLogs(to destination: URL) throws {
        lock.withLock {
            _exportedURLs.append(destination)
        }
        throw error
    }
}

final class BlockingLogService: AppLogService, @unchecked Sendable {
    private let lock = NSLock()
    private let exportSemaphore = DispatchSemaphore(value: 0)
    private var _exportedURLs: [URL] = []
    private var _exportStartedCount = 0

    let logsDirectoryURL = URL(fileURLWithPath: "/tmp/CodexKeyring/Logs", isDirectory: true)
    let currentLogFileURL = URL(fileURLWithPath: "/tmp/CodexKeyring/Logs/current.log")

    var exportedURLs: [URL] {
        lock.withLock { _exportedURLs }
    }

    var exportStartedCount: Int {
        lock.withLock { _exportStartedCount }
    }

    func debug(_ message: String) {}
    func info(_ message: String) {}
    func notice(_ message: String) {}
    func warning(_ message: String) {}
    func error(_ message: String) {}

    func exportLogs(to destination: URL) throws {
        lock.withLock {
            _exportStartedCount += 1
            _exportedURLs.append(destination)
        }
        exportSemaphore.wait()
    }

    func resumeExport() {
        exportSemaphore.signal()
    }
}
