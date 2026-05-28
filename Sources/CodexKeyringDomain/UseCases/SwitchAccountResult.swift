import Foundation

public struct SwitchAccountResult: Sendable {
    public let state: AccountState
    public let switchedAlias: String
    public let restartOutcome: CodexAppRestartOutcome?
    public let restartFailureReason: String?
    /// True when the live auth file was already this account's; no backup/replace happened.
    public let wasAlreadyActive: Bool
    /// True when per-account agent preferences were applied to the local Codex
    /// state files as part of this switch.
    public let appliedAgentPreferences: Bool
    /// Non-fatal warning when the switch succeeded but a best-effort agent
    /// preferences step could not be completed.
    public let agentPreferencesWarningReason: String?
    /// Non-fatal warning when the switch succeeded but the local Codex
    /// project/sidebar arrangement could not be preserved around the restart.
    public let projectArrangementWarningReason: String?
}
