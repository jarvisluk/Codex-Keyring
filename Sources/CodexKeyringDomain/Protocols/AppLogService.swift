import Foundation

/// Application-level logging facade exposed to the UI layer.
///
/// Concrete implementations (see `AppLogger` in the Infrastructure module)
/// fan logs out to both unified logging (`os.Logger`) and a local rolling
/// log file so users can export and share them later from the Settings
/// screen.
public protocol AppLogService: Sendable {
    /// Directory where rolling log files are persisted.
    var logsDirectoryURL: URL { get }

    /// URL of the most recent log file.
    var currentLogFileURL: URL { get }

    func debug(_ message: String)
    func info(_ message: String)
    func notice(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)

    /// Write the combined contents of every retained log file to
    /// `destination`. An implementation should include a short header
    /// describing the export (timestamp, app version) so the resulting
    /// file is self-contained.
    func exportLogs(to destination: URL) throws
}
