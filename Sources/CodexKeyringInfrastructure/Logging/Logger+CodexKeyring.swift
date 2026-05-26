import Foundation
import os

public enum LoggerCategory: String, Sendable {
    case manifest
    case authParser
    case installer
    case codexApp
    case launchAtLogin
    case store
    case oauth
    case app
    case settings
    case agentPrefs
}

public enum CodexKeyringLog {
    public static let subsystem = "com.junrong.CodexKeyring"

    private static let sinkLock = NSLock()
    nonisolated(unsafe) private static var _sharedSink: FileLogSink?

    /// The process-wide file log sink, if `bootstrapFileSink` has been called.
    public static var sharedSink: FileLogSink? {
        sinkLock.lock()
        defer { sinkLock.unlock() }
        return _sharedSink
    }

    /// Initialise (or return) the process-wide file log sink. The first
    /// caller wins; later calls are no-ops and return the existing sink.
    @discardableResult
    public static func bootstrapFileSink(
        directory: URL = AppPaths.logsDirectory,
        fileName: String = AppPaths.logFileName,
        maxFileBytes: Int = 256_000,
        maxFiles: Int = 5
    ) -> FileLogSink {
        sinkLock.lock()
        defer { sinkLock.unlock() }
        if let existing = _sharedSink {
            return existing
        }
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let sink = FileLogSink(
            directory: directory,
            fileName: fileName,
            maxFileBytes: maxFileBytes,
            maxFiles: maxFiles
        )
        _sharedSink = sink
        return sink
    }

    /// Test-only: drop the shared sink so subsequent bootstrap calls succeed.
    public static func resetSharedSinkForTesting() {
        sinkLock.lock()
        defer { sinkLock.unlock() }
        _sharedSink = nil
    }

    /// Legacy convenience preserved for any pure `os.Logger` call sites.
    public static func make(_ category: LoggerCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    /// Construct an `AppLogger` for the supplied category. The logger writes
    /// to both unified logging and the shared file sink (when bootstrapped).
    public static func makeAppLogger(_ category: LoggerCategory) -> AppLogger {
        AppLogger(category: category, subsystem: subsystem, sink: sharedSink)
    }
}
