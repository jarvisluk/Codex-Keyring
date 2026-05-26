import Foundation

public enum CodexAppRestartOutcome: Equatable, Sendable {
    /// Codex App was not running before the switch. CLI auth is already live.
    case wasNotRunning
    /// Codex App was running and has been relaunched successfully.
    case relaunched
    /// Codex App was quit but its bundle was not found at the expected location.
    case bundleMissing(path: String)
}

public protocol CodexAppControlling: Sendable {
    var isRunning: Bool { get }
    func restartIfRunning() async throws -> CodexAppRestartOutcome
}
