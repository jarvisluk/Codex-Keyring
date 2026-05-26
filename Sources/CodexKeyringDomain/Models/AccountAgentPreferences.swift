import Foundation

/// Per-account snapshot of the Codex App / CLI agent preferences that the
/// user expects to follow them across account switches:
///   * model selection
///   * reasoning effort ("speed")
///   * approval policy + reviewer
///   * sandbox mode
///   * Codex App agent mode (full-access / auto-review / read-only)
///   * "skip full-access confirm" UI gate
///
/// All fields are optional: `nil` means "no opinion, leave whatever Codex App
/// currently has". This lets the feature start out empty for accounts that
/// were imported before the feature shipped, and lets users explicitly clear
/// a preference by editing the underlying files.
public struct AccountAgentPreferences: Codable, Equatable, Hashable, Sendable {
    // From ~/.codex/config.toml (root table).
    public var model: String?
    public var modelReasoningEffort: String?
    public var approvalPolicy: String?
    public var approvalsReviewer: String?
    public var sandboxMode: String?

    // From ~/.codex/.codex-global-state.json under "electron-persisted-atom-state".
    /// `agent-mode-by-host-id.local`; e.g. "full-access" / "auto-review" / "read-only".
    public var agentMode: String?
    /// `skip-full-access-confirm`.
    public var skipFullAccessConfirm: Bool?

    public init(
        model: String? = nil,
        modelReasoningEffort: String? = nil,
        approvalPolicy: String? = nil,
        approvalsReviewer: String? = nil,
        sandboxMode: String? = nil,
        agentMode: String? = nil,
        skipFullAccessConfirm: Bool? = nil
    ) {
        self.model = model
        self.modelReasoningEffort = modelReasoningEffort
        self.approvalPolicy = approvalPolicy
        self.approvalsReviewer = approvalsReviewer
        self.sandboxMode = sandboxMode
        self.agentMode = agentMode
        self.skipFullAccessConfirm = skipFullAccessConfirm
    }

    /// True when every field is `nil` — i.e. there is nothing to restore.
    public var isEmpty: Bool {
        model == nil
            && modelReasoningEffort == nil
            && approvalPolicy == nil
            && approvalsReviewer == nil
            && sandboxMode == nil
            && agentMode == nil
            && skipFullAccessConfirm == nil
    }
}

/// Local Codex App project-list arrangement that should remain attached to
/// this Mac, not to a saved Codex account.
public struct CodexProjectArrangement: Equatable, Hashable, Sendable {
    /// Top-level `project-order` from `.codex-global-state.json`.
    public var projectOrder: [String]?
    /// Top-level `pinned-project-ids` from `.codex-global-state.json`.
    public var pinnedProjectIDs: [String]?
    /// `electron-persisted-atom-state.sidebar-organize-mode-v1`.
    public var sidebarOrganizeMode: String?

    public init(
        projectOrder: [String]? = nil,
        pinnedProjectIDs: [String]? = nil,
        sidebarOrganizeMode: String? = nil
    ) {
        self.projectOrder = projectOrder
        self.pinnedProjectIDs = pinnedProjectIDs
        self.sidebarOrganizeMode = sidebarOrganizeMode
    }

    public var isEmpty: Bool {
        projectOrder == nil
            && pinnedProjectIDs == nil
            && sidebarOrganizeMode == nil
    }
}
