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

    let osLogger: Logger
    let sink: FileLogSink?

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
}
