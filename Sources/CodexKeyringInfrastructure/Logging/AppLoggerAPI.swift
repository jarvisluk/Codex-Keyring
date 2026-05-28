import Foundation
import CodexKeyringDomain

extension AppLogger {
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
        try sink.exportCombined(to: destination, header: AppLoggerExportHeader.make())
    }
}
