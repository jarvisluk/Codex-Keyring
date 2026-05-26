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

    /// Terminate any running Codex App processes, run the supplied hook while
    /// no Codex App process is alive (so callers can safely rewrite Codex
    /// state files without them being overwritten on quit), and finally
    /// relaunch the app.
    ///
    /// If Codex App is not running the hook is NOT executed — callers must
    /// guard their writes with `isRunning` themselves when they need them
    /// applied unconditionally.
    func restartIfRunning(
        beforeRelaunch: @Sendable () async throws -> Void
    ) async throws -> CodexAppRestartOutcome
}

public extension CodexAppControlling {
    func restartIfRunning() async throws -> CodexAppRestartOutcome {
        try await restartIfRunning(beforeRelaunch: {})
    }
}
