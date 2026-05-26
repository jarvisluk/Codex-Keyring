import Foundation

public enum CodexKeyringError: Error, Equatable, Sendable {
    case authFileMissing(URL)
    case authFileUnreadable
    case unsupportedAuthShape
    case snapshotMissing(accountID: UUID)
    case backupFailed(reason: String)
    case fileSystemFailure(reason: String)
    case launchAtLoginUnsupported
    case launchAtLoginFailed(reason: String)
    case codexAppRelaunchFailed(reason: String)
    case codexAppBundleNotFound(path: String)
    case codexLoginFailed(reason: String)
    case codexLoginUnexpectedResponse(reason: String)
    case quotaQueryFailed(reason: String)
    case quotaRequiresRelogin(reason: String)
}

extension CodexKeyringError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .authFileMissing(let url):
            return "Codex auth file was not found at \(url.path)."
        case .authFileUnreadable:
            return "The selected auth file is not readable JSON."
        case .unsupportedAuthShape:
            return "The file does not look like a Codex auth.json file."
        case .snapshotMissing:
            return "The saved auth snapshot is missing."
        case .backupFailed(let reason):
            return "Could not back up the current Codex auth before switching: \(reason)"
        case .fileSystemFailure(let reason):
            return "Local storage operation failed: \(reason)"
        case .launchAtLoginUnsupported:
            return "Launch at login requires macOS 13 or newer."
        case .launchAtLoginFailed(let reason):
            return "Could not update launch-at-login: \(reason)"
        case .codexAppRelaunchFailed(let reason):
            return "Failed to restart Codex App: \(reason)"
        case .codexAppBundleNotFound(let path):
            return "Codex App was quit, but \(path) was not found for relaunch."
        case .codexLoginFailed(let reason):
            return "Codex login failed: \(reason)"
        case .codexLoginUnexpectedResponse(let reason):
            return "Codex login returned an unexpected response: \(reason)"
        case .quotaQueryFailed(let reason):
            return "Could not read Codex quota: \(reason)"
        case .quotaRequiresRelogin(let reason):
            return "Codex quota requires signing in again: \(reason)"
        }
    }
}
