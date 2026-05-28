import Foundation

/// Persisted log entry written to the rolling log file.
public struct LogRecord: Sendable {
    public enum Level: String, Sendable {
        case debug   = "DEBUG"
        case info    = "INFO"
        case notice  = "NOTE"
        case warning = "WARN"
        case error   = "ERROR"
        case fault   = "FAULT"
    }

    public let timestamp: Date
    public let category: String
    public let level: Level
    public let message: String

    public init(timestamp: Date = Date(), category: String, level: Level, message: String) {
        self.timestamp = timestamp
        self.category = category
        self.level = level
        self.message = message
    }
}
