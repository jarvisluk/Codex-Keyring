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
    case currentAuthSyncFailed(reason: String)
    case previousAuthRestoreFailed(reason: String, recoveryPath: String?)
    case manifestRollbackFailed(originalReason: String, rollbackReason: String)
    case snapshotCleanupFailed(originalReason: String, cleanupReason: String, snapshotFileName: String)
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
        case .currentAuthSyncFailed(let reason):
            return "Could not save the current Codex auth back to its saved account: \(reason)"
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
        case .previousAuthRestoreFailed(let reason, let recoveryPath):
            if let recoveryPath {
                return "Previous Codex auth could not be restored: \(reason). A recovery copy was kept at \(recoveryPath)."
            }
            return "Previous Codex auth could not be restored: \(reason)"
        case .manifestRollbackFailed(let originalReason, let rollbackReason):
            return "Account manifest rollback failed after an earlier storage error. Original error: \(originalReason). Rollback error: \(rollbackReason)"
        case .snapshotCleanupFailed(let originalReason, let cleanupReason, _):
            return "Auth snapshot cleanup failed after an earlier storage error. Original error: \(originalReason). Cleanup error: \(cleanupReason)"
        }
    }
}
