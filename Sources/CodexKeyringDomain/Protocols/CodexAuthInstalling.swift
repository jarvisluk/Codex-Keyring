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

    /// Copy the live Codex auth file into temporary staging storage.
    /// Returns nil when there is no live auth file.
    func stageLiveAuthIfPresent(prefix: String) async throws -> URL?

    /// Copy the live Codex auth file into temporary staging storage.
    /// Throws when the live auth file does not exist.
    func stageRequiredLiveAuth(prefix: String) async throws -> URL

    /// Restore a previously staged auth file, or remove the live auth when nil.
    func restoreLiveAuth(from stagedURL: URL?) async throws

    /// Delete a temporary staged auth file.
    func removeStagedAuth(_ url: URL?) async
}
