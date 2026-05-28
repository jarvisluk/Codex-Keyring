import Foundation

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
