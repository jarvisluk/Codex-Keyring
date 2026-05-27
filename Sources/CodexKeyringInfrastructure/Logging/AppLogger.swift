import Foundation
import os
import CodexKeyringDomain

/// `AppLogService` implementation that mirrors every message into both
/// unified logging (so `log stream` / Console.app keep working) and the
/// shared rolling file sink used by the "Export Logs" feature. Unified
/// log messages are private by default; the local file sink preserves the
/// full message inside the app's private logs directory.
///
/// `AppLogger` is intentionally a value type so call sites can hold a
/// `private let log = ...` without dealing with reference identity. All
/// shared mutable state lives inside `FileLogSink`, which is
/// thread-safe via its internal serial queue.
public struct AppLogger: AppLogService {
    public let category: String
    public let subsystem: String

    private let osLogger: Logger
    private let sink: FileLogSink?

    public init(
        category: String,
        subsystem: String = CodexKeyringLog.subsystem,
        sink: FileLogSink? = CodexKeyringLog.sharedSink
    ) {
        self.category = category
        self.subsystem = subsystem
        self.osLogger = Logger(subsystem: subsystem, category: category)
        self.sink = sink
    }

    public init(
        category: LoggerCategory,
        subsystem: String = CodexKeyringLog.subsystem,
        sink: FileLogSink? = CodexKeyringLog.sharedSink
    ) {
        self.init(category: category.rawValue, subsystem: subsystem, sink: sink)
    }

    // MARK: - AppLogService

    public var logsDirectoryURL: URL {
        sink?.directory ?? AppPaths.logsDirectory
    }

    public var currentLogFileURL: URL {
        sink?.currentFileURL ?? AppPaths.currentLogFile
    }

    public func debug(_ message: String) {
        osLogger.debug("\(message, privacy: .private)")
        sink?.write(LogRecord(category: category, level: .debug, message: message))
    }

    public func info(_ message: String) {
        osLogger.info("\(message, privacy: .private)")
        sink?.write(LogRecord(category: category, level: .info, message: message))
    }

    public func notice(_ message: String) {
        osLogger.notice("\(message, privacy: .private)")
        sink?.write(LogRecord(category: category, level: .notice, message: message))
    }

    public func warning(_ message: String) {
        osLogger.warning("\(message, privacy: .private)")
        sink?.write(LogRecord(category: category, level: .warning, message: message))
    }

    public func error(_ message: String) {
        osLogger.error("\(message, privacy: .private)")
        sink?.write(LogRecord(category: category, level: .error, message: message))
    }

    public func fault(_ message: String) {
        osLogger.fault("\(message, privacy: .private)")
        sink?.write(LogRecord(category: category, level: .fault, message: message))
    }

    public func exportLogs(to destination: URL) throws {
        guard let sink else {
            throw FileLogSinkError.exportFailed(reason: "Logging is not initialised yet.")
        }
        sink.flush()
        try sink.exportCombined(to: destination, header: Self.exportHeader())
    }

    private static func exportHeader() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let process = ProcessInfo.processInfo
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "unknown"
        let os = process.operatingSystemVersionString
        return """
        # Codex Keyring log export
        # Exported: \(formatter.string(from: Date()))
        # App version: \(appVersion) (build \(build))
        # macOS: \(os)
        # Subsystem: \(CodexKeyringLog.subsystem)
        # Note: lines older than this file's retention window are not included.

        """
    }
}
