import Foundation

public protocol CodexAuthInstalling: Sendable {
    /// URL of the user's active Codex auth.json. Used for parsing the current state.
    var liveAuthFileURL: URL { get }

    /// Replace the live Codex auth file with the bytes from the given snapshot URL.
    func install(snapshot: URL) async throws

    /// Copy the live Codex auth file into the backups directory.
    /// Returns the URL of the written backup, or nil if no live file existed.
    @discardableResult
    func backupCurrent() async throws -> URL?
}
