import Foundation

/// Capture / apply Codex agent preferences against the local Codex App state
/// (`~/.codex/config.toml` and `~/.codex/.codex-global-state.json`).
///
/// Implementations MUST:
///   * Treat missing source files as "no preferences" (`captureCurrent` returns
///     an empty value, never throws).
///   * Preserve every byte of the source files that does not correspond to one
///     of the captured keys when writing back (no whole-file rewrites, no key
///     reordering for JSON, no comment stripping for TOML).
///   * Write atomically.
public protocol CodexAgentPreferencesPorting: Sendable {
    /// Read the current Codex agent preferences from `~/.codex/config.toml` and
    /// `~/.codex/.codex-global-state.json`. Returns an empty value when neither
    /// file exists or none of the tracked keys are present.
    func captureCurrent() async throws -> AccountAgentPreferences

    /// Apply the given preferences to `~/.codex/config.toml` and
    /// `~/.codex/.codex-global-state.json`. Only fields with non-nil values in
    /// `preferences` are written; everything else is left exactly as-is.
    ///
    /// Callers MUST ensure Codex App is not running when this is invoked,
    /// otherwise the running Codex App may overwrite the changes when it quits.
    func apply(_ preferences: AccountAgentPreferences) async throws

    /// Capture local project-list arrangement from
    /// `~/.codex/.codex-global-state.json` after Codex App has quit and
    /// flushed its latest UI state. This is intentionally separate from
    /// `AccountAgentPreferences`: project ordering should survive account
    /// switches instead of following either account.
    func captureProjectArrangement() async throws -> CodexProjectArrangement

    /// Restore a previously captured local project-list arrangement while
    /// Codex App is stopped, before it is relaunched.
    func restoreProjectArrangement(_ arrangement: CodexProjectArrangement) async throws
}

public extension CodexAgentPreferencesPorting {
    func captureProjectArrangement() async throws -> CodexProjectArrangement {
        CodexProjectArrangement()
    }

    func restoreProjectArrangement(_ arrangement: CodexProjectArrangement) async throws {}
}

/// No-op port used in tests / environments without a real Codex install.
public struct NoopCodexAgentPreferencesPort: CodexAgentPreferencesPorting {
    public init() {}

    public func captureCurrent() async throws -> AccountAgentPreferences {
        AccountAgentPreferences()
    }

    public func apply(_ preferences: AccountAgentPreferences) async throws {}
}
